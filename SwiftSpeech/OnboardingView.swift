import SwiftUI

struct OnboardingView: View {
    var coordinator: AppCoordinator

    @State private var step = 0
    @State private var selectedModel = "base.en"

    private var permissionManager: PermissionManager { coordinator.permissionManager }
    private var modelManager: ModelManager { coordinator.modelManager }

    private let models = ModelManager.models

    var body: some View {
        VStack(spacing: 0) {
            stepIndicator
                .padding(.top, 28)

            Group {
                switch step {
                case 0:  microphoneStep
                case 1:  accessibilityStep
                default: modelStep
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 420, height: 440)
        .onAppear {
            // Sync from real system status before deciding which step to skip to
            permissionManager.checkMicrophone()
            permissionManager.checkAccessibility()
            if permissionManager.microphoneGranted {
                step = permissionManager.accessibilityGranted ? 2 : 1
            }
        }
        .onChange(of: permissionManager.microphoneGranted) { _, granted in
            if granted && step == 0 { step = 1 }
        }
        .onChange(of: modelManager.status) { _, status in
            if status == .ready { coordinator.completeOnboarding() }
        }
    }

    // MARK: - Step indicator

    private var stepIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(i == step ? Color.accentColor : Color.secondary.opacity(0.25))
                    .frame(width: 8, height: 8)
                    .animation(.easeInOut, value: step)
            }
        }
    }

    // MARK: - Step 1: Microphone

    private var microphoneStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "mic.circle")
                .font(.system(size: 52))
                .foregroundStyle(.secondary)
                .padding(.top, 24)

            Text("Microphone Access")
                .font(.title2)
                .fontWeight(.semibold)

            Text("SwiftSpeech needs your microphone to record your voice while the hotkey is held.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()

            Button("Grant Access") {
                Task { await permissionManager.requestMicrophone() }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Step 2: Accessibility

    private var accessibilityStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "accessibility")
                .font(.system(size: 52))
                .foregroundStyle(.secondary)
                .padding(.top, 24)

            Text("Accessibility Access")
                .font(.title2)
                .fontWeight(.semibold)

            Text("SwiftSpeech needs Accessibility access to intercept your global hotkey before it reaches other apps.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()

            HStack(spacing: 12) {
                Button("Open Settings") {
                    // Trigger the system prompt first — this adds the app to the
                    // Accessibility list so the user can enable the toggle.
                    permissionManager.requestAccessibility()
                    permissionManager.openAccessibilitySettings()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button("I've Done This") {
                    permissionManager.checkAccessibility()
                    if permissionManager.accessibilityGranted { step = 2 }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(.bottom, 32)
        }
    }

    // MARK: - Step 3: Model selection + download

    private var modelStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "cpu")
                .font(.system(size: 52))
                .foregroundStyle(.secondary)
                .padding(.top, 28)

            Text("Choose Your Model")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(spacing: 8) {
                ForEach(models, id: \.name) { m in
                    modelRow(m)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 4)

            Spacer()

            downloadControls
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
        }
    }

    @ViewBuilder
    private func modelRow(_ m: (name: String, description: String, size: String)) -> some View {
        let isSelected = selectedModel == m.name
        let inProgress = modelManager.status == .downloading || modelManager.status == .loading

        HStack(spacing: 10) {
            Image(systemName: isSelected ? "circle.inset.filled" : "circle")
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(m.name)
                        .fontWeight(.medium)
                    if m.name == "base.en" {
                        Text("Recommended")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.15))
                            .foregroundStyle(Color.accentColor)
                            .clipShape(Capsule())
                    }
                }
                Text("\(m.description) · \(m.size)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if !inProgress { selectedModel = m.name }
        }
        .padding(10)
        .background(isSelected ? Color.accentColor.opacity(0.07) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var downloadControls: some View {
        switch modelManager.status {
        case .idle:
            Button("Download & Get Started") {
                Task { await modelManager.downloadAndLoad(modelName: selectedModel) }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

        case .downloading:
            VStack(spacing: 8) {
                ProgressView(value: modelManager.downloadProgress)
                    .progressViewStyle(.linear)
                    .frame(width: 280)
                Text("Downloading… \(Int(modelManager.downloadProgress * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

        case .loading:
            VStack(spacing: 8) {
                ProgressView()
                Text("Loading model…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

        case .ready:
            Label("Ready!", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)

        case .failed(let message):
            VStack(spacing: 10) {
                Text("Download failed")
                    .fontWeight(.medium)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
                Button("Retry") {
                    Task { await modelManager.downloadAndLoad(modelName: selectedModel) }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}
