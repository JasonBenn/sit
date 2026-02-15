import SwiftUI
import AVFoundation

struct VoiceRecorderView: View {
    let prompt: String
    var onSave: (Double, Data?) -> Void
    var onSkip: () -> Void

    @State private var isRecording = false
    @State private var recordingDuration: Double = 0
    @State private var audioRecorder: AVAudioRecorder?
    @State private var recordingURL: URL?
    @State private var timer: Timer?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: isRecording ? "mic.fill" : "mic")
                .font(.system(size: 64))
                .foregroundColor(isRecording ? .red : Theme.sage)

            Text(prompt)
                .font(Theme.display(24))
                .foregroundColor(Theme.text)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if isRecording {
                Text(formatDuration(recordingDuration))
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .foregroundColor(.red)
            }

            Spacer()

            VStack(spacing: 16) {
                if isRecording {
                    Button(action: stopRecording) {
                        HStack(spacing: 8) {
                            Image(systemName: "stop.fill")
                            Text("Stop & Save")
                                .font(Theme.body(16))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.red)
                        .cornerRadius(16)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(action: startRecording) {
                        HStack(spacing: 8) {
                            Image(systemName: "mic.fill")
                            Text("Record")
                                .font(Theme.body(16))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Theme.sage)
                        .cornerRadius(16)
                    }
                    .buttonStyle(.plain)

                    Button(action: onSkip) {
                        Text("Skip")
                            .font(Theme.body(14))
                            .foregroundColor(Theme.textMuted)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .onDisappear {
            audioRecorder?.stop()
            timer?.invalidate()
        }
    }

    private func formatDuration(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func startRecording() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)

            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("voice_note_\(Date().timeIntervalSince1970).m4a")
            recordingURL = url

            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]

            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.record()
            isRecording = true
            recordingDuration = 0

            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                recordingDuration += 1
            }

            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } catch {
            print("Failed to start recording: \(error)")
        }
    }

    private func stopRecording() {
        audioRecorder?.stop()
        timer?.invalidate()
        timer = nil
        isRecording = false

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        var audioData: Data?
        if let url = recordingURL {
            audioData = try? Data(contentsOf: url)
        }

        onSave(recordingDuration, audioData)
    }
}
