import SwiftUI
import FirebaseAuth

// MARK: - Table Test View (V4 — Utility First, real data)
//
// Two sections:
//   1. Trust for…   -- occasion → trusted person
//   2. Your people  -- compact rows, derived descriptor + hint
//
// Backed by Firestore circle members + SharedRestaurants.

struct TableTestView: View {
    @EnvironmentObject var store: RestaurantStore
    @State private var showInviteSheet = false
    @State private var hasLoaded = false
    @State private var tableMembers: [FirestoreService.CircleMember] = []
    @State private var tableRestaurants: [SharedRestaurant] = []
    private let firestoreService = FirestoreService.shared

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
                VStack(alignment: .leading, spacing: 28) {
                    header
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                    let trust = trustMap
                    let people = derivedPeople

                    if !trust.isEmpty {
                        trustForSection(trust)
                            .padding(.horizontal, 20)
                    }

                    if !people.isEmpty {
                        yourPeopleSection(people)
                            .padding(.horizontal, 20)
                    } else {
                        emptyPeopleState
                            .padding(.horizontal, 20)
                    }

                    Color.clear.frame(height: 40)
                }
                .padding(.top, 8)
            }
        }
        .sheet(isPresented: $showInviteSheet) {
            InvitePlaceholderSheet()
        }
        .task {
            guard !hasLoaded else { return }
            hasLoaded = true
            await loadTable()
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

                Text("Who should I ask?")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(hex: "8E8E93"))
            }

            Spacer()

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showInviteSheet = true
            } label: {
                Text("+ Invite")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.fbWarm)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule().fill(Color.fbWarm.opacity(0.12))
                    )
                    .overlay(
                        Capsule().stroke(Color.fbWarm.opacity(0.25), lineWidth: 1)
                    )
            }
            .buttonStyle(TableCardPressStyle())
        }
    }

    // MARK: Section 1 — Trust for…

    private func trustForSection(_ trust: [TrustPair]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("TRUST FOR\u{2026}")

            VStack(spacing: 0) {
                ForEach(Array(trust.enumerated()), id: \.offset) { index, pair in
                    TrustShortcutRow(pair: pair)

                    if index < trust.count - 1 {
                        Rectangle()
                            .fill(Color.white.opacity(0.04))
                            .frame(height: 0.5)
                            .padding(.leading, 16)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(hex: "131517"))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
    }

    // MARK: Section 2 — Your people

    private func yourPeopleSection(_ people: [TablePerson]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("YOUR PEOPLE")

            VStack(spacing: 10) {
                ForEach(Array(people.enumerated()), id: \.offset) { _, person in
                    CompactPersonRow(person: person)
                }
            }
        }
    }

    private var emptyPeopleState: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("YOUR PEOPLE")

            Text("Your table is empty")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.fbText)

            Text("Invite 3\u{2013}5 people whose taste you trust. Once they log a place, they\u{2019}ll show up here with the areas they\u{2019}re strongest in.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(hex: "B0B0B4"))
                .fixedSize(horizontal: false, vertical: true)

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showInviteSheet = true
            } label: {
                Text("Invite people")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.fbText)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.fbWarm.opacity(0.18)))
                    .overlay(Capsule().stroke(Color.fbWarm.opacity(0.35), lineWidth: 1))
            }
            .padding(.top, 4)
            .buttonStyle(TableCardPressStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .tracking(1.4)
            .foregroundStyle(Color(hex: "8E8E93"))
    }

    // =========================================================================
    // MARK: - Data Loading
    // =========================================================================

    private func loadTable() async {
        let circles = await firestoreService.getMyCircles()
        guard let circle = circles.first else {
            // No circle yet — seed with mock data so the tab isn't empty.
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

        // Mock data fallback when the user's circle is empty.
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
    // MARK: - Derived Data
    // =========================================================================

    /// For each occasion category, pick the member with the strongest signal.
    private var trustMap: [TrustPair] {
        guard !friends.isEmpty, !friendEntries.isEmpty else { return [] }

        // Define categories with a heuristic (cuisines most associated with that occasion)
        struct CategorySpec {
            let label: String
            let dishyCuisines: Set<CuisineType>
            /// Priority scorer: higher count is better
            let score: (SharedRestaurant) -> Int
        }

        let specs: [CategorySpec] = [
            CategorySpec(
                label: "Date night",
                dishyCuisines: [.french, .italian, .japanese, .mediterranean],
                score: { r in
                    (Set([CuisineType.french, .italian, .japanese, .mediterranean]).contains(r.cuisine) ? 3 : 0)
                    + (r.rating >= 5 ? 2 : (r.rating >= 3 ? 1 : 0))
                }
            ),
            CategorySpec(
                label: "Lunch",
                dishyCuisines: [.indian, .vietnamese, .thai, .mexican, .american, .chinese, .korean],
                score: { r in
                    (Set([CuisineType.indian, .vietnamese, .thai, .mexican, .american, .chinese, .korean]).contains(r.cuisine) ? 3 : 0)
                    + max(0, r.visitCount - 1)
                }
            ),
            CategorySpec(
                label: "New spots",
                dishyCuisines: [],
                score: { r in
                    guard let d = r.dateVisited else { return 0 }
                    let days = Calendar.current.dateComponents([.day], from: d, to: Date()).day ?? 999
                    if days <= 14 { return 4 }
                    if days <= 30 { return 2 }
                    return 0
                }
            ),
            CategorySpec(
                label: "Group dinner",
                dishyCuisines: [.italian, .chinese, .mexican, .american, .mediterranean],
                score: { r in
                    (Set([CuisineType.italian, .chinese, .mexican, .american, .mediterranean]).contains(r.cuisine) ? 2 : 0)
                    + (r.visitCount >= 2 ? 2 : 0)
                    + (r.rating >= 4 ? 1 : 0)
                }
            )
        ]

        var out: [TrustPair] = []
        var usedMembers = Set<String>()

        for spec in specs {
            // Tally per member
            var tally: [String: Int] = [:]
            for r in friendEntries {
                tally[r.userId, default: 0] += spec.score(r)
            }
            // Filter already-used members so each person owns at most one category
            let candidates = tally
                .filter { $0.value > 0 }
                .filter { !usedMembers.contains($0.key) }
                .sorted { $0.value > $1.value }

            guard let top = candidates.first else { continue }
            let member = tableMembers.first(where: { $0.uid == top.key })
            let name = shortName(member?.displayName ?? "Friend")
            out.append(TrustPair(category: spec.label, person: name))
            usedMembers.insert(top.key)
        }

        return out
    }

    /// Derive a descriptor + hint for each friend.
    private var derivedPeople: [TablePerson] {
        friends.map { member in
            let theirEntries = friendEntries.filter { $0.userId == member.uid }
            let name = shortName(member.displayName)
            let initial = name.first.map(String.init) ?? "?"

            let descriptor = descriptorText(for: theirEntries)
            let hint = hintText(member: member, entries: theirEntries)

            return TablePerson(
                initial: initial,
                name: name,
                descriptor: descriptor,
                hint: hint
            )
        }
    }

    private func descriptorText(for entries: [SharedRestaurant]) -> String {
        guard !entries.isEmpty else { return "No places yet." }

        // Top cuisines
        let cuisineCounts = Dictionary(grouping: entries.filter { $0.cuisine != .other }, by: { $0.cuisine })
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }

        if let top = cuisineCounts.first, cuisineCounts.count >= 2 {
            let second = cuisineCounts[1]
            if top.value >= 2 && second.value >= 2 {
                return "\(top.key.rawValue) · \(second.key.rawValue)"
            }
            return top.key.rawValue
        }
        if let top = cuisineCounts.first {
            return top.key.rawValue
        }
        return "\(entries.count) place\(entries.count == 1 ? "" : "s") logged"
    }

    private func hintText(member: FirestoreService.CircleMember, entries: [SharedRestaurant]) -> String {
        // Overlap with user's places by name
        let myNames = Set(store.restaurants.map { $0.name.lowercased() })
        let theirNames = Set(entries.map { $0.name.lowercased() })
        let overlap = myNames.intersection(theirNames)

        // How many of their picks has the user loved/liked?
        let myLoved = store.visitedRestaurants.filter {
            ($0.reaction == .loved || $0.reaction == .liked) &&
            theirNames.contains($0.name.lowercased())
        }

        if myLoved.count >= 3 {
            return "You\u{2019}ve loved \(myLoved.count) of their picks."
        }
        if overlap.count >= 3 {
            return "You agree on \(overlap.count) places."
        }
        if overlap.count >= 1 {
            return "You overlap on \(overlap.count) place\(overlap.count == 1 ? "" : "s")."
        }
        if entries.isEmpty {
            return "Nothing logged yet."
        }
        return "Useful when you want something new."
    }

    private func shortName(_ full: String) -> String {
        full.components(separatedBy: " ").first ?? full
    }
}

// MARK: - Models

private struct TablePerson {
    let initial: String
    let name: String
    let descriptor: String
    let hint: String
}

private struct TrustPair {
    let category: String
    let person: String
}

// MARK: - Trust Shortcut Row (section 1)

private struct TrustShortcutRow: View {
    let pair: TrustPair

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack(spacing: 10) {
                Text(pair.category)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.fbText)

                Spacer()

                Text("\u{2192}")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(hex: "6B6B70"))

                Text(pair.person)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.fbWarm)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .contentShape(Rectangle())
        }
        .buttonStyle(TableCardPressStyle())
    }
}

// MARK: - Compact Person Row (section 2)

private struct CompactPersonRow: View {
    let person: TablePerson

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack(alignment: .top, spacing: 14) {
                avatar

                VStack(alignment: .leading, spacing: 4) {
                    Text(person.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.fbText)

                    Text(person.descriptor)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color(hex: "B0B0B4"))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(person.hint)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.fbWarm.opacity(0.9))
                        .padding(.top, 2)
                }

                Spacer(minLength: 0)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(hex: "131517"))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
            )
        }
        .buttonStyle(TableCardPressStyle())
    }

    private var avatar: some View {
        ZStack {
            Circle()
                .fill(Color.fbWarm.opacity(0.14))

            Circle()
                .stroke(Color.fbWarm.opacity(0.35), lineWidth: 1)

            Text(person.initial)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.fbWarm)
        }
        .frame(width: 34, height: 34)
    }
}

// MARK: - Invite Placeholder Sheet

private struct InvitePlaceholderSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.fbBg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                Text("Invite to your table")
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(Color.fbText)

                Text("Your table works best with 3\u{2013}5 people whose taste you already trust. Share a quick invite via text.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(hex: "8E8E93"))
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    dismiss()
                } label: {
                    Text("Invite by text")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.fbText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.fbWarm.opacity(0.18))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.fbWarm.opacity(0.35), lineWidth: 1)
                        )
                }
                .buttonStyle(TableCardPressStyle())

                Button {
                    dismiss()
                } label: {
                    Text("Not now")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color(hex: "6B6B70"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
            }
            .padding(24)
        }
        .presentationDetents([.height(280)])
        .presentationDragIndicator(.visible)
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
