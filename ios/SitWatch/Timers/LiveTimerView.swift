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
                    .stroke(Color(hex: "2A2825"), lineWidth: 6)

                // Progress ring
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(WatchTheme.amberText, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: progress)

                // Time text
                VStack(spacing: 2) {
                    Text(formatTime(timerManager.timeRemaining))
                        .font(.title2)
                        .fontWeight(.medium)
                        .monospacedDigit()
                        .foregroundColor(WatchTheme.text)
                    Text("of \(formatTime(timerManager.totalTime))")
                        .font(.caption2)
                        .foregroundColor(WatchTheme.textMuted)
                }
            }
            .frame(width: 128, height: 128)

            HStack(spacing: 16) {
                // Cancel on left
                Button {
                    timerManager.cancel()
                    dismiss()
                } label: {
                    Text("×")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(WatchTheme.textMuted)
                        .frame(width: 40, height: 40)
                        .background(WatchTheme.card)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Spacer()

                // Pause/Play on right
                if timerManager.isPaused {
                    Button {
                        WKInterfaceDevice.current().play(.click)
                        timerManager.resume()
                    } label: {
                        Image(systemName: "play.fill")
                            .font(.caption)
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(WatchTheme.amber)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        WKInterfaceDevice.current().play(.click)
                        timerManager.pause()
                    } label: {
                        Text("❚❚")
                            .font(.caption2)
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(WatchTheme.amber)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
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
