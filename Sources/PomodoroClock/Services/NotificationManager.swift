import Foundation
import UserNotifications

final class NotificationManager {
    private let center = UNUserNotificationCenter.current()

    func requestAuthorizationIfNeeded() {
        self.center.requestAuthorization(options: [.alert, .badge]) { _, _ in }
    }

    func postTransition(from previousRound: PomodoroRound, to nextRound: PomodoroRound) {
        let content = UNMutableNotificationContent()
        content.title = nextRound == .focus ? "Back to focus" : "\(nextRound.title) started"
        content.body = self.bodyText(from: previousRound, to: nextRound)
        content.sound = nil

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        self.center.add(request)
    }

    private func bodyText(from previousRound: PomodoroRound, to nextRound: PomodoroRound) -> String {
        switch (previousRound, nextRound) {
        case (.focus, .shortBreak):
            return "Focus round finished. Step away for a short break."
        case (.focus, .longBreak):
            return "Focus cycle finished. Take a longer break."
        case (.shortBreak, .focus), (.longBreak, .focus):
            return "Break is over. Start the next focus round when ready."
        default:
            return "The timer advanced to the next round."
        }
    }
}
