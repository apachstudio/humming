import Foundation

public enum Titles {
    public static func title(for date: Date, existing: [String]) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        let prefix: String
        switch hour {
        case 0..<5: prefix = "Late Night Jam"
        case 5..<12: prefix = "Morning Melody"
        case 12..<17: prefix = "Afternoon Sketch"
        case 17..<21: prefix = "Evening Hum"
        default: prefix = "Late Night Jam"
        }
        let used = Set(existing)
        for n in 1..<200 {
            let title = "\(prefix) #\(n)"
            if !used.contains(title) { return title }
        }
        return "\(prefix) #\(Int(date.timeIntervalSince1970))"
    }

    public static func duration(_ ms: Double) -> String {
        let total = max(0, Int((ms / 1000).rounded()))
        let m = total / 60
        let s = total % 60
        return m > 0 ? "\(m):\(String(format: "%02d", s))" : "0:\(String(format: "%02d", s))"
    }

    public static func recordedAt(_ date: Date, now: Date = Date()) -> String {
        let calendar = Calendar.current
        let time = date.formatted(date: .omitted, time: .shortened)
        if calendar.isDate(date, inSameDayAs: now) {
            return "Today, \(time)"
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) {
            return "Yesterday, \(time)"
        }
        return date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    public static func timer(_ interval: TimeInterval) -> String {
        let total = Int(interval)
        let m = total / 60
        let s = total % 60
        return String(format: "%02d:%02d", m, s)
    }

    public static func greeting(on date: Date = Date()) -> (kicker: String, line: String) {
        let greetings = [
            ("Yo!", "What's in your head?"),
            ("Haven't seen you in a while", "Feeling creative today?"),
            ("Yo.", "Back for another hit?"),
            ("Welcome back my friend,", "Today is jamming seshhhh"),
        ]
        let day = Int(date.timeIntervalSince1970 / 86_400)
        return greetings[day % greetings.count]
    }
}
