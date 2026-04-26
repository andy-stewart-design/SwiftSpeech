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

    static let models: [(name: String, description: String, size: String)] = [
        ("tiny.en",   "Fastest, less accurate",  "~40 MB"),
        ("base.en",   "Balanced",                 "~140 MB"),
        ("small.en",  "More accurate, slower",    "~466 MB"),
        ("medium.en", "Most accurate, slowest",   "~500 MB"),
    ]

    var status: Status = .idle
    var downloadProgress: Double = 0.0
    private(set) var selectedModel: String = UserDefaults.standard.string(forKey: "app.selectedModel") ?? "base.en"
    private(set) var whisperKit: WhisperKit?
    private var currentModelFolder: URL?

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
            currentModelFolder = folder
            whisperKit = kit
            status = .ready
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func switchModel(to modelName: String) async {
        guard modelName != selectedModel else { return }
        let oldFolder = currentModelFolder
        whisperKit = nil
        await downloadAndLoad(modelName: modelName)
        if status == .ready, let folder = oldFolder {
            try? FileManager.default.removeItem(at: folder)
        }
    }
}
