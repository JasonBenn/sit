import SwiftUI
import AVFoundation

struct Step4VoiceNoteView: View {
    var onComplete: (Double?) -> Void
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
                .foregroundColor(isRecording ? .red : .orange)

            VStack(spacing: 12) {
                Text("What's going on?")
                    .font(.title2)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)

                Text("Can you find the limiting beliefs, or would you like to do parts work?")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 32)

            if isRecording {
                Text(formatDuration(recordingDuration))
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.red)
                    .monospacedDigit()
            }

            Spacer()

            VStack(spacing: 16) {
                if isRecording {
                    Button(action: stopRecording) {
                        HStack {
                            Image(systemName: "stop.fill")
                                .font(.headline)
                            Text("Stop & Save")
                                .font(.headline)
                                .fontWeight(.semibold)
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
                        HStack {
                            Image(systemName: "mic.fill")
                                .font(.headline)
                            Text("Record")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.orange)
                        .cornerRadius(16)
                    }
                    .buttonStyle(.plain)

                    Button(action: onSkip) {
                        Text("Skip")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .onDisappear {
            cleanupRecording()
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

        if let url = recordingURL {
            print("Voice note recorded at: \(url)")
            print("Duration: \(recordingDuration) seconds")
        }

        onComplete(recordingDuration)
    }

    private func cleanupRecording() {
        audioRecorder?.stop()
        timer?.invalidate()
        timer = nil
    }
}

#Preview {
    Step4VoiceNoteView(onComplete: { _ in }, onSkip: {})
}
