import Foundation
import WhisperKit

@MainActor
@Observable
class AppCoordinator {
    let modelManager    = ModelManager()
    let permissionManager = PermissionManager()
    let hotkeyManager   = HotkeyManager()
    let audioRecorder   = AudioRecorder()

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
            print("Transcription: \(text)")
        } catch {
            print("Transcription error: \(error)")
        }
    }
}
