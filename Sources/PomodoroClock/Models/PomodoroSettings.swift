import AppKit
import Foundation
import SwiftUI

struct PomodoroSettings: Codable, Equatable {
    var focusMinutes: Int
    var shortBreakMinutes: Int
    var longBreakMinutes: Int
    var sessionSequence: [PomodoroRound]
    var focusColorHex: String
    var shortBreakColorHex: String
    var longBreakColorHex: String
    var completedColorHex: String

    static let `default` = PomodoroSettings(
        focusMinutes: 25,
        shortBreakMinutes: 5,
        longBreakMinutes: 15,
        sessionSequence: [
            .focus, .shortBreak,
            .focus, .shortBreak,
            .focus, .shortBreak,
            .focus, .longBreak,
        ],
        focusColorHex: "5E5CE6",
        shortBreakColorHex: "30D158",
        longBreakColorHex: "FF9F0A",
        completedColorHex: "34C759"
    )

    var completedColor: Color {
        Color(hex: self.completedColorHex)
    }

    var completedNSColor: NSColor {
        NSColor(hex: self.completedColorHex)
    }

    func color(for round: PomodoroRound) -> Color {
        switch round {
        case .focus:
            return Color(hex: self.focusColorHex)
        case .shortBreak:
            return Color(hex: self.shortBreakColorHex)
        case .longBreak:
            return Color(hex: self.longBreakColorHex)
        }
    }

    func nsColor(for round: PomodoroRound) -> NSColor {
        switch round {
        case .focus:
            return NSColor(hex: self.focusColorHex)
        case .shortBreak:
            return NSColor(hex: self.shortBreakColorHex)
        case .longBreak:
            return NSColor(hex: self.longBreakColorHex)
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }

    var hexString: String {
        guard let components = NSColor(self).usingColorSpace(.sRGB) else {
            return "808080"
        }
        let r = Int(round(components.redComponent * 255))
        let g = Int(round(components.greenComponent * 255))
        let b = Int(round(components.blueComponent * 255))
        return String(format: "%02X%02X%02X", r, g, b)
    }
}

extension NSColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = CGFloat((int >> 16) & 0xFF) / 255.0
        let g = CGFloat((int >> 8) & 0xFF) / 255.0
        let b = CGFloat(int & 0xFF) / 255.0
        self.init(srgbRed: r, green: g, blue: b, alpha: 1.0)
    }
}
