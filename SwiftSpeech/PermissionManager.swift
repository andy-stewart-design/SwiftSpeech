import AppKit
import ApplicationServices
import AVFoundation

@MainActor
@Observable
class PermissionManager {
    var accessibilityGranted = false
    var microphoneGranted = false

    var allGranted: Bool { accessibilityGranted && microphoneGranted }

    func checkAccessibility() {
        accessibilityGranted = AXIsProcessTrusted()
    }

    func requestMicrophone() async {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            microphoneGranted = true
        case .notDetermined:
            microphoneGranted = await AVCaptureDevice.requestAccess(for: .audio)
        case .denied, .restricted:
            openMicrophoneSettings()
        default:
            break
        }
    }

    func openAccessibilitySettings() {
        NSWorkspace.shared.open(
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        )
    }

    func openMicrophoneSettings() {
        NSWorkspace.shared.open(
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!
        )
    }
}
