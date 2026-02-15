import SwiftUI
import AVFoundation
import WatchKit

struct WatchVoiceRecorderView: View {
    let prompt: String
    let onSave: (Double, URL?) -> Void
    let onSkip: () -> Void

    @State private var isRecording = false
    @State private var isStartingRecording = false
    @State private var recordingDuration: Double = 0
    @State private var audioRecorder: AVAudioRecorder?
    @State private var recordingURL: URL?
    @State private var timer: Timer?

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Image(systemName: isRecording ? "mic.fill" : "mic")
                    .font(.system(size: 28))
                    .foregroundColor(isRecording ? .red : WatchTheme.amberText)
                    .padding(.top, 4)

                Text(prompt)
                    .font(.caption)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .foregroundColor(WatchTheme.text)

                if isRecording {
                    Text(formatDuration(recordingDuration))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                        .monospacedDigit()
                }

                if isRecording {
                    Button(action: stopRecording) {
                        HStack {
                            Image(systemName: "stop.fill").font(.caption)
                            Text("Stop & Save").font(.caption).fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.red)
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                } else if isStartingRecording {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                } else {
                    Button(action: startRecording) {
                        HStack {
                            Image(systemName: "mic.fill").font(.caption)
                            Text("Record").font(.caption).fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(WatchTheme.amber)
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)

                    Button(action: onSkip) {
                        Text("Skip")
                            .font(.caption)
                            .foregroundColor(WatchTheme.textMuted)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
        }
        .onDisappear { cleanupRecording() }
    }

    private func formatDuration(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func startRecording() {
        isStartingRecording = true
        Task {
            let session = AVAudioSession.sharedInstance()
            do {
                try session.setCategory(.playAndRecord, mode: .default)
                try session.setActive(true)

                let url = FileManager.default.temporaryDirectory
                    .appendingPathComponent("voice_note_\(Date().timeIntervalSince1970).m4a")

                let settings: [String: Any] = [
                    AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                    AVSampleRateKey: 44100,
                    AVNumberOfChannelsKey: 1,
                    AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
                ]

                let recorder = try AVAudioRecorder(url: url, settings: settings)
                recorder.record()

                await MainActor.run {
                    audioRecorder = recorder
                    recordingURL = url
                    isRecording = true
                    isStartingRecording = false
                    recordingDuration = 0
                    timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                        recordingDuration += 1
                    }
                }

                WKInterfaceDevice.current().play(.start)
            } catch {
                await MainActor.run { isStartingRecording = false }
                print("Failed to start recording: \(error)")
            }
        }
    }

    private func stopRecording() {
        audioRecorder?.stop()
        timer?.invalidate()
        timer = nil
        isRecording = false
        WKInterfaceDevice.current().play(.stop)
        onSave(recordingDuration, recordingURL)
    }

    private func cleanupRecording() {
        audioRecorder?.stop()
        timer?.invalidate()
        timer = nil
    }
}

#Preview {
    WatchVoiceRecorderView(prompt: "What's going on?", onSave: { _, _ in }, onSkip: {})
}
