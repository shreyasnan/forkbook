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

    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    @State private var tableRestaurants: [SharedRestaurant] = []
    @State private var tableMembers: [FirestoreService.CircleMember] = []
    @State private var isLoadingTable = true

    @State private var selectedDetail: SearchDetailData? = nil
    @State private var toastMessage: String?
    @State private var showToast = false
    @State private var showAddPlace = false

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
            guard nameKey.contains(q)
                    || entries.first?.cuisine.rawValue.lowercased().contains(q) == true
                    || entries.flatMap(\.dishes).contains(where: { $0.name.lowercased().contains(q) })
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

    private var hasAnyResults: Bool {
        bestMatch != nil || !worthTrying.isEmpty
    }

    private var showNoResults: Bool {
        searchText.count >= 2 && !hasAnyResults && !searchService.isSearching
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
                        FBToast(message: message)
                            .transition(.opacity)
                            .padding(.bottom, 90)
                    }
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            withAnimation { showToast = false }
                        }
                    }
                }
            }
            .toolbar(.hidden)
            .sheet(item: $selectedDetail) { detail in
                searchDetailSheet(detail)
            }
            .sheet(isPresented: $showAddPlace) {
                AddPlaceTestFlow()
                    .environmentObject(store)
            }
            .task { await loadTableData() }
            .onChange(of: searchText) { newValue in
                searchService.searchText = newValue
            }
        }
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
            // Quick mood chips instead of generic shortcuts
            Text("WHAT SOUNDS GOOD?")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(Self.mutedGray)
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 14)

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
                    selectedDetail = buildDetailData(from: match)
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
            selectedDetail = buildDetailData(from: match)
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
            selectedDetail = buildDetailData(from: match)
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
                    .padding(.bottom, 8)
            }

            // Context line — why this is worth trying
            HStack(spacing: 6) {
                Circle()
                    .fill(contextColor(for: item.contextType))
                    .frame(width: 5, height: 5)
                Text(item.contextLine)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(hex: "B0B0B4"))
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
            selectedDetail = SearchDetailData(
                name: item.name,
                cuisine: "Restaurant",
                location: item.location,
                address: item.fullAddress,
                topDish: nil,
                secondDish: nil,
                reasoning: item.contextLine,
                trustLine: "New to your table",
                memberNames: []
            )
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
            selectedDetail = buildDetailData(from: match)
        }
    }

    // =========================================================================
    // MARK: - No Results
    // =========================================================================

    private var noResultsState: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 60)
            Text("Nothing from your table")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color.fbText)
            Text("No one in your table has logged a match.\nTry a different dish, cuisine, or neighborhood.")
                .font(.system(size: 14))
                .foregroundStyle(Self.mutedGray)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
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

                    // ── CTAs ──
                    VStack(spacing: 10) {
                        // Primary: Go here
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            showToastMessage("Added to your plan")
                            selectedDetail = nil
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

                        // Secondary: I went here
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            selectedDetail = nil
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                showAddPlace = true
                            }
                        } label: {
                            Text("I went here")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color(hex: "B0B0B4"))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color.white.opacity(0.05))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                )
                        }
                        .buttonStyle(SearchCardPressStyle())

                        // Tertiary: Save
                        Button {
                            showToastMessage("Saved for later")
                            selectedDetail = nil
                        } label: {
                            Text("Save for later")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Self.dimGray)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 6)
                    }
                }
                .padding(24)
                .padding(.top, 12)
            }
            .background(Color.fbBg)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { selectedDetail = nil } label: {
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
        // Prioritize repeat behavior
        if isRepeat && !topDish.isEmpty {
            if let name = names.first, names.count == 1 {
                return "\(name) keeps ordering the \(topDish)"
            }
            return "Your table keeps ordering the \(topDish)"
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

        // Location-based
        let shortLoc = shortLocation(from: result.subtitle)
        if !shortLoc.isEmpty {
            return ("Nearby in \(shortLoc)", .nearby)
        }

        return ("Worth exploring", .generic)
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

        let realEntries = tableRestaurants.filter { $0.userId != currentUid }
        if realEntries.isEmpty {
            tableRestaurants.append(contentsOf: MockTableData.buildSharedRestaurants())
        }

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

    private var moodChips: [MoodChip] {
        [
            MoodChip(dish: "Pizza", query: "pizza", reason: "Raj gets this weekly"),
            MoodChip(dish: "Sushi", query: "sushi", reason: "3 spots from your table"),
            MoodChip(dish: "Ramen", query: "ramen", reason: "Maya\u{2019}s go-to"),
            MoodChip(dish: "Tacos", query: "tacos", reason: "New spot nearby"),
            MoodChip(dish: "Indian", query: "indian", reason: "Your table\u{2019}s favorite"),
            MoodChip(dish: "Italian", query: "italian", reason: "4 spots from your table"),
        ]
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
