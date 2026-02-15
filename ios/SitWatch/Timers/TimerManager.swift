import Foundation
import WatchKit

@MainActor
class TimerManager: ObservableObject {
    @Published var timeRemaining: TimeInterval = 0
    @Published var totalTime: TimeInterval = 0
    @Published var isRunning = false
    @Published var isPaused = false
    @Published var isComplete = false

    private var timer: Timer?
    private var extendedSession: WKExtendedRuntimeSession?

    func start(minutes: Int) {
        totalTime = TimeInterval(minutes * 60)
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
        timer?.invalidate()
        timer = nil
    }

    func resume() {
        isPaused = false
        startTimer()
    }

    func cancel() {
        cleanup()
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    private func tick() {
        timeRemaining -= 1
        if timeRemaining <= 0 {
            timeRemaining = 0
            isComplete = true
            isRunning = false
            WKInterfaceDevice.current().play(.success)
            cleanup()
        }
    }

    private func startExtendedSession() {
        extendedSession?.invalidate()
        let session = WKExtendedRuntimeSession()
        session.start()
        extendedSession = session
    }

    private func cleanup() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        isPaused = false
        extendedSession?.invalidate()
        extendedSession = nil
    }
}
