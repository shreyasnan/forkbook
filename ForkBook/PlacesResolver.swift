import Foundation

// MARK: - PlacesResolver
//
// Resolves a restaurant name + location to a stable Google Place ID,
// which we then use as the key for menu lookups.
//
// MapKit's `MKLocalSearchCompleter` — the source of truth in our picker —
// does NOT expose Place IDs, so we need this separate resolution step.
//
// Mirrors the Python resolver at
// menu-scraper-data/scripts/menu_scraper/places_resolver.py
// Any change to stopwords or thresholds should be made in both places.

struct PlaceIDResolution: Equatable {
    enum Status: String {
        case matched
        case needsReview = "needs_review"
    }

    let placeId: String
    let matchedName: String
    let confidence: Double
    let status: Status
    let lat: Double?
    let lng: Double?
}

@MainActor
final class PlacesResolver {
    static let shared = PlacesResolver()

    // Same thresholds as the backfill script. Keep in sync.
    private let acceptThreshold = 0.85
    private let reviewThreshold = 0.60
    private let session: URLSession

    private init(session: URLSession = .shared) {
        self.session = session
    }

    /// Resolve (name, city, lat, lng) → best Place ID match, or nil.
    ///
    /// - Returns: nil if the API key is missing, the network fails, Google
    ///   returns no plausible candidates, or the best candidate scores
    ///   below `reviewThreshold`.
    func resolve(
        name: String,
        city: String?,
        lat: Double? = nil,
        lng: Double? = nil
    ) async -> PlaceIDResolution? {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return nil }
        guard let apiKey = Secrets.googlePlacesApiKey, !apiKey.isEmpty else {
            print("[PlacesResolver] Missing GOOGLE_PLACES_API_KEY — skipping")
            return nil
        }

        // Build the query text: name + city + CA. Mirrors the Python
        // resolver so behavior matches what we saw during the backfill.
        var queryParts = [trimmedName]
        if let city = city?.trimmingCharacters(in: .whitespaces), !city.isEmpty {
            queryParts.append(city)
        }
        queryParts.append("CA")
        let query = queryParts.joined(separator: ", ")

        var components = URLComponents(
            string: "https://maps.googleapis.com/maps/api/place/findplacefromtext/json"
        )!
        var items: [URLQueryItem] = [
            URLQueryItem(name: "input", value: query),
            URLQueryItem(name: "inputtype", value: "textquery"),
            URLQueryItem(name: "fields", value: "place_id,name,formatted_address,geometry"),
            URLQueryItem(name: "key", value: apiKey),
        ]
        if let lat, let lng {
            // 2km radius — wide enough to forgive a coord-to-storefront
            // offset, tight enough to not cross neighborhoods.
            items.append(URLQueryItem(
                name: "locationbias",
                value: "circle:2000@\(lat),\(lng)"
            ))
        }
        components.queryItems = items
        guard let url = components.url else { return nil }

        let candidates: [PlaceCandidate]
        do {
            let (data, _) = try await session.data(from: url)
            let response = try JSONDecoder().decode(PlacesResponse.self, from: data)
            if response.status == "ZERO_RESULTS" {
                print("[PlacesResolver] ZERO_RESULTS for '\(query)' — Google has no listing matching that text")
                return nil
            }
            guard response.status == "OK" else {
                print("[PlacesResolver] API status=\(response.status) for '\(query)' (err=\(response.errorMessage ?? "nil"))")
                return nil
            }
            candidates = response.candidates ?? []
        } catch {
            print("[PlacesResolver] request failed for '\(query)': \(error)")
            return nil
        }
        if candidates.isEmpty {
            print("[PlacesResolver] OK but empty candidates for '\(query)'")
            return nil
        }

        // Score each candidate against the user-entered name. Pick best.
        var scored: [(candidate: PlaceCandidate, score: Double)] = []
        scored.reserveCapacity(candidates.count)
        for cand in candidates {
            let score = Self.nameSimilarity(
                trimmedName,
                cand.name ?? "",
                city: city
            )
            scored.append((cand, score))
        }
        scored.sort { $0.score > $1.score }
        let best = scored.first

        guard let match = best?.candidate,
              let placeId = match.placeId,
              let bestScore = best?.score,
              bestScore >= reviewThreshold
        else {
            // Below review threshold — log what Google actually returned so
            // we can tell "stopword gap" from "wrong place entirely" without
            // running a separate debug build. Mirrors the Python resolver's
            // logger.debug output.
            let topPreview = scored.prefix(3)
                .map { "\"\($0.candidate.name ?? "")\"(\(String(format: "%.2f", $0.score)))" }
                .joined(separator: ", ")
            print("[PlacesResolver] rejected '\(query)' — best below \(reviewThreshold). Top: \(topPreview)")
            return nil
        }

        return PlaceIDResolution(
            placeId: placeId,
            matchedName: match.name ?? "",
            confidence: (bestScore * 1000).rounded() / 1000,
            status: bestScore >= acceptThreshold ? .matched : .needsReview,
            lat: match.geometry?.location.lat,
            lng: match.geometry?.location.lng
        )
    }
}

// MARK: - Name Similarity
//
// Algorithm kept deliberately close to Python's difflib.SequenceMatcher
// so backfilled-by-Python and resolved-by-iOS Place IDs converge on the
// same decisions for the same input.

extension PlacesResolver {
    /// Filler words stripped before fuzzy comparison.
    /// Mirrors `_STOPWORDS` in places_resolver.py. Keep in sync.
    static let stopwords: Set<String> = [
        // Generic framing
        "the", "a", "an", "and", "&",
        // Establishment-type words
        "restaurant", "restaurants", "cafe", "café", "coffee", "bar", "pub",
        "tavern", "lounge", "kitchen", "grill", "eatery", "bistro", "diner",
        "place", "house", "bakery", "deli", "company", "co",
        // Descriptor words Google appends inconsistently
        "cuisine", "food", "foods", "eats", "dining", "fine",
        "cucina", "trattoria", "osteria",
        // Cuisine-type suffixes
        "taqueria", "pizzeria", "sushi", "pizza", "tacos", "ramen", "noodle",
        "noodles", "bbq", "barbecue", "steakhouse",
        // Cuisine adjectives
        "indian", "japanese", "italian", "mexican", "chinese", "thai",
        "vietnamese", "korean", "french", "mediterranean", "american",
        "greek", "turkish", "spanish", "ethiopian", "peruvian",
        // Catering / marketing suffixes
        "catering", "co.", "inc", "llc",
    ]

    static func normalize(
        _ s: String,
        extraStopwords: Set<String> = []
    ) -> String {
        // Fold diacritics: "Réveille" → "Reveille"
        let folded = s.folding(options: .diacriticInsensitive, locale: nil)
        let lowered = folded.lowercased()
        // Replace anything that isn't a letter, number, or space with a space.
        var cleaned = ""
        cleaned.reserveCapacity(lowered.count)
        for ch in lowered {
            if ch.isLetter || ch.isNumber || ch == " " {
                cleaned.append(ch)
            } else {
                cleaned.append(" ")
            }
        }
        let stops = stopwords.union(extraStopwords)
        let tokens = cleaned
            .split(separator: " ")
            .map(String.init)
            .filter { !$0.isEmpty && !stops.contains($0) }
        return tokens.joined(separator: " ")
    }

    /// Tokens of the (normalized) city. Used to strip "- San Mateo" style
    /// suffixes that Google adds for disambiguation — we already searched
    /// with that city, so it's not new information.
    static func cityTokens(_ city: String?) -> Set<String> {
        guard let city = city?.trimmingCharacters(in: .whitespaces), !city.isEmpty else {
            return []
        }
        let folded = city.folding(options: .diacriticInsensitive, locale: nil).lowercased()
        var cleaned = ""
        for ch in folded {
            if ch.isLetter || ch.isNumber || ch == " " {
                cleaned.append(ch)
            } else {
                cleaned.append(" ")
            }
        }
        return Set(
            cleaned.split(separator: " ")
                .map(String.init)
                .filter { !$0.isEmpty }
        )
    }

    /// [0, 1] — 1.0 is identical after normalization.
    /// Does NOT auto-boost substring containment; "Amber India" vs
    /// "Amber India Milpitas" stays below 0.85 so the needs_review flag
    /// surfaces it.
    static func nameSimilarity(
        _ a: String,
        _ b: String,
        city: String? = nil
    ) -> Double {
        let cityStops = cityTokens(city)
        let na = normalize(a, extraStopwords: cityStops)
        let nb = normalize(b, extraStopwords: cityStops)
        if na.isEmpty || nb.isEmpty { return 0 }
        if na == nb { return 1.0 }
        return lcsRatio(na, nb)
    }

    /// 2 * LCS / (|a| + |b|). Close analog to Python's
    /// difflib.SequenceMatcher.ratio() — not identical but gives the same
    /// ordinal decisions for the cases we care about.
    static func lcsRatio(_ a: String, _ b: String) -> Double {
        let aa = Array(a.unicodeScalars)
        let bb = Array(b.unicodeScalars)
        let n = aa.count
        let m = bb.count
        if n == 0 || m == 0 { return 0 }

        // Two-row LCS DP for O(min(n,m)) space.
        var prev = [Int](repeating: 0, count: m + 1)
        var curr = [Int](repeating: 0, count: m + 1)
        for i in 1...n {
            for j in 1...m {
                if aa[i - 1] == bb[j - 1] {
                    curr[j] = prev[j - 1] + 1
                } else {
                    curr[j] = max(prev[j], curr[j - 1])
                }
            }
            swap(&prev, &curr)
            for k in 0..<curr.count { curr[k] = 0 }
        }
        return 2.0 * Double(prev[m]) / Double(n + m)
    }
}

// MARK: - Places API response types

private struct PlacesResponse: Decodable {
    let status: String
    let candidates: [PlaceCandidate]?
    let errorMessage: String?

    enum CodingKeys: String, CodingKey {
        case status, candidates
        case errorMessage = "error_message"
    }
}

private struct PlaceCandidate: Decodable {
    let placeId: String?
    let name: String?
    let formattedAddress: String?
    let geometry: Geometry?

    enum CodingKeys: String, CodingKey {
        case placeId = "place_id"
        case name
        case formattedAddress = "formatted_address"
        case geometry
    }
}

private struct Geometry: Decodable {
    let location: PlaceLocation
}

private struct PlaceLocation: Decodable {
    let lat: Double
    let lng: Double
}
