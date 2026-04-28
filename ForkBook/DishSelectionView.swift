import SwiftUI

// MARK: - Dish Selection View
//
// Shared dish-picking UI used by both AddPlaceTestFlow (post-visit
// logging) and AddForgottenDishesSheet (Place memory's "I forgot to
// add some dishes" flow). Single source of truth for:
//
//   • A "Rate what you had" section that promotes each selected dish
//     to a card with three explicit, labeled verdict buttons:
//     Loved / Okay / Didn't like. No silent defaults — the verdict is
//     the actual signal we care about, so it must be deliberately
//     picked.
//   • A "Suggestions" area below: rich menu rows (when scraped data
//     is available) above compact chips for curated + cuisine
//     fallbacks. Tap any suggestion to promote it into the rating
//     section.
//   • Custom-dish text input promoted to the top.
//
// Selection is split across two bindings so a dish can sit in the
// "selected but not yet rated" state cleanly:
//
//   • `selected: Set<String>` — names the user has picked
//   • `verdicts: [String: DishVerdict]` — verdict per name
//
// Callers gate their save on `selected.allSatisfy { verdicts[$0] != nil }`
// so the user can't ship a half-rated batch.

struct DishSelectionView: View {
    @Binding var selected: Set<String>
    @Binding var verdicts: [String: DishVerdict]
    @Binding var customText: String
    @Binding var menuSuggestions: [MenuDish]
    @Binding var chipSuggestions: [String]

    /// Caller-supplied handler for "+ a custom dish." Caller does the
    /// validation (e.g. skipping dishes already on the restaurant) and
    /// can decide to insert into chipSuggestions, mark as selected, etc.
    var onCustomSubmit: () -> Void

    // Verdict palette. Loved = warm sand (the brand's trust accent),
    // Okay = neutral muted, Didn't like = red. Red is deliberate —
    // it's the only verdict the user might regret picking later, and
    // a clearly different hue keeps the choice unmistakable at a
    // glance. The previous neutral-brown for skip was visually
    // indistinguishable from "Loved" at small sizes.
    private static let cLoved = Color.fbWarm
    private static let cOkay = Color.fbMuted
    private static let cDislike = Color.fbRed

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            // Promoted text input — first thing visible after the title
            // so the "type what you remember" escape hatch is obvious.
            // Inline "Add" pill on the right is the primary commit
            // affordance; the keyboard's Done key still works as a
            // shortcut, but most users won't think to look for it.
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.fbMuted2)
                TextField("Type a dish you forgot\u{2026}", text: $customText)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.fbText)
                    .submitLabel(.done)
                    .onSubmit { onCustomSubmit() }
                    .autocorrectionDisabled()

                Button {
                    onCustomSubmit()
                } label: {
                    Text("Add")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(canAddCustom ? Color.fbText : Color.fbMuted2)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            Capsule().fill(
                                canAddCustom
                                    ? Color.fbWarm.opacity(0.25)
                                    : Color.white.opacity(0.04)
                            )
                        )
                        .overlay(
                            Capsule().stroke(
                                canAddCustom
                                    ? Color.fbWarm.opacity(0.55)
                                    : Color.white.opacity(0.10),
                                lineWidth: 1
                            )
                        )
                }
                .buttonStyle(.plain)
                .disabled(!canAddCustom)
                .animation(.easeInOut(duration: 0.15), value: canAddCustom)
            }
            .padding(.leading, 16)
            .padding(.trailing, 6)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color.white.opacity(0.05)))
            .overlay(Capsule().stroke(Color.white.opacity(0.10), lineWidth: 1))

            // RATE WHAT YOU HAD — only renders when the user has at
            // least one dish in flight. Sorted by name for stable order
            // (Set<String> has no inherent order; SwiftUI re-renders
            // would otherwise shuffle the cards).
            if !selected.isEmpty {
                sectionLabel("RATE WHAT YOU HAD")
                VStack(spacing: 10) {
                    ForEach(selected.sorted(), id: \.self) { name in
                        ratingCard(name)
                    }
                }
            }

            if !menuSuggestions.isEmpty {
                sectionLabel(suggestionLabel(.menu))
                VStack(spacing: 8) {
                    ForEach(menuSuggestions, id: \.name) { dish in
                        menuRow(dish)
                    }
                }
            }

            if !chipSuggestions.isEmpty {
                sectionLabel(suggestionLabel(.chips))
                FlowLayout(spacing: 8) {
                    ForEach(chipSuggestions, id: \.self) { dish in
                        chip(dish)
                    }
                }
            }

            if menuSuggestions.isEmpty && chipSuggestions.isEmpty && selected.isEmpty {
                Text("No suggestions yet \u{2014} type a dish above to add it.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.fbMuted2)
                    .padding(.top, 4)
            }

            if !selected.isEmpty && !allRated {
                Text("Pick a rating for each dish to save.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.fbMuted)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 4)
            }
        }
    }

    // MARK: - Section labels

    private enum SuggestionsKind { case menu, chips }
    private func suggestionLabel(_ kind: SuggestionsKind) -> String {
        let prefix = selected.isEmpty ? "" : "MORE \u{2014} "
        switch kind {
        case .menu:  return "\(prefix)FROM THE MENU"
        case .chips: return "\(prefix)COMMON DISHES"
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .bold))
            .tracking(1.5)
            .foregroundStyle(Color.fbMuted2)
    }

    // MARK: - Rating card
    //
    // The card IS the rating commitment. Three full-width labeled
    // buttons; the user must pick one. Tap the same button to deselect
    // (back to "rate me"); tap a different one to switch. The "x" in
    // the corner removes the dish entirely.

    private func ratingCard(_ name: String) -> some View {
        let current = verdicts[name]
        let isRated = current != nil
        let activeColor = current.map(color(for:)) ?? Color.fbMuted2

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                Text(name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.fbText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selected.remove(name)
                        verdicts.removeValue(forKey: name)
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.fbMuted2)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                verdictButton("Loved", verdict: .getAgain, current: current, name: name)
                verdictButton("Okay", verdict: .maybe, current: current, name: name)
                verdictButton("Didn\u{2019}t like", verdict: .skip, current: current, name: name)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isRated ? activeColor.opacity(0.10) : Color.fbSurface2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    isRated ? activeColor.opacity(0.55) : Color.white.opacity(0.10),
                    lineWidth: 1
                )
        )
    }

    private func verdictButton(_ label: String, verdict: DishVerdict, current: DishVerdict?, name: String) -> some View {
        let isActive = current == verdict
        let c = color(for: verdict)

        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.easeInOut(duration: 0.12)) {
                if isActive {
                    // Tap the chosen verdict again → unrate, returning
                    // the card to its "rate me" state. Lets the user
                    // back out of an accidental pick without losing the
                    // dish itself.
                    verdicts.removeValue(forKey: name)
                } else {
                    verdicts[name] = verdict
                }
            }
        } label: {
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isActive ? Color.fbText : c.opacity(0.85))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isActive ? c.opacity(0.32) : Color.white.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(isActive ? c.opacity(0.75) : c.opacity(0.30), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Suggestion row (menu) and chip
    //
    // Suggestions are pure "tap to add" affordances now — verdicts
    // happen in the rating cards above. Selected suggestions show a
    // muted "Added" treatment and become tap-to-remove.

    private func menuRow(_ dish: MenuDish) -> some View {
        let isAdded = selected.contains(dish.name)

        return Button {
            toggle(dish.name)
        } label: {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(dish.name)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(Color.fbText)
                        .multilineTextAlignment(.leading)
                    if let desc = dish.description, !desc.isEmpty {
                        Text(desc)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(Color.fbMuted)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    if let priceStr = formatPrice(dish.price) {
                        Text(priceStr)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(Color.fbMuted2)
                            .padding(.top, 2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                addedMarker(isAdded: isAdded)
            }
            .contentShape(Rectangle())
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isAdded ? Self.cLoved.opacity(0.08) : Color.white.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isAdded ? Self.cLoved.opacity(0.40) : Color.white.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func chip(_ name: String) -> some View {
        let isAdded = selected.contains(name)

        return Button {
            toggle(name)
        } label: {
            HStack(spacing: 6) {
                if isAdded {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Self.cLoved)
                }
                Text(name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(isAdded ? Color.fbText : Color.fbMuted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule().fill(
                    isAdded
                        ? Self.cLoved.opacity(0.15)
                        : Color.white.opacity(0.06)
                )
            )
            .overlay(
                Capsule().stroke(
                    isAdded
                        ? Self.cLoved.opacity(0.45)
                        : Color.white.opacity(0.22),
                    lineWidth: 1
                )
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func addedMarker(isAdded: Bool) -> some View {
        if isAdded {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Self.cLoved)
        } else {
            Image(systemName: "plus.circle")
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(Color.fbMuted2)
        }
    }

    // MARK: - State helpers

    private var allRated: Bool {
        selected.allSatisfy { verdicts[$0] != nil }
    }

    private var canAddCustom: Bool {
        !customText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func toggle(_ name: String) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.easeInOut(duration: 0.15)) {
            if selected.contains(name) {
                selected.remove(name)
                verdicts.removeValue(forKey: name)
            } else {
                selected.insert(name)
            }
        }
    }

    // MARK: - Visual helpers

    private func color(for verdict: DishVerdict) -> Color {
        switch verdict {
        case .getAgain: return Self.cLoved
        case .maybe:    return Self.cOkay
        case .skip:     return Self.cDislike
        }
    }

    /// Render a price string only if there's a real value. Menu data
    /// often has 0 for "no price found" — showing "$0" would be wrong.
    /// Strip trailing ".00" so common round prices render as "$18"
    /// instead of "$18.00".
    private func formatPrice(_ price: Double) -> String? {
        guard price > 0 else { return nil }
        if price.rounded() == price {
            return "$\(Int(price))"
        }
        return String(format: "$%.2f", price)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State var selected: Set<String> = ["Lamb Seekh Kebab"]
        @State var verdicts: [String: DishVerdict] = [:]
        @State var customText: String = ""
        @State var menu: [MenuDish] = [
            MenuDish(name: "Lamb Seekh Kebab", description: "Charred minced lamb skewer with onion and herbs", price: 18),
            MenuDish(name: "Joojeh Kabob", description: "Saffron-marinated chicken thigh, basmati rice", price: 22),
            MenuDish(name: "Tahdig", description: "Crispy saffron-rice crust", price: 11),
        ]
        @State var chips: [String] = ["Saffron Rice", "Doogh", "Baklava"]

        var body: some View {
            ScrollView {
                DishSelectionView(
                    selected: $selected,
                    verdicts: $verdicts,
                    customText: $customText,
                    menuSuggestions: $menu,
                    chipSuggestions: $chips,
                    onCustomSubmit: {}
                )
                .padding(20)
            }
            .background(Color.fbBg)
        }
    }
    return PreviewWrapper()
        .preferredColorScheme(.dark)
}
