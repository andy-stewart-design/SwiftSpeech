import SwiftUI

@main
struct SwiftSpeechApp: App {
    @State private var coordinator = AppCoordinator()

    var body: some Scene {
        MenuBarExtra("SwiftSpeech", systemImage: menuBarIcon) {
            ContentView(coordinator: coordinator)
                .onChange(of: coordinator.permissionManager.allGranted) { _, granted in
                    if granted { coordinator.startHotkey() }
                }
        }
        .menuBarExtraStyle(.menu)
    }

    private var menuBarIcon: String {
        switch coordinator.modelManager.status {
        case .downloading, .loading:
            return "arrow.triangle.2.circlepath"
        case .ready:
            return coordinator.hotkeyManager.isRecording ? "mic.fill" : "mic"
        default:
            return "mic"
        }
    }
}
