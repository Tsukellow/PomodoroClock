# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build / Run

```bash
swift build
swift run
```

The app is macOS-only (macOS 14+, Swift 6.0). There is no test target yet.

Binary lands at `.build/debug/PomodoroClock`. The app uses `LSUIElement` — it runs as a menu bar accessory (no Dock icon, `.accessory` activation policy) except when the settings window is open (`.regular` activation policy).

## Architecture

**`PomodoroAppModel`** (`Sources/.../Services/PomodoroAppModel.swift`) — `@MainActor ObservableObject`, the single source of truth. Owns the `CountdownEngine`, `HistoryStore`, `NotificationManager`, and current `PomodoroSettings`. All timer state, round sequencing, and history mutations flow through this model. The `sessionSequence` array in settings drives the round order; advancing wraps around, and hitting index 0 again sets `cycleCompleted = true`.

**`AppDelegate`** (`Sources/.../AppDelegate.swift`) — `NSApplicationDelegate` that creates the `NSStatusItem` (menu bar icon), the `NSPopover` (panel shown on click), and the settings `NSWindow`. Draws the menu bar ring icon procedurally with `NSBezierPath`. Left-click toggles the timer; right-click toggles the popover.

**`CountdownEngine`** (`Sources/.../Services/CountdownEngine.swift`) — `@MainActor` countdown runtime using `Timer.scheduledTimer` with `.common` run loop mode. Tracks live elapsed time via `Date()` diff against `startedAt` + previously accumulated elapsed time. Calls `onTick` each second and `onCompletion` when elapsed >= total.

**`HistoryStore`** (`Sources/.../Services/HistoryStore.swift`) — Reads/writes `[PomodoroSessionRecord]` as JSON at `~/Library/Application Support/PomodoroClock/history.json`. Not Sendable; runs on main actor via the model.

**`PomodoroSettings`** (`Sources/.../Models/PomodoroSettings.swift`) — `Codable`, persisted to `UserDefaults` via JSON encoding with key `pomodoroClock.settings`. Also contains `Color`/`NSColor` hex extensions used throughout views.

## Key behaviors

- On natural round completion, the timer auto-starts the next round (unless cycle is complete).
- `resetRound()` from completed state resets to the first session of the sequence.
- `goBackRound()` moves backward in the session sequence without firing a notification.
- Manual focus session adjustments (the +/- buttons in statistics) write `isManualEntry: true` records to history.
- Notifications are silent (`content.sound = nil`), firing immediately (`trigger: nil`).
- The `StatsSummary` chart data is computed from `HistoryStore` records on every reload.

## Data flow

```
User interaction → AppDelegate → PomodoroAppModel
                                    ├── CountdownEngine (timer ticks)
                                    ├── HistoryStore (session persistence)
                                    ├── NotificationManager (round transitions)
                                    └── @Published properties → MenuPanelView / SettingsWindowView
```
