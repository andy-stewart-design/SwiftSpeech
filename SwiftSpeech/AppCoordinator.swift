import Foundation

@MainActor
@Observable
class AppCoordinator {
    let modelManager = ModelManager()
    let permissionManager = PermissionManager()
    let hotkeyManager = HotkeyManager()

    init() {
        Task { await setup() }
    }

    private func setup() async {
        await modelManager.prepare()
        permissionManager.checkAccessibility()
        await permissionManager.requestMicrophone()
        if permissionManager.allGranted {
            startHotkey()
        }
    }

    func startHotkey() {
        hotkeyManager.onKeyDown = { print("▶ key down — start recording") }
        hotkeyManager.onKeyUp   = { print("■ key up — stop recording") }
        hotkeyManager.start()
    }
}
