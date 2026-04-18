import Foundation

// MARK: - OccasionClassifier
//
// Pure, stateless scorer that assigns occasion-tag scores to a restaurant
// based on its cuisine, liked/logged dish names, and behavioral signals.
// Returns a dictionary of OccasionTag → score in [0, 1].
//
// Used by HomeTestView to filter and re-rank candidates when an
// occasion chip is active. No Firestore round trips, no network calls —
// everything runs synchronously from already-loaded data.
//
// Tuning history: rules iterated in /sessions scratch using the bay-area
// menus DB as a 350-restaurant test set. Tag-assignment threshold 0.45
// chosen empirically — gives ~60% coverage with conservative mis-tags.

enum OccasionClassifier {

    /// Score threshold above which a restaurant is considered tagged.
    static let assignmentThreshold: Double = 0.45

    /// The four chip-row occasions supported by Home today.
    static let homeChipOrder: [OccasionTag] = [
        .dateNight, .quickBite, .family, .groupDinner
    ]

    /// Score a restaurant across the four Home chip occasions.
    /// - dishNames should be the LIKED dishes (what the user or circle members
    ///   actually chose to log as liked — higher-signal than full scraped menu).
    static func classify(
        cuisine: CuisineType,
        dishNames: [String],
        visitCount: Int,
        reaction: Reaction?,
        isGoTo: Bool
    ) -> [OccasionTag: Double] {
        let cuisineLower = cuisine.rawValue.lowercased()
        let dishText = dishNames.joined(separator: " | ").lowercased()

        func hits(_ keys: [String]) -> Int {
            keys.reduce(0) { $0 + (dishText.contains($1) ? 1 : 0) }
        }
        func cuisineIn(_ keys: [String]) -> Bool {
            keys.contains(where: { cuisineLower.contains($0) })
        }

        var out: [OccasionTag: Double] = [:]

        // --- Date night ---
        var dn = 0.0
        let dnHits = hits(dateNightDishKeys)
        if dnHits >= 1 { dn += 0.4 }
        if dnHits >= 2 { dn += 0.15 }
        if cuisineIn(dateNightCuisineKeys) { dn += 0.2 }
        if reaction == .loved { dn += 0.1 }
        if isGoTo { dn += 0.05 }
        out[.dateNight] = min(dn, 1.0)

        // --- Group dinner ---
        var gd = 0.0
        let gdHits = hits(groupDinnerDishKeys)
        if gdHits >= 1 { gd += 0.5 }
        if gdHits >= 2 { gd += 0.25 }
        if cuisineIn(groupDinnerCuisineKeys) { gd += 0.2 }
        out[.groupDinner] = min(gd, 1.0)

        // --- Quick bite ---
        var qb = 0.0
        let qbHits = hits(quickBiteDishKeys)
        if qbHits >= 1 { qb += 0.3 }
        if qbHits >= 3 { qb += 0.2 }
        if cuisineIn(quickBiteCuisineKeys) { qb += 0.2 }
        if visitCount >= 3 { qb += 0.1 }           // repeated casual visits
        if hits(formalDishKeys) >= 1 { qb *= 0.3 } // anti-signal
        out[.quickBite] = min(qb, 1.0)

        // --- Kid friendly (OccasionTag.family) ---
        var kf = 0.0
        let kfHits = hits(kidFriendlyDishKeys)
        if kfHits >= 1 { kf += 0.5 }
        if kfHits >= 2 { kf += 0.2 }
        if cuisineIn(kidFriendlyCuisineKeys) { kf += 0.2 }
        if hits(formalDishKeys) >= 1 { kf = 0.0 }  // hard anti-signal
        out[.family] = min(kf, 1.0)

        return out
    }

    /// Convenience: which of the four Home chip tags does this restaurant
    /// score above threshold for? Multi-label — a place can hit more than one.
    static func assignedTags(
        cuisine: CuisineType,
        dishNames: [String],
        visitCount: Int,
        reaction: Reaction?,
        isGoTo: Bool
    ) -> Set<OccasionTag> {
        let scores = classify(
            cuisine: cuisine,
            dishNames: dishNames,
            visitCount: visitCount,
            reaction: reaction,
            isGoTo: isGoTo
        )
        return Set(scores.filter { $0.value >= assignmentThreshold }.keys)
    }

    // MARK: - Keyword lists (kept private; iterate via probe, then port)

    private static let dateNightDishKeys: [String] = [
        "omakase", "tasting menu", "chef\u{2019}s tasting", "chef's tasting",
        "chef\u{2019}s counter", "chef's counter",
        "prix fixe", "prix-fixe", "course menu", "multi-course",
        "caviar", "foie gras", "uni ", "truffle",
        "wine pairing", "sommelier",
        // Broader date-night signals for vegetarian dishes
        "ravioli", "risotto", "tiramisu", "cr\u{00E8}me br\u{00FB}l\u{00E9}e", "creme brulee",
        "burrata", "tartare", "carpaccio", "panna cotta",
        "cocktail", "sashimi", "nigiri", "tempura"
    ]
    private static let dateNightCuisineKeys: [String] = [
        "italian", "japanese", "french"
    ]

    private static let groupDinnerDishKeys: [String] = [
        "for the table", "family style", "family-style",
        "dim sum", "hot pot", "hotpot", "korean bbq", "kbbq", "shabu",
        "thali", "ayce", "all you can eat",
        "feast", "banquet", "platter",
        // Broader group-dinner signals
        "dumpling", "naan", "biryani", "curry", "paneer",
        "momo", "samosa", "chaat", "dosa", "idli",
        "mapo tofu", "fried rice", "lo mein", "chow mein",
        "spring roll", "egg roll", "wonton"
    ]
    private static let groupDinnerCuisineKeys: [String] = [
        "chinese", "korean", "indian", "mediterranean"
    ]

    private static let quickBiteDishKeys: [String] = [
        "burrito", "taco", "banh mi", "b\u{00E1}nh m\u{00EC}",
        "sandwich", "pho", "ramen", "poke", "pok\u{00E9}",
        " bao", "pizza slice", "by the slice",
        "rice bowl", "grain bowl", "wrap", "salad bowl",
        "boba", "smoothie", "quesadilla",
        // Broader quick-bite signals
        "noodle", "udon", "soba", "miso", "onigiri",
        "falafel", "hummus", "pizza", "toast",
        "gyoza", "edamame", "roll"
    ]
    private static let quickBiteCuisineKeys: [String] = [
        "vietnamese", "mexican", "thai"
    ]

    private static let kidFriendlyDishKeys: [String] = [
        "kid\u{2019}s menu", "kid's menu", "kids menu", "children\u{2019}s menu",
        "children's menu",
        "chicken tenders", "chicken strips",
        "mac and cheese", "mac & cheese",
        "grilled cheese", "cheese pizza", "plain pasta",
        // Broader kid-friendly signals (vegetarian)
        "margherita", "pasta", "noodle", "fried rice",
        "pancake", "french fries", "fries", "garlic bread",
        "mozzarella stick", "quesadilla", "cheese"
    ]
    private static let kidFriendlyCuisineKeys: [String] = [
        "american", "italian", "mexican"
    ]

    private static let formalDishKeys: [String] = [
        "omakase", "tasting menu", "prix fixe", "caviar", "sommelier"
    ]
}

// MARK: - OccasionTag presentation

extension OccasionTag {
    /// Short label used on the Home chip row.
    var chipLabel: String {
        switch self {
        case .dateNight: return "Date night"
        case .quickBite: return "Quick bite"
        case .family: return "Kid friendly"
        case .groupDinner: return "Group dinner"
        case .business: return "Business"
        case .celebration: return "Celebration"
        case .casual: return "Casual"
        case .specialOccasion: return "Special"
        }
    }

    /// Lower-case phrase used in contextual copy, e.g.
    /// "Strongest {phrase} signal right now".
    var contextualPhrase: String {
        switch self {
        case .dateNight: return "date-night"
        case .quickBite: return "quick-bite"
        case .family: return "kid-friendly"
        case .groupDinner: return "group-dinner"
        case .business: return "business"
        case .celebration: return "celebration"
        case .casual: return "casual"
        case .specialOccasion: return "special-occasion"
        }
    }

    /// Section-header version used in "ALSO GOOD FOR …".
    var sectionUppercase: String {
        switch self {
        case .dateNight: return "DATE NIGHT"
        case .quickBite: return "QUICK BITE"
        case .family: return "KID FRIENDLY"
        case .groupDinner: return "GROUP DINNER"
        case .business: return "BUSINESS"
        case .celebration: return "CELEBRATION"
        case .casual: return "CASUAL"
        case .specialOccasion: return "SPECIAL OCCASION"
        }
    }
}
