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

    func checkMicrophone() {
        microphoneGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    /// Triggers the macOS system prompt ("SwiftSpeech would like to control your computer"),
    /// which adds the app to the Accessibility list in System Settings so the user can enable it.
    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        accessibilityGranted = AXIsProcessTrustedWithOptions(options)
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
