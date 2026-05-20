import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var settingsWindow: NSWindow?
    private var model: PomodoroAppModel!
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        if NSApp.activationPolicy() != .accessory {
            NSApp.setActivationPolicy(.accessory)
        }

        self.model = PomodoroAppModel()
        self.setupStatusItem()
        self.setupPopover()
        self.observeModelChanges()
        self.updateMenuBarIcon()
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        guard let button = self.statusItem.button else { return }

        button.target = self
        button.action = #selector(statusItemLeftClicked(_:))
        button.sendAction(on: [.leftMouseUp])

        NSEvent.addLocalMonitorForEvents(matching: .rightMouseUp) { [weak self] event in
            guard let self,
                  let button = self.statusItem.button,
                  let window = button.window,
                  window == event.window
            else {
                return event
            }
            self.togglePopover()
            return nil
        }
    }

    @objc private func statusItemLeftClicked(_ sender: NSStatusBarButton) {
        self.model.toggleTimer()
    }

    // MARK: - Menu Bar Icon Rendering

    private func updateMenuBarIcon() {
        guard let button = self.statusItem.button else { return }

        let diameter: CGFloat = 18
        let lineWidth: CGFloat = 2.0
        let trackAlpha: CGFloat = 0.3
        let isCycleCompleted = self.model.cycleCompleted
        let isPaused = !self.model.isRunning && !isCycleCompleted
        let remaining = isCycleCompleted ? 1.0 : self.model.remainingFraction
        let ringColor = isCycleCompleted
            ? self.model.settings.completedNSColor
            : self.model.settings.nsColor(for: self.model.round)

        let image = NSImage(
            size: NSSize(width: diameter, height: diameter),
            flipped: false
        ) { _ in
            let center = NSPoint(x: diameter / 2, y: diameter / 2)
            let radius = (diameter - lineWidth) / 2

            // Background track
            let track = NSBezierPath()
            track.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
            track.lineWidth = lineWidth
            track.lineCapStyle = .round
            ringColor.withAlphaComponent(trackAlpha).setStroke()
            track.stroke()

            // Remaining arc (full at start, empties as time passes)
            let clamped = min(max(remaining, 0), 1)
            if clamped > 0.001 {
                let arc = NSBezierPath()
                arc.appendArc(
                    withCenter: center,
                    radius: radius,
                    startAngle: 90,
                    endAngle: 90 - 360 * clamped,
                    clockwise: true
                )
                arc.lineWidth = lineWidth
                arc.lineCapStyle = .round
                ringColor.setStroke()
                arc.stroke()
            }

            if isCycleCompleted {
                // Checkmark icon
                let checkPath = NSBezierPath()
                checkPath.move(to: NSPoint(x: center.x - 3.5, y: center.y - 0.5))
                checkPath.line(to: NSPoint(x: center.x - 1, y: center.y - 3))
                checkPath.line(to: NSPoint(x: center.x + 4, y: center.y + 3))
                checkPath.lineWidth = 1.8
                checkPath.lineCapStyle = .round
                checkPath.lineJoinStyle = .round
                ringColor.setStroke()
                checkPath.stroke()
            } else if isPaused {
                // Pause icon (two vertical bars)
                let barWidth: CGFloat = 2.0
                let barHeight: CGFloat = 7.0
                let gap: CGFloat = 2.5
                let barY = center.y - barHeight / 2

                let leftBar = NSBezierPath(rect: NSRect(
                    x: center.x - gap / 2 - barWidth,
                    y: barY,
                    width: barWidth,
                    height: barHeight
                ))
                let rightBar = NSBezierPath(rect: NSRect(
                    x: center.x + gap / 2,
                    y: barY,
                    width: barWidth,
                    height: barHeight
                ))

                ringColor.setFill()
                leftBar.fill()
                rightBar.fill()
            }

            return true
        }

        image.isTemplate = false
        button.image = image
    }

    // MARK: - Model Observation

    private func observeModelChanges() {
        self.model.$elapsedSeconds
            .combineLatest(self.model.$isRunning, self.model.$round, self.model.$cycleCompleted)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateMenuBarIcon()
            }
            .store(in: &self.cancellables)

        self.model.$settings
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateMenuBarIcon()
            }
            .store(in: &self.cancellables)
    }

    // MARK: - Popover

    private func setupPopover() {
        self.popover.contentSize = NSSize(width: 170, height: 240)
        self.popover.behavior = .transient
        self.popover.animates = true

        let panelView = MenuPanelView(
            model: self.model,
            onOpenSettings: { [weak self] in
                self?.openSettingsWindow()
            }
        )
        self.popover.contentViewController = NSHostingController(rootView: panelView)
    }

    private func togglePopover() {
        if self.popover.isShown {
            self.popover.performClose(nil)
        } else {
            guard let button = self.statusItem.button else { return }
            self.popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            self.popover.contentViewController?.view.window?.makeKey()
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // MARK: - Settings Window

    private func openSettingsWindow() {
        if self.popover.isShown {
            self.popover.performClose(nil)
        }

        if let window = self.settingsWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsWindowView(model: self.model, launchAtLoginManager: self.model.launchAtLoginManager)
        let hostingController = NSHostingController(rootView: settingsView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 580),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = hostingController
        window.title = "Pomodoro Clock Settings"
        window.isReleasedWhenClosed = false
        window.center()

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.settingsWindow = nil
                NSApp.setActivationPolicy(.accessory)
            }
        }

        self.settingsWindow = window
    }
}
