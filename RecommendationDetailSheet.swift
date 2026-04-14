import SwiftUI

// MARK: - Recommendation Detail Sheet
//
// This is the decision explanation layer — the first thing a user sees
// when they tap a recommendation on Home.
//
// It answers:
// 1. Why is this being recommended?
// 2. Why should I trust this?
// 3. What should I order?
// 4. What can I do next?
//
// For table-driven picks: emphasizes who from the table, their reactions, dishes.
// For personal picks: emphasizes your history, visit count, reliability.

struct RecommendationDetailSheet: View {
    let pick: ScoredPick
    var onIWentHere: () -> Void
    var onSaved: () -> Void

    @EnvironmentObject var store: RestaurantStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {

                // Header: restaurant identity
                headerSection
                    .padding(.bottom, 20)

                // Why this pick — trust explanation
                whySection
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)

                // Table's take (when trust signal exists)
                if pick.hasTableSignal {
                    tableTakeSection
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                }

                // Your history (when you've been before)
                if !pick.isNewToYou {
                    yourHistorySection
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                }

                // What to order
                if !pick.allDishes.isEmpty {
                    dishSection
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                }

                // Good for (moment fit)
                momentFitSection
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)

                // CTAs
                ctaSection
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
            }
        }
        .background(Color.igBlack)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 14) {
            // Cuisine emoji
            ZStack {
                Circle()
                    .fill(Color.igSurface)
                    .frame(width: 72, height: 72)
                Text(cuisineEmoji(pick.cuisine))
                    .font(.system(size: 36))
            }

            VStack(spacing: 5) {
                Text(pick.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Color.igTextPrimary)
                    .multilineTextAlignment(.center)

                HStack(spacing: 6) {
                    if pick.cuisine != .other {
                        Text(pick.cuisine.rawValue)
                            .font(.subheadline)
                            .foregroundColor(Color.igTextSecondary)
                    }
                    if let dist = pick.distance {
                        Text("·")
                            .foregroundColor(Color.igTextTertiary)
                        Text(LocationManager.formatDistance(dist) + " away")
                            .font(.subheadline)
                            .foregroundColor(Color.igTextSecondary)
                    }
                }
            }

            if !pick.address.isEmpty {
                Text(pick.address)
                    .font(.caption)
                    .foregroundColor(Color.igTextTertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
    }

    // MARK: - Why This Pick

    private var whySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("WHY THIS PICK")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(Color.igGradientOrange)
                .tracking(0.5)

            Text(pick.reason)
                .font(.body)
                .foregroundColor(Color.igTextPrimary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            // Summary trust line
            if pick.hasTableSignal {
                let loveCount = pick.tableLoveCount
                let totalCount = pick.tableCount
                if loveCount > 0 || totalCount > 1 {
                    HStack(spacing: 6) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 10))
                        if loveCount > 0 {
                            Text("\(loveCount) loved · \(totalCount) at your table \(totalCount == 1 ? "has" : "have") been")
                                .font(.caption)
                        } else {
                            Text("\(totalCount) at your table \(totalCount == 1 ? "has" : "have") been here")
                                .font(.caption)
                        }
                    }
                    .foregroundColor(Color.igBlue)
                }
            }
        }
        .padding(16)
        .background(Color.igSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.igGradientOrange.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Table's Take

    private var tableTakeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("YOUR TABLE'S TAKE")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(Color.igBlue)
                .tracking(0.5)

            ForEach(pick.tableTakes) { take in
                tableMemberRow(take)
            }
        }
    }

    private func tableMemberRow(_ take: TableMemberTake) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                AvatarView(name: take.name, size: 36)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(take.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(Color.igTextPrimary)

                        if let reaction = take.reaction {
                            Text(reaction.emoji)
                                .font(.caption)
                            Text(reactionVerb(reaction))
                                .font(.caption)
                                .foregroundColor(Color.igTextSecondary)
                        }
                    }

                    HStack(spacing: 8) {
                        if take.visitCount > 1 {
                            Text("Been \(take.visitCount) times")
                                .font(.caption2)
                                .foregroundColor(Color.igTextTertiary)
                        }

                        let recency = recencyPhrase(take.daysAgo)
                        if !recency.isEmpty {
                            Text(recency)
                                .font(.caption2)
                                .foregroundColor(Color.igTextTertiary)
                        }
                    }
                }

                Spacer()
            }

            // Their dish recommendation
            if let dish = take.bestDish {
                HStack(spacing: 6) {
                    Image(systemName: "fork.knife")
                        .font(.system(size: 9))
                    Text("\(take.name) says order the \(dish)")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(Color.igGradientOrange)
            }
        }
        .padding(14)
        .background(Color.igSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Your History

    private var yourHistorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("YOUR HISTORY")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(Color.igTextTertiary)
                .tracking(0.5)

            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.igSurface)
                        .frame(width: 40, height: 40)
                    if let reaction = pick.yourReaction {
                        Text(reaction.emoji)
                            .font(.title3)
                    } else {
                        Image(systemName: "checkmark")
                            .font(.caption)
                            .foregroundColor(Color.igTextSecondary)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        if let reaction = pick.yourReaction {
                            Text("You \(reactionVerb(reaction))")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(Color.igTextPrimary)
                        } else {
                            Text("You've been here")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(Color.igTextPrimary)
                        }
                    }

                    HStack(spacing: 8) {
                        if pick.yourVisitCount > 1 {
                            Text("\(pick.yourVisitCount) visits")
                                .font(.caption)
                                .foregroundColor(Color.igTextSecondary)
                        }

                        let recency = recencyPhrase(pick.yourDaysAgo)
                        if !recency.isEmpty {
                            Text("Last went \(recency)")
                                .font(.caption)
                                .foregroundColor(Color.igTextTertiary)
                        }
                    }
                }

                Spacer()
            }
            .padding(14)
            .background(Color.igSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    // MARK: - What to Order

    private var dishSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("WHAT TO ORDER")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(Color.igGradientOrange)
                .tracking(0.5)

            ForEach(pick.allDishes.prefix(4)) { dish in
                HStack(spacing: 10) {
                    Image(systemName: "fork.knife")
                        .font(.caption)
                        .foregroundColor(Color.igGradientOrange)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(dish.dish)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(Color.igTextPrimary)

                        Text("\(dish.recommender) recommends")
                            .font(.caption)
                            .foregroundColor(Color.igTextSecondary)
                    }

                    Spacer()
                }
                .padding(12)
                .background(Color.igSurface)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }

    // MARK: - Good For

    private var momentFitSection: some View {
        let fits = momentFits(for: pick.cuisine)

        return Group {
            if !fits.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("GOOD FOR")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(Color.igTextTertiary)
                        .tracking(0.5)

                    HStack(spacing: 8) {
                        ForEach(fits, id: \.self) { fit in
                            Text(fit)
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.igSurface)
                                .foregroundColor(Color.igTextSecondary)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
    }

    private func momentFits(for cuisine: CuisineType) -> [String] {
        var fits: [String] = []
        let moments = NewHomeView.MealMoment.allCases
        for moment in moments {
            if let affinities = moment.affinityCuisines, affinities.contains(cuisine) {
                fits.append(moment.rawValue)
            }
        }
        // Add generic fits
        if fits.isEmpty {
            fits = ["Dinner", "Lunch"]
        }
        return Array(fits.prefix(4))
    }

    // MARK: - CTAs

    private var ctaSection: some View {
        VStack(spacing: 12) {
            Button {
                onIWentHere()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.subheadline)
                    Text(pick.isNewToYou ? "I went here" : "I went again")
                }
            }
            .buttonStyle(FBPrimaryButtonStyle())

            Button {
                onSaved()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "bookmark")
                        .font(.subheadline)
                    Text("Save for later")
                }
            }
            .buttonStyle(FBSecondaryButtonStyle())
        }
    }

    // MARK: - Helpers

    private func reactionVerb(_ reaction: Reaction) -> String {
        switch reaction {
        case .loved: return "loved it"
        case .liked: return "liked it"
        case .meh: return "thought it was okay"
        }
    }

    private func recencyPhrase(_ daysAgo: Int) -> String {
        if daysAgo == 0 { return "today" }
        if daysAgo == 1 { return "yesterday" }
        if daysAgo < 7 { return "this week" }
        if daysAgo < 30 { return "recently" }
        if daysAgo < 90 { return "a few months ago" }
        return ""
    }

    private func cuisineEmoji(_ cuisine: CuisineType) -> String {
        switch cuisine {
        case .japanese: return "🍣"
        case .chinese: return "🥟"
        case .korean: return "🍜"
        case .thai: return "🌶️"
        case .vietnamese: return "🍲"
        case .indian: return "🍛"
        case .italian: return "🍝"
        case .french: return "🥐"
        case .mexican: return "🌮"
        case .mediterranean: return "🥗"
        case .american: return "🍔"
        case .other: return "🍽️"
        }
    }
}

// MARK: - Preview

#Preview {
    let samplePick = ScoredPick(
        name: "Dosa Kitchen",
        address: "123 Main St, San Francisco",
        cuisine: .indian,
        tableTakes: [
            TableMemberTake(
                name: "Puneet",
                reaction: .loved,
                dishes: ["Masala dosa", "Filter coffee"],
                daysAgo: 3,
                visitCount: 2
            ),
            TableMemberTake(
                name: "Neha",
                reaction: .liked,
                dishes: ["Idli sambar"],
                daysAgo: 14,
                visitCount: 1
            )
        ],
        bestDish: "Masala dosa",
        allDishes: [
            DishRecommendation(dish: "Masala dosa", recommender: "Puneet"),
            DishRecommendation(dish: "Filter coffee", recommender: "Puneet"),
            DishRecommendation(dish: "Idli sambar", recommender: "Neha")
        ],
        distance: 0.8,
        yourReaction: nil,
        yourVisitCount: 0,
        yourDaysAgo: 999,
        reason: "Puneet loved it this week — get the masala dosa",
        score: 14
    )

    return RecommendationDetailSheet(
        pick: samplePick,
        onIWentHere: {},
        onSaved: {}
    )
    .environmentObject(RestaurantStore())
    .preferredColorScheme(.dark)
}
