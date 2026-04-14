import SwiftUI
import FirebaseAuth

// MARK: - My Places Test View (V2 — Memory-first, query-led)
//
// Three routes:
//   .home       — "Ask from memory": search bar, suggested queries, quick access places
//   .place      — Place memory: warm hero, visits, what to remember, actions
//   .city       — City recommendations summary
//
// Replaces the earlier memory-scoring prototype.

struct MyPlacesTestView: View {
    @State private var route: Route = .home

    // MARK: Routes

    enum Route: Equatable {
        case home
        case place(String)   // keyed by place id
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
                    if let place = placeLookup[id] {
                        placeDetailScreen(place)
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

                chipsRow
                    .padding(.top, 12)

                sectionLabel("YOU MIGHT ASK")
                    .padding(.top, 24)

                VStack(spacing: 10) {
                    ForEach(suggestedQueries) { query in
                        queryRow(query)
                    }
                }
                .padding(.horizontal, 16)

                sectionLabel("QUICK ACCESS")
                    .padding(.top, 24)

                VStack(spacing: 10) {
                    ForEach(quickAccessPlaces) { place in
                        quickPlaceRow(place)
                    }
                }
                .padding(.horizontal, 16)

                Spacer(minLength: 80)
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

                sectionLabel("WHAT YOU ATE")
                    .padding(.top, 26)

                VStack(spacing: 10) {
                    ForEach(place.visits) { visit in
                        visitCard(visit)
                    }
                }
                .padding(.horizontal, 16)

                sectionLabel("WHAT TO REMEMBER")
                    .padding(.top, 26)

                VStack(spacing: 10) {
                    memoryRow(name: "Most repeated", detail: place.mostRepeated)
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

                sectionLabel("TOP PICKS")
                    .padding(.top, 10)

                VStack(spacing: 10) {
                    ForEach(topPicks(in: name)) { place in
                        quickPlaceRow(place)
                    }
                }
                .padding(.horizontal, 16)

                sectionLabel("ALSO GOOD")
                    .padding(.top, 24)

                VStack(spacing: 10) {
                    ForEach(alsoGood(in: name)) { place in
                        quickPlaceRow(place)
                    }
                }
                .padding(.horizontal, 16)

                Spacer(minLength: 80)
            }
        }
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

            Text("Ask about places, dishes, cities")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color(hex: "B0B0B4"))

            Spacer()
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

    private var chipsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(
                    label: "Have I been to Ju-Ni?",
                    active: true,
                    action: { navigate(.place(juNi.id)) }
                )
                chip(
                    label: "What did I eat at Flour + Water?",
                    active: false,
                    action: { navigate(.place(flourWater.id)) }
                )
                chip(
                    label: "Best places in SF?",
                    active: false,
                    action: { navigate(.city("San Francisco")) }
                )
            }
            .padding(.horizontal, 16)
        }
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

    private func queryRow(_ query: SuggestedQuery) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            navigate(query.target)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(query.question)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.fbText)

                Text(query.answerPreview)
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

                Text(place.rating)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.fbWarm)
                    .padding(.bottom, 4)

                Text(place.dishes)
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

            Text(place.summarySub)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color(hex: "B0B0B4"))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 12)

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
            .padding(.bottom, 10)

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
    // MARK: - Sample Data
    // =========================================================================

    private var placeLookup: [String: PlaceMemory] {
        var map: [String: PlaceMemory] = [:]
        for place in allPlaces { map[place.id] = place }
        return map
    }

    private var allPlaces: [PlaceMemory] {
        [juNi, flourWater, tartine]
    }

    private var suggestedQueries: [SuggestedQuery] {
        [
            SuggestedQuery(
                question: "Have I been to Ju-Ni?",
                answerPreview: "2 visits \u{00B7} amazing",
                target: .place(juNi.id)
            ),
            SuggestedQuery(
                question: "What did I eat at Tartine?",
                answerPreview: "Morning bun \u{00B7} 1 visit",
                target: .place(tartine.id)
            ),
            SuggestedQuery(
                question: "What should I recommend in San Francisco?",
                answerPreview: "Ju-Ni, Flour + Water, Tartine",
                target: .city("San Francisco")
            )
        ]
    }

    private var quickAccessPlaces: [PlaceMemory] {
        [juNi, flourWater]
    }

    private func topPicks(in city: String) -> [PlaceMemory] {
        [juNi, flourWater]
    }

    private func alsoGood(in city: String) -> [PlaceMemory] {
        [tartine]
    }

    // MARK: Place definitions

    private let juNi = PlaceMemory(
        id: "ju-ni",
        name: "Ju-Ni",
        meta: "Japanese \u{00B7} 23 min \u{00B7} $$",
        visitCount: "2 visits",
        rating: "Amazing",
        dishes: "Omakase, uni toast",
        summary: "Yes \u{2014} you\u{2019}ve been here 2 times",
        summarySub: "Last visit 2 weeks ago \u{00B7} both times omakase",
        heroNote: "One of your strongest San Francisco recommendations.",
        visits: [
            VisitRecord(
                id: "juni-v1",
                title: "Most recent visit",
                timeAgo: "2w ago",
                dishes: [DishRating(id: "juni-v1-d1", name: "Omakase", rating: "Amazing")]
            ),
            VisitRecord(
                id: "juni-v2",
                title: "Earlier visit",
                timeAgo: "4m ago",
                dishes: [
                    DishRating(id: "juni-v2-d1", name: "Omakase", rating: "Amazing"),
                    DishRating(id: "juni-v2-d2", name: "Uni toast", rating: "Amazing")
                ]
            )
        ],
        mostRepeated: "Omakase",
        confidence: "High \u{2014} one of your best remembered SF places"
    )

    private let flourWater = PlaceMemory(
        id: "flour-water",
        name: "Flour + Water",
        meta: "Italian \u{00B7} 18 min \u{00B7} $$",
        visitCount: "1 visit",
        rating: "Amazing",
        dishes: "Pappardelle",
        summary: "Yes \u{2014} you went once",
        summarySub: "6 weeks ago \u{00B7} pappardelle stood out",
        heroNote: "Go back for the pappardelle.",
        visits: [
            VisitRecord(
                id: "fw-v1",
                title: "Only visit",
                timeAgo: "6w ago",
                dishes: [
                    DishRating(id: "fw-v1-d1", name: "Pappardelle", rating: "Amazing"),
                    DishRating(id: "fw-v1-d2", name: "Meatballs", rating: "Good")
                ]
            )
        ],
        mostRepeated: "Pappardelle",
        confidence: "High \u{2014} one standout dish"
    )

    private let tartine = PlaceMemory(
        id: "tartine",
        name: "Tartine",
        meta: "Bakery \u{00B7} 12 min \u{00B7} $",
        visitCount: "1 visit",
        rating: "Okay",
        dishes: "Morning bun",
        summary: "Yes \u{2014} you went once",
        summarySub: "3 months ago \u{00B7} grabbed a morning bun",
        heroNote: "Fine for a quick bakery stop, not a destination.",
        visits: [
            VisitRecord(
                id: "tar-v1",
                title: "Only visit",
                timeAgo: "3m ago",
                dishes: [DishRating(id: "tar-v1-d1", name: "Morning bun", rating: "Okay")]
            )
        ],
        mostRepeated: "Morning bun",
        confidence: "Medium \u{2014} pleasant, not memorable"
    )
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
        .preferredColorScheme(.dark)
}
