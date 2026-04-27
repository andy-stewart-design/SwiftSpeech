import AVFoundation
import CoreAudio
import Foundation

@MainActor
@Observable
class AudioRecorder {
    enum Status { case idle, recording, failed(String) }

    var status: Status = .idle

    private var recorder: AVAudioRecorder?
    private var idleTimer: Timer?
    private var pendingRecord = false
    private var lastStopTime: Date?

    private let recordingURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("swiftspeech_recording.wav")

    private let settings: [String: Any] = [
        AVFormatIDKey:             kAudioFormatLinearPCM,
        AVSampleRateKey:           16000.0,
        AVNumberOfChannelsKey:     1,
        AVLinearPCMBitDepthKey:    16,
        AVLinearPCMIsFloatKey:     false,
        AVLinearPCMIsBigEndianKey: false
    ]

    func start() {
        idleTimer?.invalidate()
        idleTimer = nil
        pendingRecord = true
        do {
            if recorder == nil {
                recorder = try AVAudioRecorder(url: recordingURL, settings: settings)
            }
            recorder?.prepareToRecord()

            let delay = renegotiationDelay()
            if delay > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                    guard let self, self.pendingRecord else { return }
                    self.pendingRecord = false
                    self.recorder?.record()
                    self.status = .recording
                }
            } else {
                pendingRecord = false
                recorder?.record()
                status = .recording
            }
        } catch {
            pendingRecord = false
            status = .failed(error.localizedDescription)
        }
    }

    // Returns the file URL if a recording was in progress, nil otherwise.
    func stop() -> URL? {
        pendingRecord = false
        guard let r = recorder, r.isRecording else { return nil }
        r.stop()
        lastStopTime = Date()
        status = .idle
        scheduleRelease()
        return recordingURL
    }

    // Returns a delay (in seconds) to wait before calling record(), or 0 if none
    // is needed. When Bluetooth headphones are in use, macOS switches from HFP
    // back to A2DP after ~5 seconds of inactivity. If we start recording while
    // the switch back to HFP is still in progress, we capture silence. We detect
    // this by checking whether enough time has passed for the switch-back to have
    // occurred, and if so, give the renegotiation time to complete.
    private func renegotiationDelay() -> TimeInterval {
        guard currentInputIsBluetooth() else { return 0 }
        guard let lastStop = lastStopTime else { return 0.7 }  // first recording
        return Date().timeIntervalSince(lastStop) > 4.5 ? 0.7 : 0
    }

    private func scheduleRelease() {
        idleTimer?.invalidate()
        idleTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.recorder = nil
            }
        }
    }

    private func currentInputIsBluetooth() -> Bool {
        var deviceID = AudioDeviceID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID
        )
        guard deviceID != kAudioObjectUnknown else { return false }

        var transport: UInt32 = 0
        size = UInt32(MemoryLayout<UInt32>.size)
        address.mSelector = kAudioDevicePropertyTransportType
        AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &transport)
        return transport == kAudioDeviceTransportTypeBluetooth
            || transport == kAudioDeviceTransportTypeBluetoothLE
    }
}
