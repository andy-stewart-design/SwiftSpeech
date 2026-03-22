import AVFoundation
import SwiftUI

struct ContentView: View {
    var modelManager: ModelManager
    var permissionManager: PermissionManager

    var body: some View {
        VStack(spacing: 12) {
            switch modelManager.status {
            case .idle:
                EmptyView()

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
            Text("Ready")
                .fontWeight(.medium)
            Divider()
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.plain)
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
