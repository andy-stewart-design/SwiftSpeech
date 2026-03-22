import AVFoundation
import Foundation

@MainActor
@Observable
class AudioRecorder {
    enum Status { case idle, recording, failed(String) }

    var status: Status = .idle

    private var recorder: AVAudioRecorder?

    // Temp file reused each recording
    private let recordingURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("swiftspeech_recording.wav")

    func start() {
        let settings: [String: Any] = [
            AVFormatIDKey:             kAudioFormatLinearPCM,
            AVSampleRateKey:           16000.0,
            AVNumberOfChannelsKey:     1,
            AVLinearPCMBitDepthKey:    16,
            AVLinearPCMIsFloatKey:     false,
            AVLinearPCMIsBigEndianKey: false
        ]
        do {
            recorder = try AVAudioRecorder(url: recordingURL, settings: settings)
            recorder?.record()
            status = .recording
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    // Returns the file URL if a recording was in progress, nil otherwise
    func stop() -> URL? {
        guard let r = recorder, r.isRecording else { return nil }
        r.stop()
        recorder = nil
        status = .idle
        return recordingURL
    }
}
