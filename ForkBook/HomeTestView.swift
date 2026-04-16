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
    private let firestoreService = FirestoreService.shared

    // -- Design tokens --
    private static let cardBg = Color(hex: "131517")
    private static let cardHero = Color(hex: "171A1D")
    private static let warmAccent = Color(hex: "C4A882")
    private static let mutedGray = Color(hex: "8E8E93")
    private static let dimGray = Color(hex: "6B6B70")
    private static let lightText = Color(hex: "F5F5F7")

    private var currentUid: String? { Auth.auth().currentUser?.uid }

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

                    // Committed pick — "Did you go?" card sits above the hero.
                    if let pick = committedPick, pick.hoursAgo < 24 * 7 {
                        committedPickCard(pick)
                            .padding(.horizontal, 16)
                            .padding(.top, 18)
                    }

                    if !heroes.isEmpty {
                        // When committed pick is active, show fresh picks
                        // under a lighter label so they don't compete.
                        if committedPick != nil {
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
                            .padding(.top, committedPick != nil ? 0 : 18)
                    } else if committedPick == nil {
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
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selectedHero) { hero in
                testDetailSheet(hero)
            }
            .sheet(isPresented: $showAddPlace) {
                AddPlaceTestFlow(
                    prefillName: logPrefillName.isEmpty ? nil : logPrefillName,
                    prefillAddress: logPrefillAddress.isEmpty ? nil : logPrefillAddress,
                    prefillCuisine: logPrefillCuisine
                )
                .environmentObject(store)
            }
            .navigationDestination(isPresented: $showProfile) {
                ProfileView()
                    .environmentObject(store)
            }
        }
        .task {
            guard !hasLoaded else { return }
            hasLoaded = true
            committedPick = CommittedPick.load()
            await loadTableData()
        }
    }

    // =========================================================================
    // MARK: - Header + Empty State
    // =========================================================================

    private var homeHeader: some View {
        HStack(alignment: .top) {
            Text("Tonight")
                .font(.system(size: 26, weight: .heavy))
                .tracking(-0.5)
                .foregroundColor(Color.fbText)
            Spacer()
            Button { showProfile = true } label: {
                RingedAvatarView(
                    name: Auth.auth().currentUser?.displayName ?? "User",
                    size: 32,
                    photoData: ProfilePhotoStore.shared.load(),
                    showRing: true
                )
            }
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
                    Text("\u{00B7} Saved just now")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Self.mutedGray)
                } else if pick.hoursAgo < 24 {
                    Text("\u{00B7} Saved \(Int(pick.hoursAgo))h ago")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Self.mutedGray)
                } else {
                    let days = Int(pick.hoursAgo / 24)
                    Text("\u{00B7} Saved \(days)d ago")
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

            // Prompt
            Text("Did you end up going?")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color(hex: "B0B0B4"))
                .padding(.bottom, 16)

            // CTAs
            VStack(spacing: 10) {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    logPrefillName = pick.name
                    logPrefillAddress = pick.address
                    logPrefillCuisine = pick.cuisine
                    clearPick()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
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
                        .fill(active ? Self.warmAccent.opacity(0.10)
                                     : Color.white.opacity(0.03))
                )
                .overlay(
                    Capsule()
                        .stroke(
                            active ? Self.warmAccent.opacity(0.40)
                                   : Color.white.opacity(0.06),
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
        return "OTHER STRONG OPTIONS"
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
                return "Log a few places or invite your circle \u{2014} ForkBook gets sharper with every entry."
            }
            if !hasOwnPlaces {
                return "Your circle has logs, but we need yours too. Add a place you\u{2019}ve been."
            }
            if !hasTableFriends {
                return "Picks get much stronger with a few trusted friends logging too."
            }
            if !hasTableSignal {
                return "Your circle hasn\u{2019}t logged anything recent. Nudge them to share what they\u{2019}ve been eating."
            }
            return "Log a few places you\u{2019}ve been and ForkBook will start surfacing what to get tonight."
        }()

        let ctaLabel = hasOwnPlaces && !hasTableFriends ? "Add a place anyway" : "Add a place"

        return VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.fbText)
            Text(body)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(hex: "B0B0B4").opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)
            Button {
                showAddPlace = true
            } label: {
                Text(ctaLabel)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.fbText)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Self.warmAccent.opacity(0.18)))
                    .overlay(Capsule().stroke(Self.warmAccent.opacity(0.35), lineWidth: 1))
            }
            .padding(.top, 6)
            .buttonStyle(HomeCardPressStyle())
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
        let cardContent = VStack(alignment: .leading, spacing: 0) {
            Text(hero.eyebrow)
                .font(.system(size: 11, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(Self.mutedGray)
                .padding(.bottom, 10)

            Text(hero.restaurant)
                .font(.system(size: 28, weight: .heavy))
                .tracking(-0.6)
                .foregroundStyle(Self.lightText)
                .padding(.bottom, 3)

            Text(hero.meta)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Self.dimGray)
                .padding(.bottom, 20)

            Text(hero.directive)
                .font(.system(size: 22, weight: .heavy))
                .tracking(-0.3)
                .foregroundStyle(Self.lightText)
                .padding(.bottom, 10)

            if !hero.supportingDishes.isEmpty {
                Text(hero.supportingDishes.joined(separator: " \u{00B7} "))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(hex: "B0B0B4"))
                    .padding(.bottom, hero.socialProof == nil ? 16 : 10)
            }

            if let social = hero.socialProof {
                Text(social)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Self.warmAccent)
                    .padding(.bottom, 14)
            }

            Text(hero.trustLine)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Self.warmAccent.opacity(0.85))
                .padding(.bottom, hero.changedConfidence == nil ? 22 : 10)

            if let changed = hero.changedConfidence {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Self.warmAccent)
                        .frame(width: 6, height: 6)
                    Text(changed)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(hex: "B0B0B4"))
                }
                .padding(.bottom, 22)
            }

            HStack {
                Spacer()
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    selectedHero = hero
                } label: {
                    Text("Go here \u{2192}")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.fbText)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 11)
                        .background(Color.white.opacity(0.10))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.14), lineWidth: 1))
                        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(HomeCardPressStyle())
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
                selectedHero = hero
            }
    }

    // =========================================================================
    // MARK: - Backup Card
    // =========================================================================

    private func backupCard(_ backup: BackupCardData) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(backup.restaurant)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.fbText)
                Spacer()
                if let time = extractTime(from: backup.meta) {
                    Text(time)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Self.dimGray)
                }
            }
            .padding(.bottom, 4)

            Text(backup.directive)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Self.warmAccent)
                .padding(.bottom, 5)

            Text(backup.trustLine)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color(hex: "B0B0B4").opacity(0.92))
                .lineLimit(1)

            if let changed = backup.changedConfidence {
                Text(changed)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Self.warmAccent.opacity(0.85))
                    .padding(.top, 3)
                    .lineLimit(1)
            }
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
                directive: backup.directive,
                heroDish: backup.heroDish,
                supportingDishes: backup.supportingDishes,
                trustLine: backup.trustLine,
                socialProof: backup.socialProof,
                changedConfidence: backup.changedConfidence,
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

    private func extractDish(from directive: String) -> String {
        let prefixes = ["Get the ", "Order the ", "Go for the ",
                        "Don\u{2019}t skip the ", "Have to try the ",
                        "If you go, get the "]
        for prefix in prefixes {
            if directive.hasPrefix(prefix) {
                return String(directive.dropFirst(prefix.count))
            }
        }
        return directive
    }

    private func extractTime(from meta: String) -> String? {
        let parts = meta
            .components(separatedBy: "\u{00B7}")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        return parts.first(where: { $0.contains("min") || $0.contains("hr") })
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
                        .padding(.bottom, 28)

                    Text(hero.directive)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(Color.fbText)
                        .padding(.bottom, 20)

                    Text(hero.heroDish)
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundStyle(Self.warmAccent)
                        .padding(.bottom, 8)

                    ForEach(hero.supportingDishes, id: \.self) { dish in
                        Text(dish)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color(hex: "B0B0B4"))
                            .padding(.bottom, 3)
                    }

                    if let social = hero.socialProof {
                        Text(social)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Self.warmAccent)
                            .padding(.top, 18)
                    }

                    Text(hero.trustLine)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Self.warmAccent.opacity(0.8))
                        .padding(.top, hero.socialProof == nil ? 18 : 8)
                        .padding(.bottom, hero.changedConfidence == nil ? 36 : 10)

                    if let changed = hero.changedConfidence {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Self.warmAccent)
                                .frame(width: 5, height: 5)
                            Text(changed)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color(hex: "B0B0B4"))
                        }
                        .padding(.bottom, 36)
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

    private func detailCTAs(hero: HeroCardData) -> some View {
        VStack(spacing: 10) {
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                commitPick(from: hero)
                selectedHero = nil
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
                prefillLog(for: hero)
                selectedHero = nil
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
            .buttonStyle(HomeCardPressStyle())

            Button {
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

    enum DirectiveTier {
        case standard
        case elevated
        case strongest
    }

    static func selectDirectiveTier(
        trustedCount: Int,
        repeatBehavior: Bool,
        dishDominance: Bool,
        recentSignal: Bool
    ) -> DirectiveTier {
        if (trustedCount >= 3 && recentSignal) || (dishDominance && trustedCount >= 3) {
            return .strongest
        }
        if trustedCount >= 3 || repeatBehavior || dishDominance {
            return .elevated
        }
        return .standard
    }

    static func buildDirective(tier: DirectiveTier, dish: String) -> String {
        switch tier {
        case .standard:
            let t = ["Get the \(dish)", "Order the \(dish)", "Go for the \(dish)"]
            return t[abs(dish.hashValue) % t.count]
        case .elevated:
            let t = ["Don\u{2019}t skip the \(dish)", "This is what to get here", "Go here for the \(dish)"]
            return t[abs(dish.hashValue) % t.count]
        case .strongest:
            let t = ["This is the move \u{2014} \(dish)", "Have to try the \(dish)", "If you go, get the \(dish)"]
            return t[abs(dish.hashValue) % t.count]
        }
    }

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
            // No circle yet — seed with mock data so the hero has table signal.
            self.tableMembers = MockTableData.buildMembers()
            self.tableRestaurants = MockTableData.buildSharedRestaurants()
            return
        }
        let members = await firestoreService.getCircleMembers(circle: circle)
        var restaurants = await firestoreService.getCircleRestaurants(circleId: circle.id)
        let memberMap = Dictionary(uniqueKeysWithValues: members.map { ($0.uid, $0.displayName) })
        for i in restaurants.indices {
            restaurants[i].userName = memberMap[restaurants[i].userId] ?? "Friend"
        }

        // Mock data fallback when the user's circle has no friend entries.
        let realFriends = restaurants.filter { $0.userId != currentUid }
        if realFriends.isEmpty {
            self.tableMembers = members + MockTableData.buildMembers()
            self.tableRestaurants = restaurants + MockTableData.buildSharedRestaurants()
        } else {
            self.tableMembers = members
            self.tableRestaurants = restaurants
        }
    }

    // =========================================================================
    // MARK: - Scoring + Candidate Assembly
    // =========================================================================

    /// Named candidate — a restaurant aggregated across table members + user.
    private struct ScoredCandidate {
        let name: String
        let cuisine: CuisineType
        let address: String
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

            var score = 0
            score += names.count * 10
            score += totalVisits * 5
            score += topDishCount * 8
            if isRepeat { score += 15 }
            if myEntry != nil { score += 5 }
            if myEntry?.reaction == .loved { score += 10 }
            if myEntry?.isGoTo == true { score += 8 }
            if let d = freshestDays, d <= 7 { score += 10 }
            score += recentCount * 4

            // Changed-confidence string — explain what's new
            let changed: String? = {
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

            out.append(ScoredCandidate(
                name: ref.name,
                cuisine: ref.cuisine,
                address: ref.address,
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

        return out.sorted { $0.score > $1.score }
    }

    /// Candidates filtered + re-ranked for the currently-selected occasion chip.
    /// When no chip is selected, returns `rankedCandidates` unchanged.
    private var candidatesForActiveOccasion: [ScoredCandidate] {
        let all = rankedCandidates
        guard let tag = selectedOccasion else { return all }
        let threshold = OccasionClassifier.assignmentThreshold

        return all
            .compactMap { c -> (ScoredCandidate, Int)? in
                let occ = c.occasionScores[tag] ?? 0
                guard occ >= threshold else { return nil }
                // Boost score by occasion-fit so the best-fit card rises to top.
                let boost = Int((occ - threshold) * 60) // 0 .. ~33 pts
                return (c, c.score + boost)
            }
            .sorted { $0.1 > $1.1 }
            .map { $0.0 }
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
        return Array(candidates.dropFirst().prefix(5)).map { buildBackup(from: $0) }
    }

    // MARK: Candidate → Card

    private func buildHero(from c: ScoredCandidate) -> HeroCardData {
        let metaParts: [String] = {
            var p: [String] = []
            if c.cuisine != .other { p.append(c.cuisine.rawValue) }
            let city = cityString(from: c.address)
            if !city.isEmpty { p.append(city) }
            return p
        }()
        let meta = metaParts.joined(separator: " \u{00B7} ")

        let dishDominance = c.topDishCount >= max(2, c.memberNames.count)
        let recent = (c.freshestDaysAgo ?? Int.max) <= 7
        let tier = Self.selectDirectiveTier(
            trustedCount: c.memberNames.count,
            repeatBehavior: c.isRepeat,
            dishDominance: dishDominance,
            recentSignal: recent
        )
        let dish = c.topDish ?? "what they get"
        let directive = c.topDish != nil
            ? Self.buildDirective(tier: tier, dish: dish)
            : (c.userLoved ? "You loved it here" : "Solid pick")

        let eyebrow: String = {
            // When an occasion chip is active and we have any table signal,
            // lean on the simple "FROM YOUR TABLE" framing from the mock.
            if selectedOccasion != nil && c.memberNames.count >= 1 {
                return "FROM YOUR TABLE"
            }
            if c.memberNames.count >= 3 {
                return "YOUR TABLE\u{2019}S PICK FOR TONIGHT"
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

        return HeroCardData(
            eyebrow: eyebrow,
            restaurant: c.name,
            meta: meta,
            directive: directive,
            heroDish: dish,
            supportingDishes: c.supportingDishes,
            trustLine: trustLine,
            socialProof: socialProof,
            changedConfidence: changed,
            address: c.address,
            cuisine: c.cuisine
        )
    }

    private func buildBackup(from c: ScoredCandidate) -> BackupCardData {
        let metaParts: [String] = {
            var p: [String] = []
            if c.cuisine != .other { p.append(c.cuisine.rawValue) }
            let city = cityString(from: c.address)
            if !city.isEmpty { p.append(city) }
            return p
        }()
        let meta = metaParts.joined(separator: " \u{00B7} ")

        let dishDominance = c.topDishCount >= max(2, c.memberNames.count)
        let recent = (c.freshestDaysAgo ?? Int.max) <= 7
        let tier = Self.selectDirectiveTier(
            trustedCount: c.memberNames.count,
            repeatBehavior: c.isRepeat,
            dishDominance: dishDominance,
            recentSignal: recent
        )
        let directive: String = {
            if let d = c.topDish { return Self.buildDirective(tier: tier, dish: d) }
            if c.userIsGoTo { return "You always go back" }
            if c.userLoved { return "You loved it" }
            return "Worth it"
        }()
        let trustLine = buildTrustLine(
            names: c.memberNames,
            visits: c.totalTableVisits,
            userSignal: userSignalText(c)
        )

        return BackupCardData(
            restaurant: c.name,
            meta: meta,
            directive: directive,
            heroDish: c.topDish ?? extractDish(from: directive),
            supportingDishes: c.supportingDishes,
            trustLine: trustLine,
            socialProof: nil,      // kept off backups — hero carries the warm line
            changedConfidence: c.changedConfidence,
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

    private func buildTrustLine(names: [String], visits: Int, userSignal: String?) -> String {
        // Prefer cross-table signal when present
        if visits >= 3 {
            return "\(visits) visits from your table"
        }
        if names.count >= 3 {
            return "\(names[0]), \(names[1]) & \(names.count - 2) more"
        }
        if names.count == 2 {
            return "\(names[0]) & \(names[1]) both order this"
        }
        if let name = names.first {
            return "\(name) from your table"
        }
        // Fall back to user signal
        if let u = userSignal { return u }
        return "Worth exploring"
    }

    private func cityString(from address: String) -> String {
        let parts = address
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard parts.count >= 2 else { return parts.first ?? "" }
        // "Street, City, State Zip[, Country]" → City
        if parts.count >= 3, let first = parts.first, first.first?.isNumber == true {
            return parts[1]
        }
        return parts.first ?? ""
    }
}

// =========================================================================
// MARK: - Data Models
// =========================================================================

struct HeroCardData: Identifiable {
    let id = UUID()
    let eyebrow: String
    let restaurant: String
    let meta: String
    let directive: String
    let heroDish: String
    let supportingDishes: [String]
    let trustLine: String
    let socialProof: String?
    let changedConfidence: String?

    // Needed for CommittedPick persistence — not rendered directly on the card.
    var address: String = ""
    var cuisine: CuisineType = .other
}

struct BackupCardData: Identifiable {
    let id = UUID()
    let restaurant: String
    let meta: String
    let directive: String
    let heroDish: String
    let supportingDishes: [String]
    let trustLine: String
    let socialProof: String?
    let changedConfidence: String?

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
