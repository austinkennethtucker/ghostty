import SwiftUI
import WebKit

/// NSViewRepresentable wrapping WKWebView for use in SwiftUI.
/// Uses a non-persistent data store for session isolation.
struct BrowserWebView: NSViewRepresentable {
    @ObservedObject var model: BrowserPaneModel

    func makeCoordinator() -> Coordinator {
        Coordinator(model: model)
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        // Non-persistent data store — no cross-session bleed
        config.websiteDataStore = .nonPersistent()

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true

        // Bind model to webView for KVO
        model.bind(to: webView)

        // Load initial URL if set
        if !model.urlString.isEmpty, let url = URL(string: model.urlString) {
            webView.load(URLRequest(url: url))
        }

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        // Updates driven by model.navigate(), not here
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        let model: BrowserPaneModel

        init(model: BrowserPaneModel) {
            self.model = model
        }

        func webView(
            _ webView: WKWebView,
            didReceive challenge: URLAuthenticationChallenge,
            completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
        ) {
            guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
                  let serverTrust = challenge.protectionSpace.serverTrust else {
                completionHandler(.performDefaultHandling, nil)
                return
            }

            // If TLS validation is disabled entirely
            if !model.tlsStrict {
                completionHandler(.useCredential, URLCredential(trust: serverTrust))
                return
            }

            // If a proxy CA cert is configured, trust it for this connection only
            if let certPath = model.proxyCertPath,
               let cert = loadCertificate(fromPEM: certPath) {
                SecTrustSetAnchorCertificates(serverTrust, [cert] as CFArray)
                SecTrustSetAnchorCertificatesOnly(serverTrust, false)
                completionHandler(.useCredential, URLCredential(trust: serverTrust))
                return
            }

            completionHandler(.performDefaultHandling, nil)
        }

        /// Load a PEM-encoded certificate file and return a SecCertificate.
        /// Strips PEM headers and decodes base64 to DER format.
        private func loadCertificate(fromPEM path: String) -> SecCertificate? {
            guard let pemData = try? String(contentsOfFile: path, encoding: .utf8) else { return nil }
            let base64 = pemData
                .replacingOccurrences(of: "-----BEGIN CERTIFICATE-----", with: "")
                .replacingOccurrences(of: "-----END CERTIFICATE-----", with: "")
                .replacingOccurrences(of: "\n", with: "")
                .replacingOccurrences(of: "\r", with: "")
            guard let derData = Data(base64Encoded: base64) else { return nil }
            return SecCertificateCreateWithData(nil, derData as CFData)
        }
    }
}
