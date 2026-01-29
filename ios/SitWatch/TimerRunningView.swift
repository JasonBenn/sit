import SwiftUI

struct TimerRunningView: View {
    @EnvironmentObject var viewModel: WatchViewModel
    @ObservedObject var timerViewModel: TimerViewModel
    let preset: TimerPreset
    @Environment(\.dismiss) var dismiss
    @State private var showingInnerTimerPresets = false
    @State private var hasStarted = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Outer timer (main session)
                VStack(spacing: 8) {
                    Text("Session")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                            .frame(width: 100, height: 100)

                        Circle()
                            .trim(from: 0, to: timerViewModel.progress)
                            .stroke(Color.green, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .frame(width: 100, height: 100)
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 1), value: timerViewModel.progress)

                        VStack(spacing: 2) {
                            Text(timerViewModel.formattedTime)
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .monospacedDigit()

                            if !timerViewModel.isRunning && timerViewModel.remainingSeconds == 0 {
                                Text("Complete!")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                            }
                        }
                    }

                    // Outer timer controls
                    HStack(spacing: 16) {
                        if timerViewModel.isRunning {
                            Button {
                                timerViewModel.pauseTimer()
                            } label: {
                                Image(systemName: "pause.fill")
                                    .font(.title3)
                            }
                            .buttonStyle(.plain)
                        } else if timerViewModel.remainingSeconds > 0 {
                            Button {
                                timerViewModel.resumeTimer()
                            } label: {
                                Image(systemName: "play.fill")
                                    .font(.title3)
                            }
                            .buttonStyle(.plain)
                        }

                        Button {
                            handleFinish()
                        } label: {
                            Image(systemName: timerViewModel.remainingSeconds == 0 ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.title3)
                                .foregroundColor(timerViewModel.remainingSeconds == 0 ? .green : .red)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Inner timer section (only show if outer timer is running)
                if timerViewModel.isRunning || timerViewModel.remainingSeconds > 0 {
                    Divider()
                        .padding(.vertical, 4)

                    VStack(spacing: 8) {
                        Text("Exercise")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        if timerViewModel.innerIsRunning || timerViewModel.innerRemainingSeconds > 0 {
                            // Show inner timer
                            ZStack {
                                Circle()
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 6)
                                    .frame(width: 80, height: 80)

                                Circle()
                                    .trim(from: 0, to: timerViewModel.innerProgress)
                                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                                    .frame(width: 80, height: 80)
                                    .rotationEffect(.degrees(-90))
                                    .animation(.linear(duration: 1), value: timerViewModel.innerProgress)

                                VStack(spacing: 2) {
                                    Text(timerViewModel.innerFormattedTime)
                                        .font(.system(size: 20, weight: .bold, design: .rounded))
                                        .monospacedDigit()

                                    if !timerViewModel.innerIsRunning && timerViewModel.innerRemainingSeconds == 0 {
                                        Text("Done!")
                                            .font(.caption2)
                                            .foregroundColor(.blue)
                                    }
                                }
                            }

                            // Stop inner timer button
                            if timerViewModel.innerRemainingSeconds > 0 {
                                Button {
                                    timerViewModel.stopInnerTimer()
                                } label: {
                                    Label("Stop Exercise", systemImage: "stop.fill")
                                        .font(.caption)
                                }
                                .buttonStyle(.bordered)
                                .tint(.blue)
                            }
                        } else {
                            // Show button to start inner timer
                            Button {
                                showingInnerTimerPresets = true
                            } label: {
                                Label("Start Exercise", systemImage: "plus.circle.fill")
                                    .font(.caption)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.blue)
                        }
                    }
                }

                // Session info
                if timerViewModel.remainingSeconds == 0 {
                    Divider()
                        .padding(.vertical, 4)

                    Text("Session logged")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Meditation")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingInnerTimerPresets) {
            InnerTimerPresetsSheet(timerViewModel: timerViewModel, viewModel: viewModel)
        }
        .onAppear {
            if !hasStarted {
                timerViewModel.startTimer(durationMinutes: preset.durationMinutes)
                hasStarted = true
            }
        }
        .onChange(of: timerViewModel.remainingSeconds) { oldValue, newValue in
            // Log session when timer completes (0 seconds remaining)
            if oldValue > 0 && newValue == 0 {
                logSession()
            }
        }
    }

    private func logSession() {
        let duration = timerViewModel.completedDurationMinutes
        viewModel.logMeditationSession(durationMinutes: duration)
        print("📝 Logged meditation session: \(duration) min")
    }

    private func handleFinish() {
        timerViewModel.stopTimer()
        dismiss()
    }
}

// MARK: - Inner Timer Presets Sheet

struct InnerTimerPresetsSheet: View {
    @ObservedObject var timerViewModel: TimerViewModel
    @ObservedObject var viewModel: WatchViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            List {
                if viewModel.timerPresets.isEmpty {
                    Text("No presets available")
                        .foregroundColor(.secondary)
                        .font(.caption)
                } else {
                    ForEach(viewModel.timerPresets) { preset in
                        Button {
                            timerViewModel.startInnerTimer(durationMinutes: preset.durationMinutes)
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    if let label = preset.label, !label.isEmpty {
                                        Text(label)
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                    }
                                    Text("\(Int(preset.durationMinutes)) min")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "play.circle.fill")
                                    .foregroundColor(.blue)
                                    .font(.caption)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Exercise Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct TimerRunningView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            TimerRunningView(
                timerViewModel: TimerViewModel(),
                preset: TimerPreset(
                    id: "test",
                    durationMinutes: 5,
                    label: "Test",
                    order: 0,
                    createdAt: Date().timeIntervalSince1970 * 1000
                )
            )
            .environmentObject(WatchViewModel())
        }
    }
}
