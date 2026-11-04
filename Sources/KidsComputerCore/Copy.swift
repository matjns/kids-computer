import Foundation

public enum Greeting {
    public static func line(name: String, at date: Date, calendar: Calendar) -> String {
        let cleaned = name
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let hour = calendar.component(.hour, from: date)
        let hello: String
        switch hour {
        case 5..<12:
            hello = "Good morning"
        case 12..<17:
            hello = "Good afternoon"
        case 17..<21:
            hello = "Good evening"
        default:
            hello = "Hello"
        }
        if cleaned.isEmpty {
            return hello
        }
        return "\(hello), \(cleaned)"
    }
}

public enum DurationText {
    public static func minutes(_ seconds: Int) -> String {
        if seconds < 60 { return "Less than a minute" }
        let minutes = seconds / 60
        if minutes == 1 { return "1 minute" }
        return "\(minutes) minutes"
    }
}

public enum KidCopy {
    public static let prompt = "What do you want to do?"
    public static let comingSoonBadge = "Coming soon"
    public static let seeYouTomorrow = "See you tomorrow"
    public static let lockPaused = "Desktop lock is paused."
    public static let settingsGrace = "Desktop lock is paused for a few minutes so Settings can stay open."
    public static let emptyActivities = "Nothing here yet. A parent can add activities."
    public static let configError = "The activity list could not be read. A parent can fix it."
    public static let oneMinuteLeft = "1 min left"
    public static let lookNotSaved = "Your colors couldn't be saved. Ask a parent for help."

    public static func minutesLeft(_ minutes: Int) -> String {
        minutes == 1 ? oneMinuteLeft : "\(minutes) min left"
    }

    public static func comingSoon(title: String) -> String {
        "\(title) is coming soon."
    }

    public static func doneForToday(title: String) -> String {
        "\(title) is all done for today. It comes back tomorrow."
    }

    public static func failedToOpen(title: String) -> String {
        "Couldn't open \(title). Ask a parent for help."
    }

    public static func warning(title: String, secondsRemaining: Int) -> String {
        let minutes = max(1, Int((Double(secondsRemaining) / 60.0).rounded(.up)))
        if minutes == 1 {
            return "\(title) has about 1 minute left today."
        }
        return "\(title) has about \(minutes) minutes left today."
    }

    public static func timeUp(title: String) -> String {
        doneForToday(title: title)
    }

    public static var fixedStrings: [String] {
        [prompt, comingSoonBadge, seeYouTomorrow, lockPaused, settingsGrace, emptyActivities, configError, oneMinuteLeft, lookNotSaved]
    }
}
