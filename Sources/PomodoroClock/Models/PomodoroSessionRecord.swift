import Foundation

struct PomodoroSessionRecord: Codable, Identifiable, Sendable {
    let id: UUID
    let startedAt: Date
    let endedAt: Date
    let round: PomodoroRound
    let plannedDurationSeconds: Int
    let completed: Bool
    let isManualEntry: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case startedAt
        case endedAt
        case round
        case plannedDurationSeconds
        case completed
        case isManualEntry
    }

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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.startedAt = try container.decode(Date.self, forKey: .startedAt)
        self.endedAt = try container.decode(Date.self, forKey: .endedAt)
        self.round = try container.decode(PomodoroRound.self, forKey: .round)
        self.plannedDurationSeconds = try container.decode(Int.self, forKey: .plannedDurationSeconds)
        self.completed = try container.decode(Bool.self, forKey: .completed)
        self.isManualEntry = try container.decodeIfPresent(Bool.self, forKey: .isManualEntry) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.id, forKey: .id)
        try container.encode(self.startedAt, forKey: .startedAt)
        try container.encode(self.endedAt, forKey: .endedAt)
        try container.encode(self.round, forKey: .round)
        try container.encode(self.plannedDurationSeconds, forKey: .plannedDurationSeconds)
        try container.encode(self.completed, forKey: .completed)
        try container.encode(self.isManualEntry, forKey: .isManualEntry)
    }
}
