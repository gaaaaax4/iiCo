import Foundation
import AVFoundation

final class ImageAudioManager: NSObject, ObservableObject {
    static let shared = ImageAudioManager()
    private static let maxRecordingDuration: TimeInterval = 5

    @Published private(set) var recordingImageID: String? = nil
    @Published private(set) var playingImageID: String? = nil

    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?

    private override init() {
        super.init()
    }

    func isRecording(id: String) -> Bool {
        recordingImageID == id
    }

    func isPlaying(id: String) -> Bool {
        playingImageID == id
    }

    func toggleRecording(for imageID: String) {
        if recordingImageID == imageID {
            stopRecording()
            return
        }
        requestRecordPermissionIfNeeded { [weak self] granted in
            guard let self, granted else { return }
            self.startRecording(for: imageID)
        }
    }

    func stopRecording() {
        recorder?.stop()
        recorder = nil
        recordingImageID = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func playAudio(for imageID: String) {
        guard let url = RegisteredImageStore.shared.audioURL(for: imageID),
              FileManager.default.fileExists(atPath: url.path) else {
            return
        }

        stopPlayback()
        if recordingImageID != nil {
            stopRecording()
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)

            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.delegate = self
            newPlayer.prepareToPlay()
            newPlayer.play()
            player = newPlayer
            playingImageID = imageID
        } catch {
            stopPlayback()
        }
    }

    func stopPlayback() {
        player?.stop()
        player = nil
        playingImageID = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func deleteAudio(for imageID: String) {
        if isRecording(id: imageID) {
            stopRecording()
        }
        if isPlaying(id: imageID) {
            stopPlayback()
        }

        guard let url = RegisteredImageStore.shared.audioURL(for: imageID) else {
            RegisteredImageStore.shared.updateAudioFileName(id: imageID, audioFileName: nil)
            return
        }

        try? FileManager.default.removeItem(at: url)
        RegisteredImageStore.shared.updateAudioFileName(id: imageID, audioFileName: nil)
    }

    private func requestRecordPermissionIfNeeded(completion: @escaping (Bool) -> Void) {
        let session = AVAudioSession.sharedInstance()
        switch session.recordPermission {
        case .granted:
            completion(true)
        case .denied:
            completion(false)
        case .undetermined:
            session.requestRecordPermission { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        @unknown default:
            completion(false)
        }
    }

    private func startRecording(for imageID: String) {
        stopPlayback()
        if recordingImageID != nil {
            stopRecording()
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)

            let fileName = "audio-\(imageID).m4a"
            let outputURL = documentsDirectory.appendingPathComponent(fileName)

            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]

            let newRecorder = try AVAudioRecorder(url: outputURL, settings: settings)
            newRecorder.delegate = self
            newRecorder.prepareToRecord()
            newRecorder.record(forDuration: Self.maxRecordingDuration)

            recorder = newRecorder
            recordingImageID = imageID
            RegisteredImageStore.shared.updateAudioFileName(id: imageID, audioFileName: fileName)
        } catch {
            stopRecording()
        }
    }

    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}

extension ImageAudioManager: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag, let imageID = recordingImageID {
            deleteAudio(for: imageID)
        }
        self.recorder = nil
        recordingImageID = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

extension ImageAudioManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        self.player = nil
        playingImageID = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
