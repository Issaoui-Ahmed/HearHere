import Foundation
import AVFoundation

@MainActor
final class AudioRecorder: NSObject, ObservableObject {
    @Published private(set) var hasMicrophonePermission: Bool

    private let session = AVAudioSession.sharedInstance()
    private var recorder: AVAudioRecorder?

    override init() {
        switch session.recordPermission {
        case .granted:
            hasMicrophonePermission = true
        case .denied, .undetermined:
            hasMicrophonePermission = false
        @unknown default:
            hasMicrophonePermission = false
        }
        super.init()
    }

    func requestPermission() async -> Bool {
        if session.recordPermission == .granted {
            hasMicrophonePermission = true
            return true
        }

        return await withCheckedContinuation { continuation in
            session.requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async {
                    self?.hasMicrophonePermission = granted
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    func startRecording() throws -> URL {
        guard hasMicrophonePermission else {
            throw RecorderError.microphoneAccessDenied
        }

        try configureSession()

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder?.isMeteringEnabled = true
        recorder?.record()
        return url
    }

    func stopRecording() -> URL? {
        guard let recorder else { return nil }
        recorder.stop()
        let url = recorder.url
        self.recorder = nil
        return url
    }

    func cancelRecording() {
        guard let recorder else { return }
        recorder.stop()
        try? FileManager.default.removeItem(at: recorder.url)
        self.recorder = nil
    }

    private func configureSession() throws {
        var options: AVAudioSession.CategoryOptions = [.defaultToSpeaker]

        if #available(iOS 10.0, *) {
            options.insert(.allowBluetoothA2DP)
        } else {
            options.insert(.allowBluetooth)
        }

        try session.setCategory(.playAndRecord, mode: .default, options: options)
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }
}

enum RecorderError: Error, LocalizedError {
    case microphoneAccessDenied

    var errorDescription: String? {
        switch self {
        case .microphoneAccessDenied:
            return "Microphone access has been denied."
        }
    }
}
