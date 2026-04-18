import Foundation
import SwiftUI

// MARK: - Debug Clock
//
// A process-wide virtual clock used by debug/test code to pretend the
// current time is shifted forward by N hours. Lets you validate the
// follow-through copy tiers (36h / 4d / 7d) without waiting real days,
// and exercise meal-slot / recency logic against mock data.
//
// Production code should continue to call `Date()` directly. Only
// surfaces that are specifically about "what time is it right now for
// UX purposes" (committed-pick elapsed time, mock data anchoring,
// meal-slot detection) should read from `DebugClock.now`.
//
// The offset is persisted in UserDefaults so it survives app restarts,
// and defaults to 0 (real time) in all cases.

enum DebugClock {

    private static let offsetHoursKey = "ForkBook_DebugClock_OffsetHours"

    /// Hours added to real time. 0 = real time. Positive = future.
    static var offsetHours: Double {
        get { UserDefaults.standard.double(forKey: offsetHoursKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: offsetHoursKey)
            NotificationCenter.default.post(name: .debugClockChanged, object: nil)
        }
    }

    /// Current virtual time. Equals `Date()` when offsetHours == 0.
    static var now: Date {
        Date().addingTimeInterval(offsetHours * 3600)
    }

    /// Reset to real time.
    static func reset() { offsetHours = 0 }

    /// Convenience presets for testing follow-through copy tiers.
    static func shiftForward(hours: Double) { offsetHours += hours }
    static func shiftForward(days: Double) { offsetHours += days * 24 }
}

extension Notification.Name {
    static let debugClockChanged = Notification.Name("ForkBook_DebugClockChanged")
}

// MARK: - Debug Clock Panel
//
// A minimal debug sheet you can wire into any view with
// `.sheet(isPresented: $showDebugClock) { DebugClockPanel() }`.
// Attach it to a hidden long-press on a nav-bar element, or a
// debug-only gear button in #if DEBUG.

struct DebugClockPanel: View {
    @State private var offset: Double = DebugClock.offsetHours
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Virtual Time") {
                    Text("Offset: \(formatOffset(offset))")
                        .font(.headline)
                    Text("Virtual now: \(DebugClock.now.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section("Shift Forward") {
                    Button("+ 1 hour")  { bump(hours: 1) }
                    Button("+ 6 hours") { bump(hours: 6) }
                    Button("+ 1 day")   { bump(hours: 24) }
                    Button("+ 2 days")  { bump(hours: 48) }
                    Button("+ 4 days")  { bump(hours: 96) }
                    Button("+ 7 days")  { bump(hours: 168) }
                }

                Section("Follow-Through Tier Presets") {
                    Button("Tier 1: 'How'd it go?' (+12h)")       { set(hours: 12) }
                    Button("Tier 2: 'Did you go?' (+2 days)")     { set(hours: 48) }
                    Button("Tier 3: 'Still planning?' (+5 days)") { set(hours: 120) }
                    Button("Past window (+8 days)")               { set(hours: 192) }
                }

                Section {
                    Button("Reset to real time", role: .destructive) {
                        DebugClock.reset()
                        offset = 0
                    }
                }
            }
            .navigationTitle("Debug Clock")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func bump(hours: Double) {
        DebugClock.shiftForward(hours: hours)
        offset = DebugClock.offsetHours
    }

    private func set(hours: Double) {
        DebugClock.offsetHours = hours
        offset = hours
    }

    private func formatOffset(_ hours: Double) -> String {
        if hours == 0 { return "real time" }
        if abs(hours) < 24 { return String(format: "%+.0f hours", hours) }
        return String(format: "%+.1f days", hours / 24)
    }
}
