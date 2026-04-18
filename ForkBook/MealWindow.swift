import Foundation

// MARK: - Meal Window
//
// Time-of-day bucket used to tune copy on the home surface ("Tonight" vs
// "Lunch" vs "Breakfast"). Reads from DebugClock so the in-app time
// shifter can exercise each state without waiting for the real wall clock.
//
// The windows are intentionally coarse (three buckets, no late-night):
//   - Late-night opens land in Tonight because a user scrolling at
//     midnight is almost always thinking "tonight" or "tomorrow night,"
//     not literally "what's open right now."
//   - Afternoon rolls into Tonight around 2:30 PM because that's when
//     people start planning dinner.
//
// If richer states are needed later (late-night, afternoon-coffee), add
// cases here and update the call sites in HomeTestView.

enum MealWindow {
    case breakfast
    case lunch
    case tonight

    /// Shown as the big page header on Home ("Tonight", "Lunch", etc.)
    var headerLabel: String {
        switch self {
        case .breakfast: return "Breakfast"
        case .lunch:     return "Lunch"
        case .tonight:   return "Tonight"
        }
    }

    /// Uppercase fragment used after "YOUR TABLE'S PICK FOR " in hero eyebrow.
    var eyebrowFragment: String {
        switch self {
        case .breakfast: return "BREAKFAST"
        case .lunch:     return "LUNCH"
        case .tonight:   return "TONIGHT"
        }
    }

    /// Uppercase "FRIDAY · 7:14 PM · BROOKLYN" line shown above the big
    /// "Tonight" header. Grounds the home surface in time + place so picks
    /// read as "right now, right here" rather than generic browsing.
    /// Drops the city segment when `city` is nil / empty.
    static func anchorLine(city: String?) -> String {
        let now = DebugClock.now
        let weekdayFmt = DateFormatter()
        weekdayFmt.dateFormat = "EEEE"
        let weekday = weekdayFmt.string(from: now).uppercased()

        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "h:mm a"
        // Force uppercase AM/PM (locale can return lowercase in some regions)
        let time = timeFmt.string(from: now).uppercased()

        var parts = [weekday, time]
        if let city, !city.isEmpty { parts.append(city.uppercased()) }
        return parts.joined(separator: " \u{00B7} ")
    }

    /// Current window based on DebugClock.now (which respects the in-app
    /// time shifter; equals real `Date()` when offset is zero).
    static var current: MealWindow {
        let cal = Calendar.current
        let now = DebugClock.now
        let h = cal.component(.hour, from: now)
        let m = cal.component(.minute, from: now)
        let minutes = h * 60 + m

        switch minutes {
        case 300..<630:   return .breakfast  // 05:00 – 10:30
        case 630..<870:   return .lunch      // 10:30 – 14:30
        default:          return .tonight    // everything else rolls to Tonight
        }
    }
}
