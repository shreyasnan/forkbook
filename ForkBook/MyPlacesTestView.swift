import SwiftUI
import FirebaseAuth

// MARK: - My Places Test View (V2 — Memory-first, query-led, real data)
//
// Three routes:
//   .home       — "Ask from memory": search bar, suggested queries, quick access places
//   .place      — Place memory: warm hero, visits, what to remember, actions
//   .city       — City recommendations summary
//
// Backed by RestaurantStore.

struct MyPlacesTestView: View {
    @EnvironmentObject var store: RestaurantStore
    @State private var route: Route = .home
    @State private var query: String = ""
    @FocusState private var searchFocused: Bool

    // MARK: Routes

    enum Route: Equatable {
        case home
        case place(String)   // Restaurant.id.uuidString
        case city(String)    // city name
    }

    // =========================================================================
    // MARK: - Body
    // =========================================================================

    var body: some View {
        ZStack {
            Color.fbBg.ignoresSafeArea()

            Group {
                switch route {
                case .home:
                    homeScreen
                case .place(let id):
                    if let restaurant = restaurantByIdString(id) {
                        placeDetailScreen(memory(from: restaurant))
                    } else {
                        emptyRouteFallback
                    }
                case .city(let name):
                    cityScreen(name)
                }
            }
        }
    }

    // =========================================================================
    // MARK: - Home Screen
    // =========================================================================

    private var homeScreen: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                headerBlock(title: "My Places", subtitle: "Ask from memory")

                searchBar
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                if !query.trimmingCharacters(in: .whitespaces).isEmpty {
                    searchResultsSection
                        .padding(.top, 18)
                } else {
                    chipsRow
                        .padding(.top, 12)

                    if !suggestedQueries.isEmpty {
                        sectionLabel("YOU MIGHT ASK")
                            .padding(.top, 24)

                        VStack(spacing: 10) {
                            ForEach(suggestedQueries) { q in
                                queryRow(q)
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    if !quickAccessPlaces.isEmpty {
                        sectionLabel("QUICK ACCESS")
                            .padding(.top, 24)

                        VStack(spacing: 10) {
                            ForEach(quickAccessPlaces) { place in
                                quickPlaceRow(place)
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    if store.visitedRestaurants.isEmpty {
                        emptyState
                            .padding(.top, 40)
                    }
                }

                Spacer(minLength: 80)
            }
        }
    }

    // Empty state when no visited restaurants
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Nothing logged yet")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.fbText)
            Text("Add places you\u{2019}ve been and ForkBook will help you remember what you loved.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(hex: "B0B0B4").opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
    }

    private var emptyRouteFallback: some View {
        VStack {
            Spacer()
            Text("Place not found.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color(hex: "B0B0B4"))
            Button("Back") { navigate(.home) }
                .padding(.top, 8)
                .foregroundStyle(Color.fbWarm)
            Spacer()
        }
    }

    // =========================================================================
    // MARK: - Search Results Section (live)
    // =========================================================================

    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if searchResults.isEmpty {
                Text("No matches")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(hex: "6B6B70"))
                    .padding(.horizontal, 22)
            } else {
                ForEach(searchResults) { result in
                    queryRow(result)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    // Compose live suggestions from real data
    private var searchResults: [SuggestedQuery] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return [] }
        var out: [SuggestedQuery] = []

        // Explicit best-in-city pattern
        if q.hasPrefix("best in ") || q.hasPrefix("best places in ") {
            let city = q.replacingOccurrences(of: "best places in ", with: "")
                        .replacingOccurrences(of: "best in ", with: "")
                        .trimmingCharacters(in: .whitespaces)
            if !city.isEmpty {
                out.append(SuggestedQuery(
                    question: "Best in \(city.capitalized)?",
                    answerPreview: answerPreview(forCity: city),
                    target: .city(city.capitalized)
                ))
            }
        }

        // Match by restaurant name
        for r in store.visitedRestaurants {
            if r.name.lowercased().contains(q) {
                out.append(SuggestedQuery(
                    question: "Have I been to \(r.name)?",
                    answerPreview: "\(r.visitCount) visit\(r.visitCount == 1 ? "" : "s") \u{00B7} \(ratingText(for: r))",
                    target: .place(r.id.uuidString)
                ))
            }
        }

        // Match by dish
        for r in store.visitedRestaurants {
            if let dish = r.likedDishes.first(where: { $0.name.lowercased().contains(q) }) {
                let exists = out.contains(where: {
                    if case .place(let pid) = $0.target { return pid == r.id.uuidString }
                    return false
                })
                if !exists {
                    out.append(SuggestedQuery(
                        question: "Had \(dish.name) at \(r.name)",
                        answerPreview: ratingText(for: r),
                        target: .place(r.id.uuidString)
                    ))
                }
            }
        }

        // Match by city
        let cities = uniqueCities.filter { $0.lowercased().contains(q) }
        for city in cities.prefix(3) {
            let exists = out.contains(where: {
                if case .city(let c) = $0.target { return c.lowercased() == city.lowercased() }
                return false
            })
            if !exists {
                out.append(SuggestedQuery(
                    question: "Best in \(city)?",
                    answerPreview: answerPreview(forCity: city),
                    target: .city(city)
                ))
            }
        }

        return Array(out.prefix(6))
    }

    private func answerPreview(forCity city: String) -> String {
        let topNames = topPicks(in: city).prefix(3).map(\.name)
        if topNames.isEmpty { return "No places yet" }
        return topNames.joined(separator: ", ")
    }

    // =========================================================================
    // MARK: - Place Detail Screen
    // =========================================================================

    private func placeDetailScreen(_ place: PlaceMemory) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                backButton
                    .padding(.top, 12)

                headerBlock(title: "My Places", subtitle: "Place memory")

                placeHero(place)
                    .padding(.horizontal, 16)
                    .padding(.top, 18)

                if !place.visits.isEmpty {
                    sectionLabel("WHAT YOU ATE")
                        .padding(.top, 26)

                    VStack(spacing: 10) {
                        ForEach(place.visits) { visit in
                            visitCard(visit)
                        }
                    }
                    .padding(.horizontal, 16)
                }

                sectionLabel("WHAT TO REMEMBER")
                    .padding(.top, 26)

                VStack(spacing: 10) {
                    if !place.mostRepeated.isEmpty {
                        memoryRow(name: "Standout dish", detail: place.mostRepeated)
                    }
                    memoryRow(name: "Recommendation confidence", detail: place.confidence)
                }
                .padding(.horizontal, 16)

                sectionLabel("ACTIONS")
                    .padding(.top, 26)

                HStack(spacing: 10) {
                    actionButton("Log again")
                    actionButton("Recommend")
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)

                Spacer(minLength: 80)
            }
        }
    }

    // =========================================================================
    // MARK: - City Screen
    // =========================================================================

    private func cityScreen(_ name: String) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                backButton
                    .padding(.top, 12)

                headerBlock(title: name, subtitle: "Your recommendations")

                let stats = cityStats(in: name)
                let top = topPicks(in: name)
                let also = alsoGood(in: name)
                let cuisines = topCuisines(in: name)
                let repeated = mostRepeatedDishes(in: name)

                if stats.total == 0 {
                    Text("No places in \(name) yet.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color(hex: "B0B0B4"))
                        .padding(.horizontal, 22)
                        .padding(.top, 20)
                } else {
                    cityStatsStrip(stats)
                        .padding(.horizontal, 16)
                        .padding(.top, 14)

                    if !cuisines.isEmpty {
                        cityCuisineChips(cuisines)
                            .padding(.top, 14)
                    }

                    if !repeated.isEmpty {
                        sectionLabel("YOU KEEP ORDERING")
                            .padding(.top, 22)

                        cityRepeatedDishesStrip(repeated)
                            .padding(.top, 4)
                    }
                }

                if !top.isEmpty {
                    sectionLabel("TOP PICKS")
                        .padding(.top, 22)

                    VStack(spacing: 10) {
                        ForEach(top) { place in
                            quickPlaceRow(place)
                        }
                    }
                    .padding(.horizontal, 16)
                }

                if !also.isEmpty {
                    sectionLabel("ALSO GOOD")
                        .padding(.top, 24)

                    VStack(spacing: 10) {
                        ForEach(also) { place in
                            quickPlaceRow(place)
                        }
                    }
                    .padding(.horizontal, 16)
                }

                Spacer(minLength: 80)
            }
        }
    }

    // MARK: City stats + breakdown

    private struct CityStats {
        let total: Int
        let loved: Int
        let goTo: Int
        let visits: Int
    }

    private func cityStats(in city: String) -> CityStats {
        let lower = city.lowercased()
        let here = store.visitedByRelationship.filter { $0.city.lowercased() == lower }
        let loved = here.filter { $0.reaction == .loved }.count
        let goTo = here.filter { $0.isGoTo }.count
        let visits = here.reduce(0) { $0 + max($1.visitCount, 1) }
        return CityStats(total: here.count, loved: loved, goTo: goTo, visits: visits)
    }

    private func topCuisines(in city: String) -> [(name: String, count: Int)] {
        let lower = city.lowercased()
        let here = store.visitedByRelationship.filter { $0.city.lowercased() == lower }
        var counts: [String: Int] = [:]
        for r in here where r.cuisine != .other {
            counts[r.cuisine.rawValue, default: 0] += 1
        }
        return counts
            .sorted { lhs, rhs in
                if lhs.value != rhs.value { return lhs.value > rhs.value }
                return lhs.key < rhs.key
            }
            .prefix(4)
            .map { (name: $0.key, count: $0.value) }
    }

    private func mostRepeatedDishes(in city: String) -> [(name: String, count: Int)] {
        let lower = city.lowercased()
        let here = store.visitedByRelationship.filter { $0.city.lowercased() == lower }
        var counts: [String: Int] = [:]
        for r in here {
            for d in r.likedDishes {
                let key = d.name.trimmingCharacters(in: .whitespaces)
                guard !key.isEmpty else { continue }
                counts[key, default: 0] += 1
            }
        }
        return counts
            .filter { $0.value >= 2 }
            .sorted { lhs, rhs in
                if lhs.value != rhs.value { return lhs.value > rhs.value }
                return lhs.key < rhs.key
            }
            .prefix(4)
            .map { (name: $0.key, count: $0.value) }
    }

    private func cityStatsStrip(_ stats: CityStats) -> some View {
        HStack(spacing: 10) {
            cityStatPill(label: "Places", value: "\(stats.total)")
            if stats.goTo > 0 {
                cityStatPill(label: "Go-to", value: "\(stats.goTo)", warm: true)
            }
            if stats.loved > 0 {
                cityStatPill(label: "Loved", value: "\(stats.loved)", warm: true)
            }
            if stats.visits > stats.total {
                cityStatPill(label: "Visits", value: "\(stats.visits)")
            }
            Spacer(minLength: 0)
        }
    }

    private func cityStatPill(label: String, value: String, warm: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(warm ? Color.fbWarm : Color.fbText)
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(Color(hex: "8E8E93"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(minWidth: 64, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(warm ? Color.fbWarm.opacity(0.07) : Color.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    warm ? Color.fbWarm.opacity(0.18) : Color.white.opacity(0.06),
                    lineWidth: 1
                )
        )
    }

    private func cityCuisineChips(_ cuisines: [(name: String, count: Int)]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(cuisines.enumerated()), id: \.offset) { _, c in
                    HStack(spacing: 6) {
                        Text(c.name)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.fbText)
                        Text("\(c.count)")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(Color.fbWarm)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule().fill(Color.white.opacity(0.03))
                    )
                    .overlay(
                        Capsule().stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func cityRepeatedDishesStrip(_ dishes: [(name: String, count: Int)]) -> some View {
        VStack(spacing: 8) {
            ForEach(Array(dishes.enumerated()), id: \.offset) { _, d in
                HStack(spacing: 10) {
                    Circle()
                        .fill(Color.fbWarm.opacity(0.9))
                        .frame(width: 6, height: 6)
                    Text(d.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.fbText)
                    Spacer(minLength: 8)
                    Text("\(d.count)\u{00D7}")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(Color.fbWarm)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.03))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
            }
        }
        .padding(.horizontal, 16)
    }

    // =========================================================================
    // MARK: - Shared Header
    // =========================================================================

    private func headerBlock(title: String, subtitle: String) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 26, weight: .heavy))
                    .tracking(-0.5)
                    .foregroundStyle(Color.fbText)

                Text(subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(hex: "8E8E93"))
            }

            Spacer()

            AvatarRing()
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private var backButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                route = .home
            }
        } label: {
            HStack(spacing: 8) {
                Text("\u{2190}")
                    .font(.system(size: 16, weight: .medium))
                Text("Back")
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundStyle(Color(hex: "B0B0B4"))
            .padding(.horizontal, 20)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(MyPlacesPressStyle())
    }

    // =========================================================================
    // MARK: - Search + Chips
    // =========================================================================

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color(hex: "8E8E93"))

            TextField(
                "",
                text: $query,
                prompt: Text("Ask about places, dishes, cities")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(hex: "B0B0B4"))
            )
            .focused($searchFocused)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(Color.fbText)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
            .submitLabel(.search)
            .onSubmit { handleSubmit() }

            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color(hex: "6B6B70"))
                }
                .buttonStyle(MyPlacesPressStyle())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .contentShape(Rectangle())
    }

    private func handleSubmit() {
        if let first = searchResults.first {
            navigate(first.target)
            query = ""
            searchFocused = false
        }
    }

    private var chipsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(chipSpecs().enumerated()), id: \.offset) { idx, spec in
                    chip(
                        label: spec.label,
                        active: idx == 0,
                        action: { navigate(spec.target) }
                    )
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private struct ChipSpec {
        let label: String
        let target: Route
    }

    private func chipSpecs() -> [ChipSpec] {
        var out: [ChipSpec] = []
        let top = store.visitedByRelationship.prefix(2)
        for r in top {
            out.append(ChipSpec(
                label: "Have I been to \(r.name)?",
                target: .place(r.id.uuidString)
            ))
        }
        if let topCity = uniqueCities.first {
            out.append(ChipSpec(
                label: "Best in \(topCity)?",
                target: .city(topCity)
            ))
        }
        return out
    }

    private func chip(label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            Text(label)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(active ? Color.fbWarm : Color(hex: "B0B0B4"))
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    Capsule()
                        .fill(active ? Color.fbWarm.opacity(0.08) : Color.white.opacity(0.03))
                )
                .overlay(
                    Capsule()
                        .stroke(
                            active ? Color.fbWarm.opacity(0.18) : Color.white.opacity(0.06),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(MyPlacesPressStyle())
    }

    // =========================================================================
    // MARK: - Rows
    // =========================================================================

    private func queryRow(_ queryItem: SuggestedQuery) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            query = ""
            searchFocused = false
            navigate(queryItem.target)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(queryItem.question)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.fbText)

                Text(queryItem.answerPreview)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(hex: "B0B0B4").opacity(0.92))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(hex: "131517"))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
            )
        }
        .buttonStyle(MyPlacesPressStyle())
    }

    private func quickPlaceRow(_ place: PlaceMemory) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            navigate(.place(place.id))
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text(place.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.fbText)
                    Spacer()
                    Text(place.visitCount)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(hex: "6B6B70"))
                }
                .padding(.bottom, 4)

                if !place.rating.isEmpty {
                    Text(place.rating)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.fbWarm)
                        .padding(.bottom, 4)
                }

                if !place.dishes.isEmpty {
                    Text(place.dishes)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(hex: "B0B0B4").opacity(0.92))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(hex: "131517"))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
            )
        }
        .buttonStyle(MyPlacesPressStyle())
    }

    private func memoryRow(name: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.fbText)

            Text(detail)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(hex: "B0B0B4").opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(hex: "131517"))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }

    // =========================================================================
    // MARK: - Place Hero + Visits
    // =========================================================================

    private func placeHero(_ place: PlaceMemory) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(place.name)
                .font(.system(size: 28, weight: .heavy))
                .tracking(-0.6)
                .foregroundStyle(Color(hex: "F5F5F7"))
                .padding(.bottom, 4)

            Text(place.meta)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(hex: "6B6B70"))
                .padding(.bottom, 18)

            Text(place.summary)
                .font(.system(size: 20, weight: .heavy))
                .tracking(-0.4)
                .foregroundStyle(Color.fbText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 8)

            if !place.summarySub.isEmpty {
                Text(place.summarySub)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(hex: "B0B0B4"))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 12)
            }

            Text(place.heroNote)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.fbWarm)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(heroBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.42), radius: 28, x: 0, y: 16)
    }

    private var heroBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: Color.fbWarm.opacity(0.08), location: 0),
                            .init(color: Color(hex: "171A1D"), location: 0.65)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            RadialGradient(
                colors: [Color.fbWarm.opacity(0.07), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 220
            )
        }
    }

    private func visitCard(_ visit: VisitRecord) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(visit.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.fbText)
                Spacer()
                Text(visit.timeAgo)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(hex: "6B6B70"))
            }
            .padding(.bottom, visit.dishes.isEmpty ? 0 : 10)

            if !visit.dishes.isEmpty {
                VStack(spacing: 8) {
                    ForEach(visit.dishes) { dish in
                        HStack {
                            Text(dish.name)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.fbText)
                            Spacer()
                            Text(dish.rating)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color.fbWarm)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.03))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.05), lineWidth: 1)
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(hex: "131517"))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }

    // =========================================================================
    // MARK: - Action Button + Section Label
    // =========================================================================

    private func actionButton(_ label: String) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            Text(label)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.fbText)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Capsule().fill(Color.white.opacity(0.04)))
                .overlay(Capsule().stroke(Color.white.opacity(0.06), lineWidth: 1))
        }
        .buttonStyle(MyPlacesPressStyle())
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .tracking(1.5)
            .foregroundStyle(Color(hex: "8E8E93"))
            .padding(.horizontal, 22)
            .padding(.bottom, 10)
    }

    // =========================================================================
    // MARK: - Navigation
    // =========================================================================

    private func navigate(_ r: Route) {
        withAnimation(.easeInOut(duration: 0.15)) {
            route = r
        }
    }

    // =========================================================================
    // MARK: - Data Derivation (from RestaurantStore)
    // =========================================================================

    private func restaurantByIdString(_ idString: String) -> Restaurant? {
        guard let uuid = UUID(uuidString: idString) else { return nil }
        return store.restaurants.first(where: { $0.id == uuid })
    }

    private var uniqueCities: [String] {
        var seen = Set<String>()
        var out: [String] = []
        // Order by frequency (descending) so the most-visited city comes first
        let counts = store.visitedRestaurants.reduce(into: [String: Int]()) { dict, r in
            let c = r.city
            guard !c.isEmpty else { return }
            dict[c, default: 0] += 1
        }
        let ordered = counts.sorted { $0.value > $1.value }.map(\.key)
        for c in ordered {
            if !seen.contains(c.lowercased()) {
                seen.insert(c.lowercased())
                out.append(c)
            }
        }
        return out
    }

    private var suggestedQueries: [SuggestedQuery] {
        let top = Array(store.visitedByRelationship.prefix(3))
        var out: [SuggestedQuery] = []
        for (idx, r) in top.enumerated() {
            if idx == 1, let lead = r.leadDish {
                out.append(SuggestedQuery(
                    question: "What did I eat at \(r.name)?",
                    answerPreview: "\(lead.name) \u{00B7} \(r.visitCount) visit\(r.visitCount == 1 ? "" : "s")",
                    target: .place(r.id.uuidString)
                ))
            } else {
                out.append(SuggestedQuery(
                    question: "Have I been to \(r.name)?",
                    answerPreview: "\(r.visitCount) visit\(r.visitCount == 1 ? "" : "s") \u{00B7} \(ratingText(for: r))",
                    target: .place(r.id.uuidString)
                ))
            }
        }
        if let topCity = uniqueCities.first {
            let preview = answerPreview(forCity: topCity)
            out.append(SuggestedQuery(
                question: "What should I recommend in \(topCity)?",
                answerPreview: preview,
                target: .city(topCity)
            ))
        }
        return out
    }

    private var quickAccessPlaces: [PlaceMemory] {
        Array(store.visitedByRelationship.prefix(3)).map { memory(from: $0) }
    }

    private func topPicks(in city: String) -> [PlaceMemory] {
        let lower = city.lowercased()
        return store.visitedByRelationship
            .filter { $0.city.lowercased() == lower }
            .filter { $0.isGoTo || $0.reaction == .loved }
            .map { memory(from: $0) }
    }

    private func alsoGood(in city: String) -> [PlaceMemory] {
        let lower = city.lowercased()
        let topIds = Set(topPicks(in: city).map(\.id))
        return store.visitedByRelationship
            .filter { $0.city.lowercased() == lower }
            .filter { !topIds.contains($0.id.uuidString) }
            .map { memory(from: $0) }
    }

    // MARK: Restaurant → PlaceMemory

    private func memory(from r: Restaurant) -> PlaceMemory {
        let visitText = r.visitCount >= 2 ? "\(r.visitCount) visits" : "1 visit"
        let rating = ratingText(for: r)
        let dishNames = r.likedDishes.map(\.name)
        let dishesText = dishNames.isEmpty ? "" : Array(dishNames.prefix(3)).joined(separator: ", ")

        var metaParts: [String] = []
        if r.cuisine != .other { metaParts.append(r.cuisine.rawValue) }
        if !r.city.isEmpty { metaParts.append(r.city) }
        if r.visitCount >= 2 { metaParts.append("\(r.visitCount) visits") }
        let meta = metaParts.joined(separator: " \u{00B7} ")

        let summary: String
        if r.visitCount >= 2 {
            summary = "Yes \u{2014} you\u{2019}ve been here \(r.visitCount) times"
        } else {
            summary = "Yes \u{2014} you went once"
        }

        var summarySubParts: [String] = []
        if !r.relativeVisitDate.isEmpty {
            summarySubParts.append(r.relativeVisitDate.lowercased())
        }
        if let lead = r.leadDish {
            let verb = r.visitCount >= 2 ? "repeatedly had the \(lead.name)" : "the \(lead.name) stood out"
            summarySubParts.append(verb)
        }
        let summarySub = summarySubParts.joined(separator: " \u{00B7} ")

        let heroNote: String
        if let cue = r.relationshipCue {
            if let lead = r.leadDish {
                heroNote = "\(cue). Go back for the \(lead.name)."
            } else {
                heroNote = "\(cue)."
            }
        } else if r.city.isEmpty {
            heroNote = "One of your places."
        } else {
            heroNote = "One of your \(r.city) places."
        }

        let visit = VisitRecord(
            id: r.id.uuidString + "-v",
            title: r.visitCount >= 2 ? "Most recent visit" : "Only visit",
            timeAgo: r.relativeVisitDate,
            dishes: Array(r.likedDishes.prefix(4)).map { d in
                DishRating(
                    id: d.id.uuidString,
                    name: d.name,
                    rating: rating.isEmpty ? "Liked" : rating
                )
            }
        )

        return PlaceMemory(
            id: r.id.uuidString,
            name: r.name,
            meta: meta,
            visitCount: visitText,
            rating: rating,
            dishes: dishesText,
            summary: summary,
            summarySub: summarySub,
            heroNote: heroNote,
            visits: [visit],
            mostRepeated: r.leadDish?.name ?? "",
            confidence: confidenceText(for: r)
        )
    }

    private func ratingText(for r: Restaurant) -> String {
        switch r.reaction {
        case .loved: return "Amazing"
        case .liked: return "Good"
        case .meh: return "Okay"
        case .none: return ""
        }
    }

    private func confidenceText(for r: Restaurant) -> String {
        if r.isGoTo { return "High \u{2014} your go-to" }
        if r.reaction == .loved && r.visitCount >= 2 { return "High \u{2014} you keep coming back" }
        if r.reaction == .loved { return "High \u{2014} you loved it" }
        if r.reaction == .liked && r.visitCount >= 2 { return "Medium \u{2014} still solid" }
        if r.reaction == .liked { return "Medium \u{2014} you liked it" }
        return "Low \u{2014} not strongly remembered"
    }
}

// =========================================================================
// MARK: - Data Models
// =========================================================================

struct PlaceMemory: Identifiable, Equatable {
    let id: String
    let name: String
    let meta: String
    let visitCount: String
    let rating: String
    let dishes: String
    let summary: String
    let summarySub: String
    let heroNote: String
    let visits: [VisitRecord]
    let mostRepeated: String
    let confidence: String
}

struct VisitRecord: Identifiable, Equatable {
    let id: String
    let title: String
    let timeAgo: String
    let dishes: [DishRating]
}

struct DishRating: Identifiable, Equatable {
    let id: String
    let name: String
    let rating: String
}

struct SuggestedQuery: Identifiable {
    let id = UUID()
    let question: String
    let answerPreview: String
    let target: MyPlacesTestView.Route
}

// =========================================================================
// MARK: - Avatar Ring (matches other tabs)
// =========================================================================

private struct AvatarRing: View {
    var body: some View {
        RingedAvatarView(
            name: Auth.auth().currentUser?.displayName ?? "User",
            size: 32,
            photoData: ProfilePhotoStore.shared.load(),
            showRing: true
        )
    }
}

// =========================================================================
// MARK: - Press Style
// =========================================================================

private struct MyPlacesPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
            .brightness(configuration.isPressed ? 0.015 : 0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// =========================================================================
// MARK: - Preview
// =========================================================================

#Preview {
    MyPlacesTestView()
        .environmentObject(RestaurantStore())
        .preferredColorScheme(.dark)
}
