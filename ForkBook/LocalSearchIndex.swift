import Foundation

// MARK: - Local Search Index
//
// A lightweight, in-memory search index over the user's restaurants and their
// circle's shared restaurants. Designed for thousands of entries — not millions
// — so we rebuild on every query rather than maintaining a persistent inverted
// index. Faster to write, easier to reason about, and plenty fast at our scale.
//
// Used by both `MyPlacesTestView` (recall: "find a place I know") and
// `SearchTestView` (decision: "where should I go"), with provenance carried on
// every hit so each surface can render appropriately.

enum LocalSearchProvenance: Equatable {
    /// Place is in the user's own visited/saved/planned list.
    case mine
    /// Place is from the user's table, not in their own list.
    /// Carries the friend's display name(s) for trust-line rendering.
    case table(memberNames: [String])
    /// Place is in both the user's list AND the table.
    case both(memberNames: [String])

    var isTable: Bool {
        switch self {
        case .table, .both: return true
        case .mine: return false
        }
    }
}

/// A single search hit with rich context for downstream rendering.
struct LocalSearchHit: Identifiable, Equatable {
    /// Stable id derived from the underlying data source. Format:
    /// `m:<uuid>` for owned restaurants, `t:<lowercased-name>` for table-only.
    let id: String

    let name: String
    let cuisine: CuisineType
    let address: String
    let city: String

    /// One representative dish (most-voted across all sources).
    let leadDish: String?
    /// Other notable dishes (deduped, lowercased-keyed).
    let otherDishes: [String]

    /// Match score (higher = stronger). Use for ordering only — not for display.
    let score: Int

    /// Which fields the query hit, for "Matched on …" labels if needed.
    let matchedFields: Set<MatchedField>

    /// Relationship tier from the user's own data (lower = stronger). Used to
    /// break score ties so loved/go-to places win over similar matches.
    let myTier: Int

    /// The user's own record, if they have one.
    let mine: Restaurant?

    /// Table records (people in the user's circle who logged this place).
    let tableEntries: [SharedRestaurant]

    /// Computed provenance, derived from `mine` and `tableEntries`.
    let provenance: LocalSearchProvenance

    enum MatchedField: String, CaseIterable {
        case name, dish, city, cuisine, notes, recommender
    }

    static func == (lhs: LocalSearchHit, rhs: LocalSearchHit) -> Bool {
        lhs.id == rhs.id && lhs.score == rhs.score
    }
}

// MARK: - Index

enum LocalSearchIndex {

    // MARK: Public entry point

    /// Search across the user's own restaurants and their table's shared
    /// restaurants, returning ranked hits. `currentUid` is used to exclude
    /// the user's own table entries (those are already in `myRestaurants`).
    static func search(
        query rawQuery: String,
        myRestaurants: [Restaurant],
        tableRestaurants: [SharedRestaurant],
        currentUid: String?,
        limit: Int = 30
    ) -> [LocalSearchHit] {
        let normalized = normalize(rawQuery)
        let tokens = tokenize(normalized)
        guard !tokens.isEmpty else { return [] }

        // Collapse table entries to per-place groups (multiple friends may
        // log the same place). Skip entries owned by the current user.
        let friendEntries = tableRestaurants.filter { $0.userId != currentUid }
        let tableByKey = Dictionary(grouping: friendEntries) { entry in
            normalizeName(entry.name)
        }

        // Index the user's own places by normalized name for fast join.
        let mineByKey: [String: Restaurant] = Dictionary(
            uniqueKeysWithValues: myRestaurants.map { (normalizeName($0.name), $0) }
        )

        // Build the set of unique place keys we'll score.
        var placeKeys = Set<String>()
        placeKeys.formUnion(mineByKey.keys)
        placeKeys.formUnion(tableByKey.keys)

        var hits: [LocalSearchHit] = []
        for key in placeKeys {
            let mine = mineByKey[key]
            let entries = tableByKey[key] ?? []
            guard let hit = score(
                placeKey: key,
                mine: mine,
                tableEntries: entries,
                queryTokens: tokens,
                queryRaw: normalized
            ) else { continue }
            hits.append(hit)
        }

        // Sort: score desc, then tier asc, then mine first, then by name.
        hits.sort { a, b in
            if a.score != b.score { return a.score > b.score }
            if a.myTier != b.myTier { return a.myTier < b.myTier }
            switch (a.provenance, b.provenance) {
            case (.mine, .table), (.both, .table): return true
            case (.table, .mine), (.table, .both): return false
            default: break
            }
            return a.name.lowercased() < b.name.lowercased()
        }

        return Array(hits.prefix(limit))
    }

    // MARK: Scoring

    private static func score(
        placeKey: String,
        mine: Restaurant?,
        tableEntries: [SharedRestaurant],
        queryTokens: [String],
        queryRaw: String
    ) -> LocalSearchHit? {
        // Resolve a canonical name (prefer the user's own entry).
        let canonicalName = mine?.name
            ?? tableEntries.first?.name
            ?? placeKey
        let nameNorm = normalize(canonicalName)
        let nameTokens = tokenize(nameNorm)

        // Cuisine: prefer mine, else first table entry.
        let cuisine = mine?.cuisine ?? tableEntries.first?.cuisine ?? .other
        let cuisineNorm = normalize(cuisine.rawValue)

        // Address & city
        let address = mine?.address ?? tableEntries.first?.address ?? ""
        let city = mine?.city ?? extractCity(from: address)
        let cityNorm = normalize(city)

        // Dish bag: collapse all dishes from mine + table, count occurrences.
        var dishCounts: [String: Int] = [:]  // normalized dish name → count
        var dishDisplay: [String: String] = [:]  // normalized → original display
        var allDishesText: [String] = []
        if let m = mine {
            for d in m.dishes where d.liked {
                let key = normalize(d.name)
                guard !key.isEmpty else { continue }
                dishCounts[key, default: 0] += 1
                if dishDisplay[key] == nil { dishDisplay[key] = d.name }
                allDishesText.append(key)
            }
        }
        for e in tableEntries {
            for d in e.likedDishes {
                let key = normalize(d.name)
                guard !key.isEmpty else { continue }
                dishCounts[key, default: 0] += 1
                if dishDisplay[key] == nil { dishDisplay[key] = d.name }
                allDishesText.append(key)
            }
        }

        // Notes & recommender (mine only — table notes aren't user-authored
        // for search purposes the same way).
        let notesNorm = normalize(mine?.notes ?? "")
        let recommenderNorm = normalize(mine?.recommendedBy ?? "")

        // Member names from table — used for "raj recommended" style queries.
        let memberNames = Array(Set(tableEntries.map {
            $0.userName.components(separatedBy: " ").first ?? $0.userName
        }))
        let memberNamesNorm = memberNames.map(normalize)

        // Score each query token against each field.
        var totalScore = 0
        var matched: Set<LocalSearchHit.MatchedField> = []
        var allTokensMatched = true

        for token in queryTokens {
            // Skip stopwords for scoring purposes — don't let them gate the
            // "all tokens must match" check either.
            if Self.stopwords.contains(token) { continue }

            var tokenScore = 0

            // Name signals
            if nameNorm.hasPrefix(token) {
                tokenScore = max(tokenScore, 100)
                matched.insert(.name)
            } else if nameTokens.contains(where: { $0.hasPrefix(token) }) {
                tokenScore = max(tokenScore, 70)
                matched.insert(.name)
            } else if nameNorm.contains(token) {
                tokenScore = max(tokenScore, 50)
                matched.insert(.name)
            }

            // Dish signals (across all sources)
            if dishDisplay.keys.contains(token) {
                // Boost by how many people ordered it (consensus signal)
                let count = dishCounts[token] ?? 1
                tokenScore = max(tokenScore, 40 + min(count - 1, 4) * 8)
                matched.insert(.dish)
            } else if dishDisplay.keys.contains(where: { $0.contains(token) }) {
                tokenScore = max(tokenScore, 30)
                matched.insert(.dish)
            }

            // City
            if cityNorm == token {
                tokenScore = max(tokenScore, 35)
                matched.insert(.city)
            } else if cityNorm.contains(token) {
                tokenScore = max(tokenScore, 25)
                matched.insert(.city)
            }

            // Cuisine
            if cuisineNorm == token || cuisineNorm.hasPrefix(token) {
                tokenScore = max(tokenScore, 28)
                matched.insert(.cuisine)
            }

            // Notes / recommender (weakest signals)
            if notesNorm.contains(token) {
                tokenScore = max(tokenScore, 12)
                matched.insert(.notes)
            }
            if recommenderNorm.contains(token) {
                tokenScore = max(tokenScore, 18)
                matched.insert(.recommender)
            }
            if memberNamesNorm.contains(where: { $0 == token }) {
                tokenScore = max(tokenScore, 22)
                matched.insert(.recommender)
            }

            if tokenScore == 0 {
                allTokensMatched = false
            }
            totalScore += tokenScore
        }

        guard allTokensMatched, totalScore > 0 else { return nil }

        // Provenance
        let provenance: LocalSearchProvenance = {
            switch (mine != nil, !memberNames.isEmpty) {
            case (true, true):  return .both(memberNames: memberNames)
            case (true, false): return .mine
            case (false, true): return .table(memberNames: memberNames)
            case (false, false): return .mine  // shouldn't happen
            }
        }()

        // Mine-tier (drives tie-breaks; lower = stronger relationship)
        let myTier: Int = {
            guard let r = mine else { return 5 }
            if r.isGoTo { return 0 }
            if r.reaction == .loved && r.visitCount >= 2 { return 1 }
            if r.reaction == .loved { return 2 }
            if r.reaction == .liked && r.visitCount >= 2 { return 3 }
            if r.reaction == .liked { return 4 }
            return 5
        }()

        // Small relationship boost so a loved-mine outranks a similarly-scored
        // unknown — without overpowering a strong text match.
        let relationshipBoost: Int = {
            guard let r = mine else { return 0 }
            if r.isGoTo { return 12 }
            if r.reaction == .loved { return 8 }
            if r.reaction == .liked && r.visitCount >= 2 { return 4 }
            return 0
        }()

        // Lead dish — most-ordered overall, falling back to the user's own lead.
        let sortedDishes = dishCounts.sorted { lhs, rhs in
            if lhs.value != rhs.value { return lhs.value > rhs.value }
            return lhs.key < rhs.key
        }
        let lead: String? = sortedDishes.first.flatMap { dishDisplay[$0.key] }
            ?? mine?.leadDish?.name
        let others: [String] = sortedDishes
            .dropFirst()
            .prefix(2)
            .compactMap { dishDisplay[$0.key] }

        let id: String = {
            if let r = mine { return "m:\(r.id.uuidString)" }
            return "t:\(placeKey)"
        }()

        return LocalSearchHit(
            id: id,
            name: canonicalName,
            cuisine: cuisine,
            address: address,
            city: city,
            leadDish: lead,
            otherDishes: others,
            score: totalScore + relationshipBoost,
            matchedFields: matched,
            myTier: myTier,
            mine: mine,
            tableEntries: tableEntries,
            provenance: provenance
        )
    }

    // MARK: Tokenization

    /// Lowercases, strips diacritics, and collapses whitespace.
    static func normalize(_ s: String) -> String {
        s.folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Same as `normalize` but also strips common restaurant suffixes that
    /// hurt matching (e.g. "Tartine Bakery" vs "Tartine").
    static func normalizeName(_ s: String) -> String {
        let n = normalize(s)
        let suffixes = [" restaurant", " bakery", " cafe", " kitchen"]
        for sfx in suffixes {
            if n.hasSuffix(sfx) {
                return String(n.dropLast(sfx.count))
            }
        }
        return n
    }

    /// Splits into tokens on whitespace + punctuation, drops empties.
    static func tokenize(_ s: String) -> [String] {
        s.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    /// Common words we don't want to gate the all-tokens-matched check on.
    /// "Best in SF", "ramen near me", "where to eat" all leak filler tokens
    /// that shouldn't sink an otherwise-perfect match.
    static let stopwords: Set<String> = [
        "a", "an", "the", "for", "to", "of", "in", "on", "at", "is", "and",
        "or", "near", "me", "my", "best", "good", "place", "places", "where",
        "what", "should", "i", "go", "eat", "try", "have", "been", "any",
        "with", "by", "from"
    ]

    // MARK: City extraction (fallback when Restaurant.city isn't available)

    private static func extractCity(from address: String) -> String {
        let parts = address.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard parts.count >= 2 else { return parts.first ?? "" }
        // Skip leading street part if it starts with a digit.
        if parts.count >= 2, let first = parts.first, first.first?.isNumber == true {
            return parts[1]
        }
        return parts.first ?? ""
    }
}

// MARK: - Smart-query escalation

/// Heuristics for when a query is question-shaped and would benefit from the
/// LLM rather than a keyword match. Used by both MyPlaces and Search to decide
/// whether to surface an "Ask ForkBook" escalation row.
enum AskEscalationTrigger {
    static let questionStarters: Set<String> = [
        "where", "what", "best", "should", "which", "why", "how", "when",
        "who", "any", "got"
    ]

    /// Returns true when the query looks ambiguous, multi-word, or
    /// question-shaped — or when local search returned weak results.
    static func shouldOffer(query: String, localHitCount: Int) -> Bool {
        let normalized = LocalSearchIndex.normalize(query)
        let tokens = LocalSearchIndex.tokenize(normalized)
        guard tokens.count >= 1 else { return false }

        // Question-shaped: starts with a question word.
        if let first = tokens.first, questionStarters.contains(first) {
            return true
        }
        // Long-form intent: 4+ tokens implies the user is describing, not naming.
        if tokens.count >= 4 {
            return true
        }
        // Local matched poorly: < 3 hits and at least 2 tokens (not a single name).
        if localHitCount < 3 && tokens.count >= 2 {
            return true
        }
        return false
    }
}
