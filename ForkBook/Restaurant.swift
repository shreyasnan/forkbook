import Foundation

// MARK: - Data Models

enum RestaurantCategory: String, Codable, CaseIterable, Identifiable {
    case visited  = "Visited"
    case planned  = "Planned"
    case saved    = "Saved"
    case wishlist = "Wishlist"   // Legacy — treated as .saved

    var id: String { rawValue }

    /// Normalize legacy values
    var normalized: RestaurantCategory {
        self == .wishlist ? .saved : self
    }
}

enum CuisineType: String, Codable, CaseIterable, Identifiable {
    case american = "American"
    case chinese = "Chinese"
    case french = "French"
    case indian = "Indian"
    case italian = "Italian"
    case japanese = "Japanese"
    case korean = "Korean"
    case mediterranean = "Mediterranean"
    case mexican = "Mexican"
    case thai = "Thai"
    case vietnamese = "Vietnamese"
    case other = "Other"

    var id: String { rawValue }
}

// MARK: - Reaction & Occasion

enum Reaction: String, Codable, CaseIterable {
    case loved = "Loved"
    case liked = "Liked"
    case meh = "Meh"

    var emoji: String {
        switch self {
        case .loved: return "❤️"
        case .liked: return "👍"
        case .meh: return "😐"
        }
    }

    /// Map reaction to a star rating for backward compatibility
    var starRating: Int {
        switch self {
        case .loved: return 5
        case .liked: return 4
        case .meh: return 2
        }
    }
}

enum OccasionTag: String, Codable, CaseIterable, Identifiable {
    case dateNight = "Date night"
    case family = "Family"
    case groupDinner = "Group dinner"
    case quickBite = "Quick bite"
    case business = "Business"
    case celebration = "Celebration"
    case casual = "Casual"
    case specialOccasion = "Special occasion"

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .dateNight: return "🌙"
        case .family: return "👨‍👩‍👧"
        case .groupDinner: return "👥"
        case .quickBite: return "⚡"
        case .business: return "💼"
        case .celebration: return "🎉"
        case .casual: return "☕"
        case .specialOccasion: return "✨"
        }
    }
}

// MARK: - Dining Frequency

enum DiningFrequency: String, Codable, CaseIterable, Identifiable {
    case fewTimesAWeek = "A few times a week"
    case onceAWeek = "About once a week"
    case coupleTimesAMonth = "A couple times a month"
    case onceAMonthOrLess = "Once a month or less"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .fewTimesAWeek: return "flame.fill"
        case .onceAWeek: return "calendar"
        case .coupleTimesAMonth: return "calendar.badge.clock"
        case .onceAMonthOrLess: return "moon.stars"
        }
    }

    var shortLabel: String {
        switch self {
        case .fewTimesAWeek: return "Few times/week"
        case .onceAWeek: return "Once a week"
        case .coupleTimesAMonth: return "Couple times/month"
        case .onceAMonthOrLess: return "Once a month or less"
        }
    }
}

// MARK: - User Taste Preferences

struct TastePreferences: Codable {
    var favoriteCuisines: [CuisineType]   // ordered, top 3-5
    var diningFrequency: DiningFrequency?
    var onboardingCompleted: Bool

    init(favoriteCuisines: [CuisineType] = [], diningFrequency: DiningFrequency? = nil, onboardingCompleted: Bool = false) {
        self.favoriteCuisines = favoriteCuisines
        self.diningFrequency = diningFrequency
        self.onboardingCompleted = onboardingCompleted
    }
}

// MARK: - Dish Verdict
//
// Three-way per-dish signal captured in the log flow. We collapse this to
// `DishItem.liked: Bool` for existing UI (chips, counters, card summaries),
// but we ALSO preserve the original verdict so higher-fidelity views and
// future recommendations can tell "Skip" apart from "Okay" — information
// that `liked=false` alone loses.
//
// Source of truth: AddPlaceTestFlow. Raw values are the same snake_case
// strings the log flow always used, so old in-memory state is unaffected.
enum DishVerdict: String, Codable, CaseIterable {
    case getAgain = "get_again"
    case maybe = "maybe"
    case skip = "skip"

    /// Map verdict → legacy `liked` boolean. getAgain/maybe both count as
    /// liked; only skip is disliked. Matches the mapping AddPlaceTestFlow
    /// was doing inline before this field existed, so card counts don't
    /// shift for existing data.
    var liked: Bool {
        switch self {
        case .getAgain, .maybe: return true
        case .skip: return false
        }
    }
}

// MARK: - Dish Item

struct DishItem: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var liked: Bool         // true = liked, false = disliked (legacy — derived from verdict when present)
    var emoji: String       // e.g. "🍳"
    var isLead: Bool        // the standout dish for this restaurant
    var verdict: DishVerdict? // 3-way signal from the log flow; nil for legacy dishes logged before we tracked this

    init(
        id: UUID = UUID(),
        name: String,
        liked: Bool = true,
        emoji: String = "🍽️",
        isLead: Bool = false,
        verdict: DishVerdict? = nil
    ) {
        self.id = id
        self.name = name
        // When a verdict is provided, it's the source of truth — `liked`
        // is a derived convenience. This keeps the two fields consistent
        // at construction time so downstream code never sees a verdict=skip
        // dish flagged liked=true.
        self.liked = verdict?.liked ?? liked
        self.emoji = emoji
        self.isLead = isLead
        self.verdict = verdict
    }

    // Backward-compatible decoding
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        liked = try container.decode(Bool.self, forKey: .liked)
        emoji = try container.decodeIfPresent(String.self, forKey: .emoji) ?? "🍽️"
        isLead = try container.decodeIfPresent(Bool.self, forKey: .isLead) ?? false
        verdict = try container.decodeIfPresent(DishVerdict.self, forKey: .verdict)
    }
}

// MARK: - Restaurant

struct Restaurant: Identifiable, Codable {
    var id: UUID
    var name: String
    var address: String
    var cuisine: CuisineType
    var category: RestaurantCategory
    var rating: Int
    var notes: String
    var recommendedBy: String
    var dishes: [DishItem]
    var dateAdded: Date
    var dateVisited: Date?
    var visitCount: Int
    var reaction: Reaction?
    var occasionTags: [OccasionTag]
    var quickNote: String           // Short personal memory: "Great with a group", "Skip the tacos"
    var personalNote: String        // Longer personal note for detail page
    var isGoTo: Bool                // User-declared go-to status (only explicit state)
    var goToNudgeShown: Bool        // Whether the go-to nudge has been shown (show once only)
    var saveReason: String          // Auto-captured context when saved: "From Jay's recommendation"
    var latitude: Double?
    var longitude: Double?
    var googlePlaceId: String?      // Stable Google Place ID — used to look up menu data.
                                    // Populated on add for new records, backfilled for old ones.

    init(
        id: UUID = UUID(),
        name: String = "",
        address: String = "",
        cuisine: CuisineType = .other,
        category: RestaurantCategory = .visited,
        rating: Int = 0,
        notes: String = "",
        recommendedBy: String = "",
        dishes: [DishItem] = [],
        dateAdded: Date = Date(),
        dateVisited: Date? = nil,
        visitCount: Int = 1,
        reaction: Reaction? = nil,
        occasionTags: [OccasionTag] = [],
        quickNote: String = "",
        personalNote: String = "",
        isGoTo: Bool = false,
        goToNudgeShown: Bool = false,
        saveReason: String = "",
        latitude: Double? = nil,
        longitude: Double? = nil,
        googlePlaceId: String? = nil
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.cuisine = cuisine
        self.category = category
        self.rating = rating
        self.notes = notes
        self.recommendedBy = recommendedBy
        self.dishes = dishes
        self.dateAdded = dateAdded
        self.dateVisited = dateVisited
        self.visitCount = visitCount
        self.reaction = reaction
        self.occasionTags = occasionTags
        self.quickNote = quickNote
        self.personalNote = personalNote
        self.isGoTo = isGoTo
        self.goToNudgeShown = goToNudgeShown
        self.saveReason = saveReason
        self.latitude = latitude
        self.longitude = longitude
        self.googlePlaceId = googlePlaceId
    }

    // Custom decoding for backward compat
    enum CodingKeys: String, CodingKey {
        case id, name, address, cuisine, category, rating, notes
        case recommendedBy, dishes, dateAdded, dateVisited, visitCount
        case reaction, occasionTags, quickNote, personalNote
        case isGoTo, goToNudgeShown, saveReason
        case latitude, longitude
        case googlePlaceId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        address = try container.decode(String.self, forKey: .address)
        cuisine = try container.decode(CuisineType.self, forKey: .cuisine)
        let rawCategory = try container.decode(RestaurantCategory.self, forKey: .category)
        category = rawCategory.normalized
        rating = try container.decode(Int.self, forKey: .rating)
        notes = try container.decode(String.self, forKey: .notes)
        recommendedBy = try container.decode(String.self, forKey: .recommendedBy)
        dishes = try container.decode([DishItem].self, forKey: .dishes)
        dateAdded = try container.decode(Date.self, forKey: .dateAdded)
        dateVisited = try container.decodeIfPresent(Date.self, forKey: .dateVisited)
        visitCount = try container.decodeIfPresent(Int.self, forKey: .visitCount) ?? 1
        reaction = try container.decodeIfPresent(Reaction.self, forKey: .reaction)
        occasionTags = try container.decodeIfPresent([OccasionTag].self, forKey: .occasionTags) ?? []
        quickNote = try container.decodeIfPresent(String.self, forKey: .quickNote) ?? ""
        personalNote = try container.decodeIfPresent(String.self, forKey: .personalNote) ?? ""
        isGoTo = try container.decodeIfPresent(Bool.self, forKey: .isGoTo) ?? false
        goToNudgeShown = try container.decodeIfPresent(Bool.self, forKey: .goToNudgeShown) ?? false
        saveReason = try container.decodeIfPresent(String.self, forKey: .saveReason) ?? ""
        latitude = try container.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try container.decodeIfPresent(Double.self, forKey: .longitude)
        googlePlaceId = try container.decodeIfPresent(String.self, forKey: .googlePlaceId)
    }

    // MARK: - Helpers

    var likedDishes: [DishItem] { dishes.filter { $0.liked } }
    var dislikedDishes: [DishItem] { dishes.filter { !$0.liked } }
    var leadDish: DishItem? { dishes.first(where: { $0.isLead }) ?? likedDishes.first }

    /// Extract city from this restaurant's address.
    var city: String { Restaurant.city(from: address) }

    /// Parse the city component out of a comma-separated address string.
    /// Static so callers that don't have a full `Restaurant` yet (e.g. the
    /// log-flow dish-chip loader resolving a Place ID for a just-picked
    /// MapKit result) can still get a city for Places queries.
    ///
    /// Handles common formats:
    /// - "123 Main St, San Francisco, CA 94103" → "San Francisco"
    /// - "123 Main St, San Francisco, CA 94103, USA" → "San Francisco"
    /// - "San Francisco, CA" → "San Francisco"
    /// - "San Francisco" → "San Francisco"
    /// Strips trailing state/zip/country if misidentified.
    static func city(from address: String) -> String {
        let parts = address
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard !parts.isEmpty else { return "" }
        // Country-suffix aware
        let countrySuffixes: Set<String> = ["USA", "US", "United States", "UK", "Canada"]
        var working = parts
        if let last = working.last, countrySuffixes.contains(last) {
            working.removeLast()
        }
        // Drop trailing state+zip like "CA 94103" or 2-letter state codes
        if let last = working.last {
            let tokens = last.split(separator: " ")
            let stateLike = tokens.count >= 1 && tokens[0].count == 2 && tokens[0].allSatisfy { $0.isUppercase }
            let startsWithDigit = last.first?.isNumber == true
            if stateLike || startsWithDigit {
                if working.count >= 2 { working.removeLast() }
            }
        }
        // After trimming, the last remaining part is typically the city.
        // If the first part looks like a street (starts with digit), prefer parts[1].
        if working.count >= 2, let first = working.first, first.first?.isNumber == true {
            return working[1]
        }
        return working.last ?? ""
    }

    // MARK: - Relationship Sentence System

    /// The relationship cue: forward-looking signal.
    var relationshipCue: String? {
        if isGoTo { return "Your go-to" }
        if reaction == .loved && visitCount >= 4 { return "You keep going back" }
        if reaction == .loved && visitCount >= 2 { return "You\u{2019}d go back" }
        if reaction == .loved { return "You loved it" }
        if reaction == .liked && visitCount >= 2 { return "Still solid" }
        if reaction == .liked { return "You liked it" }
        // Meh and no-reaction: no cue
        return nil
    }

    /// The anchor: one memory anchor (dish > context > note).
    var relationshipAnchor: String? {
        // Prefer dish
        if let dish = leadDish {
            let verb = (isGoTo || (reaction == .loved && visitCount >= 2)) ? "Get the" : "Try the"
            return "\(verb) \(dish.name)"
        }
        // Context from occasion tags
        if let tag = occasionTags.first {
            return "Good for \(tag.rawValue.lowercased())"
        }
        // User note
        if !quickNote.isEmpty { return quickNote }
        // No anchor
        return nil
    }

    /// Full relationship sentence: "{cue} · {anchor}" or just cue/anchor/nil.
    var relationshipSentence: String? {
        guard let cue = relationshipCue else {
            // Low signal — no cue, no sentence
            return nil
        }
        if let anchor = relationshipAnchor {
            return "\(cue) \u{00B7} \(anchor)"
        }
        return cue
    }

    /// Metadata fallback for rows with no relationship sentence.
    var metadataFallback: String {
        var parts: [String] = []
        if cuisine != .other { parts.append(cuisine.rawValue) }
        let loc = address.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) ?? ""
        if !loc.isEmpty { parts.append(loc) }
        return parts.joined(separator: " \u{00B7} ")
    }

    /// Right-side signal: visit count if >= 2, else relative date.
    var visitSignal: String {
        if visitCount >= 2 { return "\(visitCount) visits" }
        return relativeVisitDate
    }

    /// Whether this place is eligible for 1-tap repeat logging.
    var canQuickLog: Bool {
        guard visitCount >= 2 else { return false }
        guard reaction == .loved || reaction == .liked else { return false }
        // Don't allow quick-log if last visit was > 3 months ago
        if let date = dateVisited {
            let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 999
            if days > 90 { return false }
        }
        return true
    }

    /// Whether this place should trigger a Go-to nudge (3rd positive visit, never shown before).
    var shouldNudgeGoTo: Bool {
        !isGoTo && !goToNudgeShown && visitCount >= 3 && (reaction == .loved || reaction == .liked)
    }

    var dateVisitedFormatted: String? {
        guard let dateVisited else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: dateVisited)
    }

    /// Relative time string: "Last week", "3 weeks ago", etc.
    var relativeVisitDate: String {
        guard let dateVisited else { return "" }
        let days = Calendar.current.dateComponents([.day], from: dateVisited, to: Date()).day ?? 0
        switch days {
        case 0: return "Today"
        case 1: return "Yesterday"
        case 2...6: return "This week"
        case 7...13: return "Last week"
        case 14...29: return "\(days / 7) weeks ago"
        case 30...59: return "Last month"
        case 60...89: return "2 months ago"
        default: return "\(days / 30) months ago"
        }
    }
}
