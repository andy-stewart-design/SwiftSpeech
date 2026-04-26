import AVFoundation
import CoreGraphics
import SwiftUI

struct ContentView: View {
    var coordinator: AppCoordinator

    private var modelManager: ModelManager { coordinator.modelManager }
    private var permissionManager: PermissionManager { coordinator.permissionManager }
    private var hotkeyManager: HotkeyManager { coordinator.hotkeyManager }

    var body: some View {
        // Divider included inside statusSection only when it has content,
        // so we never render a leading divider on an empty section.
        statusSection

        if (modelManager.status == .ready || modelManager.isSwitching),
           permissionManager.allGranted
        {
            modelMenu

            Button("Change Hotkey") {
                coordinator.showHotkeyWindow()
            }

            Divider()

            Button("Copy Last Transcription") {
                if let last = coordinator.lastTranscription {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(last, forType: .string)
                }
            }
            .disabled(coordinator.lastTranscription == nil)

            Divider()
        }

        Button("Quit") { NSApplication.shared.terminate(nil) }
    }

    // MARK: - Status

    @ViewBuilder
    private var statusSection: some View {
        if modelManager.isSwitching {
            Text("Switching model…")
            Divider()
        } else {
            switch modelManager.status {
            case .idle:
                if !coordinator.onboardingComplete {
                    Button("Open Setup") { coordinator.showOnboardingWindow() }
                } else {
                    Text("Starting…")
                }
                Divider()
            case .downloading:
                Text("Downloading model… \(Int(modelManager.downloadProgress * 100))%")
                Divider()
            case .loading:
                Text("Loading model…")
                Divider()
            case .ready:
                if !permissionManager.accessibilityGranted {
                    Text("Accessibility Required")
                    Button("Open Settings") { permissionManager.openAccessibilitySettings() }
                    Button("Check Again") { permissionManager.checkAccessibility() }
                    Divider()
                } else if !permissionManager.microphoneGranted {
                    Text("Microphone Required")
                    Button(AVCaptureDevice.authorizationStatus(for: .audio) == .denied
                           ? "Open Settings" : "Grant Access") {
                        Task { await permissionManager.requestMicrophone() }
                    }
                    Divider()
                }
                // ready + all permissions granted: emit nothing, no divider
            case .failed(let message):
                Text("Error loading model")
                Text(message)
                Button("Retry") { Task { await modelManager.prepare() } }
                Divider()
            }
        }
    }

    // MARK: - Model submenu

    @ViewBuilder
    private var modelMenu: some View {
        Menu("Model") {
            if modelManager.isSwitching {
                Text("Downloading… \(Int(modelManager.downloadProgress * 100))%")
            } else {
                Picker("", selection: Binding<String>(
                    get: { modelManager.selectedModel },
                    set: { newValue in Task { await modelManager.switchModel(to: newValue) } }
                )) {
                    ForEach(ModelManager.models, id: \.name) { m in
                        Text(m.name).tag(m.name)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
        }
    }
}

// MARK: - Hotkey capture window

struct HotkeyCaptureView: View {
    var hotkeyManager: HotkeyManager
    var onDone: () -> Void

    @State private var savedKeyCode: Int64 = 0
    @State private var savedFlags: CGEventFlags = []
    @State private var captured = false
    @State private var cancelling = false

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text(captured ? "New hotkey" : "Current hotkey")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(hotkeyManager.displayString)
                    .font(.title2)
                    .fontWeight(.medium)
            }

            if !captured {
                Text("Press a new combination to replace it")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 12) {
                Button("Cancel") {
                    cancelling = true
                    hotkeyManager.keyCode = savedKeyCode
                    hotkeyManager.requiredFlags = savedFlags
                    hotkeyManager.isCapturing = false
                    onDone()
                }
                .keyboardShortcut(.escape)

                if captured {
                    Button("Save") { onDone() }
                        .keyboardShortcut(.return)
                }
            }
        }
        .padding(24)
        .frame(width: 280)
        .onAppear {
            savedKeyCode = hotkeyManager.keyCode
            savedFlags = hotkeyManager.requiredFlags
            hotkeyManager.startCapturing()
        }
        .onChange(of: hotkeyManager.isCapturing) { _, capturing in
            if !capturing && !cancelling { captured = true }
        }
    }
}
