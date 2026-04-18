import SwiftUI

// MARK: - Add Place Test Flow
//
// Memory-first logging flow aligned with MyPlacesTestView.
// Two steps: What did you have? (with inline verdict) → Anything to remember? → Saved
// No place-level rating. No emoji reactions. Dish-first.
// Produces data compatible with My Places memory cards.
//
// The flow is only reachable from an "I went here" CTA (Home detail,
// Search detail, or the committed-pick follow-up), so restaurant context
// is always provided via prefill. There is no in-flow "pick a place"
// step — if prefill is missing the sheet dismisses immediately.

struct AddPlaceTestFlow: View {
    @EnvironmentObject var store: RestaurantStore
    @Environment(\.dismiss) private var dismiss

    // Prefill — required in practice. The flow bails if missing.
    var prefillName: String? = nil
    var prefillAddress: String? = nil
    var prefillCuisine: CuisineType? = nil
    var onComplete: (() -> Void)? = nil

    // ── Flow state ──
    // Starts on the first real step (dish capture); there is no pick-place
    // screen anymore. The rawValues keep the old numbering so the
    // progress-dot math doesn't need to change.
    @State private var step: LogStep = .whatDidYouHave
    @State private var direction: AnimationDirection = .forward

    // ── Data ──
    @State private var selectedName = ""
    @State private var selectedAddress = ""
    @State private var selectedCuisine: CuisineType = .other

    // Step 1: dishes + inline verdict (combined)
    @State private var suggestedDishes: [String] = []
    @State private var selectedDishes: Set<String> = []
    @State private var customDishText = ""
    @State private var dishVerdicts: [String: DishVerdict] = [:]

    // Step 2: note
    @State private var noteText = ""

    // Step 3: saved
    @State private var savedRestaurant: Restaurant? = nil
    @State private var showGoToNudge = false

    // ── Types ──

    enum LogStep: Int, CaseIterable {
        case whatDidYouHave = 1
        case anythingToRemember = 2
        case saved = 3
    }

    enum DishVerdict: String {
        case getAgain = "get_again"
        case maybe = "maybe"
        case skip = "skip"
    }

    enum AnimationDirection {
        case forward, backward
    }

    // ── Colors ──
    private static let cardBg = Color(hex: "131517")
    private static let verdictGetAgain = Color(hex: "C4A882")   // fbWarm
    private static let verdictMaybe = Color(hex: "8E8E93")       // muted
    private static let verdictSkip = Color(hex: "6B6560")        // muted warning

    var body: some View {
        NavigationStack {
            ZStack {
                Color.fbBg.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Progress dots — hidden on the terminal saved screen
                    if step != .saved {
                        progressDots
                            .padding(.top, 8)
                            .padding(.bottom, 4)
                    }

                    Group {
                        switch step {
                        case .whatDidYouHave:     whatDidYouHaveScreen
                        case .anythingToRemember: anythingToRememberScreen
                        case .saved:              savedScreen
                        }
                    }
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: direction == .forward ? .trailing : .leading).combined(with: .opacity),
                            removal: .move(edge: direction == .forward ? .leading : .trailing).combined(with: .opacity)
                        )
                    )
                    .id(step)
                }
            }
            .onAppear {
                // The flow only makes sense with a prefilled place. If the
                // sheet was somehow presented without one, dismiss rather
                // than show a pick-place form we no longer have.
                guard let name = prefillName, !name.isEmpty else {
                    dismiss()
                    return
                }
                selectedName = name
                selectedAddress = prefillAddress ?? ""
                if let cuisine = prefillCuisine {
                    selectedCuisine = cuisine
                } else if let detected = CuisineDetector.detect(name: name, subtitle: prefillAddress ?? "") {
                    selectedCuisine = detected
                }
                loadDishSuggestions()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    // Back is only meaningful on step 2 (anythingToRemember)
                    // since step 1 is now the entry point — on step 1 the
                    // top-right "X" dismisses the sheet instead.
                    if step == .anythingToRemember {
                        Button { goBack() } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 13, weight: .semibold))
                                Text("Back")
                                    .font(.system(size: 15, weight: .medium))
                            }
                            .foregroundColor(Color.fbMuted)
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color.fbMuted2)
                    }
                }
            }
        }
    }

    // =========================================================================
    // MARK: - Progress Dots
    // =========================================================================

    private var progressDots: some View {
        HStack(spacing: 6) {
            ForEach(1...2, id: \.self) { i in
                Capsule()
                    .fill(step.rawValue >= i ? Color.fbWarm : Color.white.opacity(0.08))
                    .frame(width: step.rawValue == i ? 20 : 8, height: 3)
                    .animation(.easeInOut(duration: 0.2), value: step)
            }
        }
    }

    // =========================================================================
    // MARK: - Step 1: What did you have?
    // =========================================================================

    // Hybrid model:
    //   • Chips at top → selection only (tap to pick / unpick)
    //   • Compact selected-dish rows below → explicit state pills
    //   • Default verdict on selection = .getAgain (fast path)

    private var whatDidYouHaveScreen: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("What did you have?")
                    .font(.system(size: 24, weight: .heavy))
                    .tracking(-0.4)
                    .foregroundStyle(Color.fbText)
                Text(selectedName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.fbMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 24)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // Dish chips — selection only
                    if !suggestedDishes.isEmpty {
                        FlowLayout(spacing: 8) {
                            ForEach(suggestedDishes, id: \.self) { dish in
                                selectionChip(dish)
                            }
                        }
                        .padding(.horizontal, 24)
                    }

                    // Selected dish rows
                    if !selectedDishes.isEmpty {
                        // Section label
                        Text("SELECTED DISHES")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1.6)
                            .foregroundStyle(Color(hex: "8E8E93"))
                            .padding(.horizontal, 24)
                            .padding(.top, 24)
                            .padding(.bottom, 12)

                        VStack(spacing: 0) {
                            let sorted = Array(selectedDishes).sorted()
                            ForEach(Array(sorted.enumerated()), id: \.element) { index, dish in
                                selectedDishRow(dish)
                                if index < sorted.count - 1 {
                                    Rectangle()
                                        .fill(Color.white.opacity(0.04))
                                        .frame(height: 1)
                                        .padding(.leading, 24)
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                    }

                    // Custom dish input
                    HStack(spacing: 10) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.fbMuted2)
                        TextField("Type a dish\u{2026}", text: $customDishText)
                            .font(.system(size: 15))
                            .foregroundStyle(Color.fbText)
                            .submitLabel(.done)
                            .onSubmit { addCustomDish() }

                        if !customDishText.isEmpty {
                            Button { addCustomDish() } label: {
                                Text("Add")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color.fbWarm)
                            }
                        }
                    }
                    .padding(14)
                    .background(Self.cardBg)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
                    .padding(.horizontal, 24)
                    .padding(.top, selectedDishes.isEmpty ? 14 : 20)

                    Spacer(minLength: 120)
                }
            }

            Spacer()

            // Next — always enabled. Picking dishes is encouraged but not
            // required; users can advance and add dishes later or skip them
            // entirely for places they only want to remember by name.
            Button {
                // Finalize: any selected dish without explicit verdict → getAgain
                for dish in selectedDishes where dishVerdicts[dish] == nil {
                    dishVerdicts[dish] = .getAgain
                }
                goForward(to: .anythingToRemember)
            } label: {
                Text("Next")
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
                            .stroke(Color.fbWarm.opacity(0.45), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }

    // ── Selection chip (pick/unpick only) ──

    private func selectionChip(_ dish: String) -> some View {
        let isSelected = selectedDishes.contains(dish)

        return Button {
            withAnimation(.easeInOut(duration: 0.12)) {
                if isSelected {
                    selectedDishes.remove(dish)
                    dishVerdicts.removeValue(forKey: dish)
                } else {
                    selectedDishes.insert(dish)
                    dishVerdicts[dish] = .getAgain
                }
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            Text(dish)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(isSelected ? Color.fbText : Color.fbMuted)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(isSelected
                              ? Self.verdictGetAgain.opacity(0.15)
                              : Color.white.opacity(0.06))
                )
                .overlay(
                    Capsule()
                        .stroke(isSelected
                                ? Self.verdictGetAgain.opacity(0.40)
                                : Color.white.opacity(0.22),
                                lineWidth: 1)
                )
        }
        .buttonStyle(ChipPressStyle())
    }

    // ── Compact selected-dish row ──

    private func selectedDishRow(_ dish: String) -> some View {
        let verdict = dishVerdicts[dish] ?? .getAgain

        return HStack(spacing: 0) {
            Text(dish)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.fbText)
                .lineLimit(1)

            Spacer(minLength: 12)

            HStack(spacing: 6) {
                statePill("Amazing", for: .getAgain, current: verdict, dish: dish)
                statePill("Okay", for: .maybe, current: verdict, dish: dish)
                statePill("Skip", for: .skip, current: verdict, dish: dish)
            }
        }
        .padding(.vertical, 12)
    }

    // ── State pill ──

    private func statePill(_ label: String, for verdict: DishVerdict, current: DishVerdict, dish: String) -> some View {
        let isActive = current == verdict

        let activeColor: Color = {
            switch verdict {
            case .getAgain: return Self.verdictGetAgain
            case .maybe:    return Self.verdictMaybe
            case .skip:     return Self.verdictSkip
            }
        }()

        return Button {
            withAnimation(.easeInOut(duration: 0.12)) {
                dishVerdicts[dish] = verdict
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isActive ? activeColor : Color.fbMuted2.opacity(0.6))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isActive ? activeColor.opacity(0.12) : Color.white.opacity(0.02))
                )
                .overlay(
                    Capsule()
                        .stroke(isActive ? activeColor.opacity(0.25) : Color.white.opacity(0.04), lineWidth: 1)
                )
        }
        .buttonStyle(ChipPressStyle())
    }

    // =========================================================================
    // MARK: - Step 2: Anything to remember?
    // =========================================================================

    private var anythingToRememberScreen: some View {
        VStack(spacing: 0) {
            // The title itself implies optional ("Anything..."), and the
            // TextEditor placeholder shows the kind of note we want — no
            // separate subtitle is needed.
            Text("Anything to remember?")
                .font(.system(size: 24, weight: .heavy))
                .tracking(-0.4)
                .foregroundStyle(Color.fbText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 28)

            // Note input
            ZStack(alignment: .topLeading) {
                if noteText.isEmpty {
                    Text("Rich broth, perfect egg\u{2026}")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.fbMuted2)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 16)
                }
                TextEditor(text: $noteText)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.fbText)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(minHeight: 120)
            }
            .background(Self.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
            .padding(.horizontal, 24)

            // Suggestion prompts
            VStack(alignment: .leading, spacing: 8) {
                noteSuggestion("Jay ordered for us")
                noteSuggestion("Great quick lunch spot")
                noteSuggestion("Skip the ramen next time")
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            Spacer()

            // Save
            Button {
                saveVisit()
            } label: {
                Text("Save")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.fbText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.fbWarm.opacity(0.2))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.fbWarm.opacity(0.3), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
            .padding(.bottom, 12)

            // Skip
            Button {
                saveVisit()
            } label: {
                Text("Skip")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.fbMuted2)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 40)
        }
    }

    private func noteSuggestion(_ text: String) -> some View {
        Button {
            if noteText.isEmpty {
                noteText = text
            } else {
                noteText += ". " + text
            }
        } label: {
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.fbMuted2)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.03))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.04), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // =========================================================================
    // MARK: - Step 3: Saved
    // =========================================================================

    private var savedScreen: some View {
        VStack(spacing: 0) {
            Spacer()

            // Quiet checkmark
            ZStack {
                Circle()
                    .fill(Color.fbWarm.opacity(0.1))
                    .frame(width: 72, height: 72)
                Image(systemName: "checkmark")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Color.fbWarm)
            }
            .padding(.bottom, 20)

            Text("Saved")
                .font(.system(size: 22, weight: .heavy))
                .tracking(-0.3)
                .foregroundStyle(Color.fbText)

            Text(selectedName)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.fbMuted)
                .padding(.top, 4)

            // Go-to nudge
            if showGoToNudge, let restaurant = savedRestaurant {
                goToNudgeView(for: restaurant)
                    .padding(.top, 28)
            }

            Spacer()

            // Done
            Button {
                // Fire the parent completion hook (e.g. to route back to Home
                // from Search) before dismissing so the tab switch happens
                // behind the sheet as it animates away.
                onComplete?()
                dismiss()
            } label: {
                Text("Done")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.fbText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
            .padding(.bottom, 50)
        }
    }

    private func verdictLabel(_ v: DishVerdict) -> String {
        switch v {
        case .getAgain: return "Get again"
        case .maybe:    return "Maybe"
        case .skip:     return "Skip"
        }
    }

    private func verdictColor(_ v: DishVerdict) -> Color {
        switch v {
        case .getAgain: return Self.verdictGetAgain
        case .maybe:    return Self.verdictMaybe
        case .skip:     return Self.verdictSkip
        }
    }

    // =========================================================================
    // MARK: - Go-to Nudge
    // =========================================================================

    private func goToNudgeView(for restaurant: Restaurant) -> some View {
        VStack(spacing: 12) {
            Text("You keep coming back here")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.fbText)

            HStack(spacing: 12) {
                Button {
                    store.markAsGoTo(restaurant)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showGoToNudge = false
                } label: {
                    Text("Mark as go-to")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.fbWarm)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Color.fbWarm.opacity(0.12))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    if let r = savedRestaurant {
                        store.markGoToNudgeShown(r)
                    }
                    showGoToNudge = false
                } label: {
                    Text("Not now")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.fbMuted2)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(Self.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.fbWarm.opacity(0.12), lineWidth: 1)
        )
        .padding(.horizontal, 32)
    }

    // =========================================================================
    // MARK: - Navigation
    // =========================================================================

    private func goForward(to next: LogStep) {
        direction = .forward
        withAnimation(.easeInOut(duration: 0.25)) { step = next }
    }

    private func goBack() {
        // Step 1 is the entry point — there's nowhere to go back to.
        // Dismiss the sheet instead so the user returns to the calling view.
        guard step != .whatDidYouHave else {
            dismiss()
            return
        }
        direction = .backward
        withAnimation(.easeInOut(duration: 0.25)) {
            if let prev = LogStep(rawValue: step.rawValue - 1) {
                step = prev
            }
        }
    }

    // =========================================================================
    // MARK: - Save
    // =========================================================================

    private func saveVisit() {
        var restaurant: Restaurant

        if let existing = store.restaurants.first(where: { $0.name.lowercased() == selectedName.lowercased() }) {
            restaurant = existing
            restaurant.category = .visited
            restaurant.visitCount += 1
            restaurant.dateVisited = Date()
            // Infer reaction from dish verdicts
            restaurant.reaction = inferReaction()
            restaurant.rating = restaurant.reaction?.starRating ?? existing.rating
            if !noteText.isEmpty { restaurant.quickNote = noteText }
            store.update(restaurant)
        } else {
            restaurant = Restaurant(
                name: selectedName,
                address: selectedAddress,
                cuisine: selectedCuisine,
                category: .visited,
                rating: inferReaction()?.starRating ?? 0,
                dateVisited: Date(),
                reaction: inferReaction()
            )
            if !noteText.isEmpty { restaurant.quickNote = noteText }
            store.add(restaurant)
        }

        // Save dish data
        for dish in selectedDishes {
            let verdict = dishVerdicts[dish] ?? .getAgain
            let liked = verdict == .getAgain || verdict == .maybe
            if !restaurant.dishes.contains(where: { $0.name.lowercased() == dish.lowercased() }) {
                restaurant.dishes.append(DishItem(name: dish, liked: liked))
            }
        }
        store.update(restaurant)

        savedRestaurant = restaurant
        showGoToNudge = restaurant.shouldNudgeGoTo

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        goForward(to: .saved)
    }

    /// Infer a place-level reaction from dish verdicts for backward compatibility
    private func inferReaction() -> Reaction? {
        let verdicts = Array(dishVerdicts.values)
        if verdicts.isEmpty { return .liked }
        let getAgainCount = verdicts.filter { $0 == .getAgain }.count
        let skipCount = verdicts.filter { $0 == .skip }.count
        if getAgainCount > 0 && skipCount == 0 { return .loved }
        if skipCount == verdicts.count { return .meh }
        return .liked
    }

    // =========================================================================
    // MARK: - Helpers
    // =========================================================================

    private func addCustomDish() {
        let trimmed = customDishText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if !suggestedDishes.contains(where: { $0.lowercased() == trimmed.lowercased() }) {
            suggestedDishes.insert(trimmed, at: 0)
        }
        selectedDishes.insert(trimmed)
        dishVerdicts[trimmed] = .getAgain
        customDishText = ""
    }

    private func loadDishSuggestions() {
        var results: [String] = []
        var seen = Set<String>()

        if let dishes = RestaurantDishDB.lookup(selectedName) {
            for d in dishes where !seen.contains(d.lowercased()) {
                seen.insert(d.lowercased())
                results.append(d)
            }
        }

        if selectedCuisine != .other {
            for d in PopularDishes.dishes(for: selectedCuisine) where !seen.contains(d.lowercased()) {
                seen.insert(d.lowercased())
                results.append(d)
            }
        }

        suggestedDishes = Array(results.prefix(8))
    }
}

// =========================================================================
// MARK: - Chip Press Style
// =========================================================================

/// Subtle scale + brightness on press — fast, no bounce
private struct ChipPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .brightness(configuration.isPressed ? 0.02 : 0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// =========================================================================
// MARK: - Preview
// =========================================================================

#Preview {
    // Preview requires a prefilled place — without one the flow dismisses
    // immediately because the pick-place step no longer exists.
    AddPlaceTestFlow(
        prefillName: "Lucali",
        prefillAddress: "575 Henry St, Brooklyn",
        prefillCuisine: .italian
    )
    .environmentObject(RestaurantStore())
    .preferredColorScheme(.dark)
}
