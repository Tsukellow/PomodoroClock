import Combine
import Foundation

@MainActor
final class PomodoroAppModel: ObservableObject {
    @Published var settings: PomodoroSettings {
        didSet {
            self.saveSettings()
            self.applySettingsIfNeeded()
            self.refreshNotifications()
        }
    }

    @Published private(set) var round: PomodoroRound = .focus
    @Published private(set) var elapsedSeconds = 0
    @Published private(set) var totalSeconds: Int
    @Published private(set) var isRunning = false
    @Published private(set) var currentSessionIndex = 0
    @Published private(set) var cycleCompleted = false
    @Published private(set) var statistics = StatisticsSummary.empty
    @Published private(set) var recentSessions: [PomodoroSessionRecord] = []

    let launchAtLoginManager = LaunchAtLoginManager()

    private let settingsKey = "pomodoroClock.settings"
    private let historyStore = HistoryStore()
    private let notificationManager = NotificationManager()
    private let calendar = Calendar.current
    private let engine: CountdownEngine
    private var activeRoundStartedAt: Date?

    init() {
        let storedSettings = Self.loadSettings()
        self.settings = storedSettings
        let initialRound = storedSettings.sessionSequence.first ?? .focus
        self.round = initialRound
        self.totalSeconds = initialRound.durationMinutes(using: storedSettings) * 60
        self.engine = CountdownEngine(totalSeconds: initialRound.durationMinutes(using: storedSettings) * 60)

        self.engine.onTick = { [weak self] elapsed, total in
            guard let self else { return }
            self.elapsedSeconds = elapsed
            self.totalSeconds = total
            self.isRunning = self.engine.isRunning
        }

        self.engine.onCompletion = { [weak self] in
            self?.handleRoundCompletion(skipped: false, keepCurrentRound: false)
        }

        self.reloadHistory()
        self.migrateHistoryV1()
        self.refreshNotifications()
        self.engine.configure(totalSeconds: self.round.durationMinutes(using: self.settings) * 60)
    }

    var remainingSeconds: Int {
        max(0, self.totalSeconds - self.elapsedSeconds)
    }

    var focusSessionLabel: String {
        let sequence = self.settings.sessionSequence
        let totalFocus = sequence.filter { $0 == .focus }.count
        if self.cycleCompleted {
            return "\(totalFocus)/\(totalFocus)"
        }
        let currentFocusOrdinal = sequence.prefix(self.currentSessionIndex + 1).filter { $0 == .focus }.count
        return "\(currentFocusOrdinal)/\(totalFocus)"
    }

    var remainingFraction: Double {
        guard self.totalSeconds > 0 else { return 1.0 }
        return 1.0 - Double(self.elapsedSeconds) / Double(self.totalSeconds)
    }

    func adjustTodaySessions(by delta: Int) {
        self.adjustSessions(by: delta, on: Date())
    }

    func adjustYesterdaySessions(by delta: Int) {
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()) else { return }
        self.adjustSessions(by: delta, on: yesterday)
    }

    private func adjustSessions(by delta: Int, on date: Date) {
        if delta > 0 {
            self.addManualFocusSessions(count: delta, on: date)
        } else if delta < 0 {
            self.removeFocusSessions(count: -delta, on: date)
        }
    }

    func toggleTimer() {
        self.cycleCompleted = false
        if self.isRunning {
            self.pauseTimer()
        } else {
            self.startTimer()
        }
    }

    func startTimer() {
        if self.activeRoundStartedAt == nil {
            self.activeRoundStartedAt = Date().addingTimeInterval(TimeInterval(-self.elapsedSeconds))
        }
        self.engine.start()
        self.isRunning = true
    }

    func pauseTimer() {
        self.engine.pause()
        self.isRunning = false
    }

    func resetRound() {
        if self.cycleCompleted {
            // From completed state, reset to the first session
            self.cycleCompleted = false
            self.currentSessionIndex = 0
            self.round = self.settings.sessionSequence.first ?? .focus
            self.configureCurrentRound()
            return
        }
        self.handleRoundCompletion(skipped: true, keepCurrentRound: true)
    }

    func skipRound() {
        self.moveRound(by: 1, postNotification: true)
    }

    func goBackRound() {
        self.moveRound(by: -1, postNotification: false)
    }

    func clearHistory() {
        self.historyStore.clear()
        self.reloadHistory()
    }

    func formattedRemainingTime() -> String {
        self.format(seconds: self.remainingSeconds)
    }

    func formattedElapsedTime() -> String {
        self.format(seconds: self.elapsedSeconds)
    }

    private func handleRoundCompletion(skipped: Bool, keepCurrentRound: Bool) {
        self.persistCurrentRoundIfNeeded(completed: !skipped)

        if keepCurrentRound {
            self.configureCurrentRound()
        } else {
            let previousRound = self.round
            self.advanceRound()
            self.notificationManager.postTransition(from: previousRound, to: self.round)
        }

        // Auto-start on natural completion (not skipped, not reset) unless cycle completed
        if !skipped && !keepCurrentRound && !self.cycleCompleted {
            self.startTimer()
        }
    }

    private func moveRound(by offset: Int, postNotification: Bool) {
        let wasRunning = self.isRunning
        let previousRound = self.round

        self.persistCurrentRoundIfNeeded(completed: false)

        let sequence = self.settings.sessionSequence
        guard !sequence.isEmpty else { return }

        let nextIndex: Int
        if self.cycleCompleted {
            nextIndex = offset > 0 ? 0 : sequence.count - 1
        } else {
            nextIndex = (self.currentSessionIndex + offset + sequence.count) % sequence.count
        }

        self.cycleCompleted = false
        self.currentSessionIndex = nextIndex
        self.round = sequence[nextIndex]
        self.configureCurrentRound()

        if wasRunning {
            self.startTimer()
        }

        if postNotification {
            self.notificationManager.postTransition(from: previousRound, to: self.round)
        }
    }

    private func persistCurrentRoundIfNeeded(completed: Bool) {
        guard self.elapsedSeconds > 0, let startedAt = self.activeRoundStartedAt else {
            self.activeRoundStartedAt = nil
            self.engine.reset()
            self.isRunning = false
            return
        }

        let record = PomodoroSessionRecord(
            startedAt: startedAt,
            endedAt: Date(),
            round: self.round,
            plannedDurationSeconds: self.totalSeconds,
            completed: completed,
            recordedAt: Date()
        )

        self.historyStore.append(record)
        self.activeRoundStartedAt = nil
        self.reloadHistory()
        self.engine.reset()
        self.isRunning = false
    }

    private func advanceRound() {
        let sequence = self.settings.sessionSequence
        guard !sequence.isEmpty else { return }
        let nextIndex = (self.currentSessionIndex + 1) % sequence.count
        if nextIndex == 0 {
            self.cycleCompleted = true
        }
        self.currentSessionIndex = nextIndex
        self.round = sequence[self.currentSessionIndex]
        self.configureCurrentRound()
    }

    private func configureCurrentRound() {
        self.activeRoundStartedAt = nil
        self.totalSeconds = self.round.durationMinutes(using: self.settings) * 60
        self.elapsedSeconds = 0
        self.engine.configure(totalSeconds: self.totalSeconds)
        self.isRunning = false
    }

    private func applySettingsIfNeeded() {
        guard !self.isRunning, self.elapsedSeconds == 0 else {
            return
        }
        self.configureCurrentRound()
    }

    private func refreshNotifications() {
        self.notificationManager.requestAuthorizationIfNeeded()
    }

    private func reloadHistory() {
        self.recentSessions = self.historyStore.load().sorted { $0.endedAt > $1.endedAt }
        self.statistics = StatisticsSummary.make(from: self.recentSessions, calendar: self.calendar)
    }

    private func saveSettings() {
        guard let data = try? JSONEncoder().encode(self.settings) else {
            return
        }
        UserDefaults.standard.set(data, forKey: self.settingsKey)
    }

    private static func loadSettings() -> PomodoroSettings {
        guard
            let data = UserDefaults.standard.data(forKey: "pomodoroClock.settings"),
            let settings = try? JSONDecoder().decode(PomodoroSettings.self, from: data)
        else {
            return .default
        }
        return settings
    }

    private func format(seconds: Int) -> String {
        let minutes = seconds / 60
        let seconds = seconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - Migration

    private func migrateHistoryV1() {
        let migratedKey = "pomodoroClock.historyMigratedV1"
        guard !UserDefaults.standard.bool(forKey: migratedKey) else { return }

        var records = self.historyStore.load()
        var changed = false

        for i in records.indices {
            let record = records[i]

            // Fix old manual entries: normalize to midnight, clear duration, preserve original time in recordedAt
            if record.isManualEntry {
                let midnight = calendar.startOfDay(for: record.endedAt)
                let originalRecordedAt = record.recordedAt.timeIntervalSince1970 == 0
                    ? record.endedAt
                    : record.recordedAt

                if record.startedAt != midnight || record.endedAt != midnight || record.plannedDurationSeconds != 0 {
                    records[i] = PomodoroSessionRecord(
                        id: record.id,
                        startedAt: midnight,
                        endedAt: midnight,
                        round: record.round,
                        plannedDurationSeconds: 0,
                        completed: record.completed,
                        isManualEntry: true,
                        recordedAt: originalRecordedAt
                    )
                    changed = true
                }
            } else if record.recordedAt.timeIntervalSince1970 == 0 {
                // Fix non-manual entries missing recordedAt: set to endedAt
                records[i] = PomodoroSessionRecord(
                    id: record.id,
                    startedAt: record.startedAt,
                    endedAt: record.endedAt,
                    round: record.round,
                    plannedDurationSeconds: record.plannedDurationSeconds,
                    completed: record.completed,
                    isManualEntry: false,
                    recordedAt: record.endedAt
                )
                changed = true
            }
        }

        if changed {
            self.historyStore.replace(records)
            self.reloadHistory()
        }

        UserDefaults.standard.set(true, forKey: migratedKey)
    }

    // MARK: - Manual Focus Sessions

    private func addManualFocusSessions(count: Int, on date: Date) {
        guard count > 0 else { return }

        let midnight = calendar.startOfDay(for: date)
        var records = self.historyStore.load()

        for _ in 0..<count {
            let record = PomodoroSessionRecord(
                startedAt: midnight,
                endedAt: midnight,
                round: .focus,
                plannedDurationSeconds: 0,
                completed: true,
                isManualEntry: true,
                recordedAt: Date()
            )
            records.append(record)
        }

        self.historyStore.replace(records)
        self.reloadHistory()
    }

    private func removeFocusSessions(count: Int, on date: Date) {
        guard count > 0 else { return }

        var records = self.historyStore.load()
        let removableIDs = Set(
            records
                .filter {
                    $0.completed
                        && $0.round == .focus
                        && self.calendar.isDate($0.endedAt, inSameDayAs: date)
                }
                .sorted { $0.endedAt > $1.endedAt }
                .prefix(count)
                .map(\.id)
        )

        guard !removableIDs.isEmpty else { return }

        records.removeAll { removableIDs.contains($0.id) }
        self.historyStore.replace(records)
        self.reloadHistory()
    }

}
