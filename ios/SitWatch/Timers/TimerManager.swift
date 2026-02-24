import Foundation
import WatchKit

@MainActor
class TimerManager: NSObject, ObservableObject, WKExtendedRuntimeSessionDelegate {
    @Published var timeRemaining: TimeInterval = 0
    @Published var totalTime: TimeInterval = 0
    @Published var isRunning = false
    @Published var isPaused = false
    @Published var isComplete = false

    private var timer: Timer?
    private var hapticTimer: Timer?
    private var extendedSession: WKExtendedRuntimeSession?
    private var endDate: Date?
    private var pausedTimeRemaining: TimeInterval = 0

    func start(minutes: Int) {
        totalTime = TimeInterval(minutes * 60)
        endDate = Date().addingTimeInterval(totalTime)
        timeRemaining = totalTime
        isRunning = true
        isPaused = false
        isComplete = false

        startExtendedSession()
        startTimer()
        WKInterfaceDevice.current().play(.start)
    }

    func pause() {
        isPaused = true
        pausedTimeRemaining = max(0, endDate?.timeIntervalSinceNow ?? 0)
        endDate = nil
        timer?.invalidate()
        timer = nil
    }

    func resume() {
        isPaused = false
        endDate = Date().addingTimeInterval(pausedTimeRemaining)
        startTimer()
    }

    func cancel() {
        cleanup()
    }

    func stopAlarm() {
        hapticTimer?.invalidate()
        hapticTimer = nil
        extendedSession?.invalidate()
        extendedSession = nil
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    private func tick() {
        guard let endDate else { return }
        timeRemaining = max(0, endDate.timeIntervalSinceNow)
        if timeRemaining <= 0 {
            timer?.invalidate()
            timer = nil
            isComplete = true
            isRunning = false
            startRepeatingHaptics()
        }
    }

    private func startRepeatingHaptics() {
        let device = WKInterfaceDevice.current()
        device.play(.notification)
        hapticTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
            device.play(.notification)
        }
    }

    private func startExtendedSession() {
        extendedSession?.invalidate()
        let session = WKExtendedRuntimeSession()
        session.delegate = self
        session.start()
        extendedSession = session
    }

    private func cleanup() {
        timer?.invalidate()
        timer = nil
        hapticTimer?.invalidate()
        hapticTimer = nil
        endDate = nil
        isRunning = false
        isPaused = false
        extendedSession?.invalidate()
        extendedSession = nil
    }

    // MARK: - WKExtendedRuntimeSessionDelegate

    nonisolated func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {}

    nonisolated func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        Task { @MainActor in
            if self.isRunning && !self.isComplete {
                self.startRepeatingHaptics()
            }
        }
    }

    nonisolated func extendedRuntimeSession(_ extendedRuntimeSession: WKExtendedRuntimeSession, didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason, error: (any Error)?) {}
}
