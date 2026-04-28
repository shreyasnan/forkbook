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

    // Step 1: dishes + inline verdict. Selection state is split into
    // a Set (what's picked) and a Dict (how each was rated) so a dish
    // can sit in the "selected but not yet rated" state — required
    // by the deliberate-rating UX in DishSelectionView. Suggestions
    // are split into rich menu rows (when scraped data is available)
    // and compact cuisine/curated chips.
    @State private var menuSuggestions: [MenuDish] = []
    @State private var chipSuggestions: [String] = []
    @State private var selected: Set<String> = []
    @State private var verdicts: [String: DishVerdict] = [:]
    @State private var customDishText = ""

    // Step 2: note
    @State private var noteText = ""

    // Step 3: saved
    @State private var savedRestaurant: Restaurant? = nil
    @State private var showGoToNudge = false

    // Place ID resolved during the flow for a first-time log — carried
    // through to `saveVisit()` so the new Restaurant lands with a
    // googlePlaceId in place, and RestaurantStore.resolvePlaceIdIfNeeded
    // doesn't do a duplicate Places API call (~$0.017 saved per log).
    @State private var resolvedPlaceId: String? = nil

    // ── Types ──

    enum LogStep: Int, CaseIterable {
        case whatDidYouHave = 1
        case anythingToRemember = 2
        case saved = 3
    }

    // DishVerdict lives in Restaurant.swift now — promoted so DishItem can
    // store it alongside the legacy `liked` boolean and we can reconstruct
    // the original 3-way signal from persisted data.

    enum AnimationDirection {
        case forward, backward
    }

    // ── Colors ──
    private static let cardBg = Color(hex: "131517")

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

    private var whatDidYouHaveScreen: some View {
        VStack(spacing: 0) {
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
            .padding(.bottom, 18)

            ScrollView(.vertical, showsIndicators: false) {
                DishSelectionView(
                    selected: $selected,
                    verdicts: $verdicts,
                    customText: $customDishText,
                    menuSuggestions: $menuSuggestions,
                    chipSuggestions: $chipSuggestions,
                    onCustomSubmit: addCustomDish
                )
                .padding(.horizontal, 24)
                .padding(.top, 4)

                Spacer(minLength: 100)
            }

            Spacer()

            // Next — enabled when (a) no dishes selected (user is
            // logging the visit without dish capture) OR (b) every
            // selected dish has a verdict. Mirrors the deliberate
            // capture rule in DishSelectionView's UI: half-rated
            // batches don't ship.
            Button {
                goForward(to: .anythingToRemember)
            } label: {
                Text("Next")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.fbText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.fbWarm.opacity(canAdvance ? 0.18 : 0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.fbWarm.opacity(canAdvance ? 0.45 : 0.20), lineWidth: 1)
                    )
                    .opacity(canAdvance ? 1.0 : 0.6)
            }
            .buttonStyle(.plain)
            .disabled(!canAdvance)
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }

    /// Step-1 advance gate. No selection = OK to continue (user is
    /// logging the visit without recording dishes). Selection present
    /// = every dish must have a verdict before moving on.
    private var canAdvance: Bool {
        selected.isEmpty || selected.allSatisfy { verdicts[$0] != nil }
    }

    // =========================================================================
    // MARK: - Step 2: Anything to remember?
    // =========================================================================

    private var anythingToRememberScreen: some View {
        VStack(spacing: 0) {
            Text("Anything to remember?")
                .font(.system(size: 24, weight: .heavy))
                .tracking(-0.4)
                .foregroundStyle(Color.fbText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 18)

            // Note input — small by default; users can tap into it and
            // type freely. Removed the pre-filled suggestion pills
            // ("Jay ordered for us", etc.) — they nudged users into
            // canned phrases rather than letting them write what
            // actually mattered.
            ZStack(alignment: .topLeading) {
                if noteText.isEmpty {
                    Text("Rich broth, perfect egg\u{2026}")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.fbMuted2)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                }
                TextEditor(text: $noteText)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.fbText)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .frame(minHeight: 80)
            }
            .background(Self.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
            .padding(.horizontal, 24)

            Spacer()

            // Skip — promoted to a real button so users see it as a
            // valid choice, not a ghost link. Save is the warm-accent
            // primary; Skip is a clearly-tappable secondary.
            Button {
                noteText = ""
                saveVisit()
            } label: {
                Text("Skip")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.fbMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
            .padding(.bottom, 12)

            // Save
            Button {
                saveVisit()
            } label: {
                Text("Save")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.fbText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.fbWarm.opacity(0.20))
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

    // =========================================================================
    // MARK: - Step 3: Saved
    // =========================================================================

    private var savedScreen: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 28)

            ZStack {
                Circle()
                    .fill(Color.fbWarm.opacity(0.10))
                    .frame(width: 72, height: 72)
                Image(systemName: "checkmark")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Color.fbWarm)
            }
            .padding(.bottom, 18)

            Text("Saved")
                .font(.system(size: 22, weight: .heavy))
                .tracking(-0.3)
                .foregroundStyle(Color.fbText)

            Text(selectedName)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.fbMuted)
                .padding(.top, 4)

            // Visit summary — rated dishes grouped by verdict so the
            // user sees exactly what was captured (the whole point of
            // the deliberate-rating UX is to make capture meaningful;
            // surfacing that capture here closes the loop).
            ScrollView {
                VStack(spacing: 16) {
                    if !savedDishesByVerdict.isEmpty {
                        savedDishesSummary
                    }
                    if !noteText.isEmpty {
                        savedNoteCard
                    }

                    if showGoToNudge, let restaurant = savedRestaurant {
                        goToNudgeView(for: restaurant)
                            .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 28)
                .padding(.bottom, 16)
            }

            Button {
                // Fire the parent completion hook (e.g. to route back to Home
                // from Search) before dismissing so the tab switch happens
                // behind the sheet as it animates away.
                onComplete?()
                dismiss()
            } label: {
                Text("Done")
                    .font(.system(size: 17, weight: .bold))
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
            .padding(.bottom, 40)
        }
    }

    /// Group saved dishes by verdict for the summary on the saved screen.
    /// Returns sections in display order — Loved, Okay, Didn't like —
    /// skipping any empty verdicts.
    private var savedDishesByVerdict: [(verdict: DishVerdict, label: String, dishes: [String])] {
        var loved: [String] = []
        var okay: [String] = []
        var dislike: [String] = []
        for name in selected.sorted() {
            switch verdicts[name] {
            case .getAgain: loved.append(name)
            case .maybe:    okay.append(name)
            case .skip:     dislike.append(name)
            case nil:       continue
            }
        }
        var sections: [(verdict: DishVerdict, label: String, dishes: [String])] = []
        if !loved.isEmpty   { sections.append((.getAgain, "Loved", loved)) }
        if !okay.isEmpty    { sections.append((.maybe, "Okay", okay)) }
        if !dislike.isEmpty { sections.append((.skip, "Didn\u{2019}t like", dislike)) }
        return sections
    }

    private var savedDishesSummary: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("WHAT YOU ATE")
                .font(.system(size: 12, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(Color.fbMuted2)

            VStack(spacing: 10) {
                ForEach(savedDishesByVerdict, id: \.verdict) { section in
                    savedVerdictRow(label: section.label, verdict: section.verdict, dishes: section.dishes)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func savedVerdictRow(label: String, verdict: DishVerdict, dishes: [String]) -> some View {
        let color = savedVerdictColor(verdict)
        return HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 80, alignment: .leading)
                .padding(.top, 2)
            Text(dishes.joined(separator: ", "))
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.fbText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(color.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(color.opacity(0.40), lineWidth: 1)
        )
    }

    private func savedVerdictColor(_ verdict: DishVerdict) -> Color {
        switch verdict {
        case .getAgain: return Color.fbWarm
        case .maybe:    return Color.fbMuted
        case .skip:     return Color.fbRed
        }
    }

    private var savedNoteCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("YOUR NOTE")
                .font(.system(size: 12, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(Color.fbMuted2)
            Text(noteText)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Color.fbText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
            // Belt & suspenders: if the existing record somehow lost its
            // Place ID (or never had one), backfill from what we resolved
            // during the dish-suggestions fetch. Costs nothing; saves a
            // duplicate Places API call from `resolvePlaceIdIfNeeded`.
            if (restaurant.googlePlaceId ?? "").isEmpty, let resolved = resolvedPlaceId {
                restaurant.googlePlaceId = resolved
            }
            store.update(restaurant)
        } else {
            restaurant = Restaurant(
                name: selectedName,
                address: selectedAddress,
                cuisine: selectedCuisine,
                category: .visited,
                rating: inferReaction()?.starRating ?? 0,
                dateVisited: Date(),
                reaction: inferReaction(),
                // Pre-populated from loadMenuDishesAsync for first-time logs.
                // If set, RestaurantStore.resolvePlaceIdIfNeeded short-
                // circuits so we don't hit the Places API twice per log.
                googlePlaceId: resolvedPlaceId
            )
            if !noteText.isEmpty { restaurant.quickNote = noteText }
            store.add(restaurant)
        }

        // Save dish data. We pass `verdict` (3-way) through — DishItem's
        // initializer derives the legacy `liked` bool from it, so both the
        // old chip/summary code (which reads `liked`) and future
        // verdict-aware views stay consistent. canAdvance gated the
        // step transition, so by the time we're here every selected
        // dish has a verdict.
        for dish in selected {
            guard let verdict = verdicts[dish] else { continue }
            if !restaurant.dishes.contains(where: { $0.name.lowercased() == dish.lowercased() }) {
                restaurant.dishes.append(DishItem(name: dish, verdict: verdict))
            }
        }
        store.update(restaurant)

        savedRestaurant = restaurant
        showGoToNudge = restaurant.shouldNudgeGoTo

        // Append an immutable per-visit record to Firestore so we keep the
        // full history of this trip — date, note, dishes with verdicts,
        // reaction — separate from the rolled-up "current state" doc that
        // syncOne() writes. Later views (per-visit timeline, richer
        // share cards) draw from this subcollection. Fire-and-forget; any
        // failure is logged but doesn't block the Saved screen.
        logVisitToFirestore(for: restaurant)

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        goForward(to: .saved)
    }

    /// Build the visit dish snapshot from the flow state and push it. We
    /// use the flow's `selected` dictionary directly rather than the
    /// restaurant's aggregated `dishes` array because a dish can exist on
    /// the restaurant from a prior visit — we want *this* visit's verdicts.
    private func logVisitToFirestore(for restaurant: Restaurant) {
        let circleId = FirestoreService.shared.primaryCircleId
        guard let circleId, !circleId.isEmpty else {
            // Offline or circle not yet known — skip. Future visit logs
            // will land, and the rolled-up restaurant doc still syncs via
            // RestaurantStore, so no visible data is lost.
            return
        }

        // Reconstruct per-visit DishItems from the picked dishes + their
        // verdicts. Matches what a fresh Restaurant append would look like.
        let visitDishes: [DishItem] = selected.compactMap { name in
            guard let verdict = verdicts[name] else { return nil }
            return DishItem(name: name, verdict: verdict)
        }

        let restaurantId = restaurant.id
        let date = Date()
        let note = noteText
        let reaction = inferReaction()
        let occasions = restaurant.occasionTags

        Task {
            do {
                try await FirestoreService.shared.logVisit(
                    restaurantId: restaurantId,
                    circleId: circleId,
                    date: date,
                    note: note,
                    reaction: reaction,
                    dishes: visitDishes,
                    occasions: occasions
                )
            } catch {
                print("[Visit] failed to log visit for '\(restaurant.name)': \(error)")
            }
        }
    }

    /// Infer a place-level reaction from dish verdicts for backward compatibility
    private func inferReaction() -> Reaction? {
        let values = selected.compactMap { verdicts[$0] }
        if values.isEmpty { return .liked }
        let getAgainCount = values.filter { $0 == .getAgain }.count
        let skipCount = values.filter { $0 == .skip }.count
        if getAgainCount > 0 && skipCount == 0 { return .loved }
        if skipCount == values.count { return .meh }
        return .liked
    }

    // =========================================================================
    // MARK: - Helpers
    // =========================================================================

    private func addCustomDish() {
        let trimmed = customDishText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if !chipSuggestions.contains(where: { $0.lowercased() == trimmed.lowercased() }) {
            chipSuggestions.insert(trimmed, at: 0)
        }
        // Add to selection without a default verdict — the user must
        // rate it before Save unlocks. Same rule as
        // suggestion-tap entries.
        selected.insert(trimmed)
        customDishText = ""
    }

    private func loadDishSuggestions() {
        // Priority order:
        //   1. Scraped menu items keyed by googlePlaceId (rich rows — async)
        //   2. Curated per-restaurant list (RestaurantDishDB — chips)
        //   3. Cuisine defaults (PopularDishes — chips)
        //
        // Curated + cuisine fallbacks render synchronously so the picker
        // never starts blank. The async path may add menu rows above
        // them once the network round-trip returns; chips that overlap
        // with menu items are pruned to avoid duplicates.
        let menuKeys = Set(menuSuggestions.map { $0.name.lowercased() })
        var results: [String] = []
        var seen = menuKeys

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

        chipSuggestions = Array(results.prefix(10))

        // Async: fetch scraped menu and patch in rich rows.
        Task { await loadMenuDishesAsync() }
    }

    /// Fetch scraped menu items for the current prefill and patch them
    /// into `menuSuggestions` as rich rows. Two paths:
    ///
    ///   • **Already-saved restaurant** — look up `googlePlaceId` directly
    ///     from the store. No network call.
    ///   • **First-time log** — resolve the Place ID via `PlacesResolver`
    ///     so chips render before the user even hits Save. The result is
    ///     stashed in `resolvedPlaceId` and threaded into `saveVisit()`
    ///     so `RestaurantStore.resolvePlaceIdIfNeeded` short-circuits
    ///     (avoids a duplicate Places API call, ~$0.017 per log).
    ///
    /// No-op if the resolver can't find a confident match — chips fall
    /// back to the curated/cuisine heuristics already loaded synchronously.
    private func loadMenuDishesAsync() async {
        let nameKey = selectedName.lowercased().trimmingCharacters(in: .whitespaces)
        guard !nameKey.isEmpty else { return }

        // Fast path: already-saved restaurant with a Place ID.
        var placeId: String? = nil
        if let match = store.restaurants.first(where: {
            $0.name.lowercased() == nameKey
        }), let cached = match.googlePlaceId, !cached.isEmpty {
            placeId = cached
            print("[MenuChips] '\(selectedName)' already has placeId=\(cached)")
        }

        // First-time-log path: resolve via Places API and cache the result
        // so saveVisit() can hand it to the new Restaurant record.
        if placeId == nil {
            let city = Restaurant.city(from: selectedAddress)
            print("[MenuChips] '\(selectedName)' needs Place ID — resolving (city=\(city))")
            guard let resolved = await PlacesResolver.shared.resolve(
                name: selectedName,
                city: city.isEmpty ? nil : city
            ) else {
                print("[MenuChips] Place ID resolve failed for '\(selectedName)' — menu suggestions skipped")
                return
            }
            placeId = resolved.placeId
            resolvedPlaceId = resolved.placeId
            print("[MenuChips] resolved '\(selectedName)' → '\(resolved.matchedName)' (conf=\(resolved.confidence), \(resolved.status.rawValue))")
        }

        guard let placeId else { return }
        print("[MenuChips] fetching menu for '\(selectedName)' (placeId=\(placeId))")

        // Pull the rich menu (name + description + price). Cap at 10
        // items — beyond that the picker gets overwhelming. The scraper
        // already orders by price desc so these are the mains.
        guard let menu = await MenuDataService.shared.menu(forPlaceId: placeId) else {
            print("[MenuChips] no menu returned for placeId=\(placeId) — 404 or empty file")
            return
        }
        let fresh = Array(menu.dishes.prefix(10))
        guard !fresh.isEmpty else {
            print("[MenuChips] menu fetched but contained no dishes for placeId=\(placeId)")
            return
        }
        print("[MenuChips] merging \(fresh.count) real dishes into picker")

        // Promote real menu items to the rich-row section, and prune any
        // chip suggestion that's now duplicated by a menu item (so the
        // user doesn't see "Lamb Seekh Kebab" as both a row and a chip).
        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.2)) {
                menuSuggestions = fresh
                let menuKeys = Set(fresh.map { $0.name.lowercased() })
                chipSuggestions.removeAll { menuKeys.contains($0.lowercased()) }
            }
        }
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
