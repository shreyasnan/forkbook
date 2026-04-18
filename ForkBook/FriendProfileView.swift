import SwiftUI

// MARK: - Friend Profile View
//
// Shown as a sheet when a user taps a row in the Table tab's "Your people"
// section. Reads as a scoped MyPlaces — "where has Priya been?" — without
// pulling in the full MyPlaces feature surface (search, Ask, city detail
// drilldown). We intentionally keep it read-only: you can see a friend's
// places but can't log on their behalf or mutate their entries.
//
// Data flow:
//   - Parent (TableTestView) already loaded `tableRestaurants: [SharedRestaurant]`
//     via FirestoreService. We slice that by `member.uid` and pass the
//     filtered array in — no extra fetch here.
//   - A friend's "city" comes from the address string (first non-numeric
//     segment), mirroring LocalSearchIndex.extractCity.
//
// Layout:
//   1. Header — avatar, name, compact taste descriptor, place count.
//   2. "Most recent" — horizontal strip of the 5 newest entries.
//   3. "By city" — count per city, tap → filtered list.
//   4. "By cuisine" — count per cuisine, tap → filtered list.
//   5. "All places" — full list sorted by recency.
//
// Tapping any place row reveals a dish-level sheet with their liked /
// disliked dishes, notes, and visit count — the raw memory for that spot.

struct FriendProfileView: View {
    let member: FirestoreService.CircleMember
    let entries: [SharedRestaurant]

    @Environment(\.dismiss) private var dismiss
    @State private var selectedPlace: SharedRestaurant? = nil
    @State private var activeFilter: Filter = .all

    enum Filter: Equatable {
        case all
        case city(String)
        case cuisine(CuisineType)

        var label: String {
            switch self {
            case .all: return "All places"
            case .city(let name): return name
            case .cuisine(let c): return c.rawValue
            }
        }
    }

    // =========================================================================
    // MARK: - Body
    // =========================================================================

    var body: some View {
        ZStack {
            Color.fbBg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    closeRow
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                    header
                        .padding(.horizontal, 20)

                    if entries.isEmpty {
                        emptyState
                            .padding(.horizontal, 20)
                    } else {
                        if !recentEntries.isEmpty {
                            recentSection
                        }

                        if cityRollup.count >= 2 {
                            citySection
                                .padding(.horizontal, 20)
                        }

                        if cuisineRollup.count >= 2 {
                            cuisineSection
                                .padding(.horizontal, 20)
                        }

                        allPlacesSection
                            .padding(.horizontal, 20)
                    }

                    Color.clear.frame(height: 40)
                }
                .padding(.top, 4)
            }
        }
        .sheet(item: $selectedPlace) { place in
            FriendPlaceSheet(place: place, friendName: shortName)
        }
    }

    // =========================================================================
    // MARK: - Close / Header
    // =========================================================================

    private var closeRow: some View {
        HStack {
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color(hex: "6B6B70"))
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            avatar

            VStack(alignment: .leading, spacing: 4) {
                Text(shortName)
                    .font(.system(size: 26, weight: .heavy))
                    .tracking(-0.5)
                    .foregroundStyle(Color.fbText)

                Text(subtitleLine)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(hex: "8E8E93"))
                    .lineLimit(1)
            }

            Spacer()
        }
    }

    private var avatar: some View {
        ZStack {
            Circle().fill(Color.fbWarm.opacity(0.14))
            Circle().stroke(Color.fbWarm.opacity(0.35), lineWidth: 1)
            Text(initialChar)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.fbWarm)
        }
        .frame(width: 50, height: 50)
    }

    private var subtitleLine: String {
        let n = entries.count
        let placeCount = "\(n) place\(n == 1 ? "" : "s")"
        let topCuisine = cuisineRollup.first?.cuisine.rawValue
        if let topCuisine {
            return "\(placeCount) \u{00B7} \(topCuisine) lead"
        }
        return placeCount
    }

    // =========================================================================
    // MARK: - Most Recent Strip
    // =========================================================================

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Most recent")
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(recentEntries) { place in
                        recentCard(place)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private func recentCard(_ place: SharedRestaurant) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            selectedPlace = place
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                Text(metaLine(place))
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(Color.fbWarm)
                    .lineLimit(1)
                    .padding(.bottom, 8)

                Text(place.name)
                    .font(.system(size: 17, weight: .heavy))
                    .tracking(-0.3)
                    .foregroundStyle(Color.fbText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 10)

                if !dishPreview(place).isEmpty {
                    Text(dishPreview(place))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(hex: "B0B0B4"))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                } else if let when = relativeVisitDate(place.dateVisited) {
                    Text("Visited \(when)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(hex: "8E8E93"))
                }
            }
            .padding(16)
            .frame(width: 220, height: 150, alignment: .leading)
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
        .buttonStyle(FriendProfilePressStyle())
    }

    // =========================================================================
    // MARK: - By City
    // =========================================================================

    private var citySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("By city")

            VStack(spacing: 8) {
                ForEach(Array(cityRollup.prefix(5)), id: \.name) { row in
                    rollupRow(
                        title: row.name,
                        subtitle: row.topCuisines,
                        count: row.count,
                        isActive: activeFilter == .city(row.name)
                    ) {
                        toggleFilter(.city(row.name))
                    }
                }
            }
        }
    }

    // =========================================================================
    // MARK: - By Cuisine
    // =========================================================================

    private var cuisineSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("By cuisine")

            VStack(spacing: 8) {
                ForEach(Array(cuisineRollup.prefix(5)), id: \.cuisine) { row in
                    rollupRow(
                        title: row.cuisine.rawValue,
                        subtitle: row.topPlaces,
                        count: row.count,
                        isActive: activeFilter == .cuisine(row.cuisine)
                    ) {
                        toggleFilter(.cuisine(row.cuisine))
                    }
                }
            }
        }
    }

    private func rollupRow(
        title: String,
        subtitle: String,
        count: Int,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.fbText)
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color(hex: "8E8E93"))
                            .lineLimit(1)
                    }
                }
                Spacer()
                Text("\(count)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.fbWarm)
                Image(systemName: isActive ? "chevron.down.circle.fill" : "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isActive ? Color.fbWarm : Color(hex: "6B6B70"))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isActive ? Color.fbWarm.opacity(0.08) : Color.fbSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        isActive ? Color.fbWarm.opacity(0.35) : Color.white.opacity(0.04),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(FriendProfilePressStyle())
    }

    // =========================================================================
    // MARK: - All Places
    // =========================================================================

    private var allPlacesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                sectionLabel(allPlacesTitle)
                Spacer()
                if activeFilter != .all {
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) { activeFilter = .all }
                    } label: {
                        Text("Clear")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1.0)
                            .foregroundStyle(Color.fbWarm)
                    }
                    .buttonStyle(FriendProfilePressStyle())
                }
            }

            VStack(spacing: 8) {
                ForEach(filteredEntries) { place in
                    placeRow(place)
                }
            }
        }
    }

    private var allPlacesTitle: String {
        switch activeFilter {
        case .all: return "ALL PLACES"
        case .city(let n): return "IN \(n.uppercased())"
        case .cuisine(let c): return c.rawValue.uppercased()
        }
    }

    private func placeRow(_ place: SharedRestaurant) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            selectedPlace = place
        } label: {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(place.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.fbText)
                        .lineLimit(1)
                    if !metaLine(place).isEmpty {
                        Text(metaLine(place))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color(hex: "8E8E93"))
                            .lineLimit(1)
                    }
                }
                Spacer()
                if let when = relativeVisitDate(place.dateVisited) {
                    Text(when)
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
        .buttonStyle(FriendProfilePressStyle())
    }

    // =========================================================================
    // MARK: - Empty State
    // =========================================================================

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No places yet")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.fbText)
            Text("\(shortName) hasn\u{2019}t logged anything yet. Once they do, their places will show up here.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(hex: "B0B0B4"))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.fbSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.04), lineWidth: 1)
        )
    }

    // =========================================================================
    // MARK: - Helpers (formatting, derived data)
    // =========================================================================

    private var shortName: String {
        member.displayName.components(separatedBy: " ").first ?? member.displayName
    }

    private var initialChar: String {
        String(shortName.first ?? "?")
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .bold))
            .tracking(1.4)
            .foregroundStyle(Color(hex: "8E8E93"))
    }

    private func metaLine(_ place: SharedRestaurant) -> String {
        var parts: [String] = []
        if place.cuisine != .other { parts.append(place.cuisine.rawValue) }
        let city = cityFromAddress(place.address)
        if !city.isEmpty { parts.append(city) }
        return parts.joined(separator: " \u{00B7} ")
    }

    private func dishPreview(_ place: SharedRestaurant) -> String {
        let liked = place.likedDishes.map(\.name).prefix(2)
        return liked.joined(separator: ", ")
    }

    /// Mirrors LocalSearchIndex.extractCity — duplicated here to keep this
    /// view self-contained and dodge making that private helper public.
    private func cityFromAddress(_ address: String) -> String {
        let parts = address.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard parts.count >= 2 else { return parts.first ?? "" }
        if parts.count >= 2, let first = parts.first, first.first?.isNumber == true {
            return parts[1]
        }
        return parts.first ?? ""
    }

    private func relativeVisitDate(_ date: Date?) -> String? {
        guard let date else { return nil }
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        if days <= 1 { return "yesterday" }
        if days < 7 { return "\(days)d ago" }
        if days < 30 { return "\(days / 7)w ago" }
        if days < 365 { return "\(days / 30)mo ago" }
        return "\(days / 365)y ago"
    }

    private func toggleFilter(_ filter: Filter) {
        withAnimation(.easeOut(duration: 0.15)) {
            activeFilter = (activeFilter == filter) ? .all : filter
        }
    }

    // MARK: Derived collections

    private var sortedEntries: [SharedRestaurant] {
        entries.sorted { a, b in
            (a.dateVisited ?? .distantPast) > (b.dateVisited ?? .distantPast)
        }
    }

    private var recentEntries: [SharedRestaurant] {
        Array(sortedEntries.prefix(5))
    }

    private var filteredEntries: [SharedRestaurant] {
        switch activeFilter {
        case .all:
            return sortedEntries
        case .city(let name):
            return sortedEntries.filter {
                cityFromAddress($0.address).caseInsensitiveCompare(name) == .orderedSame
            }
        case .cuisine(let c):
            return sortedEntries.filter { $0.cuisine == c }
        }
    }

    private struct CityRow {
        let name: String
        let count: Int
        let topCuisines: String
    }

    private struct CuisineRow {
        let cuisine: CuisineType
        let count: Int
        let topPlaces: String
    }

    private var cityRollup: [CityRow] {
        let grouped = Dictionary(grouping: entries, by: { cityFromAddress($0.address) })
            .filter { !$0.key.isEmpty }
        return grouped
            .map { (name, places) in
                let cuisines = places
                    .map(\.cuisine)
                    .filter { $0 != .other }
                    .reduce(into: [CuisineType: Int]()) { $0[$1, default: 0] += 1 }
                    .sorted { $0.value > $1.value }
                    .prefix(2)
                    .map(\.key.rawValue)
                    .joined(separator: ", ")
                return CityRow(name: name, count: places.count, topCuisines: cuisines)
            }
            .sorted { $0.count > $1.count }
    }

    private var cuisineRollup: [CuisineRow] {
        let grouped = Dictionary(grouping: entries, by: { $0.cuisine })
            .filter { $0.key != .other }
        return grouped
            .map { (cuisine, places) in
                let topPlaces = places
                    .sorted { ($0.dateVisited ?? .distantPast) > ($1.dateVisited ?? .distantPast) }
                    .prefix(2)
                    .map(\.name)
                    .joined(separator: ", ")
                return CuisineRow(cuisine: cuisine, count: places.count, topPlaces: topPlaces)
            }
            .sorted { $0.count > $1.count }
    }
}

// =============================================================================
// MARK: - Friend Place Detail Sheet
// =============================================================================
//
// When the user taps a specific place (from any row in the profile), we
// present this read-only memory sheet. It shows:
//   - Restaurant name + meta
//   - Visit count / last visited
//   - Liked / disliked dishes
//   - Optional notes the friend left
//
// No edit affordances — this is someone else's memory.

private struct FriendPlaceSheet: View {
    let place: SharedRestaurant
    let friendName: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.fbBg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        Text("\(friendName)\u{2019}s memory")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1.4)
                            .foregroundStyle(Color.fbWarm)
                        Spacer()
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(Color(hex: "6B6B70"))
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(place.name)
                            .font(.system(size: 26, weight: .heavy))
                            .tracking(-0.5)
                            .foregroundStyle(Color.fbText)
                        if !metaLine.isEmpty {
                            Text(metaLine)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color(hex: "8E8E93"))
                        }
                    }

                    if !statLine.isEmpty {
                        Text(statLine)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color(hex: "D6D6DA"))
                    }

                    if !place.likedDishes.isEmpty {
                        dishBlock(
                            title: "Liked",
                            dishes: place.likedDishes.map(\.name),
                            accent: Color.fbWarm
                        )
                    }

                    if !place.dislikedDishes.isEmpty {
                        dishBlock(
                            title: "Skipped",
                            dishes: place.dislikedDishes.map(\.name),
                            accent: Color(hex: "8E8E93")
                        )
                    }

                    if !place.notes.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("NOTES")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(1.4)
                                .foregroundStyle(Color(hex: "8E8E93"))
                            Text(place.notes)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.fbText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Spacer(minLength: 30)
                }
                .padding(24)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var metaLine: String {
        var parts: [String] = []
        if place.cuisine != .other { parts.append(place.cuisine.rawValue) }
        if !place.address.isEmpty { parts.append(place.address) }
        return parts.joined(separator: " \u{00B7} ")
    }

    private var statLine: String {
        var parts: [String] = []
        if place.visitCount > 0 {
            parts.append("\(place.visitCount) visit\(place.visitCount == 1 ? "" : "s")")
        }
        if let date = place.dateVisited {
            let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
            if days <= 1 { parts.append("last yesterday") }
            else if days < 7 { parts.append("last \(days)d ago") }
            else if days < 30 { parts.append("last \(days / 7)w ago") }
            else if days < 365 { parts.append("last \(days / 30)mo ago") }
            else { parts.append("last \(days / 365)y ago") }
        }
        return parts.joined(separator: ", ")
    }

    private func dishBlock(title: String, dishes: [String], accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(accent)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(dishes, id: \.self) { dish in
                    Text("\u{2022} \(dish)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.fbText)
                }
            }
        }
    }
}

// =============================================================================
// MARK: - Press Style
// =============================================================================

private struct FriendProfilePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
            .brightness(configuration.isPressed ? 0.015 : 0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
