import AppKit
import SwiftUI

struct MenuPanelView: View {
    @ObservedObject var model: PomodoroAppModel
    var onOpenSettings: () -> Void

    private var ringColor: Color {
        self.model.cycleCompleted
            ? self.model.settings.completedColor
            : self.model.settings.color(for: self.model.round)
    }

    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 2) {
                Text(self.model.cycleCompleted ? "Completed" : self.model.round.title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(self.model.focusSessionLabel)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            // Ring (clickable for pause/play)
            ZStack {
                TimerRingView(
                    remainingFraction: self.model.cycleCompleted ? 1.0 : self.model.remainingFraction,
                    isPaused: false,
                    ringColor: self.ringColor,
                    lineWidth: 6,
                    pauseIconSize: 24
                )

                if self.model.cycleCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(self.model.settings.completedColor)
                } else {
                    Text(self.model.formattedRemainingTime())
                        .font(.system(size: 20, weight: .medium, design: .monospaced))
                        .foregroundStyle(.primary.opacity(0.7))
                }
            }
            .frame(width: 100, height: 100)
            .contentShape(Circle())
            .onTapGesture {
                self.model.toggleTimer()
            }

            // Control buttons: left, reset, start/pause, right
            HStack(spacing: 16) {
                HoverIconButton(systemName: "backward.end.fill", help: "Previous") {
                    self.model.goBackRound()
                }
                HoverIconButton(systemName: "arrow.counterclockwise", help: "Reset") {
                    self.model.resetRound()
                }
                HoverIconButton(
                    systemName: self.model.isRunning ? "pause.fill" : "play.fill",
                    help: self.model.isRunning ? "Pause" : "Start"
                ) {
                    self.model.toggleTimer()
                }
                HoverIconButton(systemName: "forward.end.fill", help: "Next") {
                    self.model.skipRound()
                }
            }

            // Action bar: settings (left), quit (right)
            HStack {
                HoverIconButton(systemName: "gearshape", help: "Settings") {
                    self.onOpenSettings()
                }
                Spacer()
                HoverIconButton(systemName: "power", help: "Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .padding(10)
        .frame(width: 150)
    }
}

private struct HoverIconButton: View {
    let systemName: String
    let help: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: self.action) {
            Image(systemName: self.systemName)
                .font(.system(size: 12))
                .frame(width: 20, height: 20)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.primary.opacity(self.isHovered ? 0.1 : 0))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(self.help)
        .onHover { hovering in
            self.isHovered = hovering
        }
    }
}
