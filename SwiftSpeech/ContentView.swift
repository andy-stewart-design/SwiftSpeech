import SwiftUI

struct ContentView: View {
    var modelManager: ModelManager

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
                Text("Ready")
                    .fontWeight(.medium)
                Divider()
                Button("Quit") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.plain)

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
        .frame(width: 220)
    }
}
