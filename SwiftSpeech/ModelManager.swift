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
    var downloadProgress: Double = 0.0
    private(set) var selectedModel: String = UserDefaults.standard.string(forKey: "app.selectedModel") ?? "base.en"
    private(set) var whisperKit: WhisperKit?

    var modelVariantDescription: String { selectedModel }

    func prepare() async {
        await downloadAndLoad(modelName: selectedModel)
    }

    func downloadAndLoad(modelName: String) async {
        guard status != .downloading && status != .loading else { return }
        status = .downloading
        downloadProgress = 0.0
        do {
            let folder = try await WhisperKit.download(variant: modelName) { [weak self] p in
                Task { @MainActor [weak self] in
                    self?.downloadProgress = p.fractionCompleted
                }
            }
            status = .loading
            let kit = try await WhisperKit(model: modelName, modelFolder: folder.path)
            selectedModel = modelName
            UserDefaults.standard.set(modelName, forKey: "app.selectedModel")
            whisperKit = kit
            status = .ready
        } catch {
            status = .failed(error.localizedDescription)
        }
    }
}
