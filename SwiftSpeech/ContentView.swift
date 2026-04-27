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
    @State private var dismissing = false

    private var hasChanged: Bool {
        hotkeyManager.keyCode != savedKeyCode || hotkeyManager.requiredFlags != savedFlags
    }

    var body: some View {
        VStack(spacing: 0) {
            // Caption sits above on its own line
            Text("Current hotkey")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 4)

            // Hotkey text + Record button, vertically centered on the same row
            HStack(alignment: .center) {
                Text(hotkeyManager.isCapturing ? "Recording…" : hotkeyManager.displayString)
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundStyle(hotkeyManager.isCapturing ? .secondary : .primary)

                Spacer()

                Button(hasChanged ? "Re-record" : "Record") {
                    hotkeyManager.startCapturing()
                }
                .disabled(hotkeyManager.isCapturing)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)

            Divider()

            // Bottom bar — same horizontal padding keeps Save's right edge
            // aligned with Record's right edge above.
            HStack {
                Spacer()
                Button("Cancel") {
                    dismissing = true
                    hotkeyManager.isCapturing = false
                    hotkeyManager.keyCode = savedKeyCode
                    hotkeyManager.requiredFlags = savedFlags
                    onDone()
                }
                .keyboardShortcut(.escape)

                Button("Save") { onDone() }
                    .keyboardShortcut(.return)
                    .buttonStyle(.borderedProminent)
                    .disabled(!hasChanged)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 320)
        .onAppear {
            savedKeyCode = hotkeyManager.keyCode
            savedFlags = hotkeyManager.requiredFlags
        }
        .onChange(of: hotkeyManager.isCapturing) { _, capturing in
            if !capturing && !dismissing {
                // Restore display string to reflect committed value
            }
        }
    }
}
