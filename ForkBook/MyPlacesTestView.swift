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
    @ObservedObject private var askService = AskForkBookService.shared
    @ObservedObject private var firestoreService = FirestoreService.shared

    // Optional binding so the empty-state CTA can route the user to the
    // Search tab. Optional keeps previews/previews-only callers working.
    var selectedTab: Binding<Int>? = nil

    @State private var route: Route = .home
    @State private var query: String = ""
    @FocusState private var searchFocused: Bool

    // Table-side data — loaded from Firestore on appear so we can rank the
    // user's circle's places alongside their own in local search.
    @State private var tableRestaurants: [SharedRestaurant] = []
    @State private var tableMembers: [FirestoreService.CircleMember] = []

    // Ask state — when the user runs an Ask escalation, we hold onto the
    // query that was asked so we know whether to render the answer card.
    @State private var lastAskedQuery: String? = nil

    // For table-only hits, present the SearchTestView-style detail sheet
    // rather than a new MyPlaces route (the user has no memory page for them).
    @State private var selectedTableHit: LocalSearchHit? = nil

    private var currentUid: String? { Auth.auth().currentUser?.uid }

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
        .task { await loadTableData() }
        // Refetch when circle membership changes (e.g. deep-link invite
        // auto-accepted after this view was already mounted).
        .onChange(of: firestoreService.circlesVersion) { _, _ in
            Task { await loadTableData() }
        }
        .sheet(item: $selectedTableHit) { hit in
            tableHitSheet(hit)
        }
    }

    // =========================================================================
    // MARK: - Table Data Loading
    // =========================================================================

    private func loadTableData() async {
        let circles = await firestoreService.getMyCircles()
        guard let circle = circles.first else {
            // No circle yet — in DEBUG seed mock data so search has table signal.
            // In Release (TestFlight/App Store) leave empty so real users start clean.
            #if DEBUG
            tableMembers = MockTableData.buildMembers()
            tableRestaurants = MockTableData.buildSharedRestaurants()
            #endif
            return
        }

        tableMembers = await firestoreService.getCircleMembers(circle: circle)
        var fetched = await firestoreService.getCircleRestaurants(circleId: circle.id)

        let memberMap = Dictionary(uniqueKeysWithValues: tableMembers.map { ($0.uid, $0.displayName) })
        for i in fetched.indices {
            fetched[i].userName = memberMap[fetched[i].userId] ?? "Friend"
        }

        // Mock data fallback when the user's circle has no friend entries.
        // In Release leave empty so real users start clean.
        #if DEBUG
        let realEntries = fetched.filter { $0.userId != currentUid }
        if realEntries.isEmpty {
            tableMembers = tableMembers + MockTableData.buildMembers()
            fetched.append(contentsOf: MockTableData.buildSharedRestaurants())
        }
        #endif

        tableRestaurants = fetched
    }

    // =========================================================================
    // MARK: - Home Screen
    // =========================================================================

    private var homeScreen: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                headerBlock(title: "Your places")

                searchBar
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                searchHelper
                    .padding(.top, 8)

                if !query.trimmingCharacters(in: .whitespaces).isEmpty {
                    searchResultsSection
                        .padding(.top, 18)
                } else {
                    if !mostLovedSpecs.isEmpty {
                        homeSectionLabel("Your most-loved")
                            .padding(.top, 22)
                        mostLovedStrip
                    }

                    if !cityRollup.isEmpty {
                        homeSectionLabel("By city")
                            .padding(.top, 26)
                        VStack(spacing: 8) {
                            ForEach(cityRollup, id: \.name) { c in
                                cityRow(name: c.name, count: c.count, cuisines: c.cuisines)
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    if !recentPlaceSpecs.isEmpty {
                        homeSectionLabel("Recent places")
                            .padding(.top, 26)
                        VStack(spacing: 8) {
                            ForEach(recentPlaceSpecs) { spec in
                                recentRow(spec)
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

    // Helper text under search — teaches what's searchable without
    // resurrecting a separate "you might ask" surface. Cycles based on
    // whether the user has logged anything yet.
    private var searchHelper: some View {
        Group {
            if store.visitedRestaurants.isEmpty {
                Text("Search by name, dish, city, or cuisine")
            } else {
                Text("Try: \u{201C}ramen\u{201D} or \u{201C}best in SF\u{201D}")
            }
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(Color(hex: "8E8E93"))
        .padding(.horizontal, 18)
    }

    // Title-case section label for the home screen. The all-caps `sectionLabel`
    // is preserved for detail screens that need that scannable rhythm.
    private func homeSectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color(hex: "8E8E93"))
            .padding(.horizontal, 22)
            .padding(.bottom, 10)
    }

    // Empty state when no visited restaurants
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Nothing logged yet")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.fbText)
            Text("Log the places you already love so your table gets smarter.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(hex: "B0B0B4").opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                // Route to Search tab (tag 1) if the binding is wired.
                selectedTab?.wrappedValue = 1
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Add your first place")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundStyle(Color.fbText)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Capsule().fill(Color.fbWarm.opacity(0.18)))
                .overlay(Capsule().stroke(Color.fbWarm.opacity(0.35), lineWidth: 1))
            }
            .padding(.top, 6)
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
    // MARK: - Search Results Section (LocalSearchIndex-backed)
    // =========================================================================

    /// Live search hits drawn from the user's own + table data.
    private var localHits: [LocalSearchHit] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }
        return LocalSearchIndex.search(
            query: q,
            myRestaurants: store.restaurants,
            tableRestaurants: tableRestaurants,
            currentUid: currentUid,
            limit: 12
        )
    }

    /// Best-in-city shortcut row (preserves the prior smart-query for cities).
    private var cityShortcut: SuggestedQuery? {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard q.hasPrefix("best in ") || q.hasPrefix("best places in ") else { return nil }
        let city = q.replacingOccurrences(of: "best places in ", with: "")
                    .replacingOccurrences(of: "best in ", with: "")
                    .trimmingCharacters(in: .whitespaces)
        guard !city.isEmpty else { return nil }
        return SuggestedQuery(
            question: "Best in \(city.capitalized)?",
            answerPreview: answerPreview(forCity: city),
            target: .city(city.capitalized)
        )
    }

    private var shouldShowAskRow: Bool {
        AskEscalationTrigger.shouldOffer(
            query: query,
            localHitCount: localHits.count
        )
    }

    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Ask ForkBook escalation row — first when triggered.
            if shouldShowAskRow {
                askEscalationRow
            }

            // Inline answer card (renders only for the most recent asked query).
            if let asked = lastAskedQuery,
               asked == query.trimmingCharacters(in: .whitespaces),
               let answer = askService.lastAnswer {
                askAnswerCard(answer: answer)
            } else if askService.isLoading {
                askLoadingCard
            } else if let err = askService.error,
                      lastAskedQuery == query.trimmingCharacters(in: .whitespaces) {
                askErrorCard(err)
            }

            // City shortcut, if applicable.
            if let shortcut = cityShortcut {
                queryRow(shortcut)
            }

            if localHits.isEmpty && !shouldShowAskRow {
                Text("No matches")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(hex: "6B6B70"))
                    .padding(.horizontal, 22)
            } else if localHits.isEmpty {
                // Triggered Ask but no local hits — soft prompt.
                Text("Nothing in your places matches \u{2014} ask above to look broader.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(hex: "6B6B70"))
                    .padding(.horizontal, 22)
            } else {
                ForEach(localHits) { hit in
                    hitRow(hit)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private func answerPreview(forCity city: String) -> String {
        let topNames = topPicks(in: city).prefix(3).map(\.name)
        if topNames.isEmpty { return "No places yet" }
        return topNames.joined(separator: ", ")
    }

    // =========================================================================
    // MARK: - Ask ForkBook escalation
    // =========================================================================

    private var askEscalationRow: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            runAsk()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.fbAccent1.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.fbAccent1)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ask ForkBook")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.fbText)
                    Text("\u{201C}\(query.trimmingCharacters(in: .whitespaces))\u{201D}")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(hex: "B0B0B4"))
                        .lineLimit(1)
                }
                Spacer()
                Text("\u{2192}")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.fbAccent1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.fbAccent1.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.fbAccent1.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(MyPlacesPressStyle())
    }

    private var askLoadingCard: some View {
        HStack(spacing: 10) {
            ProgressView()
                .tint(Color.fbWarm)
                .scaleEffect(0.8)
            Text("Thinking\u{2026}")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(hex: "B0B0B4"))
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.fbWarm.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.fbWarm.opacity(0.15), lineWidth: 1)
        )
    }

    private func askErrorCard(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color.fbRed.opacity(0.9))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.fbRed.opacity(0.06))
            )
    }

    private func askAnswerCard(answer: AskForkBookService.ForkBookAnswer) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.fbAccent1)
                Text("FORKBOOK")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.4)
                    .foregroundStyle(Color.fbWarm)
            }

            Text(answer.text)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.fbText)
                .fixedSize(horizontal: false, vertical: true)

            if !answer.suggestions.isEmpty {
                VStack(spacing: 8) {
                    ForEach(Array(answer.suggestions.enumerated()), id: \.offset) { _, s in
                        suggestionRow(s)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.fbWarm.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.fbWarm.opacity(0.18), lineWidth: 1)
        )
    }

    private func suggestionRow(_ s: AskForkBookService.Suggestion) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            // Try to deep-link into the user's own place, then table place.
            if let mine = store.restaurants.first(where: {
                LocalSearchIndex.normalizeName($0.name) == LocalSearchIndex.normalizeName(s.name)
            }) {
                navigate(.place(mine.id.uuidString))
                query = ""
                searchFocused = false
            } else {
                let entries = tableRestaurants.filter {
                    LocalSearchIndex.normalizeName($0.name) == LocalSearchIndex.normalizeName(s.name)
                }
                if !entries.isEmpty {
                    selectedTableHit = LocalSearchHit(
                        id: "t:\(LocalSearchIndex.normalizeName(s.name))",
                        name: s.name,
                        cuisine: entries.first?.cuisine ?? .other,
                        address: entries.first?.address ?? "",
                        city: "",
                        leadDish: nil,
                        otherDishes: [],
                        score: 0,
                        matchedFields: [],
                        myTier: 5,
                        mine: nil,
                        tableEntries: entries,
                        provenance: .table(memberNames: Array(Set(entries.map {
                            $0.userName.components(separatedBy: " ").first ?? $0.userName
                        })))
                    )
                }
            }
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Circle()
                    .fill(Color.fbAccent1.opacity(0.85))
                    .frame(width: 6, height: 6)
                    .padding(.top, 6)
                VStack(alignment: .leading, spacing: 2) {
                    Text(s.name)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.fbText)
                    Text(s.reason)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(hex: "B0B0B4"))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(MyPlacesPressStyle())
    }

    private func runAsk() {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        lastAskedQuery = q
        Task {
            await askService.ask(
                question: q,
                myRestaurants: store.restaurants,
                tableRestaurants: tableRestaurants,
                members: tableMembers,
                tastePrefs: TastePreferences()
            )
        }
    }

    // =========================================================================
    // MARK: - Local Hit Row (shared rendering for mine + table)
    // =========================================================================

    private func hitRow(_ hit: LocalSearchHit) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            openHit(hit)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(hit.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.fbText)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    hitProvenanceBadge(hit)
                }

                let metaParts: [String] = {
                    var parts: [String] = []
                    if hit.cuisine != .other { parts.append(hit.cuisine.rawValue) }
                    if !hit.city.isEmpty { parts.append(hit.city) }
                    return parts
                }()
                if !metaParts.isEmpty {
                    Text(metaParts.joined(separator: " \u{00B7} "))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(hex: "8E8E93"))
                        .lineLimit(1)
                }

                if let lead = hit.leadDish {
                    let extras = hit.otherDishes.isEmpty
                        ? ""
                        : " \u{00B7} also: \(hit.otherDishes.joined(separator: ", "))"
                    Text("Get the \(lead)\(extras)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.fbWarm)
                        .lineLimit(1)
                }

                if let trust = hitTrustLine(hit) {
                    Text(trust)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(hex: "B0B0B4"))
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

    @ViewBuilder
    private func hitProvenanceBadge(_ hit: LocalSearchHit) -> some View {
        switch hit.provenance {
        case .mine:
            if let r = hit.mine, r.isGoTo {
                badgeChip("Go-to", color: .fbWarm)
            } else if let r = hit.mine, r.reaction == .loved {
                badgeChip("Loved", color: .fbWarm)
            } else {
                badgeChip("Yours", color: Color(hex: "8E8E93"))
            }
        case .both:
            badgeChip("You + table", color: .fbWarm)
        case .table:
            badgeChip("From table", color: .fbWarm)
        }
    }

    private func badgeChip(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .heavy))
            .tracking(0.6)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(color.opacity(0.10)))
            .overlay(Capsule().stroke(color.opacity(0.22), lineWidth: 1))
    }

    private func hitTrustLine(_ hit: LocalSearchHit) -> String? {
        switch hit.provenance {
        case .mine:
            if let r = hit.mine, r.visitCount >= 2 {
                return "\(r.visitCount) visits \u{00B7} \(r.relativeVisitDate.lowercased())"
            }
            if let r = hit.mine, !r.relativeVisitDate.isEmpty {
                return "Visited \(r.relativeVisitDate.lowercased())"
            }
            return nil
        case .both(let names), .table(let names):
            if names.count >= 3 {
                return "\(names[0]), \(names[1]) & \(names.count - 2) more"
            }
            if names.count == 2 { return "\(names[0]) & \(names[1])" }
            if let first = names.first { return "\(first) from your table" }
            return nil
        }
    }

    private func openHit(_ hit: LocalSearchHit) {
        if let r = hit.mine {
            navigate(.place(r.id.uuidString))
            query = ""
            searchFocused = false
        } else {
            selectedTableHit = hit
        }
    }

    // =========================================================================
    // MARK: - Table Hit Sheet (for table-only places)
    // =========================================================================

    private func tableHitSheet(_ hit: LocalSearchHit) -> some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(hit.name)
                        .font(.system(size: 26, weight: .heavy))
                        .tracking(-0.5)
                        .foregroundStyle(Color.fbText)
                        .padding(.bottom, 4)

                    let meta: String = {
                        var parts: [String] = []
                        if hit.cuisine != .other { parts.append(hit.cuisine.rawValue) }
                        if !hit.city.isEmpty { parts.append(hit.city) }
                        return parts.joined(separator: " \u{00B7} ")
                    }()
                    if !meta.isEmpty {
                        Text(meta)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color(hex: "8E8E93"))
                    }

                    if let lead = hit.leadDish {
                        Text("Get the \(lead)")
                            .font(.system(size: 22, weight: .heavy))
                            .foregroundStyle(Color.fbWarm)
                            .padding(.top, 22)
                        if !hit.otherDishes.isEmpty {
                            Text("Also try: \(hit.otherDishes.joined(separator: ", "))")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color(hex: "B0B0B4"))
                                .padding(.top, 4)
                        }
                    }

                    if let trust = hitTrustLine(hit) {
                        Text(trust)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.fbWarm.opacity(0.9))
                            .padding(.top, 18)
                    }

                    Spacer(minLength: 32)
                }
                .padding(24)
            }
            .background(Color.fbBg)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { selectedTableHit = nil } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(hex: "8E8E93"))
                    }
                }
            }
        }
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

    private func headerBlock(title: String, subtitle: String? = nil) -> some View {
        // Avatar/profile link removed — profile is reachable from the Home
        // tab via AccountMenuView. Keeps this surface focused on place
        // memory without a tappable identity affordance competing for
        // attention with the search bar.
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 26, weight: .heavy))
                .tracking(-0.5)
                .foregroundStyle(Color.fbText)

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(hex: "8E8E93"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
        // Sized to match the Search tab's search bar so the two feel like
        // peers rather than one being a primary and the other an afterthought.
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundStyle(Color(hex: "8E8E93"))

            TextField(
                "",
                text: $query,
                prompt: Text("Search your places or ask")
                    .font(.body)
                    .foregroundColor(Color(hex: "B0B0B4"))
            )
            .focused($searchFocused)
            .font(.body)
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
                        .font(.system(size: 16))
                        .foregroundStyle(Color(hex: "6B6B70"))
                }
                .buttonStyle(MyPlacesPressStyle())
            }
        }
        .padding(14)
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
        // Prefer opening the strongest local hit; if there's none, fall back
        // to the city shortcut, then to running an Ask.
        if let first = localHits.first {
            openHit(first)
            return
        }
        if let shortcut = cityShortcut {
            navigate(shortcut.target)
            query = ""
            searchFocused = false
            return
        }
        if shouldShowAskRow {
            runAsk()
        }
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

    // =========================================================================
    // MARK: - Home V2: Most-loved / City / Recent rows
    // =========================================================================

    private struct LovedSpec: Identifiable {
        let id: String
        let name: String
        let badge: String
        let meta: String
        let stat: String
        let dishes: String
    }

    private struct CityRollupRow {
        let name: String
        let count: Int
        let cuisines: String
    }

    private struct RecentSpec: Identifiable {
        let id: String
        let name: String
        let meta: String
        let timeAgo: String
    }

    private var mostLovedSpecs: [LovedSpec] {
        var out: [LovedSpec] = []
        for r in store.visitedByRelationship {
            let badge: String?
            if r.isGoTo { badge = "Go-to" }
            else if r.reaction == .loved && r.visitCount >= 2 { badge = "Repeat favorite" }
            else if r.reaction == .loved { badge = "Worth repeating" }
            else if r.reaction == .liked && r.visitCount >= 3 { badge = "Comfort pick" }
            else { badge = nil }
            guard let b = badge else { continue }

            var metaParts: [String] = []
            if r.cuisine != .other { metaParts.append(r.cuisine.rawValue) }
            if !r.city.isEmpty { metaParts.append(r.city) }
            let meta = metaParts.joined(separator: " \u{00B7} ")

            let stat: String
            if r.visitCount >= 2 {
                let timing = r.relativeVisitDate.isEmpty
                    ? ""
                    : ", last \(r.relativeVisitDate.lowercased())"
                stat = "\(r.visitCount) visits\(timing)"
            } else if !r.relativeVisitDate.isEmpty {
                stat = "Visited \(r.relativeVisitDate.lowercased())"
            } else {
                stat = "1 visit"
            }

            let dishNames = r.likedDishes.map(\.name)
            let dishes = Array(dishNames.prefix(3)).joined(separator: ", ")

            out.append(LovedSpec(
                id: r.id.uuidString,
                name: r.name,
                badge: b,
                meta: meta,
                stat: stat,
                dishes: dishes
            ))
            if out.count >= 5 { break }
        }
        return out
    }

    private var cityRollup: [CityRollupRow] {
        uniqueCities.prefix(8).map { city in
            let count = store.visitedRestaurants
                .filter { $0.city.lowercased() == city.lowercased() }
                .count
            let cuisines = topCuisines(in: city)
                .prefix(3)
                .map(\.name)
                .joined(separator: ", ")
            return CityRollupRow(name: city, count: count, cuisines: cuisines)
        }
    }

    private var recentPlaceSpecs: [RecentSpec] {
        Array(store.visitedRestaurants.prefix(5)).map { r in
            var metaParts: [String] = []
            if r.cuisine != .other { metaParts.append(r.cuisine.rawValue) }
            if !r.city.isEmpty { metaParts.append(r.city) }
            let meta = metaParts.joined(separator: " \u{00B7} ")
            return RecentSpec(
                id: r.id.uuidString,
                name: r.name,
                meta: meta,
                timeAgo: r.relativeVisitDate
            )
        }
    }

    private var mostLovedStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(mostLovedSpecs) { spec in
                    lovedCard(spec)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func lovedCard(_ spec: LovedSpec) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            navigate(.place(spec.id))
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                Text(spec.badge)
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(Color.fbWarm)
                    .padding(.bottom, 8)
                Text(spec.name)
                    .font(.system(size: 17, weight: .heavy))
                    .tracking(-0.3)
                    .foregroundStyle(Color.fbText)
                    .lineLimit(1)
                if !spec.meta.isEmpty {
                    Text(spec.meta)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(hex: "6B6B70"))
                        .padding(.top, 2)
                        .lineLimit(1)
                }
                Spacer(minLength: 14)
                Text(spec.stat)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(hex: "D6D6DA"))
                    .padding(.bottom, 4)
                if !spec.dishes.isEmpty {
                    Text(spec.dishes)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(hex: "8E8E93"))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(16)
            .frame(width: 220, height: 160, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [Color(hex: "18181B"), Color(hex: "131316")],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.32), radius: 8, x: 0, y: 6)
        }
        .buttonStyle(MyPlacesPressStyle())
    }

    private func cityRow(name: String, count: Int, cuisines: String) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            navigate(.city(name))
        } label: {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.fbText)
                    if !cuisines.isEmpty {
                        Text(cuisines)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color(hex: "8E8E93"))
                            .lineLimit(1)
                    }
                }
                Spacer()
                Text("\(count)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.fbWarm)
                Text("\u{203A}")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(hex: "6B6B70"))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.fbSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.04), lineWidth: 1)
            )
        }
        .buttonStyle(MyPlacesPressStyle())
    }

    private func recentRow(_ spec: RecentSpec) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            navigate(.place(spec.id))
        } label: {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(spec.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.fbText)
                    if !spec.meta.isEmpty {
                        Text(spec.meta)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color(hex: "8E8E93"))
                            .lineLimit(1)
                    }
                }
                Spacer()
                if !spec.timeAgo.isEmpty {
                    Text(spec.timeAgo)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(hex: "6B6B70"))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.fbSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.04), lineWidth: 1)
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
