# ForkBook UX Audit — Vision Alignment

Audited against `product_vision.md`. Goal: every screen justifies its existence, every tap is the natural next step, users spend the least time possible in the app, and logging feels like a natural part of deciding — not a chore.

Updated after founder review. This is now the locked working direction for the next iteration.

---

## 1. Profile: important but secondary

The product vision defines five screen roles: Home (Decide), Search (Find), My Places (Remember), Table (Trust), and Profile (Taste identity). The current tab bar has four tabs. Profile is accessed via a navigation push from Home's toolbar.

**Diagnosis:** Profile matters — it's your taste identity, not account settings. But five roles does not mean five tabs need equal navigation prominence. Profile is something you check occasionally, not at every meal decision. Making it a 5th tab could make the app feel heavier than it needs to.

**Decision:** Keep Profile as a secondary surface for now. It's reachable, well-built, and serves its role. Only promote to a tab if testing shows people need frequent direct access.

**Still do:** Move settings (sign out, edit username, privacy links) behind a gear icon or into a separate sheet so the Profile screen feels like taste identity, not an account page.

---

## 2. Home screen is doing too much

The Home screen currently has 7 sections: decision header, moment chooser, hero recommendation, more picks, latest from table, your reliable spots, and a log nudge. That's a lot of scrolling for a screen whose job is to answer one question: *"Where should we go right now?"*

**What to cut:**

**a) The log nudge.** The vision says "Decisions over posting" and Home = Decide. A log nudge on the decision surface pulls attention from deciding toward capturing. Remove it from Home entirely. Logging should be triggered post-decision (see section 7 below), not mid-browse.

**b) "Latest from your table" as a raw activity feed.** Showing what your friends recently logged is interesting, but a raw feed is not a decision tool. The question isn't "what did my friends eat recently?" — it's "what should *I* eat tonight?" However, recent friend activity is extremely valuable when transformed into recommendation signal. "Puneet loved the dosa here last week" is a great reason to recommend a place. So: don't show a "Latest from table" module. Instead, absorb recent friend activity into the recommendation logic so it strengthens picks rather than sitting beside them.

**What to keep (but make smaller):**

**c) "Your reliable spots."** The original audit said remove this, but reliable spots are actually one of the strongest "avoid bad meals" patterns in the product. A trusted app should be allowed to say: "here are your proven safe bets." Keep it, but make it compact (a small row, not a hero section), clearly tied to the current moment, and positioned below the recommendations so it doesn't compete with the trust-first hero pick.

**Rebuilt Home structure:**
1. Moment chooser
2. One strong recommendation (hero)
3. 2–3 secondary picks
4. One small reliable-spots row
5. Nothing else

**Critical: the hero and picks must be rich, not just present.** A slimmed-down Home only works if each card carries real decision weight. Every recommendation should show: who recommends it, why it fits the moment, what to order, and why it's a safe bet. Without that density of reason, Home becomes elegant but underpowered — a prettier list instead of a decision tool.

---

## 3. Consolidate logging into one flow

There are currently three ways to add a restaurant:

1. **AddPlaceFlow** — 5-step guided Q&A (pick place → did you go? → how was it? → saved → enrich)
2. **QuickLogView** — 4-step flow (search → how was it? → saved → enrich)
3. **AddRestaurantView** — traditional form with fields

This creates cognitive overhead. A user tapping "+" in different parts of the app gets different flows. They shouldn't have to think about *which* logging experience they're in.

**Specific issue with AddPlaceFlow:** The "Did you go?" step is an unnecessary fork. If someone is logging a place, the vast majority of the time they went. This extra step slows down the most common path.

**Decision:** Consolidate to one logging flow everywhere: *select restaurant → reaction → saved → optional enrichment.* Three taps to log. This matches the vision's required flow exactly (select restaurant, how was it, save). The "did you go?" fork should be removed from the logging path. Wishlist adds should be a separate, clearly labeled action — a "save for later" button on recommendation cards or search results, not a branch inside logging.

---

## 4. Search should lead with trusted signal, not logging

The vision says Search = Find. It should help users "look up a restaurant and get trusted signal." But currently, tapping a search result immediately launches QuickLogView — a logging flow. The assumption is that searching means you want to log, but often a user is searching to *decide*: "Has anyone at my table been to this place? What should I order there?"

**Decision:** When a user taps a search result, show trusted signal first — who from your table has been there, what they thought, what to order. Then offer clear next actions: "I went here" (log), "Save for later" (wishlist), or "Get directions." The default action from search should be information, not capture.

---

## 5. Table should be a trust map, not a member list

The vision says Table should answer: "Who do I trust for date night? Who is good for family meals? Who usually knows the right casual spot?" The current Table screen shows a member list sorted by contribution count, with their top cuisines and sample restaurants. It answers "who is in my circle and what have they shared" — but not "who should I listen to for *this* kind of meal?"

**Decision:** Organize members by what they're good for, not just who they are. Surface tags like "Great for date night" or "Knows casual spots" derived from their logging patterns. When a user is on the Table screen, they should be able to see trust by context, not just trust by volume.

---

## 6. My Places — mostly aligned, keep wishlist as secondary mode

My Places is the closest to vision alignment. The timeline is visit-based, chronological, and personal. The "Go back to these" section is useful. The warm sentence-style summary works.

**On wishlist:** The original audit said to separate wishlist entirely from My Places. But users often mentally group "where I've been" and "where I want to go" as part of one personal restaurant memory layer. Completely separating them feels architecturally clean but behaviorally unnatural.

**Decision:** Keep My Places primarily as visited history. "Want to try" stays as a secondary filter or subview — clearly subordinate to the visited timeline, but still accessible in the same place. The hierarchy should make it obvious that visited history is the primary content.

---

## 7. Logging should feel like a natural ending to a decision

The vision's core loop is: **Invite → decide → log → strengthen the trust graph.** Right now, deciding and logging are disconnected experiences. You decide on Home, then you have to go find the "+" button or navigate to Search to log.

**Decision:** After a user taps a recommendation and goes to the restaurant, the most natural next step is logging that visit. The recommendation detail sheet already has an "I went here" button — good. Make the loop tighter: the next time the user opens the app after viewing a recommendation, surface a gentle "How was [restaurant]?" prompt at the top of Home. One tap to react, done. Logging becomes a 2-second closure to a decision, not a separate workflow.

**Calibration:** This prompt should be used carefully. Only show it when confidence is high (the user clearly engaged with a recommendation recently), don't show it too often, and make sure it feels like closure — not nagging. Treat this as something to test carefully rather than ship broadly.

---

## 8. Note on sparse data (early product reality)

Some of these recommendations assume a rich trust graph — multiple table members, lots of shared restaurants, clear patterns to derive trust domains. In the early product, data will be sparse. A few "bridging" modules that aren't perfectly pure but help the product feel alive may be necessary. For example, reliable spots may carry more weight on Home when trust-circle data is thin. The structural direction above is right, but implementation should be sensitive to what the product can actually show at each stage of data density.

---

## 9. Open problem: recommendation ranking logic

This audit clarifies what each screen should show, but it does not yet solve *how* recommendations should be ranked and explained. That is the next layer, and it's where the app's real power will come from.

Questions that need answers:

- When should personal history win over trusted-friend signal? (e.g., you loved this place vs. your friend loved this place)
- When should reliability beat novelty? (e.g., your proven go-to vs. a place your table is excited about)
- How should "good for tonight" differ from "you loved this before"? (moment fit vs. personal track record)
- How should friend activity recency factor in? (Puneet went last week vs. Puneet went six months ago)
- What happens when the trust graph is too thin to generate a strong hero pick?

These are not UX questions — they're ranking and signal-weighting questions. They should be addressed in a separate recommendation logic doc before the Home rebuild, because the quality of those picks is what makes the slimmed-down Home work or fail.

---

## Action plan

| Priority | Area | Change |
|----------|------|--------|
| **P0** | Home | Rebuild: moment chooser → hero → secondary picks → small reliable-spots row. Remove log nudge and raw table activity feed. |
| **P0** | Logging | Consolidate to one flow: select → react → save → optional enrich. Remove "Did you go?" fork. |
| **P0** | Search | Tap result → show trusted signal first, then offer log/save/directions. |
| **P1** | Table | Rework around trust domains ("good for what") instead of contribution count. |
| **P1** | Loop | Post-visit prompt on next app open: "How was [restaurant]?" |
| **P2** | My Places | Keep wishlist as secondary filter, ensure visited timeline is clearly primary. |
| **P2** | Profile | Move settings behind gear icon. Keep as secondary navigation for now. |

---

*The north star for every change: the user opens the app, gets a trusted answer, acts on it, and closes the app. Logging happens as a natural side effect of that loop — not as a separate chore.*
