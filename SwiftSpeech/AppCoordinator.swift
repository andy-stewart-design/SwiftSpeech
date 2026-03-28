import AppKit
import Foundation
import SwiftUI
import WhisperKit

@MainActor
@Observable
class AppCoordinator {
    let modelManager      = ModelManager()
    let permissionManager = PermissionManager()
    let hotkeyManager     = HotkeyManager()
    let audioRecorder     = AudioRecorder()
    private(set) var lastTranscription: String? = nil
    private(set) var onboardingComplete: Bool = UserDefaults.standard.bool(forKey: "app.onboardingComplete")
    private var onboardingWindow: NSWindow?

    init() {
        Task { await setup() }
    }

    private func setup() async {
        if onboardingComplete {
            await modelManager.prepare()
            permissionManager.checkAccessibility()
            await permissionManager.requestMicrophone()
            if permissionManager.allGranted {
                startHotkey()
            }
        } else {
            showOnboardingWindow()
        }
    }

    func showOnboardingWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 440),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to SwiftSpeech"
        window.contentView = NSHostingView(rootView: OnboardingView(coordinator: self))
        window.isReleasedWhenClosed = false
        window.center()
        onboardingWindow = window
        // orderFrontRegardless is required for LSUIElement (menu-bar-only) apps —
        // makeKeyAndOrderFront + activate don't reliably bring windows forward without a Dock presence.
        window.orderFrontRegardless()
    }

    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "app.onboardingComplete")
        onboardingComplete = true
        onboardingWindow?.close()
        onboardingWindow = nil
        startHotkey()
    }

    func startHotkey() {
        hotkeyManager.onKeyDown = { [weak self] in
            self?.audioRecorder.start()
        }
        hotkeyManager.onKeyUp = { [weak self] in
            guard let self else { return }
            guard let url = audioRecorder.stop() else { return }
            Task { await self.transcribe(audioURL: url) }
        }
        hotkeyManager.start()
    }

    private func transcribe(audioURL: URL) async {
        guard let whisperKit = modelManager.whisperKit else { return }
        do {
            let results = try await whisperKit.transcribe(audioPath: audioURL.path)
            let text = results.map(\.text).joined().trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }
            lastTranscription = text
            Clipboard.paste(text + " ")
        } catch {
            print("Transcription error: \(error)")
        }
    }
}
