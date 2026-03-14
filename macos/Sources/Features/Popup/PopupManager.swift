import Cocoa
import GhosttyKit

/// Registry that owns and manages PopupController instances.
///
/// Each named popup profile gets at most one controller. Controllers are
/// created lazily on first toggle/show and kept alive for the lifetime
/// of the manager (or until explicitly removed).
class PopupManager {
    private let ghosttyApp: Ghostty.App
    private var controllers: [String: PopupController] = [:]

    /// Profile configurations keyed by name.  Populated from the Ghostty
    /// config in a future task (Task 20) via the C API.
    private var profileConfigs: [String: PopupController.PopupProfileConfig] = [:]

    init(ghosttyApp: Ghostty.App) {
        self.ghosttyApp = ghosttyApp
        // TODO: Load popup profiles from config via C API (Task 20).
    }

    // MARK: - Public API

    /// Toggle the named popup: show it if hidden, hide it if visible.
    func toggle(_ name: String) {
        let controller = getOrCreateController(name: name)
        controller.toggle()
    }

    /// Ensure the named popup is visible.
    func show(_ name: String) {
        let controller = getOrCreateController(name: name)
        controller.show()
    }

    /// Hide the named popup if it exists and is visible.
    func hide(_ name: String) {
        controllers[name]?.hide()
    }

    /// Hide every popup that is currently showing.
    func hideAll() {
        for controller in controllers.values {
            controller.hide()
        }
    }

    // MARK: - Profile Config Management

    /// Update the stored profile configurations (called when the Ghostty
    /// config is reloaded).  Existing controllers are NOT recreated — they
    /// keep the config they were created with.
    func updateProfileConfigs(_ configs: [String: PopupController.PopupProfileConfig]) {
        self.profileConfigs = configs
    }

    // MARK: - Private

    private func getOrCreateController(name: String) -> PopupController {
        if let existing = controllers[name] {
            return existing
        }

        let config = profileConfigs[name] ?? PopupController.PopupProfileConfig()
        let controller = PopupController(
            name: name,
            config: config,
            ghosttyApp: ghosttyApp
        )
        controllers[name] = controller
        return controller
    }
}
