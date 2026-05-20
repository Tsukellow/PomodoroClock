import Foundation

struct PomodoroSessionRecord: Codable, Identifiable, Sendable {
    let id: UUID
    let startedAt: Date
    let endedAt: Date
    let round: PomodoroRound
    let plannedDurationSeconds: Int
    let completed: Bool
    let isManualEntry: Bool

    init(
        id: UUID = UUID(),
        startedAt: Date,
        endedAt: Date,
        round: PomodoroRound,
        plannedDurationSeconds: Int,
        completed: Bool,
        isManualEntry: Bool = false
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.round = round
        self.plannedDurationSeconds = plannedDurationSeconds
        self.completed = completed
        self.isManualEntry = isManualEntry
    }
}
