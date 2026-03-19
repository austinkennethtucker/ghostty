import Darwin
import Foundation

/// Unix domain socket server that accepts newline-delimited JSON commands
/// and returns JSON responses. Used for programmatic control of a browser pane.
class BrowserSocketServer {
    let socketPath: String
    let paneId: UUID
    private var socketFD: Int32 = -1
    private var listenSource: DispatchSourceRead?
    private var clientSources: [Int32: DispatchSourceRead] = [:]
    private let queue = DispatchQueue(label: "com.trident.browser-socket", qos: .userInitiated)
    weak var model: BrowserPaneModel?

    init(paneId: UUID) {
        self.paneId = paneId
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("trident", isDirectory: true)
        try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        self.socketPath = tmpDir.appendingPathComponent("browser-\(paneId.uuidString).sock").path
    }

    deinit {
        stop()
    }

    // MARK: - Lifecycle

    func start() throws {
        // Remove stale socket file if present
        unlink(socketPath)

        // Create socket
        socketFD = socket(AF_UNIX, SOCK_STREAM, 0)
        guard socketFD >= 0 else {
            throw ServerError.socketCreationFailed(errno: errno)
        }

        // Bind to path
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = socketPath.utf8CString
        guard pathBytes.count <= MemoryLayout.size(ofValue: addr.sun_len) + MemoryLayout.size(ofValue: addr.sun_path) else {
            Darwin.close(socketFD)
            socketFD = -1
            throw ServerError.pathTooLong
        }
        withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            let raw = UnsafeMutableRawPointer(ptr)
            pathBytes.withUnsafeBufferPointer { buf in
                raw.copyMemory(from: buf.baseAddress!, byteCount: buf.count)
            }
        }
        addr.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)

        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                bind(socketFD, sockPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bindResult == 0 else {
            let err = errno
            Darwin.close(socketFD)
            socketFD = -1
            throw ServerError.bindFailed(errno: err)
        }

        // Set socket permissions to owner-only (0600)
        chmod(socketPath, 0o600)

        // Listen for connections
        guard listen(socketFD, 5) == 0 else {
            let err = errno
            Darwin.close(socketFD)
            socketFD = -1
            unlink(socketPath)
            throw ServerError.listenFailed(errno: err)
        }

        // Set up GCD dispatch source for accepting connections
        let source = DispatchSource.makeReadSource(fileDescriptor: socketFD, queue: queue)
        source.setEventHandler { [weak self] in
            self?.acceptConnection()
        }
        source.setCancelHandler { [weak self] in
            if let fd = self?.socketFD, fd >= 0 {
                Darwin.close(fd)
                self?.socketFD = -1
            }
        }
        listenSource = source
        source.resume()
    }

    func stop() {
        // Cancel listen source
        listenSource?.cancel()
        listenSource = nil

        // Cancel all client sources
        for (fd, source) in clientSources {
            source.cancel()
            Darwin.close(fd)
        }
        clientSources.removeAll()

        // Close socket FD if still open
        if socketFD >= 0 {
            Darwin.close(socketFD)
            socketFD = -1
        }

        // Remove socket file
        unlink(socketPath)
    }

    // MARK: - Connection Handling

    private func acceptConnection() {
        var clientAddr = sockaddr_un()
        var clientAddrLen = socklen_t(MemoryLayout<sockaddr_un>.size)
        let clientFD = withUnsafeMutablePointer(to: &clientAddr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                accept(socketFD, sockPtr, &clientAddrLen)
            }
        }
        guard clientFD >= 0 else { return }

        // Create per-client read source
        let clientSource = DispatchSource.makeReadSource(fileDescriptor: clientFD, queue: queue)
        var buffer = Data()

        clientSource.setEventHandler { [weak self] in
            self?.readFromClient(fd: clientFD, buffer: &buffer)
        }
        clientSource.setCancelHandler { [weak self] in
            Darwin.close(clientFD)
            self?.clientSources.removeValue(forKey: clientFD)
        }
        clientSources[clientFD] = clientSource
        clientSource.resume()
    }

    private func readFromClient(fd: Int32, buffer: inout Data) {
        var readBuf = [UInt8](repeating: 0, count: 4096)
        let bytesRead = read(fd, &readBuf, readBuf.count)

        if bytesRead <= 0 {
            // Client disconnected or error
            clientSources[fd]?.cancel()
            return
        }

        buffer.append(contentsOf: readBuf[0..<bytesRead])

        // Process complete lines (newline-delimited JSON)
        while let newlineIndex = buffer.firstIndex(of: UInt8(ascii: "\n")) {
            let lineData = buffer[buffer.startIndex..<newlineIndex]
            buffer.removeSubrange(buffer.startIndex...newlineIndex)

            guard let lineString = String(data: lineData, encoding: .utf8),
                  !lineString.isEmpty else { continue }

            // Parse JSON command
            guard let jsonData = lineString.data(using: .utf8),
                  let command = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                let errorResponse: [String: Any] = ["ok": false, "error": "invalid JSON"]
                sendResponse(errorResponse, to: fd)
                continue
            }

            // Dispatch to main thread for WKWebView access
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                let response = self.handleCommand(command)
                self.queue.async {
                    self.sendResponse(response, to: fd)
                }
            }
        }
    }

    private func sendResponse(_ response: [String: Any], to fd: Int32) {
        guard let data = try? JSONSerialization.data(withJSONObject: response),
              var responseString = String(data: data, encoding: .utf8) else { return }
        responseString.append("\n")
        responseString.withCString { ptr in
            _ = write(fd, ptr, strlen(ptr))
        }
    }

    // MARK: - Command Handling

    /// Handle a JSON command dictionary and return a response dictionary.
    /// Called on the main thread so WKWebView access is safe.
    private func handleCommand(_ command: [String: Any]) -> [String: Any] {
        guard let cmd = command["cmd"] as? String else {
            return ["ok": false, "error": "missing 'cmd' field"]
        }

        switch cmd {
        case "navigate":
            guard let url = command["url"] as? String else {
                return ["ok": false, "error": "missing 'url' parameter"]
            }
            model?.navigate(to: url)
            return ["ok": true]

        case "back":
            model?.goBack()
            return ["ok": true]

        case "forward":
            model?.goForward()
            return ["ok": true]

        case "reload":
            model?.reload()
            return ["ok": true]

        case "status":
            return [
                "ok": true,
                "url": model?.urlString as Any,
                "title": model?.pageTitle as Any,
                "loading": model?.isLoading as Any,
            ]

        default:
            return ["ok": false, "error": "unknown command"]
        }
    }

    // MARK: - Errors

    enum ServerError: Error {
        case socketCreationFailed(errno: Int32)
        case pathTooLong
        case bindFailed(errno: Int32)
        case listenFailed(errno: Int32)
    }
}
