import SwiftUI
import FirebaseAuth

// MARK: - Home Test View
//
// Decision-surface home page: "Where tonight? What to get? Why trust this?"
// Hero: top-scored place. Backups: other strong picks.
// Real data: user store + Firestore circle restaurants.

struct HomeTestView: View {
    @EnvironmentObject var store: RestaurantStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var selectedHero: HeroCardData? = nil
    @State private var showAddPlace = false
    @State private var showProfile = false
    @State private var currentHeroIndex: Int = 0
    @State private var logPrefillName: String = ""
    @State private var logPrefillAddress: String = ""
    @State private var logPrefillCuisine: CuisineType? = nil
    @State private var selectedOccasion: OccasionTag? = nil

    // Committed pick — persisted to UserDefaults so it survives restarts
    @State private var committedPick: CommittedPick? = nil

    // Table data
    @State private var tableRestaurants: [SharedRestaurant] = []
    @State private var tableMembers: [FirestoreService.CircleMember] = []
    @State private var hasLoaded = false
    @State private var usingMockData = false
    @ObservedObject private var locationManager = LocationManager.shared

    // Transient toast shown after "Go here" (and similar confirmations)
    // so the user gets immediate feedback that the action was noted.
    @State private var toastMessage: String? = nil
    @State private var showToast = false

    // Restaurants the user has dismissed ("Changed my mind") or acted on
    // ("Save for later", "Go here" → logged). Persisted so they don't
    // resurface on next launch.
    @State private var dismissedNames: Set<String> = []
    private static let dismissedKey = "ForkBook_DismissedHeroNames"
    @ObservedObject private var firestoreService = FirestoreService.shared

    // -- Design tokens --
    private static let cardBg = Color(hex: "131517")
    private static let cardHero = Color(hex: "171A1D")
    private static let warmAccent = Color(hex: "C4A882")
    private static let mutedGray = Color(hex: "8E8E93")
    private static let dimGray = Color(hex: "6B6B70")
    private static let lightText = Color(hex: "F5F5F7")

    private var currentUid: String? { Auth.auth().currentUser?.uid }

    /// Whether the committed-pick card should be visible right now.
    /// Requires: pick exists, at least 2 hours old, under 7 days, no chip active.
    private var isPickCardVisible: Bool {
        guard selectedOccasion == nil,
              let pick = committedPick,
              pick.hoursAgo >= 2,
              pick.hoursAgo < 24 * 7
        else { return false }
        return true
    }

    // =========================================================================
    // MARK: - Body
    // =========================================================================

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    homeHeader
                        .padding(.horizontal, 20)
                        .padding(.top, 12)

                    occasionChipRow
                        .padding(.top, 18)

                    let heroes = heroCards
                    let backups = backupCards

                    // Committed pick — "Did you go?" card.
                    // Only shown after 2 hours (user went out and came back).
                    // Hidden when an occasion chip is active.
                    if isPickCardVisible, let pick = committedPick {
                        committedPickCard(pick)
                            .padding(.horizontal, 16)
                            .padding(.top, 18)
                    }

                    if !heroes.isEmpty {
                        // When committed pick is visible, show fresh picks
                        // under a lighter label so they don't compete.
                        if isPickCardVisible {
                            Text("FRESH PICKS")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(1.5)
                                .foregroundStyle(Self.mutedGray)
                                .padding(.horizontal, 22)
                                .padding(.top, 22)
                                .padding(.bottom, 8)
                        }

                        let idx = min(currentHeroIndex, heroes.count - 1)
                        heroCardView(heroes[idx])
                            .padding(.horizontal, 16)
                            .padding(.top, isPickCardVisible ? 0 : 18)
                    } else if !isPickCardVisible {
                        emptyState
                            .padding(.horizontal, 16)
                            .padding(.top, 18)
                    }

                    if !backups.isEmpty {
                        Text(alsoGoodSectionLabel)
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1.5)
                            .foregroundStyle(Self.mutedGray)
                            .padding(.horizontal, 22)
                            .padding(.top, 26)
                            .padding(.bottom, 12)

                        VStack(spacing: 10) {
                            ForEach(backups) { backup in
                                backupCard(backup)
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    Spacer(minLength: 80)
                }
            }
            .background(Color.fbBg)
            .overlay(alignment: .bottom) {
                if showToast, let message = toastMessage {
                    FBToast(message: message, style: .prominent)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                        .padding(.bottom, 90)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selectedHero) { hero in
                testDetailSheet(hero)
            }
            .sheet(isPresented: $showAddPlace, onDismiss: {
                // Reset prefill after sheet closes so stale data
                // doesn't leak into a future manual "+" tap.
                logPrefillName = ""
                logPrefillAddress = ""
                logPrefillCuisine = nil
            }) {
                AddPlaceTestFlow(
                    prefillName: logPrefillName.isEmpty ? nil : logPrefillName,
                    prefillAddress: logPrefillAddress.isEmpty ? nil : logPrefillAddress,
                    prefillCuisine: logPrefillCuisine
                )
                .environmentObject(store)
                .id(logPrefillName)   // force SwiftUI to create a fresh view
            }
            .navigationDestination(isPresented: $showProfile) {
                AccountMenuView()
                    .environmentObject(store)
            }
        }
        .task {
            guard !hasLoaded else { return }
            hasLoaded = true
            // DEV: clear stale committed pick from prior testing.
            // Remove this line once committed-pick flow is stable.
            CommittedPick.clear()
            committedPick = nil
            loadDismissed()
            locationManager.requestLocation()
            await loadTableData()
        }
        // Refetch when circle membership changes (e.g. deep-link invite
        // auto-accepted after this view was already mounted).
        .onChange(of: firestoreService.circlesVersion) { _, _ in
            Task { await loadTableData() }
        }
    }

    // =========================================================================
    // MARK: - Header + Empty State
    // =========================================================================

    private var homeHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                // Time-place anchor: "FRIDAY · 7:14 PM · BROOKLYN".
                // Grounds the page in right-now, right-here so picks
                // read as a decision surface, not a browsing feed.
                Text(MealWindow.anchorLine(city: locationManager.userCity))
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(Self.mutedGray)
                Text(MealWindow.current.headerLabel)
                    .font(.system(size: 26, weight: .heavy))
                    .tracking(-0.5)
                    .foregroundColor(Color.fbText)
            }
            Spacer()
            Button { showProfile = true } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color.fbText)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // =========================================================================
    // MARK: - Committed Pick Card ("Did you go?")
    // =========================================================================

    /// Shows when the user previously tapped "Go here" and hasn't logged yet.
    /// Replaces the hero card with a gentle follow-up nudge.
    private func committedPickCard(_ pick: CommittedPick) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Eyebrow
            Text("YOUR PLAN")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(Self.warmAccent)
                .padding(.bottom, 10)

            // Restaurant name
            Text(pick.name)
                .font(.system(size: 28, weight: .heavy))
                .tracking(-0.5)
                .foregroundStyle(Color.fbText)
                .padding(.bottom, 4)

            // Meta line (cuisine · time ago)
            HStack(spacing: 6) {
                Text(pick.cuisine.rawValue)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Self.mutedGray)

                if pick.hoursAgo < 1 {
                    Text("\u{00B7} Just now")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Self.mutedGray)
                } else if pick.hoursAgo < 24 {
                    Text("\u{00B7} \(Int(pick.hoursAgo))h ago")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Self.mutedGray)
                } else {
                    let days = Int(pick.hoursAgo / 24)
                    Text("\u{00B7} \(days)d ago")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Self.mutedGray)
                }
            }
            .padding(.bottom, 14)

            // Dish reminder (if saved)
            if let dish = pick.bestDish, !dish.isEmpty {
                Text("Don\u{2019}t forget the \(dish)")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.fbText)
                    .padding(.bottom, 16)
            }

            // CTAs
            VStack(spacing: 10) {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    logPrefillName = pick.name
                    logPrefillAddress = pick.address
                    logPrefillCuisine = pick.cuisine
                    clearPick()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showAddPlace = true
                    }
                } label: {
                    Text("Yes \u{2014} log my visit")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.fbText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Self.warmAccent.opacity(0.18))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Self.warmAccent.opacity(0.35), lineWidth: 1)
                        )
                }
                .buttonStyle(HomeCardPressStyle())

                HStack(spacing: 12) {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        // Keep the pick — they haven't gone yet but might still.
                        // Just scroll past to see fresh recommendations below.
                    } label: {
                        Text("Not yet")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color(hex: "B0B0B4"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.white.opacity(0.05))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                    }
                    .buttonStyle(HomeCardPressStyle())

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        dismissRestaurant(pick.name)
                        withAnimation(.easeOut(duration: 0.25)) {
                            clearPick()
                        }
                    } label: {
                        Text("Changed my mind")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color(hex: "B0B0B4"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.white.opacity(0.05))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                    }
                    .buttonStyle(HomeCardPressStyle())
                }
            }
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Self.warmAccent.opacity(0.06), Self.cardHero],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Self.warmAccent.opacity(0.12), lineWidth: 1)
        )
    }

    // MARK: - Occasion chip row

    private var occasionChipRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(OccasionClassifier.homeChipOrder, id: \.self) { tag in
                    occasionChip(tag)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func occasionChip(_ tag: OccasionTag) -> some View {
        let active = selectedOccasion == tag
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.easeInOut(duration: 0.18)) {
                selectedOccasion = active ? nil : tag
                currentHeroIndex = 0
            }
        } label: {
            Text(tag.chipLabel)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(active ? Self.warmAccent : Color(hex: "B0B0B4"))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(active ? Self.warmAccent.opacity(0.12)
                                     : Color.white.opacity(0.06))
                )
                .overlay(
                    Capsule()
                        .stroke(
                            active ? Self.warmAccent.opacity(0.50)
                                   : Color.white.opacity(0.22),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(HomeCardPressStyle())
    }

    private var alsoGoodSectionLabel: String {
        if let tag = selectedOccasion {
            return "ALSO GOOD FOR \(tag.sectionUppercase)"
        }
        return "PICKS YOU MAY LIKE FOR \(MealWindow.current.eyebrowFragment)"
    }

    private var emptyState: some View {
        let uid = currentUid ?? ""
        let hasOwnPlaces = !store.visitedRestaurants.isEmpty
        let hasTableFriends = !tableMembers.filter { $0.uid != uid }.isEmpty
        let hasTableSignal = tableRestaurants.contains { $0.userId != uid }

        let title: String = {
            if !hasOwnPlaces && !hasTableFriends { return "Nothing to show yet" }
            if !hasOwnPlaces { return "Log a place to get picks" }
            if !hasTableFriends { return "Invite your circle" }
            if !hasTableSignal { return "Waiting on your circle" }
            return "Nothing to show yet"
        }()

        let body: String = {
            if !hasOwnPlaces && !hasTableFriends {
                return "Log a few places to get picks."
            }
            if !hasOwnPlaces {
                return "Add a place you\u{2019}ve been to get picks."
            }
            if !hasTableFriends {
                return "Picks get stronger with a few trusted friends logging too."
            }
            if !hasTableSignal {
                return "Your circle is quiet. Nudge them to log."
            }
            return "Log a few places you\u{2019}ve been and we\u{2019}ll start surfacing picks."
        }()

        return VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.fbText)
            Text(body)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(hex: "B0B0B4").opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)
            // There is no generic "Add a place" form anymore — logging always
            // starts from a place card via "I went here". Nudge the user to
            // Search, which is where new places get surfaced and logged from.
            if !hasOwnPlaces {
                Text("Use the Search tab to find a place, then tap \u{201C}I went here\u{201D} to log it.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Self.warmAccent.opacity(0.95))
                    .padding(.top, 6)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    // =========================================================================
    // MARK: - Extracted Sub-Views (type-checker relief)
    // =========================================================================

    private var heroCardBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: Self.warmAccent.opacity(0.08), location: 0),
                            .init(color: Self.cardHero, location: 0.55)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            RadialGradient(
                colors: [Self.warmAccent.opacity(0.07), .clear],
                center: .topLeading,
                startRadius: 0, endRadius: 220
            )
        }
    }

    private var heroCardBorder: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .stroke(Color.white.opacity(0.06), lineWidth: 1)
    }

    // =========================================================================
    // MARK: - Hero Card
    // =========================================================================

    private func heroCardView(_ hero: HeroCardData) -> some View {
        let dishes = Array(
            ([hero.heroDish] + hero.supportingDishes)
                .filter { !$0.isEmpty }
                .prefix(2)
        )
        let showChanged = hero.changedConfidence.map { !isNewToYouPhrase($0) } ?? false

        let cardContent = VStack(alignment: .leading, spacing: 0) {
            Text(hero.eyebrow)
                .font(.system(size: 11, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(Self.mutedGray)
                .padding(.bottom, 12)

            // Name + distance + chevron (chevron = "tap for detail" affordance)
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(hero.restaurant)
                    .font(.system(size: 28, weight: .heavy))
                    .tracking(-0.6)
                    .foregroundStyle(Self.lightText)
                Spacer(minLength: 8)
                if let distance = hero.distanceText {
                    Text(distance)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Self.dimGray)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Self.dimGray)
            }
            .padding(.bottom, 4)

            if !hero.meta.isEmpty {
                Text(hero.meta)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Self.dimGray)
                    .padding(.bottom, 18)
            }

            if !dishes.isEmpty {
                Text(dishes.joined(separator: " \u{00B7} "))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Self.lightText)
                    .padding(.bottom, 14)
            }

            Text(hero.trustLine)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Self.warmAccent)

            if showChanged, let changed = hero.changedConfidence {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Self.warmAccent)
                        .frame(width: 6, height: 6)
                    Text(changed)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(hex: "B0B0B4"))
                }
                .padding(.top, 10)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)

        return cardContent
            .background(heroCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(heroCardBorder)
            .shadow(color: .black.opacity(0.42), radius: 28, x: 0, y: 16)
            .contentShape(Rectangle())
            .onTapGesture {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                selectedHero = hero
            }
    }

    // =========================================================================
    // MARK: - Backup Card
    // =========================================================================

    private func backupCard(_ backup: BackupCardData) -> some View {
        let dishes = Array(
            ([backup.heroDish] + backup.supportingDishes)
                .filter { !$0.isEmpty }
                .prefix(2)
        )

        return VStack(alignment: .leading, spacing: 0) {
            // Name + distance + chevron (mirrors hero card affordance).
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(backup.restaurant)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.fbText)
                Spacer(minLength: 8)
                if let distance = backup.distanceText {
                    Text(distance)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Self.dimGray)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Self.dimGray)
            }
            .padding(.bottom, 3)

            if !backup.meta.isEmpty {
                Text(backup.meta)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Self.dimGray)
                    .padding(.bottom, 8)
            }

            if !dishes.isEmpty {
                Text(dishes.joined(separator: " \u{00B7} "))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.fbText)
                    .lineLimit(2)
                    .padding(.bottom, 6)
            }

            Text(backup.trustLine)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Self.warmAccent)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
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
            selectedHero = HeroCardData(
                eyebrow: alsoGoodSectionLabel,
                restaurant: backup.restaurant,
                meta: backup.meta,
                heroDish: backup.heroDish,
                supportingDishes: backup.supportingDishes,
                trustLine: backup.trustLine,
                socialProof: backup.socialProof,
                changedConfidence: backup.changedConfidence,
                friendSummaries: backup.friendSummaries,
                distanceText: backup.distanceText,
                address: backup.address,
                cuisine: backup.cuisine
            )
        }
    }

    /// Populate logPrefill state from a hero, preferring real data from the
    /// user's own store, then table, falling back to best-effort from meta.
    private func prefillLog(for hero: HeroCardData) {
        logPrefillName = hero.restaurant
        let nameKey = hero.restaurant.lowercased()

        if let mine = store.restaurants.first(where: {
            $0.name.lowercased() == nameKey
        }) {
            logPrefillAddress = mine.address
            logPrefillCuisine = mine.cuisine
            return
        }
        if let table = tableRestaurants.first(where: {
            $0.name.lowercased() == nameKey
        }) {
            logPrefillAddress = table.address
            logPrefillCuisine = table.cuisine
            return
        }
        // Best-effort: first meta segment may be cuisine
        let firstMeta = hero.meta
            .components(separatedBy: "\u{00B7}")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first
        if let firstMeta, let match = CuisineType.allCases.first(where: {
            $0.rawValue.caseInsensitiveCompare(firstMeta) == .orderedSame
        }) {
            logPrefillCuisine = match
        } else {
            logPrefillCuisine = nil
        }
        logPrefillAddress = ""
    }

    // MARK: - Toast

    /// Show a transient confirmation message at the bottom of Home.
    /// Used after "Go here" so the user gets a clear signal the place
    /// was noted and we'll follow up later to ask how it went.
    private func showToastMessage(_ message: String) {
        toastMessage = message
        withAnimation(.easeInOut(duration: 0.2)) { showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            withAnimation(.easeInOut(duration: 0.2)) { showToast = false }
        }
    }

    // MARK: - Committed Pick Helpers

    private func commitPick(from hero: HeroCardData) {
        CommittedPick.save(
            name: hero.restaurant,
            address: hero.address,
            cuisine: hero.cuisine,
            bestDish: hero.heroDish
        )
        committedPick = CommittedPick.load()
    }

    private func clearPick() {
        CommittedPick.clear()
        committedPick = nil
    }

    // MARK: - Dismissed Restaurants

    private func dismissRestaurant(_ name: String) {
        dismissedNames.insert(name.lowercased())
        saveDismissed()
    }

    private func saveDismissed() {
        let arr = Array(dismissedNames)
        UserDefaults.standard.set(arr, forKey: Self.dismissedKey)
    }

    private func loadDismissed() {
        if let arr = UserDefaults.standard.stringArray(forKey: Self.dismissedKey) {
            dismissedNames = Set(arr)
        }
    }

    /// Open the hero's restaurant in Apple Maps.
    /// Uses a search query of "name city" so Maps finds the right place,
    /// falling back to just name if city can't be derived from meta.
    private func openInMaps(for hero: HeroCardData) {
        // Meta is formatted like "Cuisine · City" — take the last segment if it
        // isn't the cuisine. Safe fallback is just the restaurant name.
        let parts = hero.meta
            .components(separatedBy: "\u{00B7}")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let cityGuess = parts.count >= 2 ? parts.last : nil
        let query = [hero.restaurant, cityGuess]
            .compactMap { $0 }
            .joined(separator: " ")
        let encoded = query.addingPercentEncoding(
            withAllowedCharacters: .urlQueryAllowed
        ) ?? hero.restaurant
        if let url = URL(string: "maps://?q=\(encoded)") {
            openURL(url)
        }
    }

    /// Returns true if `s` starts with "New to you" (case-insensitive). Used
    /// to suppress the per-card "New to you" secondary line once the section
    /// subhead already carries that framing.
    private func isNewToYouPhrase(_ s: String) -> Bool {
        s.lowercased().hasPrefix("new to you")
    }

    // =========================================================================
    // MARK: - Detail Sheet
    // =========================================================================

    private func testDetailSheet(_ hero: HeroCardData) -> some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(hero.restaurant)
                        .font(.system(size: 26, weight: .heavy))
                        .tracking(-0.5)
                        .foregroundStyle(Self.lightText)
                        .padding(.bottom, 3)

                    Text(hero.meta)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Self.dimGray)
                        .padding(.bottom, 24)

                    if !hero.heroDish.isEmpty {
                        Text(hero.heroDish)
                            .font(.system(size: 22, weight: .heavy))
                            .foregroundStyle(Self.warmAccent)
                            .padding(.bottom, 8)
                    }

                    ForEach(hero.supportingDishes, id: \.self) { dish in
                        Text(dish)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color(hex: "B0B0B4"))
                            .padding(.bottom, 3)
                    }

                    // Per-friend breakdown
                    if !hero.friendSummaries.isEmpty {
                        friendBreakdownSection(hero.friendSummaries)
                            .padding(.top, 22)
                    } else if let social = hero.socialProof {
                        // Fallback for solo picks with no friend data
                        Text(social)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Self.warmAccent)
                            .padding(.top, 18)
                    }

                    if let changed = hero.changedConfidence {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Self.warmAccent)
                                .frame(width: 5, height: 5)
                            Text(changed)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color(hex: "B0B0B4"))
                        }
                        .padding(.top, hero.friendSummaries.isEmpty ? 18 : 10)
                        .padding(.bottom, 36)
                    } else {
                        Spacer().frame(height: 36)
                    }

                    detailCTAs(hero: hero)
                }
                .padding(24)
                .padding(.top, 12)
            }
            .background(Color.fbBg)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { selectedHero = nil } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Self.dimGray)
                    }
                }
            }
        }
    }

    // MARK: - Friend Breakdown (Detail Sheet)

    private func friendBreakdownSection(_ summaries: [FriendVisitSummary]) -> some View {
        let headerText: String = {
            if summaries.count >= 3 {
                return "\(summaries.count) FROM YOUR TABLE"
            }
            return "FROM YOUR TABLE"
        }()

        return VStack(alignment: .leading, spacing: 14) {
            Text(headerText)
                .font(.system(size: 11, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(Self.mutedGray)
                .padding(.bottom, 2)

            ForEach(summaries) { friend in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 0) {
                        Text(friend.name)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Self.lightText)

                        if friend.visitCount > 1 {
                            Text(" \u{00B7} \(friend.visitCount) visits")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Self.dimGray)
                        }

                        Spacer()

                        if !friend.recencyLabel.isEmpty {
                            Text(friend.recencyLabel)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Self.dimGray)
                        }
                    }

                    if !friend.likedDishes.isEmpty {
                        let dishText = friend.likedDishes.count <= 2
                            ? friend.likedDishes.joined(separator: ", ")
                            : friend.likedDishes.prefix(2).joined(separator: ", ")
                                + " +\(friend.likedDishes.count - 2) more"
                        Text("Liked: \(dishText)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Self.warmAccent.opacity(0.85))
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                )
            }
        }
    }

    private func detailCTAs(hero: HeroCardData) -> some View {
        VStack(spacing: 10) {
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                commitPick(from: hero)
                dismissRestaurant(hero.restaurant)
                selectedHero = nil
                // Give clear feedback: the place is noted, and we'll
                // follow up after the visit to ask how it went.
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
            .buttonStyle(HomeCardPressStyle())

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                dismissRestaurant(hero.restaurant)
                prefillLog(for: hero)
                selectedHero = nil
                // Wait for hero sheet dismiss animation to fully complete
                // before presenting the add-place sheet, otherwise SwiftUI
                // silently drops the second presentation.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
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
            .buttonStyle(HomeCardPressStyle())

            Button {
                // Actually save to the user's store so it appears in My Places
                store.addQuick(
                    name: hero.restaurant,
                    address: hero.address,
                    category: .saved
                )
                dismissRestaurant(hero.restaurant)
                selectedHero = nil
            } label: {
                Text("Save for later")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Self.dimGray)
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
        }
    }

    // =========================================================================
    // MARK: - Copy Variant Logic
    // =========================================================================

    enum TrustType {
        case names, count, recency, confidence
    }

    static func selectTrustType(
        names: [String],
        totalCount: Int,
        freshestDaysAgo: Int?
    ) -> TrustType {
        if totalCount >= 3 { return .count }
        if names.count >= 1 && names.count <= 2 { return .names }
        if let days = freshestDaysAgo, days <= 7 { return .recency }
        return .confidence
    }

    // =========================================================================
    // MARK: - Data Loading
    // =========================================================================

    private func loadTableData() async {
        let circles = await firestoreService.getMyCircles()
        guard let circle = circles.first else {
            // No circle yet — in DEBUG seed mock data so the hero has table signal.
            // In Release (TestFlight/App Store) leave empty so real users start clean.
            #if DEBUG
            self.tableMembers = MockTableData.buildMembers()
            self.tableRestaurants = MockTableData.buildSharedRestaurants()
            self.usingMockData = true
            #endif
            return
        }

        // Fetch members and restaurants in parallel.
        async let membersFetch = firestoreService.getCircleMembers(circle: circle)
        async let restaurantsFetch = firestoreService.getCircleRestaurants(circleId: circle.id)
        let members = await membersFetch
        var restaurants = await restaurantsFetch

        // Also import user's own Firestore entries using already-fetched data
        // (avoids a duplicate getMyCircles + getCircleRestaurants round trip).
        await store.importFromFirestore(prefetchedRestaurants: restaurants)

        let memberMap = Dictionary(uniqueKeysWithValues: members.map { ($0.uid, $0.displayName) })
        for i in restaurants.indices {
            restaurants[i].userName = memberMap[restaurants[i].userId] ?? "Friend"
        }

        // Mock data fallback when the user's circle has no friend entries.
        // In Release (TestFlight/App Store) leave empty so real users start clean.
        #if DEBUG
        let realFriends = restaurants.filter { $0.userId != currentUid }
        if realFriends.isEmpty {
            self.tableMembers = members + MockTableData.buildMembers()
            self.tableRestaurants = restaurants + MockTableData.buildSharedRestaurants()
            self.usingMockData = true
        } else {
            self.tableMembers = members
            self.tableRestaurants = restaurants
            self.usingMockData = false
        }
        #else
        self.tableMembers = members
        self.tableRestaurants = restaurants
        self.usingMockData = false
        #endif
    }

    // =========================================================================
    // MARK: - Scoring + Candidate Assembly
    // =========================================================================

    /// Named candidate — a restaurant aggregated across table members + user.
    private struct ScoredCandidate {
        let name: String
        let cuisine: CuisineType
        let address: String
        let latitude: Double?
        let longitude: Double?
        let topDish: String?
        let supportingDishes: [String]
        let memberNames: [String]
        let totalTableVisits: Int
        let topDishCount: Int
        let isRepeat: Bool
        let userHasVisited: Bool
        let userIsGoTo: Bool
        let userLoved: Bool
        let freshestDaysAgo: Int?
        let recentEntryCount: Int      // entries in last 14d
        let changedConfidence: String? // why this moved up
        let occasionScores: [OccasionTag: Double]
        let score: Int
    }

    /// Build all candidates, scored and sorted descending.
    private var rankedCandidates: [ScoredCandidate] {
        let myRestaurants = store.restaurants
        let friendEntries = tableRestaurants.filter { $0.userId != currentUid }

        // Group table entries by name (case-insensitive)
        let byName = Dictionary(grouping: friendEntries, by: { $0.name.lowercased() })

        // Also pick up user-only places (visited, loved/liked, no table match) — solo heroes
        let myVisited = myRestaurants.filter { $0.category == .visited }
        let namedFromTable = Set(byName.keys)

        var out: [ScoredCandidate] = []

        // Table-signal candidates
        for (key, entries) in byName {
            guard let ref = entries.first else { continue }
            let myEntry = myRestaurants.first { $0.name.lowercased() == key }

            // Aggregate liked dishes across all table members
            let allLikedDishes = entries.flatMap { $0.likedDishes }
            let dishCounts = Dictionary(grouping: allLikedDishes, by: { $0.name })
                .mapValues { $0.count }
                .sorted { $0.value > $1.value }
            let topDish = dishCounts.first?.key
            let topDishCount = dishCounts.first?.value ?? 0
            let supporting = dishCounts.dropFirst().prefix(2).map(\.key)

            let names = Array(Set(entries.map {
                $0.userName.components(separatedBy: " ").first ?? $0.userName
            })).sorted()

            let totalVisits = entries.reduce(0) { $0 + max(1, $1.visitCount) }
            let isRepeat = entries.contains { $0.visitCount > 1 }

            // Freshest visit
            let now = Date()
            let freshestDays: Int? = entries
                .compactMap { $0.dateVisited }
                .map { Calendar.current.dateComponents([.day], from: $0, to: now).day ?? 999 }
                .min()

            // Recent-window analysis (last 14d)
            let recentEntries = entries.filter { r in
                guard let d = r.dateVisited else { return false }
                let days = Calendar.current.dateComponents([.day], from: d, to: now).day ?? 999
                return days <= 14
            }
            let recentCount = recentEntries.count

            let isDiscovery = myEntry == nil   // user hasn't been here

            var score = 0
            score += names.count * 10
            score += totalVisits * 5
            score += topDishCount * 8
            if isRepeat { score += 15 }
            if myEntry != nil { score += 5 }
            if myEntry?.reaction == .loved { score += 10 }
            if myEntry?.isGoTo == true { score += 8 }
            if isDiscovery { score += 12 }        // discovery bonus — surface new-to-you places
            if let d = freshestDays, d <= 7 { score += 10 }
            score += recentCount * 4

            // Changed-confidence string — explain what's new
            let changed: String? = {
                if isDiscovery && names.count >= 2 {
                    return "New to you · \(names.count) friends love it"
                }
                if isDiscovery && names.count == 1 {
                    return "New to you · \(names[0]) loves it"
                }
                if recentCount >= 2 && names.count >= 2 {
                    return "+\(recentCount) logs this week"
                }
                if let d = freshestDays, d <= 7, isRepeat {
                    return "Back here this week"
                }
                if let d = freshestDays, d <= 7, names.count == 1 {
                    return "\(names[0]) just logged this"
                }
                if topDishCount >= 3, let dish = topDish {
                    return "\(dish) endorsed by \(topDishCount)"
                }
                if let d = freshestDays, d <= 14, recentCount >= 2 {
                    return "\(recentCount) fresh logs"
                }
                return nil
            }()

            // Combined dish-name corpus for classification: circle liked
            // dishes + user's own liked dishes if we have an entry.
            var dishNames = allLikedDishes.map { $0.name }
            if let mine = myEntry { dishNames.append(contentsOf: mine.likedDishes.map { $0.name }) }
            let occ = OccasionClassifier.classify(
                cuisine: ref.cuisine,
                dishNames: dishNames,
                visitCount: max(totalVisits, myEntry?.visitCount ?? 0),
                reaction: myEntry?.reaction,
                isGoTo: myEntry?.isGoTo ?? false
            )

            // Prefer coordinates from any entry that has them.
            let coordEntry = entries.first(where: { $0.hasCoordinates }) ?? ref
            out.append(ScoredCandidate(
                name: ref.name,
                cuisine: ref.cuisine,
                address: ref.address,
                latitude: coordEntry.latitude,
                longitude: coordEntry.longitude,
                topDish: topDish,
                supportingDishes: Array(supporting),
                memberNames: names,
                totalTableVisits: totalVisits,
                topDishCount: topDishCount,
                isRepeat: isRepeat,
                userHasVisited: myEntry != nil,
                userIsGoTo: myEntry?.isGoTo ?? false,
                userLoved: myEntry?.reaction == .loved,
                freshestDaysAgo: freshestDays,
                recentEntryCount: recentCount,
                changedConfidence: changed,
                occasionScores: occ,
                score: score
            ))
        }

        // Solo user candidates (no table signal yet)
        // Skip when using mock data — personal log may contain non-veg / irrelevant entries.
        guard !usingMockData else {
            return out
                .filter { !dismissedNames.contains($0.name.lowercased()) }
                .sorted { $0.score > $1.score }
        }
        for r in myVisited {
            if namedFromTable.contains(r.name.lowercased()) { continue }
            // Only surface strong solo picks
            let isStrong = r.isGoTo || r.reaction == .loved ||
                (r.reaction == .liked && r.visitCount >= 2)
            guard isStrong else { continue }

            var score = 0
            if r.isGoTo { score += 25 }
            if r.reaction == .loved { score += 18 }
            if r.reaction == .liked { score += 8 }
            score += min(r.visitCount, 5) * 3
            if let d = r.dateVisited {
                let days = Calendar.current.dateComponents([.day], from: d, to: Date()).day ?? 999
                if days <= 7 { score += 6 }
            }

            let topDish = r.leadDish?.name
            let supporting = Array(r.likedDishes.dropFirst().prefix(2).map(\.name))

            let freshDays = r.dateVisited.map {
                Calendar.current.dateComponents([.day], from: $0, to: Date()).day ?? 999
            }
            let soloChanged: String? = {
                if let d = freshDays, d <= 7 {
                    if r.isGoTo { return "You keep coming back, logged this week" }
                    if r.reaction == .loved { return "You loved this recently" }
                    if r.visitCount >= 2 { return "You came back this week" }
                    return "Fresh in your log"
                }
                return nil
            }()

            let occ = OccasionClassifier.classify(
                cuisine: r.cuisine,
                dishNames: r.likedDishes.map { $0.name },
                visitCount: r.visitCount,
                reaction: r.reaction,
                isGoTo: r.isGoTo
            )

            out.append(ScoredCandidate(
                name: r.name,
                cuisine: r.cuisine,
                address: r.address,
                latitude: r.latitude,
                longitude: r.longitude,
                topDish: topDish,
                supportingDishes: supporting,
                memberNames: [],
                totalTableVisits: 0,
                topDishCount: 0,
                isRepeat: r.visitCount >= 2,
                userHasVisited: true,
                userIsGoTo: r.isGoTo,
                userLoved: r.reaction == .loved,
                freshestDaysAgo: freshDays,
                recentEntryCount: 0,
                changedConfidence: soloChanged,
                occasionScores: occ,
                score: score
            ))
        }

        return out
            .filter { !dismissedNames.contains($0.name.lowercased()) }
            .sorted { $0.score > $1.score }
    }

    /// Candidates filtered + re-ranked for the currently-selected occasion chip.
    /// When no chip is selected, returns `rankedCandidates` unchanged.
    private var candidatesForActiveOccasion: [ScoredCandidate] {
        let all = rankedCandidates
        guard let tag = selectedOccasion else { return all }
        let threshold = OccasionClassifier.assignmentThreshold

        let filtered = all
            .compactMap { c -> (ScoredCandidate, Int)? in
                let occ = c.occasionScores[tag] ?? 0
                guard occ >= threshold else { return nil }
                // Boost score by occasion-fit so the best-fit card rises to top.
                let boost = Int((occ - threshold) * 60) // 0 .. ~33 pts
                return (c, c.score + boost)
            }
            .sorted { $0.1 > $1.1 }
            .map { $0.0 }

        // Fallback: if no restaurants match the chip, show all candidates
        // rather than a blank screen. The hero eyebrow will still note
        // the chip context so the user knows filtering was attempted.
        return filtered.isEmpty ? all : filtered
    }

    /// Top 1 (or 2) as heroes, rest as backups.
    /// When an occasion chip is active, source comes from the filtered list so
    /// heroes and backups both honor the chip selection.
    private var heroCards: [HeroCardData] {
        let candidates = candidatesForActiveOccasion
        guard !candidates.isEmpty else { return [] }
        return Array(candidates.prefix(1)).map { buildHero(from: $0) }
    }

    private var backupCards: [BackupCardData] {
        let candidates = candidatesForActiveOccasion
        guard candidates.count > 1 else { return [] }
        return Array(candidates.dropFirst().prefix(12)).map { buildBackup(from: $0) }
    }

    // MARK: Candidate → Card

    private func buildHero(from c: ScoredCandidate) -> HeroCardData {
        let dist = distanceText(lat: c.latitude, lng: c.longitude)
        // Meta is rendered on the card as the subtitle line under the name.
        // Distance now lives in its own slot on the name row, so meta becomes
        // "Cuisine · City" — purely categorical context.
        let where_ = locationLabel(lat: c.latitude, lng: c.longitude, address: c.address)
        let metaParts: [String] = {
            var p: [String] = []
            if c.cuisine != .other { p.append(c.cuisine.rawValue) }
            if !where_.isEmpty { p.append(where_) }
            return p
        }()
        let meta = metaParts.joined(separator: " \u{00B7} ")

        let recent = (c.freshestDaysAgo ?? Int.max) <= 7
        let dish = c.topDish ?? ""

        let eyebrow: String = {
            // When an occasion chip is active and we have any table signal,
            // lean on the simple "FROM YOUR TABLE" framing from the mock.
            if selectedOccasion != nil && c.memberNames.count >= 1 {
                return "FROM YOUR TABLE"
            }
            if c.memberNames.count >= 3 {
                return "YOUR TABLE\u{2019}S PICK FOR \(MealWindow.current.eyebrowFragment)"
            }
            if c.isRepeat && c.memberNames.count >= 1 {
                return "YOUR TABLE KEEPS ORDERING THIS"
            }
            if c.userIsGoTo { return "YOU ALWAYS GO BACK" }
            if c.userLoved && c.memberNames.isEmpty { return "YOU LOVED THIS PLACE" }
            if recent { return "FRESH FROM YOUR TABLE" }
            return "STRONG PICK"
        }()

        let trustLine = buildTrustLine(
            names: c.memberNames,
            visits: c.totalTableVisits,
            userSignal: userSignalText(c)
        )

        // Social-proof line: "N people from your table got this"
        // Prefer top-dish endorsement count; fall back to member count.
        let socialProof: String? = {
            if c.topDishCount >= 2 {
                return "\(c.topDishCount) people from your table got this"
            }
            if c.memberNames.count >= 2 {
                return "\(c.memberNames.count) people from your table loved it"
            }
            return nil
        }()

        // Category-aware changed-confidence: when a chip is active, the hero
        // is the top match for that category — say so explicitly.
        let changed: String? = {
            if let tag = selectedOccasion {
                return "Strongest \(tag.contextualPhrase) signal right now"
            }
            return c.changedConfidence
        }()

        // Build per-friend visit summaries from raw table entries.
        let now = Date()
        let friendEntries = tableRestaurants.filter { $0.userId != currentUid }
        let entriesForPlace = friendEntries.filter { $0.name.lowercased() == c.name.lowercased() }
        // Group by user to collapse multiple entries per friend.
        let byUser = Dictionary(grouping: entriesForPlace, by: { $0.userId })
        let summaries: [FriendVisitSummary] = byUser.values.compactMap { entries in
            guard let first = entries.first else { return nil }
            let name = first.userName.components(separatedBy: " ").first ?? first.userName
            let totalVisits = entries.reduce(0) { $0 + max(1, $1.visitCount) }
            let dishes = Array(Set(entries.flatMap { $0.likedDishes.map(\.name) }))
            let freshestDays: Int? = entries
                .compactMap { $0.dateVisited }
                .map { Calendar.current.dateComponents([.day], from: $0, to: now).day ?? 999 }
                .min()
            return FriendVisitSummary(
                name: name,
                visitCount: totalVisits,
                likedDishes: dishes,
                daysAgo: freshestDays
            )
        }.sorted { ($0.daysAgo ?? 999) < ($1.daysAgo ?? 999) }

        return HeroCardData(
            eyebrow: eyebrow,
            restaurant: c.name,
            meta: meta,
            heroDish: dish,
            supportingDishes: c.supportingDishes,
            trustLine: trustLine,
            socialProof: socialProof,
            changedConfidence: changed,
            friendSummaries: summaries,
            distanceText: dist,
            address: c.address,
            cuisine: c.cuisine
        )
    }

    private func buildBackup(from c: ScoredCandidate) -> BackupCardData {
        let dist = distanceText(lat: c.latitude, lng: c.longitude)
        // Meta is "Cuisine · City" — distance now lives in its own slot on
        // the name row (mirrors hero card layout).
        let where_ = locationLabel(lat: c.latitude, lng: c.longitude, address: c.address)
        let metaParts: [String] = {
            var p: [String] = []
            if c.cuisine != .other { p.append(c.cuisine.rawValue) }
            if !where_.isEmpty { p.append(where_) }
            return p
        }()
        let meta = metaParts.joined(separator: " \u{00B7} ")

        let trustLine = buildTrustLine(
            names: c.memberNames,
            visits: c.totalTableVisits,
            userSignal: userSignalText(c)
        )

        // Build per-friend visit summaries (same logic as buildHero).
        let now = Date()
        let friendEntries = tableRestaurants.filter { $0.userId != currentUid }
        let entriesForPlace = friendEntries.filter { $0.name.lowercased() == c.name.lowercased() }
        let byUser = Dictionary(grouping: entriesForPlace, by: { $0.userId })
        let summaries: [FriendVisitSummary] = byUser.values.compactMap { entries in
            guard let first = entries.first else { return nil }
            let name = first.userName.components(separatedBy: " ").first ?? first.userName
            let totalVisits = entries.reduce(0) { $0 + max(1, $1.visitCount) }
            let dishes = Array(Set(entries.flatMap { $0.likedDishes.map(\.name) }))
            let freshestDays: Int? = entries
                .compactMap { $0.dateVisited }
                .map { Calendar.current.dateComponents([.day], from: $0, to: now).day ?? 999 }
                .min()
            return FriendVisitSummary(name: name, visitCount: totalVisits, likedDishes: dishes, daysAgo: freshestDays)
        }.sorted { ($0.daysAgo ?? 999) < ($1.daysAgo ?? 999) }

        return BackupCardData(
            restaurant: c.name,
            meta: meta,
            heroDish: c.topDish ?? "",
            supportingDishes: c.supportingDishes,
            trustLine: trustLine,
            socialProof: nil,      // kept off backups — hero carries the warm line
            changedConfidence: c.changedConfidence,
            friendSummaries: summaries,
            distanceText: dist,
            address: c.address,
            cuisine: c.cuisine
        )
    }

    private func userSignalText(_ c: ScoredCandidate) -> String? {
        if c.userIsGoTo { return "You always go back" }
        if c.userLoved { return "You loved it" }
        if c.userHasVisited { return "You\u{2019}ve been" }
        return nil
    }

    /// Social-proof line under the dishes: "Picked by X from your table" /
    /// "Picked by A & B" / "Picked by A". Visits are counted in the scoring
    /// step but the display collapses to unique names here — "picked by 4
    /// people" reads cleaner than "7 visits."
    private func buildTrustLine(names: [String], visits: Int, userSignal: String?) -> String {
        _ = visits   // retained in signature for call-site stability
        if names.count >= 3 {
            return "Picked by \(names.count) from your table"
        }
        if names.count == 2 {
            return "Picked by \(names[0]) & \(names[1])"
        }
        if let name = names.first {
            return "Picked by \(name)"
        }
        if let u = userSignal { return u }
        return "Worth exploring"
    }

    private func distanceText(lat: Double?, lng: Double?) -> String? {
        guard let lat, let lng,
              let miles = locationManager.distanceMiles(to: lat, lng: lng)
        else { return nil }
        return LocationManager.formatDistance(miles)
    }

    /// Representative centers for major SF neighborhoods, used by
    /// `sfNeighborhood(lat:lng:)` via nearest-center lookup. Not a polygon
    /// map — it's intentionally approximate; a point near the edge of two
    /// neighborhoods may fall either way. Good enough for the card meta.
    private static let sfNeighborhoods: [(name: String, lat: Double, lng: Double)] = [
        ("Marina",             37.8037, -122.4368),
        ("Pacific Heights",    37.7927, -122.4362),
        ("Presidio Heights",   37.7877, -122.4520),
        ("Russian Hill",       37.8018, -122.4180),
        ("Nob Hill",           37.7930, -122.4161),
        ("North Beach",        37.8060, -122.4103),
        ("Chinatown",          37.7941, -122.4078),
        ("Financial District", 37.7946, -122.3996),
        ("Union Square",       37.7880, -122.4075),
        ("Tenderloin",         37.7845, -122.4130),
        ("Fillmore",           37.7843, -122.4324),
        ("Japantown",          37.7848, -122.4296),
        ("Hayes Valley",       37.7759, -122.4245),
        ("Lower Haight",       37.7719, -122.4320),
        ("Haight-Ashbury",     37.7699, -122.4469),
        ("Cole Valley",        37.7653, -122.4509),
        ("Castro",             37.7609, -122.4350),
        ("Noe Valley",         37.7505, -122.4333),
        ("Mission",            37.7599, -122.4148),
        ("SoMa",               37.7790, -122.4050),
        ("Mission Bay",        37.7706, -122.3895),
        ("Potrero Hill",       37.7600, -122.4000),
        ("Dogpatch",           37.7570, -122.3890),
        ("Bernal Heights",     37.7396, -122.4147),
        ("Inner Sunset",       37.7640, -122.4665),
        ("Outer Sunset",       37.7550, -122.4950),
        ("Inner Richmond",     37.7796, -122.4648),
        ("Outer Richmond",     37.7795, -122.4900),
    ]

    /// Returns the closest SF neighborhood name for the given point, or nil
    /// if the point is outside the rough SF bounding box. Uses squared
    /// lat/lng distance — fine for a coarse nearest-neighbor at this scale.
    private static func sfNeighborhood(lat: Double, lng: Double) -> String? {
        // Rough SF bounding box — skip lookup for points obviously elsewhere.
        guard lat >= 37.70, lat <= 37.83,
              lng >= -122.52, lng <= -122.36 else { return nil }
        let nearest = sfNeighborhoods.min { a, b in
            let da = (a.lat - lat) * (a.lat - lat) + (a.lng - lng) * (a.lng - lng)
            let db = (b.lat - lat) * (b.lat - lat) + (b.lng - lng) * (b.lng - lng)
            return da < db
        }
        return nearest?.name
    }

    /// Prefer the SF neighborhood name when coordinates are available and
    /// fall inside the city; otherwise use the broader city string parsed
    /// from the address. The meta line should feel local ("Mission") when
    /// we can, and stay correct ("Oakland", "Austin") when we can't.
    private func locationLabel(lat: Double?, lng: Double?, address: String) -> String {
        if let lat, let lng,
           let hood = Self.sfNeighborhood(lat: lat, lng: lng) {
            return hood
        }
        return cityString(from: address)
    }

    /// Extracts just the city from a free-form address. Handles the common
    /// mock-data shape "Street, City" (2 parts), the fuller "Street, City,
    /// State Zip" (3+ parts), and bare "City" (1 part). If the first comma
    /// segment looks like a street (starts with a digit, or ends in a known
    /// street suffix), the city is the next segment; otherwise the first
    /// segment already *is* the city.
    private func cityString(from address: String) -> String {
        let parts = address
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard !parts.isEmpty else { return "" }

        let streetSuffixes: Set<String> = [
            "st", "st.", "street", "ave", "ave.", "avenue", "blvd", "blvd.",
            "rd", "rd.", "road", "way", "ln", "lane", "dr", "dr.", "drive",
            "pl", "ct", "pkwy", "parkway", "hwy", "highway", "sq", "square",
            "ter", "terrace"
        ]
        func looksLikeStreet(_ s: String) -> Bool {
            if let first = s.first, first.isNumber { return true }
            let lastWord = (s.components(separatedBy: .whitespaces).last ?? "")
                .lowercased()
            return streetSuffixes.contains(lastWord)
        }

        if parts.count >= 2, looksLikeStreet(parts[0]) {
            return parts[1]
        }
        return parts[0]
    }
}

// =========================================================================
// MARK: - Data Models
// =========================================================================

/// Per-friend visit detail for the detail sheet.
struct FriendVisitSummary: Identifiable {
    let id = UUID()
    let name: String               // "Pragya"
    let visitCount: Int
    let likedDishes: [String]      // dishes they liked
    let daysAgo: Int?              // days since their most recent visit
    var recencyLabel: String {
        guard let d = daysAgo else { return "" }
        if d == 0 { return "today" }
        if d == 1 { return "yesterday" }
        if d < 7 { return "\(d) days ago" }
        if d < 14 { return "last week" }
        if d < 30 { return "\(d / 7) weeks ago" }
        if d < 60 { return "last month" }
        return "\(d / 30) months ago"
    }
}

struct HeroCardData: Identifiable {
    let id = UUID()
    let eyebrow: String
    let restaurant: String
    let meta: String
    let heroDish: String
    let supportingDishes: [String]
    let trustLine: String
    let socialProof: String?
    let changedConfidence: String?
    let friendSummaries: [FriendVisitSummary]
    let distanceText: String?

    // Needed for CommittedPick persistence — not rendered directly on the card.
    var address: String = ""
    var cuisine: CuisineType = .other
}

struct BackupCardData: Identifiable {
    let id = UUID()
    let restaurant: String
    let meta: String
    let heroDish: String
    let supportingDishes: [String]
    let trustLine: String
    let socialProof: String?
    let changedConfidence: String?
    let friendSummaries: [FriendVisitSummary]
    let distanceText: String?

    var address: String = ""
    var cuisine: CuisineType = .other
}

// =========================================================================
// MARK: - Press Style
// =========================================================================

private struct HomeCardPressStyle: ButtonStyle {
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
    HomeTestView()
        .environmentObject(RestaurantStore())
        .preferredColorScheme(.dark)
}
