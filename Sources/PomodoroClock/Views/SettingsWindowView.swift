import Charts
import SwiftUI

struct SettingsWindowView: View {
    @ObservedObject var model: PomodoroAppModel
    @ObservedObject var launchAtLoginManager: LaunchAtLoginManager

    enum Tab: String, CaseIterable, Identifiable {
        case statistics = "Statistics"
        case settings = "Settings"
        var id: String { self.rawValue }
    }

    enum ChartPeriod: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case year = "Year"
    }

    @State private var selectedTab: Tab = .statistics
    @State private var chartPeriod: ChartPeriod = .week
    @State private var newRoundType: PomodoroRound = .focus
    @State private var showClearHistoryConfirm = false
    @State private var launchAtLogin = false

    var body: some View {
        TabView(selection: self.$selectedTab) {
            statisticsTab
                .tabItem { Label("Statistics", systemImage: "chart.bar") }
                .tag(Tab.statistics)

            settingsTab
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(Tab.settings)
        }
        .padding(20)
        .frame(width: 450, height: 580)
    }

    // MARK: - Statistics Tab

    private var statisticsTab: some View {
        self.settingsScrollView {
            self.settingsSection(title: "Summary", systemImage: "number") {
                self.settingsCard {
                    VStack(spacing: 10) {
                        HStack {
                            Text("Today")
                            Spacer()
                            HStack(spacing: 6) {
                                Button {
                                    self.model.adjustTodaySessions(by: -1)
                                } label: {
                                    Image(systemName: "minus.circle")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)

                                Text("\(self.model.statistics.todayFocusSessions) \(self.model.statistics.todayFocusSessions == 1 ? "session" : "sessions")")
                                    .foregroundStyle(.secondary)

                                Button {
                                    self.model.adjustTodaySessions(by: 1)
                                } label: {
                                    Image(systemName: "plus.circle")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Divider()

                        HStack {
                            Text("This Week")
                            Spacer()
                            Text("\(self.model.statistics.weeklyFocusSessions) \(self.model.statistics.weeklyFocusSessions == 1 ? "session" : "sessions")")
                                .foregroundStyle(.secondary)
                        }

                        Divider()

                        HStack {
                            Text("All Time")
                            Spacer()
                            Text("\(self.model.statistics.allTimeFocusSessions) \(self.model.statistics.allTimeFocusSessions == 1 ? "session" : "sessions")")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            self.settingsSection(title: "Chart", systemImage: "chart.bar") {
                self.settingsCard {
                    VStack(spacing: 12) {
                        Picker("Period", selection: self.$chartPeriod) {
                            ForEach(ChartPeriod.allCases, id: \.self) { period in
                                Text(period.rawValue).tag(period)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()

                        self.chartView
                            .frame(height: 150)
                    }
                }
            }

            self.settingsSection(title: "Data", systemImage: "trash") {
                self.settingsCard {
                    HStack {
                        Spacer()
                        Button("Clear History", role: .destructive) {
                            self.showClearHistoryConfirm = true
                        }
                        .alert("Clear All History?", isPresented: self.$showClearHistoryConfirm) {
                            Button("Cancel", role: .cancel) {}
                            Button("Clear", role: .destructive) {
                                self.model.clearHistory()
                            }
                        } message: {
                            Text("This will permanently delete all session records. This cannot be undone.")
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var chartView: some View {
        switch self.chartPeriod {
        case .week:
            Chart(self.model.statistics.lastSevenDays) { entry in
                BarMark(
                    x: .value("Day", entry.shortLabel),
                    y: .value("Sessions", entry.completedFocusSessions)
                )
                .foregroundStyle(Color.accentColor)
            }
            .chartYAxis {
                AxisMarks(preset: .automatic) { _ in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
        case .month:
            Chart(self.model.statistics.lastThirtyDays) { entry in
                BarMark(
                    x: .value("Day", entry.date, unit: .day),
                    y: .value("Sessions", entry.completedFocusSessions)
                )
                .foregroundStyle(Color.accentColor)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                }
            }
        case .year:
            Chart(self.model.statistics.lastTwelveMonths) { entry in
                BarMark(
                    x: .value("Month", entry.shortLabel),
                    y: .value("Sessions", entry.completedFocusSessions)
                )
                .foregroundStyle(Color.accentColor)
            }
        }
    }

    // MARK: - Settings Tab

    private var settingsTab: some View {
        self.settingsScrollView {
            self.settingsSection(title: "Durations & Colors", systemImage: "paintpalette") {
                self.settingsCard {
                    VStack(spacing: 10) {
                        durationRow(
                            title: "Focus",
                            minutes: self.settingBinding(\.focusMinutes),
                            colorHex: \.focusColorHex
                        )
                        Divider()
                        durationRow(
                            title: "Short Break",
                            minutes: self.settingBinding(\.shortBreakMinutes),
                            colorHex: \.shortBreakColorHex
                        )
                        Divider()
                        durationRow(
                            title: "Long Break",
                            minutes: self.settingBinding(\.longBreakMinutes),
                            colorHex: \.longBreakColorHex
                        )
                        Divider()
                        HStack {
                            Text("Completed")
                            Spacer()
                            ColorPicker("", selection: self.colorBinding(\.completedColorHex))
                                .labelsHidden()
                        }
                    }
                }
            }

            self.settingsSection(title: "Session Sequence", systemImage: "list.number") {
                self.settingsCard {
                    VStack(spacing: 6) {
                        ForEach(
                            Array(self.model.settings.sessionSequence.enumerated()),
                            id: \.offset
                        ) { index, round in
                            HStack(spacing: 8) {
                                Image(systemName: round.symbolName)
                                    .foregroundStyle(self.model.settings.color(for: round))
                                    .frame(width: 18)
                                Text(round.title)
                                Spacer()
                                Button {
                                    var updated = self.model.settings
                                    updated.sessionSequence.remove(at: index)
                                    self.model.settings = updated
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.red.opacity(0.8))
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Divider()

                        HStack(spacing: 8) {
                            Image(systemName: self.newRoundType.symbolName)
                                .foregroundStyle(self.model.settings.color(for: self.newRoundType))
                                .frame(width: 18)
                            Picker("Type", selection: self.$newRoundType) {
                                ForEach(PomodoroRound.allCases) { round in
                                    Text(round.title).tag(round)
                                }
                            }
                            .labelsHidden()
                            Spacer()
                            Button {
                                var updated = self.model.settings
                                updated.sessionSequence.append(self.newRoundType)
                                self.model.settings = updated
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(.green.opacity(0.8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            self.settingsSection(title: "Startup", systemImage: "power") {
                self.settingsCard {
                    HStack {
                        Text("Launch at login")
                        Spacer()
                        Toggle("", isOn: self.$launchAtLogin)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .onAppear {
                                self.launchAtLogin = self.launchAtLoginManager.isEnabled
                            }
                            .onChange(of: self.launchAtLogin) { _, newValue in
                                guard newValue != self.launchAtLoginManager.isEnabled else { return }
                                self.launchAtLoginManager.setEnabled(newValue)
                                self.launchAtLogin = self.launchAtLoginManager.isEnabled
                            }
                    }
                }

                if let error = self.launchAtLoginManager.errorMessage, !error.isEmpty {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    // MARK: - Layout Helpers

    @ViewBuilder
    private func settingsScrollView<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func settingsSection<Content: View>(title: String, systemImage: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.headline)

            content()
        }
    }

    @ViewBuilder
    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                Color.primary.opacity(0.035),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
    }

    // MARK: - Data Helpers

    private func durationRow(
        title: String,
        minutes: Binding<Int>,
        colorHex: WritableKeyPath<PomodoroSettings, String>
    ) -> some View {
        HStack(spacing: 8) {
            Text(title)
            Spacer()
            Slider(
                value: Binding(
                    get: { Double(minutes.wrappedValue) },
                    set: { minutes.wrappedValue = max(1, min(60, Int($0.rounded()))) }
                ),
                in: 1...60
            ) {
                EmptyView()
            }
            .frame(width: 120)
            Text("\(minutes.wrappedValue) min")
                .font(.body.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 52, alignment: .trailing)
            ColorPicker("", selection: self.colorBinding(colorHex))
                .labelsHidden()
        }
    }

    private func settingBinding<Value>(_ keyPath: WritableKeyPath<PomodoroSettings, Value>) -> Binding<Value> {
        Binding(
            get: { self.model.settings[keyPath: keyPath] },
            set: { newValue in
                var updated = self.model.settings
                updated[keyPath: keyPath] = newValue
                self.model.settings = updated
            }
        )
    }

    private func colorBinding(_ keyPath: WritableKeyPath<PomodoroSettings, String>) -> Binding<Color> {
        Binding(
            get: { Color(hex: self.model.settings[keyPath: keyPath]) },
            set: { newColor in
                var updated = self.model.settings
                updated[keyPath: keyPath] = newColor.hexString
                self.model.settings = updated
            }
        )
    }
}
