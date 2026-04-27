import SwiftUI
import FirebaseAuth

// MARK: - Search Test View
//
// Decision-engine search: not "here are results" but "here's where to go."
// Sections: Best Match → From Your Table → Worth Trying → Everything Else.
// Dish > restaurant. Social proof > star ratings. Fewer, stronger picks.
// Does NOT replace SearchView.

struct SearchTestView: View {
    @EnvironmentObject var store: RestaurantStore
    @StateObject private var searchService = RestaurantSearchService()
    @ObservedObject private var firestoreService = FirestoreService.shared
    @ObservedObject private var askService = AskForkBookService.shared

    /// Parent-owned binding to the root tab selection. After the user saves a
    /// meal via `AddPlaceTestFlow` presented from this view, we route them
    /// back to Home so they land on an updated recommendations feed rather
    /// than the empty search state.
    var selectedTab: Binding<Int>? = nil

    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    @State private var tableRestaurants: [SharedRestaurant] = []
    @State private var tableMembers: [FirestoreService.CircleMember] = []
    @State private var isLoadingTable = true

    /// Prefill payload carried inside the addPlace case so it's
    /// bundled atomically with the sheet presentation. Previous
    /// design stored prefill in separate @State vars which created
    /// a window where the sheet's content closure could read stale
    /// or empty values during the detail → addPlace handoff,
    /// causing AddPlaceTestFlow's `onAppear` to see no prefill and
    /// dismiss itself (the "tap twice" bug).
    struct AddPlacePrefill: Hashable {
        let name: String
        let address: String
        let cuisine: CuisineType?
    }

    /// Single-sheet routing. Using one `.sheet(item:)` driven by an enum
    /// instead of two separate `.sheet` modifiers avoids SwiftUI's
    /// "second sheet silently dropped" bug.
    enum SearchSheet: Identifiable {
        case detail(SearchDetailData)
        case addPlace(AddPlacePrefill)
        var id: String {
            switch self {
            case .detail(let d): return "detail-\(d.name)"
            case .addPlace(let p): return "addPlace-\(p.name)"
            }
        }
    }
    @State private var activeSheet: SearchSheet? = nil

    /// If set when `activeSheet` becomes nil, the sheet's onDismiss
    /// re-presents with this value instead of treating the dismissal
    /// as final. Used by "I went here" to swap detail → addPlace
    /// via onDismiss chaining, which is more reliable than
    /// reassigning `activeSheet` from one non-nil value to another.
    @State private var pendingFollowUp: SearchSheet? = nil

    @State private var toastMessage: String?
    @State private var showToast = false

    // Account menu (top-right burger) — sheet-presented so it's reachable
    // from inside the Search NavigationStack without colliding with the
    // detail/addPlace sheet routing.
    @State private var showAccount = false

    // Ask escalation — same pattern as MyPlaces.
    @State private var lastAskedQuery: String? = nil

    private var currentUid: String? { Auth.auth().currentUser?.uid }

    // ── Design tokens ──
    private static let cardBg = Color(hex: "131517")
    private static let cardHero = Color(hex: "171A1D")
    private static let warmAccent = Color(hex: "C4A882")
    private static let mutedGray = Color(hex: "8E8E93")
    private static let dimGray = Color(hex: "6B6B70")
    private static let lightText = Color(hex: "F5F5F7")

    // =========================================================================
    // MARK: - Computed Results
    // =========================================================================

    /// All table matches for the query, scored and sorted
    private var allTableMatches: [SearchMatchData] {
        guard searchText.count >= 2 else { return [] }
        let q = searchText.lowercased()

        let friendEntries = tableRestaurants.filter { $0.userId != currentUid }
        let byName = Dictionary(grouping: friendEntries, by: { $0.name.lowercased() })
        let myRestaurants = store.restaurants

        var results: [SearchMatchData] = []
        var seen = Set<String>()

        for (nameKey, entries) in byName {
            // Match on: restaurant name, cuisine, dish names, or friend names
            let friendNames = entries.map {
                $0.userName.components(separatedBy: " ").first?.lowercased() ?? $0.userName.lowercased()
            }
            guard nameKey.contains(q)
                    || entries.first?.cuisine.rawValue.lowercased().contains(q) == true
                    || entries.flatMap(\.dishes).contains(where: { $0.name.lowercased().contains(q) })
                    || friendNames.contains(where: { $0.contains(q) })
            else { continue }

            if seen.contains(nameKey) { continue }
            seen.insert(nameKey)

            let ref = entries.first!
            let myEntry = myRestaurants.first { $0.name.lowercased() == nameKey }

            // Gather all liked dishes across table members
            let allLikedDishes = entries.flatMap { $0.likedDishes }
            let dishCounts = Dictionary(grouping: allLikedDishes, by: { $0.name })
                .mapValues { $0.count }
                .sorted { $0.value > $1.value }
            let topDish = dishCounts.first?.key ?? ""
            let topDishCount = dishCounts.first?.value ?? 0
            let secondDish = dishCounts.count > 1 ? dishCounts[1].key : nil

            // Member names
            let names = Array(Set(entries.map {
                $0.userName.components(separatedBy: " ").first ?? $0.userName
            }))

            // Repeat behavior
            let totalVisits = entries.count
            let isRepeat = entries.contains { $0.visitCount > 1 }

            // Score: higher = better match
            var score = 0
            score += names.count * 10          // more people = stronger signal
            score += totalVisits * 5           // more visits = trusted
            score += topDishCount * 8          // dish consensus
            if isRepeat { score += 15 }        // repeat behavior is gold
            if myEntry != nil { score += 5 }   // you've been here too

            // Relationship to user
            let relationship: SearchMatchRelationship = {
                if let my = myEntry {
                    if my.visitCount >= 3 || my.reaction == .loved { return .regular }
                    if my.category == .visited { return .beenHere }
                    if my.category == .saved { return .saved }
                }
                return .newToYou
            }()

            // Build reasoning line
            let reasoning = buildReasoning(
                names: names,
                topDish: topDish,
                topDishCount: topDishCount,
                totalVisits: totalVisits,
                isRepeat: isRepeat
            )

            let location = shortLocation(from: ref.address)

            results.append(SearchMatchData(
                name: ref.name,
                cuisine: ref.cuisine.rawValue,
                location: location,
                address: ref.address,
                topDish: topDish,
                secondDish: secondDish,
                topDishCount: topDishCount,
                memberNames: names,
                totalVisits: totalVisits,
                isRepeat: isRepeat,
                relationship: relationship,
                reasoning: reasoning,
                score: score,
                entries: entries,
                cuisineType: ref.cuisine
            ))
        }

        results.sort { $0.score > $1.score }
        return results
    }

    /// The single best match — strongest signal
    private var bestMatch: SearchMatchData? {
        allTableMatches.first
    }

    /// 2-4 strong table recs (after best match)
    private var fromYourTable: [SearchMatchData] {
        Array(allTableMatches.dropFirst().prefix(4))
    }

    /// New-to-table results with context
    private var worthTrying: [WorthTryingData] {
        guard searchText.count >= 2 else { return [] }

        let tableNames = Set(tableRestaurants.map { $0.name.lowercased() })
        let myNames = Set(store.restaurants.map { $0.name.lowercased() })
        let knownNames = tableNames.union(myNames)

        return searchService.suggestions
            .filter { !knownNames.contains($0.name.lowercased()) }
            .prefix(4)
            .map { result in
                let context = buildWorthTryingContext(for: result)
                return WorthTryingData(
                    name: result.name,
                    location: shortLocation(from: result.subtitle),
                    fullAddress: result.subtitle,
                    contextLine: context.line,
                    contextType: context.type
                )
            }
    }

    /// Remaining table matches as fallback
    private var fallbackResults: [SearchMatchData] {
        Array(allTableMatches.dropFirst(5))
    }

    /// Local hits from the user's own data — "have I been here?" recall.
    /// Filtered to mine-only so we don't double-show table results, which
    /// the existing `allTableMatches` flow already renders with rich reasoning.
    private var mineHits: [LocalSearchHit] {
        guard searchText.count >= 2 else { return [] }
        // Pass real table data so friend-name and dish queries work through
        // the full search index. Deduplicate against allTableMatches so we
        // don't show the same restaurant twice.
        let tableMatchNames = Set(allTableMatches.map { $0.name.lowercased() })
        let all = LocalSearchIndex.search(
            query: searchText,
            myRestaurants: store.restaurants,
            tableRestaurants: tableRestaurants,
            currentUid: currentUid,
            limit: 8
        )
        return all.filter { !tableMatchNames.contains($0.name.lowercased()) }
    }

    private var shouldShowAskRow: Bool {
        AskEscalationTrigger.shouldOffer(
            query: searchText,
            localHitCount: mineHits.count + allTableMatches.count + worthTrying.count
        )
    }

    private var hasAnyResults: Bool {
        bestMatch != nil || !worthTrying.isEmpty || !mineHits.isEmpty
    }

    private var showNoResults: Bool {
        searchText.count >= 2 && !hasAnyResults && !searchService.isSearching && !shouldShowAskRow
    }

    // =========================================================================
    // MARK: - Body
    // =========================================================================

    var body: some View {
        NavigationStack {
            ZStack {
                Color.fbBg.ignoresSafeArea()

                VStack(spacing: 0) {
                    HStack {
                        Text("Search")
                            .font(.system(size: 26, weight: .heavy))
                            .tracking(-0.5)
                        Spacer()
                        BurgerMenuButton { showAccount = true }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 4)

                    searchBar
                        .padding(.horizontal, 16)
                        .padding(.top, 12)

                    ScrollView(.vertical, showsIndicators: false) {
                        if searchText.count < 2 {
                            preSearchState
                        } else if showNoResults {
                            noResultsState
                        } else {
                            decisionResults
                        }
                    }
                }

                if showToast, let message = toastMessage {
                    VStack {
                        Spacer()
                        FBToast(message: message, style: .prominent)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                            .padding(.bottom, 90)
                    }
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
                            withAnimation { showToast = false }
                        }
                    }
                }
            }
            .toolbar(.hidden)
            .sheet(item: $activeSheet, onDismiss: {
                // Chaining: if a follow-up sheet was queued ("I
                // went here" → addPlace), re-present it. A small
                // asyncAfter is more reliable than .async here —
                // it gives the dismissal animation time to complete
                // before the next sheet tries to present, which
                // otherwise can cause SwiftUI to drop the new sheet.
                if let next = pendingFollowUp {
                    pendingFollowUp = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        activeSheet = next
                    }
                }
            }) { sheet in
                switch sheet {
                case .detail(let detail):
                    searchDetailSheet(detail)
                case .addPlace(let prefill):
                    AddPlaceTestFlow(
                        prefillName: prefill.name,
                        prefillAddress: prefill.address.isEmpty ? nil : prefill.address,
                        prefillCuisine: prefill.cuisine,
                        onComplete: {
                            // Route back to Home so the user lands
                            // on an updated recommendations feed
                            // after logging from Search.
                            selectedTab?.wrappedValue = 0
                        }
                    )
                    .environmentObject(store)
                }
            }
            .task { await loadTableData() }
            // Refetch when circle membership changes (e.g. deep-link invite
            // auto-accepted after this view was already mounted).
            .onChange(of: firestoreService.circlesVersion) { _, _ in
                Task { await loadTableData() }
            }
            .onChange(of: searchText) { newValue in
                searchService.searchText = newValue
            }
        }
        .accountMenu(isPresented: $showAccount, store: store)
    }

    // =========================================================================
    // MARK: - Search Bar
    // =========================================================================

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Self.mutedGray)
                .font(.system(size: 16))

            TextField("What are you in the mood for?", text: $searchText)
                .font(.body)
                .foregroundStyle(Color.fbText)
                .focused($isSearchFocused)
                .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    isSearchFocused = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Self.dimGray)
                        .font(.system(size: 16))
                }
            }
        }
        .padding(14)
        .background(Color.fbSurface2)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    isSearchFocused ? Self.warmAccent.opacity(0.4) : Color.fbBorder,
                    lineWidth: 1
                )
        )
    }

    // =========================================================================
    // MARK: - Pre-Search State
    // =========================================================================

    private var preSearchState: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Quick mood chips instead of generic shortcuts. The search-bar
            // placeholder ("What are you in the mood for?") already poses
            // the question, so no redundant section heading is needed.
            Spacer().frame(height: 20)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(moodChips, id: \.query) { chip in
                    Button { searchText = chip.query } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(chip.dish)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(Color.fbText)
                            Text(chip.reason)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Self.dimGray)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(Self.cardBg)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.white.opacity(0.05), lineWidth: 1)
                        )
                    }
                    .buttonStyle(SearchCardPressStyle())
                }
            }
            .padding(.horizontal, 16)

            Spacer(minLength: 100)
        }
    }

    // =========================================================================
    // MARK: - Decision Results
    // =========================================================================

    private var decisionResults: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── ASK ESCALATION (when query is question-shaped or weakly matched) ──
            if shouldShowAskRow {
                askEscalationRow
                    .padding(.horizontal, 16)
                    .padding(.top, 18)
            }

            if let asked = lastAskedQuery,
               asked == searchText.trimmingCharacters(in: .whitespaces),
               let answer = askService.lastAnswer {
                askAnswerCard(answer: answer)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
            } else if askService.isLoading {
                askLoadingCard
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
            }

            // ── SECTION 0: Your Places (memory recall) ──
            if !mineHits.isEmpty {
                Text("YOUR PLACES")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(Self.warmAccent.opacity(0.7))
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 10)

                VStack(spacing: 8) {
                    ForEach(mineHits) { hit in
                        mineHitCard(hit)
                    }
                }
                .padding(.horizontal, 16)
            }

            // ── SECTION 1: Best Match ──
            if let best = bestMatch {
                Text("BEST MATCH")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(Self.warmAccent.opacity(0.7))
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 12)

                bestMatchCard(best)
                    .padding(.horizontal, 16)
            }

            // ── SECTION 2: From Your Table ──
            if !fromYourTable.isEmpty {
                Text("FROM YOUR TABLE")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(Self.mutedGray)
                    .padding(.horizontal, 20)
                    .padding(.top, 28)
                    .padding(.bottom, 12)

                VStack(spacing: 8) {
                    ForEach(fromYourTable, id: \.name) { match in
                        tableMatchCard(match)
                    }
                }
                .padding(.horizontal, 16)
            }

            // ── SECTION 3: Worth Trying ──
            if !worthTrying.isEmpty {
                Text("WORTH TRYING")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(Self.mutedGray)
                    .padding(.horizontal, 20)
                    .padding(.top, 28)
                    .padding(.bottom, 12)

                VStack(spacing: 8) {
                    ForEach(worthTrying, id: \.name) { item in
                        worthTryingCard(item)
                    }
                }
                .padding(.horizontal, 16)
            }

            // ── SECTION 4: More Results (fallback) ──
            if !fallbackResults.isEmpty {
                HStack(spacing: 12) {
                    Rectangle().fill(Color.white.opacity(0.04)).frame(height: 1)
                    Text("MORE")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.0)
                        .foregroundStyle(Self.dimGray)
                    Rectangle().fill(Color.white.opacity(0.04)).frame(height: 1)
                }
                .padding(.horizontal, 16)
                .padding(.top, 28)
                .padding(.bottom, 8)

                ForEach(fallbackResults, id: \.name) { match in
                    fallbackRow(match)
                        .padding(.horizontal, 16)
                }
            }

            Spacer(minLength: 100)
        }
    }

    // =========================================================================
    // MARK: - Best Match Card (Hero)
    // =========================================================================

    private func bestMatchCard(_ match: SearchMatchData) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Dish name — THE answer, largest element
            Text(match.topDish.isEmpty ? match.name : match.topDish)
                .font(.system(size: 24, weight: .heavy))
                .tracking(-0.3)
                .foregroundStyle(Self.warmAccent)
                .padding(.bottom, 6)

            // Restaurant — important but secondary to dish
            Text(match.name)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Self.lightText)
                .padding(.bottom, 3)

            // Meta
            HStack(spacing: 4) {
                Text(match.cuisine)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Self.dimGray)
                if !match.location.isEmpty {
                    Text("\u{00B7}")
                        .font(.system(size: 13))
                        .foregroundStyle(Self.dimGray)
                    Text(match.location)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Self.dimGray)
                }
            }
            .padding(.bottom, 16)

            // Reasoning — the "why" line, prominent
            Text(match.reasoning)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.fbText)
                .padding(.bottom, 12)

            // Supporting dish if available
            if let second = match.secondDish {
                Text("Also try: \(second)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(hex: "B0B0B4"))
                    .padding(.bottom, 14)
            }

            // Trust line — who from your table
            Text(buildTrustLine(names: match.memberNames, visits: match.totalVisits))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Self.warmAccent.opacity(0.8))
                .padding(.bottom, 18)

            // CTA
            HStack {
                Spacer()
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    activeSheet = .detail(buildDetailData(from: match))
                } label: {
                    Text("Go here \u{2192}")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.fbText)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 11)
                        .background(Self.warmAccent.opacity(0.15))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Self.warmAccent.opacity(0.3), lineWidth: 1))
                        .shadow(color: Self.warmAccent.opacity(0.06), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(SearchCardPressStyle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Self.cardHero)
                RadialGradient(
                    colors: [Self.warmAccent.opacity(0.05), .clear],
                    center: .topLeading,
                    startRadius: 0, endRadius: 200
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.35), radius: 20, x: 0, y: 12)
        .contentShape(Rectangle())
        .onTapGesture {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            activeSheet = .detail(buildDetailData(from: match))
        }
    }

    // =========================================================================
    // MARK: - Table Match Card
    // =========================================================================

    private func tableMatchCard(_ match: SearchMatchData) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Dish first — always
            if !match.topDish.isEmpty {
                Text(match.topDish)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Self.warmAccent)
                    .padding(.bottom, 4)
            }

            // Restaurant
            Text(match.name)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Self.lightText)
                .padding(.bottom, 3)

            // Meta
            HStack(spacing: 4) {
                Text(match.cuisine)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Self.dimGray)
                if !match.location.isEmpty {
                    Text("\u{00B7}")
                        .font(.system(size: 12))
                        .foregroundStyle(Self.dimGray)
                    Text(match.location)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Self.dimGray)
                        .lineLimit(1)
                }
            }
            .padding(.bottom, 10)

            // Reasoning — the why
            Text(match.reasoning)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(hex: "B0B0B4"))
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(Self.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            activeSheet = .detail(buildDetailData(from: match))
        }
    }

    // =========================================================================
    // MARK: - Worth Trying Card
    // =========================================================================

    private func worthTryingCard(_ item: WorthTryingData) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Restaurant name
            Text(item.name)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Self.lightText)
                .padding(.bottom, 3)

            if !item.location.isEmpty {
                Text(item.location)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Self.dimGray)
                    .padding(.bottom, item.contextLine.isEmpty ? 0 : 8)
            }

            // Context line — only rendered when we have a real signal
            // to surface (taste match, popular, etc.). For plain
            // nearby results the location above is enough.
            if !item.contextLine.isEmpty {
                HStack(spacing: 6) {
                    Circle()
                        .fill(contextColor(for: item.contextType))
                        .frame(width: 5, height: 5)
                    Text(item.contextLine)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color(hex: "B0B0B4"))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.02))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.04), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            activeSheet = .detail(SearchDetailData(
                name: item.name,
                cuisine: "Restaurant",
                location: item.location,
                address: item.fullAddress,
                topDish: nil,
                secondDish: nil,
                reasoning: item.contextLine,
                trustLine: "New to your table",
                memberNames: []
            ))
        }
    }

    private func contextColor(for type: WorthTryingContextType) -> Color {
        switch type {
        case .tasteMatch: return Self.warmAccent
        case .popular: return Color(hex: "FF7A45")
        case .nearby: return Color(hex: "34C759")
        case .generic: return Self.dimGray
        }
    }

    // =========================================================================
    // MARK: - Fallback Row
    // =========================================================================

    private func fallbackRow(_ match: SearchMatchData) -> some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                Text(match.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(hex: "B0B0B4"))

                HStack(spacing: 4) {
                    Text(match.cuisine)
                        .font(.system(size: 12))
                        .foregroundStyle(Self.dimGray)
                    if !match.topDish.isEmpty {
                        Text("\u{00B7}")
                            .font(.system(size: 12))
                            .foregroundStyle(Self.dimGray)
                        Text(match.topDish)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Self.dimGray)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Self.dimGray.opacity(0.5))
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.white.opacity(0.03)).frame(height: 1)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            activeSheet = .detail(buildDetailData(from: match))
        }
    }

    // =========================================================================
    // MARK: - No Results
    // =========================================================================

    private var noResultsState: some View {
        VStack(spacing: 10) {
            Spacer(minLength: 60)
            Text("No matches")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color.fbText)
            Text("Try a different dish or cuisine.")
                .font(.system(size: 14))
                .foregroundStyle(Self.mutedGray)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, 20)
    }

    // =========================================================================
    // MARK: - Detail Sheet
    // =========================================================================

    private func searchDetailSheet(_ detail: SearchDetailData) -> some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // Restaurant name
                    Text(detail.name)
                        .font(.system(size: 26, weight: .heavy))
                        .tracking(-0.5)
                        .foregroundStyle(Self.lightText)
                        .padding(.bottom, 3)

                    // Meta
                    HStack(spacing: 4) {
                        Text(detail.cuisine)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Self.dimGray)
                        if !detail.location.isEmpty {
                            Text("\u{00B7}")
                                .font(.system(size: 13))
                                .foregroundStyle(Self.dimGray)
                            Text(detail.location)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Self.dimGray)
                        }
                    }
                    .padding(.bottom, 28)

                    // Reasoning — leads the detail
                    Text(detail.reasoning)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(Color.fbText)
                        .padding(.bottom, 20)

                    // Dish — the answer
                    if let dish = detail.topDish {
                        Text(dish)
                            .font(.system(size: 22, weight: .heavy))
                            .foregroundStyle(Self.warmAccent)
                            .padding(.bottom, 8)
                    }

                    // Second dish
                    if let second = detail.secondDish {
                        Text("Also try: \(second)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color(hex: "B0B0B4"))
                            .padding(.bottom, 6)
                    }

                    // Trust line
                    Text(detail.trustLine)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Self.warmAccent.opacity(0.8))
                        .padding(.top, 18)
                        .padding(.bottom, 36)

                    // ── CTAs (equal weight: Go here + I went here) ──
                    VStack(spacing: 10) {
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            activeSheet = nil
                            // Wait for the detail sheet to dismiss so the
                            // toast isn't hidden behind it.
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                showToastMessage("Noted \u{2014} we\u{2019}ll check in after your visit")
                            }
                        } label: {
                            Text("Go here")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(Color.fbText)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Self.warmAccent.opacity(0.18))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Self.warmAccent.opacity(0.35), lineWidth: 1)
                                )
                                .shadow(color: Self.warmAccent.opacity(0.08), radius: 12, x: 0, y: 6)
                        }
                        .buttonStyle(SearchCardPressStyle())

                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            // Prefill data is carried INSIDE the enum
                            // case, so it's passed atomically to
                            // AddPlaceTestFlow when the sheet presents.
                            // Queue it and trigger dismiss; onDismiss
                            // chain re-presents with the prefill.
                            pendingFollowUp = .addPlace(prefillFromDetail(detail))
                            activeSheet = nil
                        } label: {
                            // Distinct hue from "Go here" (warm sand →
                            // planning) so the past-tense logging action
                            // reads differently from the future-tense
                            // committing action.
                            Text("I went here")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(Color.fbText)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color.fbAccent1.opacity(0.20))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color.fbAccent1.opacity(0.45), lineWidth: 1)
                                )
                                .shadow(color: Color.fbAccent1.opacity(0.10), radius: 12, x: 0, y: 6)
                        }
                        .buttonStyle(SearchCardPressStyle())
                    }
                }
                .padding(24)
                .padding(.top, 12)
            }
            .background(Color.fbBg)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { activeSheet = nil } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Self.dimGray)
                    }
                }
            }
        }
    }

    // =========================================================================
    // MARK: - Logic Helpers
    // =========================================================================

    private func buildReasoning(
        names: [String],
        topDish: String,
        topDishCount: Int,
        totalVisits: Int,
        isRepeat: Bool
    ) -> String {
        // Prioritize repeat behavior. The top dish is already rendered as
        // the card's bold heading, so the reasoning line refers back with
        // "this" rather than naming the dish a second time.
        if isRepeat && !topDish.isEmpty {
            if let name = names.first, names.count == 1 {
                return "\(name) keeps ordering this"
            }
            return "Your table keeps ordering this"
        }

        // Dish consensus
        if topDishCount >= 2 && !topDish.isEmpty {
            return "\(topDishCount) from your table get the \(topDish)"
        }

        // Named endorsement
        if names.count >= 2 && !topDish.isEmpty {
            return "\(names[0]) and \(names[1]) both recommend the \(topDish)"
        }

        if let name = names.first, !topDish.isEmpty {
            return "\(name) says get the \(topDish)"
        }

        // Generic fallback
        if names.count >= 2 {
            return "\(names[0]) and \(names[1]) have been here"
        }

        if let name = names.first {
            return "\(name) loved it"
        }

        return "From your table"
    }

    private func buildTrustLine(names: [String], visits: Int) -> String {
        if visits >= 3 {
            return "\(visits) visits from your table"
        }
        if names.count >= 3 {
            return "\(names[0]), \(names[1]) & \(names.count - 2) more"
        }
        if names.count == 2 {
            return "\(names[0]) & \(names[1])"
        }
        if let name = names.first {
            return "\(name) from your table"
        }
        return "From your table"
    }

    private func buildWorthTryingContext(
        for result: RestaurantSearchService.RestaurantSuggestion
    ) -> (line: String, type: WorthTryingContextType) {
        let subtitle = result.subtitle.lowercased()

        // Check if it matches user's taste profile
        let myTopCuisines = Dictionary(grouping: store.visitedRestaurants, by: { $0.cuisine })
            .mapValues(\.count)
            .sorted { $0.value > $1.value }
            .prefix(3)
            .map(\.key)

        for cuisine in myTopCuisines {
            if subtitle.contains(cuisine.rawValue.lowercased()) {
                return ("Matches your taste \u{2014} you like \(cuisine.rawValue)", .tasteMatch)
            }
        }

        // Location-based: the card already shows the short location
        // directly above, so returning "Nearby in <same city>" here
        // duplicated it. Fall through to .nearby with an empty line —
        // the card skips the row when contextLine is empty.
        return ("", .nearby)
    }

    /// Build the AddPlaceTestFlow prefill payload from a tapped
    /// detail. Prefers the user's own saved entry (canonical address
    /// + cuisine), then a table entry, then the detail itself.
    /// Returned value is bundled into `SearchSheet.addPlace` so the
    /// prefill travels WITH the sheet presentation instead of living
    /// in separate @State that can race with the dismissal.
    private func prefillFromDetail(_ detail: SearchDetailData) -> AddPlacePrefill {
        let nameKey = detail.name.lowercased()

        if let mine = store.restaurants.first(where: {
            $0.name.lowercased() == nameKey
        }) {
            return AddPlacePrefill(
                name: detail.name,
                address: mine.address,
                cuisine: mine.cuisine
            )
        }
        if let table = tableRestaurants.first(where: {
            $0.name.lowercased() == nameKey
        }) {
            return AddPlacePrefill(
                name: detail.name,
                address: table.address,
                cuisine: table.cuisine
            )
        }
        return AddPlacePrefill(
            name: detail.name,
            address: detail.address,
            cuisine: CuisineType.allCases.first(where: {
                $0.rawValue.caseInsensitiveCompare(detail.cuisine) == .orderedSame
            })
        )
    }

    private func buildDetailData(from match: SearchMatchData) -> SearchDetailData {
        SearchDetailData(
            name: match.name,
            cuisine: match.cuisine,
            location: match.location,
            address: match.address,
            topDish: match.topDish.isEmpty ? nil : match.topDish,
            secondDish: match.secondDish,
            reasoning: match.reasoning,
            trustLine: buildTrustLine(names: match.memberNames, visits: match.totalVisits),
            memberNames: match.memberNames
        )
    }

    private func shortLocation(from address: String) -> String {
        let parts = address.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count >= 3 else {
            return address.replacingOccurrences(of: ", United States", with: "")
        }
        let city = parts[1]
        let stateZip = parts[2]
        let stateOnly = stateZip.components(separatedBy: " ").first ?? stateZip
        return "\(city), \(stateOnly)"
    }

    private func showToastMessage(_ message: String) {
        toastMessage = message
        withAnimation { showToast = true }
    }

    // =========================================================================
    // MARK: - Data Loading
    // =========================================================================

    private func loadTableData() async {
        isLoadingTable = true
        let circles = await firestoreService.getMyCircles()

        if let circle = circles.first {
            tableMembers = await firestoreService.getCircleMembers(circle: circle)
            tableRestaurants = await firestoreService.getCircleRestaurants(circleId: circle.id)

            let memberMap = Dictionary(uniqueKeysWithValues: tableMembers.map { ($0.uid, $0.displayName) })
            for i in tableRestaurants.indices {
                tableRestaurants[i].userName = memberMap[tableRestaurants[i].userId] ?? "Friend"
            }
        }

        // In Release (TestFlight/App Store) leave empty so real users start clean.
        #if DEBUG
        let realEntries = tableRestaurants.filter { $0.userId != currentUid }
        if realEntries.isEmpty {
            tableMembers = tableMembers + MockTableData.buildMembers()
            tableRestaurants.append(contentsOf: MockTableData.buildSharedRestaurants())
        }
        #endif

        isLoadingTable = false
    }

    // =========================================================================
    // MARK: - Sample / Static Data
    // =========================================================================

    private struct MoodChip {
        let dish: String
        let query: String
        let reason: String
    }

    /// Data-driven mood chips: top dishes from table consensus first, then top
    /// cuisines from the user's own visited places. Falls back to a static set
    /// only when there's no signal at all.
    private var moodChips: [MoodChip] {
        var out: [MoodChip] = []
        var seen: Set<String> = []

        // Top-voted dishes across the table
        let friendEntries = tableRestaurants.filter { $0.userId != currentUid }
        var dishVotes: [String: (count: Int, names: Set<String>)] = [:]
        for e in friendEntries {
            let firstName = e.userName.components(separatedBy: " ").first ?? e.userName
            for d in e.likedDishes {
                let key = d.name.trimmingCharacters(in: .whitespaces)
                guard !key.isEmpty else { continue }
                let normKey = key.lowercased()
                var entry = dishVotes[normKey] ?? (0, [])
                entry.count += 1
                entry.names.insert(firstName)
                dishVotes[normKey] = entry
            }
        }
        let topDishes = dishVotes
            .filter { $0.value.count >= 2 || $0.value.names.count >= 2 }
            .sorted { lhs, rhs in
                if lhs.value.count != rhs.value.count { return lhs.value.count > rhs.value.count }
                return lhs.value.names.count > rhs.value.names.count
            }
            .prefix(3)
        for (rawKey, info) in topDishes {
            let display = rawKey.prefix(1).uppercased() + rawKey.dropFirst()
            let reason: String
            if info.names.count >= 2 {
                let arr = Array(info.names)
                reason = arr.count >= 2 ? "\(arr[0]) & \(arr[1]) get this" : "\(arr[0]) gets this"
            } else if info.count >= 3 {
                reason = "\(info.count) people order this"
            } else if let first = info.names.first {
                reason = "\(first)'s repeat"
            } else {
                reason = "Loved on your table"
            }
            seen.insert(rawKey.lowercased())
            out.append(MoodChip(dish: display, query: rawKey.lowercased(), reason: reason))
        }

        // Top cuisines from your own visited places (skip ones we already chose)
        let cuisineCounts = Dictionary(grouping: store.visitedRestaurants, by: { $0.cuisine })
            .mapValues(\.count)
            .sorted { $0.value > $1.value }
            .prefix(4)
        for (cuisine, count) in cuisineCounts where cuisine != .other {
            let key = cuisine.rawValue.lowercased()
            if seen.contains(key) { continue }
            seen.insert(key)
            let reason = count >= 4 ? "\(count) of your places" : "Your taste"
            out.append(MoodChip(dish: cuisine.rawValue, query: key, reason: reason))
            if out.count >= 6 { break }
        }

        // Fallback only if we have nothing
        if out.isEmpty {
            return [
                MoodChip(dish: "Pizza", query: "pizza", reason: "Always works"),
                MoodChip(dish: "Sushi", query: "sushi", reason: "Quick + clean"),
                MoodChip(dish: "Ramen", query: "ramen", reason: "Cold-night standby"),
                MoodChip(dish: "Tacos", query: "tacos", reason: "Easy crowd-pleaser"),
                MoodChip(dish: "Indian", query: "indian", reason: "Bold flavors"),
                MoodChip(dish: "Italian", query: "italian", reason: "Familiar comfort"),
            ]
        }
        return out
    }

    // =========================================================================
    // MARK: - Mine Hit Card (memory recall)
    // =========================================================================

    private func mineHitCard(_ hit: LocalSearchHit) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            // Surface this as a memory-style detail sheet so the user
            // doesn't lose context about what they remember.
            let trustLine: String = {
                if let r = hit.mine, r.isGoTo { return "You always go back" }
                if let r = hit.mine, r.reaction == .loved { return "You loved it" }
                if let r = hit.mine { return "\(r.visitCount) visit\(r.visitCount == 1 ? "" : "s")" }
                return "From your places"
            }()
            let reasoning: String = {
                if let lead = hit.leadDish, let r = hit.mine, r.visitCount >= 2 {
                    return "You\u{2019}ve had the \(lead) \(r.visitCount) times"
                }
                if let lead = hit.leadDish { return "Get the \(lead)" }
                if let r = hit.mine { return "You went here \(r.relativeVisitDate.lowercased())" }
                return "From your places"
            }()
            activeSheet = .detail(SearchDetailData(
                name: hit.name,
                cuisine: hit.cuisine.rawValue,
                location: hit.city,
                address: hit.address,
                topDish: hit.leadDish,
                secondDish: hit.otherDishes.first,
                reasoning: reasoning,
                trustLine: trustLine,
                memberNames: []
            ))
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text(hit.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Self.lightText)
                    Spacer()
                    if let r = hit.mine, r.isGoTo {
                        mineBadge("Repeat")
                    } else if let r = hit.mine, r.reaction == .loved {
                        mineBadge("Loved")
                    } else if let r = hit.mine, r.visitCount >= 2 {
                        mineBadge("\(r.visitCount) visits")
                    } else {
                        mineBadge("Yours")
                    }
                }
                .padding(.bottom, 4)

                HStack(spacing: 4) {
                    if hit.cuisine != .other {
                        Text(hit.cuisine.rawValue)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Self.dimGray)
                    }
                    if !hit.city.isEmpty {
                        Text("\u{00B7}").font(.system(size: 12)).foregroundStyle(Self.dimGray)
                        Text(hit.city)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Self.dimGray)
                    }
                }

                if let lead = hit.leadDish {
                    Text("Get the \(lead)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Self.warmAccent)
                        .padding(.top, 8)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(Self.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Self.warmAccent.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(SearchCardPressStyle())
    }

    private func mineBadge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .heavy))
            .tracking(0.6)
            .foregroundStyle(Self.warmAccent)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Self.warmAccent.opacity(0.10)))
            .overlay(Capsule().stroke(Self.warmAccent.opacity(0.24), lineWidth: 1))
    }

    // =========================================================================
    // MARK: - Ask ForkBook (escalation row + answer card)
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
                    Text("\u{201C}\(searchText.trimmingCharacters(in: .whitespaces))\u{201D}")
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
        .buttonStyle(SearchCardPressStyle())
    }

    private var askLoadingCard: some View {
        HStack(spacing: 10) {
            ProgressView()
                .tint(Self.warmAccent)
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
                .fill(Self.warmAccent.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Self.warmAccent.opacity(0.15), lineWidth: 1)
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
                    .foregroundStyle(Self.warmAccent)
            }

            Text(answer.text)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.fbText)
                .fixedSize(horizontal: false, vertical: true)

            if !answer.suggestions.isEmpty {
                VStack(spacing: 8) {
                    ForEach(Array(answer.suggestions.enumerated()), id: \.offset) { _, s in
                        askSuggestionRow(s)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Self.warmAccent.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Self.warmAccent.opacity(0.18), lineWidth: 1)
        )
    }

    private func askSuggestionRow(_ s: AskForkBookService.Suggestion) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            // Try mine → table — same routing as MyPlaces.
            if let mine = store.restaurants.first(where: {
                LocalSearchIndex.normalizeName($0.name) == LocalSearchIndex.normalizeName(s.name)
            }) {
                activeSheet = .detail(SearchDetailData(
                    name: mine.name,
                    cuisine: mine.cuisine.rawValue,
                    location: mine.city,
                    address: mine.address,
                    topDish: mine.leadDish?.name,
                    secondDish: nil,
                    reasoning: s.reason,
                    trustLine: mine.relationshipCue ?? "From your places",
                    memberNames: []
                ))
            } else if let entry = tableRestaurants.first(where: {
                LocalSearchIndex.normalizeName($0.name) == LocalSearchIndex.normalizeName(s.name)
            }) {
                let names = Array(Set(tableRestaurants
                    .filter { LocalSearchIndex.normalizeName($0.name) == LocalSearchIndex.normalizeName(s.name) }
                    .map { $0.userName.components(separatedBy: " ").first ?? $0.userName }
                ))
                activeSheet = .detail(SearchDetailData(
                    name: entry.name,
                    cuisine: entry.cuisine.rawValue,
                    location: shortLocation(from: entry.address),
                    address: entry.address,
                    topDish: entry.likedDishes.first?.name,
                    secondDish: nil,
                    reasoning: s.reason,
                    trustLine: buildTrustLine(names: names, visits: 1),
                    memberNames: names
                ))
            } else {
                // Pure suggestion (not in any source) — surface it anyway.
                activeSheet = .detail(SearchDetailData(
                    name: s.name,
                    cuisine: "",
                    location: "",
                    address: "",
                    topDish: nil,
                    secondDish: nil,
                    reasoning: s.reason,
                    trustLine: "Suggested by ForkBook",
                    memberNames: []
                ))
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
        .buttonStyle(SearchCardPressStyle())
    }

    private func runAsk() {
        let q = searchText.trimmingCharacters(in: .whitespaces)
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
}

// =========================================================================
// MARK: - Data Models
// =========================================================================

struct SearchMatchData {
    let name: String
    let cuisine: String
    let location: String
    let address: String
    let topDish: String
    let secondDish: String?
    let topDishCount: Int
    let memberNames: [String]
    let totalVisits: Int
    let isRepeat: Bool
    let relationship: SearchMatchRelationship
    let reasoning: String
    let score: Int
    let entries: [SharedRestaurant]
    let cuisineType: CuisineType
}

enum SearchMatchRelationship {
    case regular, beenHere, saved, newToYou
}

struct WorthTryingData {
    let name: String
    let location: String
    let fullAddress: String
    let contextLine: String
    let contextType: WorthTryingContextType
}

enum WorthTryingContextType {
    case tasteMatch, popular, nearby, generic
}

struct SearchDetailData: Identifiable {
    let id = UUID()
    let name: String
    let cuisine: String
    let location: String
    let address: String
    let topDish: String?
    let secondDish: String?
    let reasoning: String
    let trustLine: String
    let memberNames: [String]
}

// =========================================================================
// MARK: - Press Style
// =========================================================================

private struct SearchCardPressStyle: ButtonStyle {
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
    SearchTestView()
        .environmentObject(RestaurantStore())
        .preferredColorScheme(.dark)
}
