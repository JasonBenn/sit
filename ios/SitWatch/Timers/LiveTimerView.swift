import SwiftUI
import WatchKit

struct LiveTimerView: View {
    let minutes: Int
    @StateObject private var timerManager = TimerManager()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 12) {
            if timerManager.isComplete {
                completeView
            } else {
                timerView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WatchTheme.bg)
        .navigationBarBackButtonHidden(timerManager.isRunning)
        .onAppear {
            timerManager.start(minutes: minutes)
        }
    }

    private var timerView: some View {
        VStack(spacing: 12) {
            ZStack {
                // Background ring
                Circle()
                    .stroke(WatchTheme.amber.opacity(0.2), lineWidth: 6)

                // Progress ring
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(WatchTheme.amberText, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: progress)

                // Time text
                Text(formatTime(timerManager.timeRemaining))
                    .font(.title2)
                    .fontWeight(.medium)
                    .monospacedDigit()
                    .foregroundColor(WatchTheme.text)
            }
            .frame(width: 120, height: 120)

            HStack(spacing: 16) {
                if timerManager.isPaused {
                    Button {
                        WKInterfaceDevice.current().play(.click)
                        timerManager.resume()
                    } label: {
                        Image(systemName: "play.fill")
                            .font(.caption)
                            .foregroundColor(WatchTheme.amberText)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        WKInterfaceDevice.current().play(.click)
                        timerManager.pause()
                    } label: {
                        Image(systemName: "pause.fill")
                            .font(.caption)
                            .foregroundColor(WatchTheme.amberText)
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    timerManager.cancel()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundColor(WatchTheme.textMuted)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var completeView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundColor(WatchTheme.sageText)

            Text("Done")
                .font(.headline)
                .foregroundColor(WatchTheme.text)

            Button {
                dismiss()
            } label: {
                Text("Close")
                    .font(.caption)
                    .foregroundColor(WatchTheme.textMuted)
            }
            .buttonStyle(.plain)
        }
    }

    private var progress: CGFloat {
        guard timerManager.totalTime > 0 else { return 0 }
        return timerManager.timeRemaining / timerManager.totalTime
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

#Preview {
    NavigationStack {
        LiveTimerView(minutes: 5)
    }
}
