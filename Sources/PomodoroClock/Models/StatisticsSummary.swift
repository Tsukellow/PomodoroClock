import Foundation

struct DailyFocusCount: Identifiable {
    let id = UUID()
    let date: Date
    let completedFocusSessions: Int

    var shortLabel: String {
        Self.labelFormatter.string(from: self.date)
    }

    private static let labelFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEE")
        return formatter
    }()
}

struct MonthlyFocusCount: Identifiable {
    let id = UUID()
    let date: Date
    let completedFocusSessions: Int

    var shortLabel: String {
        Self.labelFormatter.string(from: self.date)
    }

    private static let labelFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMM")
        return formatter
    }()
}

struct StatisticsSummary {
    var todayFocusSessions: Int
    var yesterdayFocusSessions: Int
    var weeklyFocusSessions: Int
    var allTimeFocusSessions: Int
    var lastSevenDays: [DailyFocusCount]
    var lastThirtyDays: [DailyFocusCount]
    var lastTwelveMonths: [MonthlyFocusCount]

    static let empty = StatisticsSummary(
        todayFocusSessions: 0,
        yesterdayFocusSessions: 0,
        weeklyFocusSessions: 0,
        allTimeFocusSessions: 0,
        lastSevenDays: [],
        lastThirtyDays: [],
        lastTwelveMonths: []
    )

    static func make(from records: [PomodoroSessionRecord], calendar: Calendar = .current) -> StatisticsSummary {
        let focusRecords = records.filter { $0.round == .focus }
        let completedFocusRecords = focusRecords.filter(\.completed)
        let now = Date()
        let today = calendar.startOfDay(for: now)
        var mondayCalendar = calendar
        mondayCalendar.firstWeekday = 2
        mondayCalendar.minimumDaysInFirstWeek = 4

        // Today
        let todayFocusRecords = completedFocusRecords.filter {
            calendar.isDate($0.endedAt, inSameDayAs: now)
        }

        // Yesterday
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else {
            return .empty
        }
        let yesterdayFocusRecords = completedFocusRecords.filter {
            calendar.isDate($0.endedAt, inSameDayAs: yesterday)
        }

        // This week
        let weekInterval = mondayCalendar.dateInterval(of: .weekOfYear, for: now)
        let weekRecords = completedFocusRecords.filter {
            guard let weekInterval else { return false }
            return weekInterval.contains($0.endedAt)
        }

        // Daily grouping for charts
        let grouped = Dictionary(grouping: completedFocusRecords) {
            calendar.startOfDay(for: $0.endedAt)
        }

        let lastSevenDays = Self.dailyCounts(days: 7, today: today, grouped: grouped, calendar: calendar)
        let lastThirtyDays = Self.dailyCounts(days: 30, today: today, grouped: grouped, calendar: calendar)

        // Monthly grouping for year chart
        let lastTwelveMonths = Self.monthlyCounts(today: today, grouped: grouped, calendar: calendar)

        return StatisticsSummary(
            todayFocusSessions: todayFocusRecords.count,
            yesterdayFocusSessions: yesterdayFocusRecords.count,
            weeklyFocusSessions: weekRecords.count,
            allTimeFocusSessions: completedFocusRecords.count,
            lastSevenDays: lastSevenDays,
            lastThirtyDays: lastThirtyDays,
            lastTwelveMonths: lastTwelveMonths
        )
    }

    private static func dailyCounts(
        days: Int,
        today: Date,
        grouped: [Date: [PomodoroSessionRecord]],
        calendar: Calendar
    ) -> [DailyFocusCount] {
        (0..<days).compactMap { offset -> DailyFocusCount? in
            guard let date = calendar.date(byAdding: .day, value: -(days - 1 - offset), to: today) else {
                return nil
            }
            return DailyFocusCount(
                date: date,
                completedFocusSessions: grouped[date]?.count ?? 0
            )
        }
    }

    private static func monthlyCounts(
        today: Date,
        grouped: [Date: [PomodoroSessionRecord]],
        calendar: Calendar
    ) -> [MonthlyFocusCount] {
        (0..<12).compactMap { offset -> MonthlyFocusCount? in
            guard let monthDate = calendar.date(byAdding: .month, value: -(11 - offset), to: today) else {
                return nil
            }
            let components = calendar.dateComponents([.year, .month], from: monthDate)
            let count = grouped.reduce(0) { total, pair in
                let dc = calendar.dateComponents([.year, .month], from: pair.key)
                return dc.year == components.year && dc.month == components.month
                    ? total + pair.value.count : total
            }
            return MonthlyFocusCount(
                date: calendar.date(from: components) ?? monthDate,
                completedFocusSessions: count
            )
        }
    }
}
