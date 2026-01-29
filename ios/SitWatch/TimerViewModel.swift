import Foundation
import WatchKit
import Combine

@MainActor
class TimerViewModel: ObservableObject {
    // Outer timer (main meditation session)
    @Published var isRunning = false
    @Published var remainingSeconds: Int = 0
    @Published var totalSeconds: Int = 0
    @Published var selectedPresetDuration: Double = 0

    // Inner timer (exercise intervals)
    @Published var innerIsRunning = false
    @Published var innerRemainingSeconds: Int = 0
    @Published var innerTotalSeconds: Int = 0

    // Interval bells configuration
    @Published var intervalBellsEnabled = false
    @Published var intervalMinutes: Double = 5.0

    private var timer: Timer?
    private var innerTimer: Timer?
    private var startTime: Date?
    private var lastIntervalSeconds: Int = 0

    // MARK: - Timer Control

    func startTimer(durationMinutes: Double) {
        // Stop any existing timer
        stopTimer()

        // Set up new timer
        totalSeconds = Int(durationMinutes * 60)
        remainingSeconds = totalSeconds
        selectedPresetDuration = durationMinutes
        isRunning = true
        startTime = Date()
        lastIntervalSeconds = 0

        // Start countdown timer that fires every second
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }

        // Ensure timer runs in background
        RunLoop.current.add(timer!, forMode: .common)

        print("⏱️ Timer started: \(durationMinutes) min (\(totalSeconds) seconds)")
        if intervalBellsEnabled {
            print("🔔 Interval bells enabled: every \(intervalMinutes) min")
        }
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        remainingSeconds = 0
        totalSeconds = 0
        startTime = nil
        print("⏱️ Timer stopped")
    }

    func pauseTimer() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        print("⏱️ Timer paused at \(remainingSeconds)s")
    }

    func resumeTimer() {
        guard remainingSeconds > 0, !isRunning else { return }

        isRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        RunLoop.current.add(timer!, forMode: .common)
        print("⏱️ Timer resumed at \(remainingSeconds)s")
    }

    // MARK: - Private Methods

    private func tick() {
        guard remainingSeconds > 0 else {
            completeTimer()
            return
        }

        remainingSeconds -= 1

        // Check for interval bell
        if intervalBellsEnabled {
            let elapsedSeconds = totalSeconds - remainingSeconds
            let intervalSeconds = Int(intervalMinutes * 60)

            // Play haptic at each interval boundary (but not at start or end)
            if elapsedSeconds > 0 && elapsedSeconds % intervalSeconds == 0 && elapsedSeconds != lastIntervalSeconds {
                playIntervalHaptic()
                lastIntervalSeconds = elapsedSeconds
            }
        }
    }

    private func completeTimer() {
        timer?.invalidate()
        timer = nil
        isRunning = false

        // Play completion haptic
        playCompletionHaptic()

        print("✅ Timer completed: \(selectedPresetDuration) min")

        // Reset state
        remainingSeconds = 0
        totalSeconds = 0
    }

    private func playCompletionHaptic() {
        // Play a strong haptic feedback pattern
        WKInterfaceDevice.current().play(.notification)

        // Additional haptic pattern for emphasis
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            WKInterfaceDevice.current().play(.success)
        }

        print("🔔 Played completion haptic")
    }

    private func playIntervalHaptic() {
        // Play a subtle haptic feedback for interval bells
        // Using .start for a gentle, non-intrusive notification
        WKInterfaceDevice.current().play(.start)

        print("🔔 Played interval bell haptic")
    }

    // MARK: - Computed Properties

    var formattedTime: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return Double(totalSeconds - remainingSeconds) / Double(totalSeconds)
    }

    var completedDurationMinutes: Double {
        return selectedPresetDuration
    }

    // MARK: - Inner Timer Control

    func startInnerTimer(durationMinutes: Double) {
        // Stop any existing inner timer
        stopInnerTimer()

        // Set up new inner timer
        innerTotalSeconds = Int(durationMinutes * 60)
        innerRemainingSeconds = innerTotalSeconds
        innerIsRunning = true

        // Start countdown timer that fires every second
        innerTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.innerTick()
            }
        }

        // Ensure timer runs in background
        RunLoop.current.add(innerTimer!, forMode: .common)

        print("⏱️ Inner timer started: \(durationMinutes) min (\(innerTotalSeconds) seconds)")
    }

    func stopInnerTimer() {
        innerTimer?.invalidate()
        innerTimer = nil
        innerIsRunning = false
        innerRemainingSeconds = 0
        innerTotalSeconds = 0
        print("⏱️ Inner timer stopped")
    }

    private func innerTick() {
        guard innerRemainingSeconds > 0 else {
            completeInnerTimer()
            return
        }

        innerRemainingSeconds -= 1
    }

    private func completeInnerTimer() {
        innerTimer?.invalidate()
        innerTimer = nil
        innerIsRunning = false

        // Play completion haptic for inner timer
        playInnerCompletionHaptic()

        print("✅ Inner timer completed")

        // Reset inner timer state
        innerRemainingSeconds = 0
        innerTotalSeconds = 0
    }

    private func playInnerCompletionHaptic() {
        // Play a lighter haptic feedback for inner timer (distinct from outer)
        WKInterfaceDevice.current().play(.click)

        print("🔔 Played inner timer haptic")
    }

    var innerFormattedTime: String {
        let minutes = innerRemainingSeconds / 60
        let seconds = innerRemainingSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var innerProgress: Double {
        guard innerTotalSeconds > 0 else { return 0 }
        return Double(innerTotalSeconds - innerRemainingSeconds) / Double(innerTotalSeconds)
    }
}
