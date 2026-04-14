import SwiftUI
import FirebaseAuth

// MARK: - Home Test View
//
// Decision-surface home page test variant.
// Hero card: Where should I go? What should I get? Why trust this?
// Backup section: OTHER STRONG OPTIONS -- trusted alternatives.
// Does NOT replace NewHomeView.

struct HomeTestView: View {
    @EnvironmentObject var store: RestaurantStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedHero: HeroCardData? = nil
    @State private var showAddPlace = false
    @State private var showProfile = false
    @State private var currentHeroIndex: Int = 0
    @State private var logPrefillName: String = ""
    @State private var logPrefillMeta: String = ""

    // -- Design tokens --
    private static let cardBg = Color(hex: "131517")
    private static let cardHero = Color(hex: "171A1D")
    private static let warmAccent = Color(hex: "C4A882")
    private static let mutedGray = Color(hex: "8E8E93")
    private static let dimGray = Color(hex: "6B6B70")
    private static let lightText = Color(hex: "F5F5F7")

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

                    heroCardView(sampleHeroes[currentHeroIndex])
                        .padding(.horizontal, 16)
                        .padding(.top, 18)

                    if !sampleBackups.isEmpty {
                        Text("OTHER STRONG OPTIONS")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1.5)
                            .foregroundStyle(Self.mutedGray)
                            .padding(.horizontal, 22)
                            .padding(.top, 26)
                            .padding(.bottom, 12)

                        VStack(spacing: 10) {
                            ForEach(sampleBackups) { backup in
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
                    prefillAddress: logPrefillMeta
                )
                .environmentObject(store)
            }
            .navigationDestination(isPresented: $showProfile) {
                ProfileView()
                    .environmentObject(store)
            }
        }
    }

    // =========================================================================
    // MARK: - Header
    // =========================================================================

    private var homeHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Home")
                    .font(.system(size: 26, weight: .heavy))
                    .tracking(-0.5)
                    .foregroundColor(Color.fbText)
                Text("Decide quickly")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Self.mutedGray)
            }
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
                    .padding(.bottom, 16)
            }

            Text(hero.trustLine)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Self.warmAccent)
                .padding(.bottom, 22)

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
                eyebrow: "OTHER STRONG OPTIONS",
                restaurant: backup.restaurant,
                meta: backup.meta,
                directive: backup.directive,
                heroDish: extractDish(from: backup.directive),
                supportingDishes: [],
                trustLine: backup.trustLine
            )
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

                    Text(hero.trustLine)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Self.warmAccent.opacity(0.8))
                        .padding(.top, 18)
                        .padding(.bottom, 36)

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
                logPrefillName = hero.restaurant
                logPrefillMeta = hero.meta
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
    // MARK: - Sample Data
    // =========================================================================

    private let sampleHeroes: [HeroCardData] = [
        HeroCardData(
            eyebrow: "YOUR TABLE\u{2019}S PICK FOR TONIGHT",
            restaurant: "Ju-Ni",
            meta: "Japanese \u{00B7} 23 min \u{00B7} $$",
            directive: "Get the Omakase",
            heroDish: "Omakase",
            supportingDishes: ["Uni Toast", "A5 Wagyu"],
            trustLine: "Priya and Raj both order this"
        ),
        HeroCardData(
            eyebrow: "YOUR TABLE KEEPS ORDERING THIS",
            restaurant: "Dosa Point",
            meta: "Indian \u{00B7} 14 min \u{00B7} $",
            directive: "Go for the Masala Dosa",
            heroDish: "Masala Dosa",
            supportingDishes: ["Filter Coffee", "Idli"],
            trustLine: "3 from your table order this"
        ),
        HeroCardData(
            eyebrow: "SAFE BET TONIGHT",
            restaurant: "Thai Diner",
            meta: "Thai \u{00B7} 18 min \u{00B7} $$",
            directive: "Don\u{2019}t skip the Khao Soi",
            heroDish: "Khao Soi",
            supportingDishes: ["Roti", "Thai Tea"],
            trustLine: "Always solid"
        ),
        HeroCardData(
            eyebrow: "YOUR TABLE\u{2019}S PICK FOR TONIGHT",
            restaurant: "Flour + Water",
            meta: "Italian \u{00B7} 18 min \u{00B7} $$",
            directive: "Order the Pappardelle",
            heroDish: "Pappardelle",
            supportingDishes: ["Meatballs", "Caesar"],
            trustLine: "Maya keeps ordering this"
        ),
        HeroCardData(
            eyebrow: "CLOSE AND WORTH IT",
            restaurant: "Mensho Tokyo",
            meta: "Ramen \u{00B7} 11 min \u{00B7} $$",
            directive: "Have to try the Tori Paitan",
            heroDish: "Tori Paitan",
            supportingDishes: ["Gyoza", "Rice Bowl"],
            trustLine: "Ankit got this last Friday"
        )
    ]

    private let sampleBackups: [BackupCardData] = [
        BackupCardData(
            restaurant: "Flour + Water",
            meta: "Italian \u{00B7} 18 min \u{00B7} $$",
            directive: "Get the Pappardelle",
            trustLine: "Raj and Maya both logged it"
        ),
        BackupCardData(
            restaurant: "Tartine",
            meta: "Bakery \u{00B7} 12 min \u{00B7} $",
            directive: "Order the Morning Bun",
            trustLine: "Priya went recently"
        ),
        BackupCardData(
            restaurant: "Dumpling Home",
            meta: "Chinese \u{00B7} 9 min \u{00B7} $",
            directive: "Get the Soup Dumplings",
            trustLine: "3 from your table logged this"
        ),
        BackupCardData(
            restaurant: "Nopalito",
            meta: "Mexican \u{00B7} 20 min \u{00B7} $$",
            directive: "Go for the Carnitas",
            trustLine: "Ankit keeps ordering this"
        ),
        BackupCardData(
            restaurant: "Sushi Zone",
            meta: "Japanese \u{00B7} 7 min \u{00B7} $$",
            directive: "Order the Chirashi",
            trustLine: "Always solid"
        )
    ]
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
}

struct BackupCardData: Identifiable {
    let id = UUID()
    let restaurant: String
    let meta: String
    let directive: String
    let trustLine: String
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
