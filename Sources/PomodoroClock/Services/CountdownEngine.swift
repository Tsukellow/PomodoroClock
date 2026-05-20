import Foundation

@MainActor
final class CountdownEngine {
    var onTick: ((Int, Int) -> Void)?
    var onCompletion: (() -> Void)?

    private var timer: Timer?
    private var totalSeconds: Int
    private var elapsedBeforeCurrentRun = 0
    private var startedAt: Date?

    init(totalSeconds: Int) {
        self.totalSeconds = totalSeconds
    }

    var isRunning: Bool {
        self.timer != nil
    }

    var elapsedSeconds: Int {
        let liveElapsed = self.startedAt.map { Int(Date().timeIntervalSince($0)) } ?? 0
        return min(self.totalSeconds, self.elapsedBeforeCurrentRun + max(0, liveElapsed))
    }

    func configure(totalSeconds: Int) {
        self.stop()
        self.totalSeconds = totalSeconds
        self.elapsedBeforeCurrentRun = 0
        self.startedAt = nil
        self.emitTick()
    }

    func start() {
        guard self.timer == nil else {
            return
        }

        self.startedAt = Date()
        self.emitTick()

        self.timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.handleTick()
            }
        }
        RunLoop.main.add(self.timer!, forMode: .common)
    }

    func pause() {
        guard self.timer != nil else {
            return
        }

        self.elapsedBeforeCurrentRun = self.elapsedSeconds
        self.stop()
        self.startedAt = nil
        self.emitTick()
    }

    func reset() {
        self.stop()
        self.elapsedBeforeCurrentRun = 0
        self.startedAt = nil
        self.emitTick()
    }

    private func handleTick() {
        let elapsed = self.elapsedSeconds
        if elapsed >= self.totalSeconds {
            self.stop()
            self.elapsedBeforeCurrentRun = self.totalSeconds
            self.startedAt = nil
            self.emitTick()
            self.onCompletion?()
            return
        }

        self.emitTick()
    }

    private func stop() {
        self.timer?.invalidate()
        self.timer = nil
    }

    private func emitTick() {
        self.onTick?(self.elapsedSeconds, self.totalSeconds)
    }
}
