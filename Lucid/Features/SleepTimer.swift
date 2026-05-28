import Foundation
import Observation

@Observable
final class SleepTimerManager {
    static let shared = SleepTimerManager()

    var isActive: Bool = false
    var remainingSeconds: Int = 0
    var fadeSeconds: Int = 10

    @ObservationIgnored private var timer: Timer?

    private init() {}

    func start(minutes: Int) {
        cancel()
        isActive = true
        remainingSeconds = minutes * 60

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func cancel() {
        timer?.invalidate()
        timer = nil
        isActive = false
        remainingSeconds = 0
    }

    private func tick() {
        remainingSeconds -= 1

        if remainingSeconds <= fadeSeconds && remainingSeconds > 0 {
            let progress = Float(remainingSeconds) / Float(fadeSeconds)
            NotificationCenter.default.post(
                name: .sleepTimerFadeTick,
                object: nil,
                userInfo: ["progress": progress]
            )
        }

        if remainingSeconds <= 0 {
            NotificationCenter.default.post(name: .sleepTimerExpired, object: nil)
            cancel()
        }
    }

    var remainingFormatted: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

extension Notification.Name {
    static let sleepTimerFadeTick = Notification.Name("sleepTimerFadeTick")
    static let sleepTimerExpired = Notification.Name("sleepTimerExpired")
}
