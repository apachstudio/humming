import SwiftUI

/// Design tokens pulled from the Humming Figma brand guidelines.
/// The app is fully greyscale by design — light arrives only as light.
enum HumTheme {
    // Dark screens
    static let charcoal = Color(hex: 0x1A1A1A)
    static let surfaceDark = Color(hex: 0x1E1E1E)
    static let textOnDark = Color(hex: 0xEBEBEB)
    static let mutedOnDark = Color(hex: 0x747474)
    static let greetingGray = Color(hex: 0x686868)
    static let labelFaint = Color(hex: 0x5B5B5B)
    static let hintGray = Color(hex: 0x979797)
    static let glyphInk = Color(hex: 0x1D1D1D)

    // Light screens
    static let ink = Color(hex: 0x0A0A0A)
    static let card = Color(hex: 0xF9FAFB)
    static let grayText = Color(hex: 0x99A1AF)
    static let grayText2 = Color(hex: 0x6A7282)
    static let dimmed = Color(hex: 0xD1D5DC)
    static let hairline = Color(hex: 0xE5E7EB)

    /// Soft grey gradient used for hum avatars.
    static let avatarGradient = LinearGradient(
        colors: [Color(hex: 0xD9D9D9), Color(hex: 0xF1F1F1)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Rotating greetings from the brand "UI COMMS" guidelines.
    static let greetings: [(top: String, bottom: String)] = [
        ("Hey!", "What's in your head?"),
        ("Hey!", "Back for another hit?"),
        ("Welcome back my friend,", "today is jamming seshhhh"),
        ("Haven't seen you in a while.", "Feeling creative today?")
    ]

    static func greetingOfTheDay(humCount: Int) -> (top: String, bottom: String) {
        guard humCount > 0 else { return greetings[0] }
        let day = Calendar.current.ordinality(of: .day, in: .year, for: .now) ?? 0
        return greetings[day % greetings.count]
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

extension TimeInterval {
    /// "0:15" style clock string.
    var clockString: String {
        let total = Int(self.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    /// "15s" or "1m 05s" style compact duration.
    var compactDuration: String {
        let total = Int(self.rounded())
        if total < 60 { return "\(total)s" }
        return String(format: "%dm %02ds", total / 60, total % 60)
    }
}

extension Date {
    var relativeLabel: String {
        let interval = Date.now.timeIntervalSince(self)
        if interval < 60 { return "Just now" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: self, relativeTo: .now)
    }
}
