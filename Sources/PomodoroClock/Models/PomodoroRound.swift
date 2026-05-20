import Foundation

enum PomodoroRound: String, Codable, CaseIterable, Identifiable, Sendable {
    case focus
    case shortBreak
    case longBreak

    var id: String { self.rawValue }

    var title: String {
        switch self {
        case .focus:
            return "Focus"
        case .shortBreak:
            return "Short Break"
        case .longBreak:
            return "Long Break"
        }
    }

    var symbolName: String {
        switch self {
        case .focus:
            return "timer"
        case .shortBreak:
            return "cup.and.saucer"
        case .longBreak:
            return "bed.double"
        }
    }

    func durationMinutes(using settings: PomodoroSettings) -> Int {
        switch self {
        case .focus:
            return settings.focusMinutes
        case .shortBreak:
            return settings.shortBreakMinutes
        case .longBreak:
            return settings.longBreakMinutes
        }
    }
}
