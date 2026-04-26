import SwiftUI
import FirebaseAuth

// MARK: - Table Test View (V5 — Activity list)
//
// Simple list of the people in your table, each row surfacing what
// they've been up to lately (most recent place / count of new spots /
// last visit). Tap a row → FriendProfileView sheet.
//
// Designed for 12–15 friends: compact ~60pt rows, no hero treatment,
// no trust-signature scoring. The goal is fast exploration, not
// decision-making.

struct TableTestView: View {
    @EnvironmentObject var store: RestaurantStore
    @State private var hasLoaded = false
    @State private var tableMembers: [FirestoreService.CircleMember] = []
    @State private var tableRestaurants: [SharedRestaurant] = []
    /// Set when the user taps a row — presents the FriendProfileView
    /// sheet. CircleMember is Identifiable by uid.
    @State private var selectedFriend: FirestoreService.CircleMember? = nil
    @ObservedObject private var firestoreService = FirestoreService.shared

    private var currentUid: String? { Auth.auth().currentUser?.uid }

    // Only friends (exclude self)
    private var friendEntries: [SharedRestaurant] {
        tableRestaurants.filter { $0.userId != currentUid }
    }

    private var friends: [FirestoreService.CircleMember] {
        tableMembers.filter { $0.uid != currentUid }
    }

    // MARK: Body

    var body: some View {
        ZStack {
            Color.fbBg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                    if friends.isEmpty {
                        emptyPeopleState
                            .padding(.horizontal, 20)
                    } else {
                        peopleList
                    }

                    Color.clear.frame(height: 40)
                }
                .padding(.top, 8)
            }
        }
        .sheet(item: $selectedFriend) { member in
            FriendProfileView(
                member: member,
                entries: tableRestaurants.filter { $0.userId == member.uid }
            )
        }
        .task {
            guard !hasLoaded else { return }
            hasLoaded = true
            await loadTable()
        }
        // Refetch when circle membership changes (e.g. deep-link invite
        // auto-accepted after this view was already mounted).
        .onChange(of: firestoreService.circlesVersion) { _, _ in
            Task { await loadTable() }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Table")
                    .font(.system(size: 26, weight: .heavy))
                    .tracking(-0.5)
                    .foregroundStyle(Color.fbText)

                Text("What your table is up to")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(hex: "8E8E93"))
            }

            Spacer()
        }
    }

    // MARK: People list

    private var peopleList: some View {
        // Ordered most-recently-active first, so the top of the list
        // is always the freshest signal.
        let ranked = rankedFriends()

        return LazyVStack(spacing: 0) {
            ForEach(Array(ranked.enumerated()), id: \.element.uid) { index, member in
                let entries = friendEntries.filter { $0.userId == member.uid }
                PersonActivityRow(
                    initial: initial(for: member),
                    name: shortName(member.displayName),
                    activity: activityLine(for: entries),
                    timestamp: lastActiveLabel(for: entries)
                ) {
                    selectedFriend = member
                }

                if index < ranked.count - 1 {
                    Rectangle()
                        .fill(Color.white.opacity(0.04))
                        .frame(height: 0.5)
                        .padding(.leading, 76)   // starts after avatar
                }
            }
        }
    }

    private var emptyPeopleState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your table is empty")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.fbText)

            Text("Invite 3\u{2013}5 people whose taste you trust from the account menu (\u{2192} Manage Table). Once they log a place, they\u{2019}ll show up here.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(hex: "B0B0B4"))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // =========================================================================
    // MARK: - Data Loading
    // =========================================================================

    private func loadTable() async {
        let circles = await firestoreService.getMyCircles()
        guard let circle = circles.first else {
            // No circle yet — in DEBUG seed mock data so the tab has signal.
            // In Release (TestFlight/App Store) leave empty so real users start clean.
            #if DEBUG
            self.tableMembers = MockTableData.buildMembers()
            self.tableRestaurants = MockTableData.buildSharedRestaurants()
            #endif
            return
        }
        let members = await firestoreService.getCircleMembers(circle: circle)
        var restaurants = await firestoreService.getCircleRestaurants(circleId: circle.id)
        let memberMap = Dictionary(uniqueKeysWithValues: members.map { ($0.uid, $0.displayName) })
        for i in restaurants.indices {
            restaurants[i].userName = memberMap[restaurants[i].userId] ?? "Friend"
        }

        // Mock data fallback. Only kicks in when the user's circle has
        // NO real friends (just themselves) — gates on member presence,
        // not on whether members have logged restaurants. Previously
        // the check was on logged restaurants, which meant a just-
        // invited friend got visually mixed with mock people until they
        // logged their first meal. In Release the mocks never run.
        #if DEBUG
        let realFriendMembers = members.filter { $0.uid != currentUid }
        if realFriendMembers.isEmpty {
            self.tableMembers = members + MockTableData.buildMembers()
            self.tableRestaurants = restaurants + MockTableData.buildSharedRestaurants()
        } else {
            self.tableMembers = members
            self.tableRestaurants = restaurants
        }
        #else
        self.tableMembers = members
        self.tableRestaurants = restaurants
        #endif
    }

    // =========================================================================
    // MARK: - Derived / Activity
    // =========================================================================

    /// Sort friends by most-recent activity first; friends with nothing
    /// logged sink to the bottom (alphabetical among themselves).
    private func rankedFriends() -> [FirestoreService.CircleMember] {
        friends.sorted { a, b in
            let da = latestDate(forUid: a.uid)
            let db = latestDate(forUid: b.uid)
            switch (da, db) {
            case let (x?, y?):   return x > y
            case (_?, nil):      return true
            case (nil, _?):      return false
            case (nil, nil):     return a.displayName < b.displayName
            }
        }
    }

    private func latestDate(forUid uid: String) -> Date? {
        friendEntries
            .filter { $0.userId == uid }
            .compactMap { $0.dateVisited }
            .max()
    }

    /// One-line activity blurb per person. Prefers the freshest, most
    /// specific signal available.
    ///   - Loved in last 7 days → "{place}"  (heart shown separately)
    ///   - New in last 7 days   → "New: {place}"
    ///   - 3+ new in last 30d   → "N new {cuisine} spots"
    ///   - Has any entry        → "Last: {place}"
    ///   - No entries           → "Yet to log"
    private func activityLine(for entries: [SharedRestaurant]) -> ActivityLine {
        guard !entries.isEmpty else {
            return ActivityLine(text: "Yet to log", isLoved: false)
        }

        let now = Date()
        let dayDelta: (Date) -> Int = { d in
            Calendar.current.dateComponents([.day], from: d, to: now).day ?? Int.max
        }

        let sorted = entries.sorted {
            ($0.dateVisited ?? .distantPast) > ($1.dateVisited ?? .distantPast)
        }

        if let freshest = sorted.first,
           let d = freshest.dateVisited,
           dayDelta(d) <= 7 {
            if freshest.rating >= 5 {
                return ActivityLine(text: freshest.name, isLoved: true)
            }
            return ActivityLine(text: "New: \(freshest.name)", isLoved: false)
        }

        let recentCount = sorted.filter {
            guard let d = $0.dateVisited else { return false }
            return dayDelta(d) <= 30
        }.count
        if recentCount >= 3,
           let topCuisine = topCuisineLabel(entries.filter {
               ($0.dateVisited.map(dayDelta) ?? 999) <= 30
           }) {
            return ActivityLine(text: "\(recentCount) new \(topCuisine) spots", isLoved: false)
        }

        if let last = sorted.first {
            return ActivityLine(text: "Last: \(last.name)", isLoved: false)
        }

        return ActivityLine(text: "Yet to log", isLoved: false)
    }

    /// Returns the most common cuisine label across the given entries,
    /// or nil if the dominant cuisine is `.other` / ties inconclusively.
    private func topCuisineLabel(_ entries: [SharedRestaurant]) -> String? {
        let counts = Dictionary(grouping: entries.filter { $0.cuisine != .other },
                                by: { $0.cuisine })
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
        return counts.first?.key.rawValue
    }

    /// Short relative timestamp for the right edge of the row: "2d",
    /// "1w", "3w", "1mo", or nil when the person has logged nothing.
    private func lastActiveLabel(for entries: [SharedRestaurant]) -> String? {
        guard let date = entries.compactMap(\.dateVisited).max() else { return nil }
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        if days < 1  { return "today" }
        if days < 7  { return "\(days)d" }
        if days < 30 { return "\(days / 7)w" }
        if days < 365 { return "\(days / 30)mo" }
        return "\(days / 365)y"
    }

    // MARK: Formatting helpers

    private func shortName(_ full: String) -> String {
        full.components(separatedBy: " ").first ?? full
    }

    private func initial(for member: FirestoreService.CircleMember) -> String {
        shortName(member.displayName).first.map(String.init) ?? "?"
    }
}

// MARK: - Activity line model

private struct ActivityLine {
    let text: String
    let isLoved: Bool
}

// MARK: - Person Activity Row
//
// One row per friend: 44pt avatar, name + inline timestamp, activity
// blurb underneath. Entire row is tappable; press animation subtle.

private struct PersonActivityRow: View {
    let initial: String
    let name: String
    let activity: ActivityLine
    let timestamp: String?
    let onTap: () -> Void

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onTap()
        } label: {
            HStack(alignment: .center, spacing: 14) {
                avatar

                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(name)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.fbText)
                            .lineLimit(1)

                        Spacer(minLength: 8)

                        if let timestamp {
                            Text(timestamp)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color(hex: "6B6B70"))
                        }
                    }

                    HStack(spacing: 5) {
                        if activity.isLoved {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color.fbWarm)
                        }

                        Text(activity.text)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color(hex: "B0B0B4"))
                            .lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(TableCardPressStyle())
    }

    private var avatar: some View {
        ZStack {
            Circle()
                .fill(Color.fbWarm.opacity(0.14))
            Circle()
                .stroke(Color.fbWarm.opacity(0.30), lineWidth: 1)
            Text(initial)
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(Color.fbWarm)
        }
        .frame(width: 44, height: 44)
    }
}

// MARK: - Press Style

private struct TableCardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
            .brightness(configuration.isPressed ? 0.015 : 0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    TableTestView()
        .environmentObject(RestaurantStore())
        .preferredColorScheme(.dark)
}
