import SwiftUI

/// A hollow ring that shows time remaining. Fully solid at start, empties as time passes.
struct TimerRingView: View {
    /// Fraction of time remaining (1.0 = full, 0.0 = empty).
    let remainingFraction: Double
    let isPaused: Bool
    var ringColor: Color = .accentColor
    var lineWidth: CGFloat = 4.0
    var pauseIconSize: CGFloat = 16

    var body: some View {
        let clamped = min(max(remainingFraction, 0), 1)

        ZStack {
            // Background track
            Circle()
                .stroke(lineWidth: lineWidth)
                .foregroundStyle(ringColor.opacity(0.2))

            // Remaining arc (starts full, shrinks clockwise from top)
            Circle()
                .trim(from: 0, to: clamped)
                .stroke(
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .foregroundStyle(ringColor)
                .rotationEffect(.degrees(-90))

            // Pause icon overlay
            if isPaused {
                HStack(spacing: pauseIconSize * 0.25) {
                    RoundedRectangle(cornerRadius: 1)
                        .frame(
                            width: pauseIconSize * 0.25,
                            height: pauseIconSize * 0.6
                        )
                    RoundedRectangle(cornerRadius: 1)
                        .frame(
                            width: pauseIconSize * 0.25,
                            height: pauseIconSize * 0.6
                        )
                }
                .foregroundStyle(ringColor)
                .opacity(0.7)
            }
        }
    }
}
