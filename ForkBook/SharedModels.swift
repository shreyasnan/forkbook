import SwiftUI

// MARK: - Shared Model Types
//
// Types used across Home, Search, My Places, and Restaurant Detail views.
// Extracted here so each view file can reference them without cross-dependencies.

// MARK: - Committed Pick (persisted — explicit user intent)

struct CommittedPick: Codable {
    let name: String
    let address: String
    let cuisineRaw: String
    let committedAt: Date
    var bestDishName: String?

    var cuisine: CuisineType {
        CuisineType(rawValue: cuisineRaw) ?? .other
    }

    var bestDish: String? { bestDishName }

    var hoursAgo: Double {
        DebugClock.now.timeIntervalSince(committedAt) / 3600
    }

    static func save(name: String, address: String, cuisine: CuisineType, bestDish: String? = nil) {
        let cp = CommittedPick(
            name: name,
            address: address,
            cuisineRaw: cuisine.rawValue,
            committedAt: Date(),
            bestDishName: bestDish
        )
        if let data = try? JSONEncoder().encode(cp) {
            UserDefaults.standard.set(data, forKey: "ForkBook_CommittedPick")
        }
    }

    static func load() -> CommittedPick? {
        guard let data = UserDefaults.standard.data(forKey: "ForkBook_CommittedPick"),
              let cp = try? JSONDecoder().decode(CommittedPick.self, from: data)
        else { return nil }
        return cp
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: "ForkBook_CommittedPick")
    }
}

// MARK: - Last Shown Hero

struct LastShownHero: Codable {
    let name: String
    let shownAt: Date

    static func save(name: String) {
        let lsh = LastShownHero(name: name, shownAt: Date())
        if let data = try? JSONEncoder().encode(lsh) {
            UserDefaults.standard.set(data, forKey: "ForkBook_LastShownHero")
        }
    }

    static func load() -> LastShownHero? {
        guard let data = UserDefaults.standard.data(forKey: "ForkBook_LastShownHero"),
              let lsh = try? JSONDecoder().decode(LastShownHero.self, from: data)
        else { return nil }
        return lsh
    }
}

// MARK: - Table Member Take

struct TableMemberTake: Identifiable {
    let id = UUID()
    let name: String
    let reaction: Reaction?
    let dishes: [String]
    let daysAgo: Int
    let visitCount: Int

    var bestDish: String? { dishes.first }
}

// MARK: - Dish Recommendation

struct DishRecommendation: Identifiable {
    let id = UUID()
    let dish: String
    let recommender: String
}

// MARK: - Scored Pick

struct ScoredPick: Identifiable {
    var id: String { name.lowercased() }
    let name: String
    let address: String
    let cuisine: CuisineType
    let tableTakes: [TableMemberTake]
    let bestDish: String?
    let allDishes: [DishRecommendation]
    let distance: Double?
    let yourReaction: Reaction?
    let yourVisitCount: Int
    let yourDaysAgo: Int
    var reason: String
    var score: Double

    var hasTableSignal: Bool { !tableTakes.isEmpty }
    var tableCount: Int { tableTakes.count }
    var tableLoveCount: Int { tableTakes.filter { $0.reaction == .loved }.count }
    var isNewToYou: Bool { yourReaction == nil && yourVisitCount <= 0 }
}

// MARK: - Home Hero State

enum HomeHeroState {
    case committed(CommittedPick)
    case decision(ScoredPick, isReturning: Bool)
    case fallback(Restaurant)
    case empty
}

// MARK: - Restaurant Detail Context
//
// The restaurant detail page adapts its content and CTAs based on where
// it was opened from and the restaurant's state.

enum DetailContext {
    /// From Home — full view/edit flow with "Go here" / "I went here" / "Save for later"
    case recommendation

    /// From Search (table result) — same as recommendation but simpler actions
    case searchResult

    /// From Search (new-to-table) — empty state, "I went here" / "Save for later"
    case newToTable

    /// From My Places — visited/go-to — shows "Your visit" history, "Log another visit"
    case visited

    /// From My Places — planned — shows "What to order", "I went here" / "Remove from plan"
    case planned

    /// From My Places — saved — shows "What to order", "Go here" / "I went here"
    case saved
}

// MARK: - Restaurant Detail Action
//
// Actions reported by RestaurantDetailPage to its parent for handling.
// Parent view manages: save to store, show toast, navigate, etc.

enum DetailAction {
    /// User tapped "Go here" — add to committed/planned
    case goHere

    /// User logged a visit — reaction, dishes eaten, note
    case iWentHere(reaction: Reaction?, dishes: [String], note: String)

    /// User tapped "Save for later"
    case saveForLater

    /// User tapped "Log another visit" (from visited context)
    case logAnotherVisit

    /// User tapped "Remove from plan" (from planned context)
    case removeFromPlan
}

// MARK: - Cuisine → Dish Emoji Helper

func dishEmoji(for cuisine: CuisineType) -> String {
    switch cuisine {
    case .japanese: return "🍣"
    case .chinese: return "🥟"
    case .korean: return "🍜"
    case .thai: return "🌶️"
    case .vietnamese: return "🍲"
    case .indian: return "🍛"
    case .italian: return "🍝"
    case .french: return "🥐"
    case .mexican: return "🌮"
    case .mediterranean: return "🥗"
    case .american: return "🍔"
    case .other: return "🍽️"
    }
}
