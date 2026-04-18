import Foundation
import FirebaseAuth
import FirebaseFirestore

// MARK: - Pick Event Logger
//
// Lightweight, fire-and-forget event logging for hero card impressions
// and user actions. Captures the feature vector a future ranking model
// would need: what was shown, in what context, and what the user did.
//
// Events are written to Firestore under:
//   users/{uid}/pickEvents/{auto-id}
//
// No reads, no UI, no blocking — just append-only telemetry.

struct PickEvent: Codable {
    // When
    let timestamp: Date
    let hourOfDay: Int
    let dayOfWeek: Int          // 1=Sunday … 7=Saturday

    // What was shown
    let restaurantName: String
    let cuisine: String
    let position: String        // "hero", "carousel_0", "carousel_1", etc.

    // Pick features (the future training features)
    let tableCount: Int         // How many table members have been
    let lovedCount: Int         // How many loved it
    let hasDish: Bool           // Did we have a dish to show?
    let freshestDaysAgo: Int    // How recent is the freshest take
    let repeatVisitorCount: Int // How many went 2+ times
    let distanceMeters: Double? // Distance from user (nil if unknown)
    let score: Double           // Current scorer output
    let yourVisitCount: Int     // User's own visit count
    let isNewToYou: Bool        // First time seeing this place?

    // What the user did
    let action: String          // "impression", "go_here", "i_went_here",
                                // "save_for_later", "swipe_past", "tap_carousel",
                                // "dismiss"
}

final class PickEventLogger {
    static let shared = PickEventLogger()
    private init() {}

    private let db = Firestore.firestore()

    // MARK: - Public API

    /// Log a hero impression (shown on screen)
    func logImpression(_ pick: ScoredPick, position: String = "hero") {
        log(pick: pick, position: position, action: "impression")
    }

    /// Log a user action on a pick
    func logAction(_ pick: ScoredPick, position: String = "hero", action: String) {
        log(pick: pick, position: position, action: action)
    }

    /// Log carousel impressions (batch — all visible cards)
    func logCarouselImpressions(_ picks: [ScoredPick]) {
        for (i, pick) in picks.prefix(5).enumerated() {
            log(pick: pick, position: "carousel_\(i)", action: "impression")
        }
    }

    // MARK: - Internal

    private func log(pick: ScoredPick, position: String, action: String) {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        let now = Date()
        let cal = Calendar.current

        let event = PickEvent(
            timestamp: now,
            hourOfDay: cal.component(.hour, from: now),
            dayOfWeek: cal.component(.weekday, from: now),
            restaurantName: pick.name,
            cuisine: pick.cuisine.rawValue,
            position: position,
            tableCount: pick.tableCount,
            lovedCount: pick.tableLoveCount,
            hasDish: pick.bestDish != nil,
            freshestDaysAgo: pick.tableTakes.map(\.daysAgo).min() ?? 999,
            repeatVisitorCount: pick.tableTakes.filter { $0.visitCount >= 2 }.count,
            distanceMeters: pick.distance,
            score: pick.score,
            yourVisitCount: pick.yourVisitCount,
            isNewToYou: pick.isNewToYou,
            action: action
        )

        // Fire-and-forget write — no await, no error handling needed
        do {
            try db.collection("users").document(uid)
                .collection("pickEvents")
                .addDocument(from: event)
        } catch {
            // Silent fail — telemetry should never block the app
            #if DEBUG
            print("[PickEventLogger] write failed: \(error.localizedDescription)")
            #endif
        }
    }
}
