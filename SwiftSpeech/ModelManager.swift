import Foundation
import WhisperKit

@MainActor
@Observable
class ModelManager {
    enum Status: Equatable {
        case idle
        case downloading
        case loading
        case ready
        case failed(String)
    }

    var status: Status = .idle
    private(set) var whisperKit: WhisperKit?
    private let modelName = "base.en"
    var modelVariantDescription: String { modelName }

    func prepare() async {
        guard status == .idle else { return }
        status = .downloading
        do {
            // WhisperKit checks local cache first — only downloads if needed
            let kit = try await WhisperKit(model: modelName)
            status = .loading
            whisperKit = kit
            status = .ready
        } catch {
            status = .failed(error.localizedDescription)
        }
    }
}
