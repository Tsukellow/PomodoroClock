# PomodoroClock

`PomodoroClock` is a macOS-only Swift menu bar Pomodoro app scaffold.

The design intentionally borrows the strong parts of `pomotroid` while removing the features that are outside the reduced scope:

- Keep: timer sequencing, persistent settings, persistent session history, menu bar presence, and statistics.
- Remove: sound, global shortcuts, theming, localization, WebSocket integration, always-on-top, and multi-window desktop chrome.

## Planned Feature Set

- Menu bar first: the app lives in the macOS menu bar and uses a single panel window when clicked.
- Silent operation: no alert sounds or ticking.
- Core timer controls: start, pause, skip, and reset round.
- Configurable durations: focus, short break, long break, and rounds before long break.
- Optional silent notifications for round transitions.
- Launch at login toggle.
- Basic statistics in-panel: today, this week, all time, streaks, and a last-7-days breakdown.

## Architecture

- `PomodoroAppModel`: application coordinator and single source of truth.
- `CountdownEngine`: countdown runtime, isolated from SwiftUI.
- `HistoryStore`: JSON-backed session persistence in Application Support.
- `PomodoroSettings`: reduced, typed settings persisted through `UserDefaults`.
- `MenuPanelView`: segmented in-panel UI for timer, statistics, and settings.

## Why This Is A Good Start From `pomotroid`

`pomotroid` is strong where it separates timer mechanics from presentation and keeps session history as a first-class concern. This scaffold keeps that separation. The difference is that the UI shell is much smaller: one menu bar entry, one panel, one reduced settings surface.
