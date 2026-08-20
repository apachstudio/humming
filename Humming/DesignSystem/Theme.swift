import SwiftUI
import UIKit

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

    /// First name extracted from the device name ("Andrea's iPhone" → "Andrea").
    static var firstName: String {
        let name = UIDevice.current.name
        for delimiter in ["'s ", "'s", "\u{2019}s ", "\u{2019}s"] {
            if let range = name.range(of: delimiter) {
                let candidate = String(name[..<range.lowerBound])
                let lower = candidate.lowercased()
                if !candidate.isEmpty, lower != "iphone", lower != "ipad", lower != "mac" {
                    return candidate
                }
            }
        }
        return ""
    }

    /// Rotating greetings from the brand "UI COMMS" guidelines.
    private static let greetings: [(top: String, bottom: String)] = [
        ("Hey!", "What\u{2019}s in your head?"),
        ("Hey!", "Back for another hit?"),
        ("Welcome back my friend,", "today is jamming seshhhh"),
        ("Haven\u{2019}t seen you in a while.", "Feeling creative today?")
    ]

    static func greetingOfTheDay(humCount: Int) -> (top: String, bottom: String) {
        let name = firstName
        let salutation = name.isEmpty ? "Hey!" : "Hey, \(name)!"
        guard humCount > 0 else {
            return (salutation, "What\u{2019}s in your head?")
        }
        let day = Calendar.current.ordinality(of: .day, in: .year, for: .now) ?? 0
        var (top, bottom) = greetings[day % greetings.count]
        if top == "Hey!" { top = salutation }
        return (top, bottom)
    }
}

enum HumMotion {
    static let headlineEntrance = Animation.easeOut(duration: 0.78).delay(0.08)
    static let headlineExit = Animation.easeInOut(duration: 0.72)
    static let libraryExit = Animation.easeInOut(duration: 0.5)
    static let bottomHintExit = Animation.easeInOut(duration: 0.58)

    static let buttonBreathing = Animation.easeInOut(duration: 2.05)
    static let buttonPress = Animation.spring(response: 0.5, dampingFraction: 0.48)
    static let buttonRelease = Animation.spring(response: 0.86, dampingFraction: 0.36, blendDuration: 0.12)
    static let buttonDescend = Animation.spring(response: 0.58, dampingFraction: 0.82)

    static let phaseChange = Animation.spring(response: 0.74, dampingFraction: 0.84)
    static let recordingTextIn = Animation.easeOut(duration: 0.58).delay(0.18)
    static let stopHintIn = Animation.easeOut(duration: 0.72).delay(0.12)
    static let textReveal = Animation.easeOut(duration: 0.62)
    static let textExit = Animation.easeInOut(duration: 0.28)
    static let librarySlide = Animation.spring(response: 0.68, dampingFraction: 0.9)

    static let startDelay: Duration = .milliseconds(580)
    static let textExitDelay: Duration = .milliseconds(220)
}

extension View {
    func premiumTextReveal(_ isVisible: Bool, yOffset: CGFloat = 14, blur: CGFloat = 8, delay: Double = 0) -> some View {
        modifier(PremiumTextRevealModifier(isVisible: isVisible, yOffset: yOffset, blur: blur, delay: delay))
    }

    @ViewBuilder
    func humMatchedTransitionSource<ID: Hashable>(id: ID, in namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
    }

    @ViewBuilder
    func humNavigationZoomDestination<ID: Hashable>(sourceID: ID, in namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            navigationTransition(.zoom(sourceID: sourceID, in: namespace))
        } else {
            self
        }
    }
}

private struct PremiumTextRevealModifier: ViewModifier {
    let isVisible: Bool
    let yOffset: CGFloat
    let blur: CGFloat
    var delay: Double = 0

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : yOffset)
            .blur(radius: isVisible ? 0 : blur)
            // The delay staggers entrances only — exits stay immediate and snappy.
            .animation(isVisible ? HumMotion.textReveal.delay(delay) : HumMotion.textExit, value: isVisible)
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
