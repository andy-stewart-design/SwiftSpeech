import AVFoundation
import SwiftUI
import WhisperKit

struct ContentView: View {
    var coordinator: AppCoordinator
    @Environment(\.dismiss) private var dismiss

    private var modelManager: ModelManager { coordinator.modelManager }
    private var permissionManager: PermissionManager { coordinator.permissionManager }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch modelManager.status {
            case .idle:
                if !coordinator.onboardingComplete {
                    Button("Open Setup") { coordinator.showOnboardingWindow() }
                        .buttonStyle(.borderedProminent)
                } else {
                    ProgressView("Loading…")
                }

            case .downloading:
                ProgressView("Downloading model…")

            case .loading:
                ProgressView("Loading model…")

            case .ready:
                readyContent

            case .failed(let message):
                Text("Failed to load model")
                    .fontWeight(.medium)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                HStack {
                    Button("Retry") { Task { await modelManager.prepare() } }
                    Button("Quit") { NSApplication.shared.terminate(nil) }
                }
            }
        }
        .padding()
        .frame(width: 240)
    }

    @ViewBuilder
    private var hotkeyRow: some View {
        let hotkey = coordinator.hotkeyManager
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Hotkey")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(hotkey.isCapturing ? "Press your hotkey…" : hotkey.displayString)
                    .fontWeight(.medium)
                    .foregroundStyle(hotkey.isCapturing ? .secondary : .primary)
            }
            Spacer()
            Button(hotkey.isCapturing ? "Cancel" : "Change") {
                if hotkey.isCapturing {
                    hotkey.isCapturing = false
                } else {
                    hotkey.startCapturing()
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var readyContent: some View {
        if !permissionManager.accessibilityGranted {
            permissionView(
                icon: "accessibility",
                title: "Accessibility Required",
                detail: "SwiftSpeech needs Accessibility access to detect your hotkey globally.",
                actionLabel: "Open Settings",
                action: { permissionManager.openAccessibilitySettings() },
                secondaryLabel: "Check Again",
                secondaryAction: { permissionManager.checkAccessibility() }
            )
        } else if !permissionManager.microphoneGranted {
            let alreadyDenied = AVCaptureDevice.authorizationStatus(for: .audio) == .denied
            permissionView(
                icon: "mic",
                title: "Microphone Required",
                detail: "SwiftSpeech needs microphone access to record your voice.",
                actionLabel: alreadyDenied ? "Open Settings" : "Grant Access",
                action: { Task { await permissionManager.requestMicrophone() } },
                secondaryLabel: "Quit",
                secondaryAction: { NSApplication.shared.terminate(nil) }
            )
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Text("Ready")
                    .fontWeight(.medium)
                Text("whisper-\(modelManager.modelVariantDescription)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Divider()
            hotkeyRow
            Divider()
            Button("Copy Last Transcription") {
                if let last = coordinator.lastTranscription {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(last, forType: .string)
                    dismiss()
                }
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
            .disabled(coordinator.lastTranscription == nil)
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func permissionView(
        icon: String,
        title: String,
        detail: String,
        actionLabel: String,
        action: @escaping () -> Void,
        secondaryLabel: String,
        secondaryAction: @escaping () -> Void
    ) -> some View {
        Image(systemName: icon)
            .font(.largeTitle)
            .foregroundStyle(.secondary)
        Text(title)
            .fontWeight(.medium)
        Text(detail)
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        HStack {
            Button(actionLabel, action: action)
                .buttonStyle(.borderedProminent)
            Button(secondaryLabel, action: secondaryAction)
        }
    }
}
