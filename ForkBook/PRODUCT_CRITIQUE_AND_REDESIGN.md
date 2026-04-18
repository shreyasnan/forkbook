# ForkBook: Product Critique & Redesign

**Vision: Avoid bad meals. Trust your people.**

**Constraint: 4 tabs only — Home · Search · My Places · Table. No Taste tab. Taste is embedded everywhere.**

---

## 1. Sanity Check Against Vision

The vision is sharp: *avoid bad meals, trust your people.* Two jobs. One is defensive (don't waste a meal), the other is relational (lean on real people, not strangers). This should produce something that feels closer to asking a friend than searching a database.

**Where the current product is aligned:**

The recommendation engine is genuinely good. Trust-first scoring — weighting table reactions, dish convergence, recency, consensus — is the right architecture. The reason engine that produces lines like "Puneet and Pragya both rec the fried rice" is the kind of proof that actually changes behavior. The hero card + CTA hierarchy (Go here → I went here → Save) maps cleanly to the decide → commit → log loop. The planned strip ("✓ You're going") is a smart ambient commitment device.

**Where it drifts:**

The moment chips (Tonight, Lunch, Date Night, Group Dinner, Quick Bite, Special) are borrowed from generic discovery apps. They fragment an already sparse dataset. If your table has 30 restaurants and you filter by "Date Night" mapped to Italian/Japanese/French, you might surface 4 results — or zero. The chips suggest ForkBook has Yelp-depth data. It doesn't. It has trust-depth data. That's a different axis entirely.

The "Or these picks" carousel feels like a concession to browsing. If the hero card is your #1 recommendation, why do you need a horizontal scroll of alternatives? That's the Spotify "we're not sure what you want" pattern. ForkBook should be more like a friend saying "go here" — not "here are 6 options, you decide." The carousel dilutes conviction.

Search currently presents results like a discovery engine: restaurant cards with badges, proof lines, and full metadata. The two-tier split (table results vs. new-to-table) is correct, but the "New to Your Table" section at 65% opacity is still showing places nobody you trust has been to. That's exactly the "generic discovery" trap. If no one at your table has been somewhere, ForkBook's value proposition doesn't apply there. Showing those results undermines the trust thesis.

The Table tab (circle/member view) currently shows member cards with stats, top cuisines, latest visits. This is profile infrastructure — it's building toward a social app pattern (see who did what, browse their activity). The risk is clear: if Table becomes "what are my friends eating," it's a feed. If it stays "who do I trust for what," it's a decision tool.

The 5th tab (Taste) existing at all was a symptom of not knowing where to put preference data. Removing it is the right call. Taste as a separate destination implies it's something you visit and configure, like settings. But taste should be *felt* in every recommendation, every search result, every piece of context — not managed in a control panel.

**Bottom line:** The core decision engine is strong. The drift happens at the edges — moment chips adding complexity without utility, carousels encouraging browsing over deciding, search showing unvetted results, and the social layer trending toward feed patterns.

---

## 2. Re-Validate the 4-Tab Structure

### Home

**Single most important job:** Answer "Where should I eat right now?"

**What it should NOT contain:** Browsing. Exploration. Content that doesn't lead to a decision within this session. Social updates. Activity feeds. Anything that says "here are some options" instead of "go here."

**How it contributes to the core loop:** Home is the entry point for the decide → commit cycle. You open the app, see a recommendation you trust, and either commit ("Go here"), log ("I went here"), or save it for later. Every element on this screen should accelerate that decision. If something doesn't help you decide faster, it shouldn't be here.

### Search

**Single most important job:** Answer "What does my table know about [X]?"

**What it should NOT contain:** Generic restaurant discovery. Broad results from unknown sources. Anything that makes you feel like you're on Yelp or Google Maps. "New to your table" results should be minimal or absent — the whole point is that ForkBook's value comes from trusted signal.

**How it contributes to the core loop:** Search is the secondary decision path — you have something specific in mind (a cuisine, a dish, a neighborhood, a name) and you want to know what your trusted circle thinks. It should surface table knowledge first, your own history second, and broader options barely if at all.

**Overlap risk with Home:** Both are decision surfaces. The distinction is: Home is proactive (ForkBook tells you), Search is reactive (you ask ForkBook). This distinction must be clean. Home should never feel like "search results you didn't ask for."

### My Places

**Single most important job:** Answer "What do I know from my own experience?"

**What it should NOT contain:** Social information. What your friends think. Recommendations. Anything forward-looking that belongs on Home. Generic saved/bookmarked lists that feel like Pinterest boards.

**How it contributes to the core loop:** My Places is the memory layer that feeds the recommendation engine. Every visit you log here makes Home smarter. It should feel like your personal food diary — what you ate, how it was, what stood out — not a collection manager.

**Overlap risk with Home:** The "Go-tos" section currently appears on both Home and My Places (Visited → Your Regulars). That's fine as a shortcut on Home, but the canonical home for your visit history is My Places. Home should reference it lightly; My Places should own it.

### Table

**Single most important job:** Answer "Who do I trust, and what are they good for?"

**What it should NOT contain:** Activity feeds. Timeline of who went where when. Social browsing. Anything that turns Table into Instagram Stories for restaurants.

**How it contributes to the core loop:** Table is the trust configuration layer. It's where you manage who's in your circle, understand each person's strengths ("Puneet is your Indian food authority, Pragya knows brunch"), and see the collective knowledge that powers Home's recommendations. It should feel like knowing your friends' expertise — not scrolling their feed.

**Overlap risk with Home:** Table member knowledge already shows up on Home via trust lines ("Puneet loved it"), reason statements, and dish recommendations. Table should be the place where you *understand* that trust network; Home is where you *use* it.

---

## 3. Strengthen the Core Loop

The ideal loop has 6 stages. Each should be fast, low-friction, and compounding.

### Stage 1: Deciding Where to Go
**Current:** Open Home → see hero recommendation → read reason + dishes → decide.
**Problem:** Moment chips fragment data. Carousel encourages browsing. Too many signals compete for attention.
**Redesign:** Home opens with ONE clear recommendation. No filtering needed. The engine already accounts for time of day, your taste, proximity, and trust signals. If the pick isn't right, the user swipes/dismisses to the next one — but the posture is "here's your best option" not "here are your options." Kill the moment chips. Replace the carousel with a simpler "not feeling this?" action that promotes the next pick inline.

### Stage 2: Committing to a Place
**Current:** Tap "Go here" → CommittedPick saved → planned strip appears → hero swaps to closure state.
**This is already good.** The commitment creates accountability. The planned strip is a visible reminder. The closure hero ("How was it?") creates natural follow-through. Keep this exactly as-is.

### Stage 3: Knowing What to Order
**Current:** Detail page shows "What to order" with dish rows, recommender names, and reactions.
**Problem:** Dish information is buried in the detail page. You have to remember to open it at the restaurant. The planned strip shows "Get the [dish]" — that's the right instinct but it should be more prominent.
**Redesign:** When you've committed ("Go here"), the planned strip should expand into a mini order card: the 2-3 dishes to order, who recommended each, and their reaction. This is the "cheat sheet" you glance at when you sit down. It should be copyable/shareable.

### Stage 4: Logging Quickly
**Current:** "I went here" → inline edit mode → reaction + dish checkboxes + note → Save.
**Problem:** The edit mode has too many fields for a quick log. Reaction selection is good (one tap). Dish checkboxes with per-dish mini-reactions is over-engineered for the "capture first" philosophy. The note field is fine as optional. But the flow from "I went here" to "Save" has too many decision points.
**Redesign:** Minimum viable log = reaction (one tap) + save. That's it. Dishes and notes are "enrich later" — they should be available but clearly secondary. The reaction is the one signal that matters most for the recommendation engine. Don't gate the save behind anything else.

### Stage 5: Enriching Later
**Current:** No explicit "enrich" flow. If you logged a bare reaction, there's no nudge to add dishes or notes later.
**Redesign:** My Places should surface "incomplete" visits — visits with a reaction but no dishes logged. A gentle prompt: "You went to Lucali 3 days ago. What did you order?" This is where dish data and notes get captured, after the moment, when the memory is still fresh but the pressure is off.

### Stage 6: Strengthening Trust Over Time
**Current:** Implicit. More visits = better recommendations. More table members = more signal.
**Problem:** Users don't see the flywheel. There's no "your recommendations got better because Puneet logged 3 new places" moment.
**Redesign:** Home should occasionally surface a "trust dividend" — a brief, non-blocking signal that the system is getting smarter. "New from your table: Puneet tried 2 places this week" as a subtle line, not a card. This creates the feeling that the product compounds — which it does, but silently.

---

## 4. Critique Key Product Surfaces

### Home (Most Important)

**Moment Chips — Cut them.**

The moment chips (Tonight, Lunch, Date Night, etc.) are solving a problem ForkBook doesn't have. They assume a large enough dataset to meaningfully filter by occasion. With a typical table of 4-6 people and 30-50 restaurants, filtering by "Date Night" (Italian + Japanese + French) might return 5 results. Filtering by "Quick Bite" might return 3. The illusion of choice without the substance.

More fundamentally, moment chips push ForkBook toward the "what kind of experience do you want?" framing of discovery apps. ForkBook's frame is different: "your people vouch for this place." The trust signal is the filter. If Puneet loved a ramen spot, that's relevant whether you're looking for a date night or a quick bite.

**Replace with:** Time-of-day awareness baked into the scoring engine (it's mostly already there). If it's 7pm, boost dinner-oriented places. If it's noon, boost lunch. Don't make the user pick a moment — infer it. If the user wants to override (e.g., planning ahead for the weekend), a single subtle toggle or long-press could surface that, but it shouldn't be the default posture.

**Hero Recommendation Card — Strengthen conviction.**

The hero card currently shows: name, cuisine/location/price, context line, dish grid, trust line. That's a lot of information. The card is trying to be comprehensive when it should be *convincing.*

The most important elements, in order:
1. **The recommendation itself** — restaurant name, the ONE dish to order
2. **Why you should trust this** — who from your table vouches for it, and how strongly
3. **Practical context** — cuisine type, distance, price range

The dish grid (showing 3-4 dishes with emojis) is too much for the hero. The hero's job is to get you to tap. One dish — the lead dish — is enough. "Get the fried rice — Puneet and Aditya both loved it." Everything else belongs in the detail page.

**Revised hero hierarchy:**
- Eyebrow: one-line reason ("Puneet and Pragya both rec the fried rice")
- Name: large, bold
- Lead dish: gradient text, prominent
- Trust proof: "3 from your table · all loved it" or "Puneet's #1 spot"
- Meta: cuisine · distance · price (small, muted)
- CTA: "Go here" (primary), "More info ›" (secondary, opens detail)

**Backup Recommendations — Replace carousel with stack.**

The "Or these picks" carousel encourages horizontal browsing — a passive, noncommittal gesture. Instead, when the user dismisses the hero (swipe down, "Not tonight" tap, or explicit skip), the next pick should *become* the hero. Same card format, same conviction. The experience is: "Here's our pick. No? Okay, here's the next one." — not "here are 6 things, scroll through them."

This is the Hinge model (one card at a time, decide on each) vs. the Tinder model (swipe through a stack). ForkBook should be Hinge — deliberate, one-at-a-time decisions.

**Planned/Committed State — This is already good. Enhance it.**

The planned strip ("✓ You're going to Lucali — Get the calzone") is exactly right. It's a persistent ambient reminder that creates follow-through. The closure hero ("How was it?" with reaction buttons) is also correct — it closes the loop naturally.

Enhancement: when in committed state, the hero area should show the "cheat sheet" — the 2-3 dishes to order with who recommended each. This is the most useful information at that moment and it should be front and center, not buried in a detail page.

**Go-To Places — Keep but simplify.**

The horizontal "go-tos" row is useful as a shortcut to reliable spots. Keep it minimal: just name + visit count. It serves the "I don't want to think, just tell me somewhere safe" use case. This is a valid fallback when the recommendation engine doesn't have a strong pick.

**Revised Home Structure (top to bottom):**
1. Header ("Home" + avatar)
2. If committed: Expanded planned card with dish cheat sheet
3. If not committed: Hero recommendation (single card, high conviction)
4. "Not this? →" subtle action to advance to next pick
5. If table has new activity: one-line trust dividend ("New: Puneet tried 2 spots this week")
6. Your go-tos (compact row, max 4-5)
7. Empty state / invite nudge (if sparse data)

No moment chips. No carousel. No "Or these picks." One decision at a time.

### Search

**The problem:** Search currently behaves like a filtered version of Yelp. You type, you get results, you browse cards. The two-tier split (table vs. new-to-table) is structurally correct but the execution still feels like discovery.

**What Search should be in ForkBook:**

Search is "query your table's collective knowledge." It's not "find restaurants near me." The frame shift matters. When you search "pizza," you're asking "does anyone at my table know a good pizza spot?" — not "show me all pizza places in my area."

**Should it split "from your table" vs. "broader search"?**

Yes, but more aggressively than currently. "From your table" should be the default and primary view. "Broader search" should barely exist — maybe a single line at the bottom: "Nobody at your table has logged a pizza place yet. Ask them?" with an option to search externally. ForkBook should resist becoming a general search engine. Its value is zero for places nobody at your table knows.

**How results should prioritize:**
1. Your regulars matching the query (strongest signal — you've been there, you know it works)
2. Table members' strong recommendations (loved reactions, multiple visits)
3. Table members' other visits (liked, been there)
4. Your saved/planned places matching the query
5. Nothing else. No "new to your table." If ForkBook doesn't have trusted signal, it should say so honestly: "Your table hasn't tried [X] yet."

**How trusted people and dishes show up:**

Every search result should lead with the trust signal, not the restaurant metadata. Instead of:

> **Lucali** — Italian · Park Slope
> 🍕 The calzone
> Puneet, Pragya & Aditya have been here

It should be:

> **Lucali** — Puneet's go-to (4 visits, ❤️)
> Get the calzone — Puneet and Aditya both loved it
> Italian · Park Slope

The person and their conviction is the headline. The restaurant metadata is secondary. This is the inversion that makes ForkBook feel different from every other restaurant app.

**Revised Search structure:**
- Search bar: "Ask your table..." (framing matters)
- Pre-search: Recent queries + "Your table knows about: [cuisine tags derived from collective data]"
- Results: person-led cards, grouped by signal strength
- Empty results: "Your table hasn't tried [X] yet. Worth asking them?" — with a share/ask action
- No "New to your table" section

### Place Detail

**The page should answer, in order:**
1. Should I go here?
2. What should I order?
3. Who do I trust that recommends this?
4. What should I do next?

**Current state:** The detail page is well-structured but front-loads metadata (name, cuisine, location, price) before the trust signal. The reason statement is the most valuable element but it's positioned as a subtitle. The dish grid is comprehensive but not prioritized — lead dish doesn't stand out enough from the rest.

**Revised information hierarchy:**

**Top (decision zone):**
- Restaurant name (large)
- Reason statement as the primary subtitle: "Puneet and Pragya both rec the fried rice" — this is the headline, not metadata
- Overall trust signal: "3 from your table · 2 loved it" with small avatar dots

**Middle (order zone):**
- "What to order" — lead dish LARGE with gradient, clear attribution ("Puneet's pick, Aditya agrees")
- Secondary dishes in a simpler list
- If the user has been before: "You had: [their previous dishes]" with their own reaction

**Bottom (proof zone):**
- Individual table member takes: each person's reaction, what they ordered, when they went, any note
- This is the "dig deeper" section for people who want more evidence before deciding

**CTA hierarchy:**
1. **"Go here"** — primary. This is the main action. Bold, full-width, unmistakable.
2. **"I went here"** — secondary. Smaller, below primary. Only relevant if you've already been.
3. **"Save for later"** — tertiary. Text link or minimal button. Not competing with the primary action.

The current implementation has all three CTAs in a sticky bottom bar, which is correct. But the visual weight should be 70/20/10 — "Go here" dominates, "I went here" is visible, "Save" is understated.

**Context-aware CTA changes (already implemented, keep these):**
- From visited: "Log another visit" primary, no "Go here"
- From planned: "I went here" primary, "Remove from plan" secondary
- From saved: "Go here" primary, "I went here" secondary

### My Places

**The problem:** My Places currently has three segments (Visited / Planned / Saved) with card-based lists. It works, but it feels like a collection manager — three buckets you sort things into. It should feel like a *memory system* — a record of your food life that gets richer over time.

**The right structure:**

The three-segment model is fine as an organizational backbone, but the *visited* section needs the most rethinking. Currently it's a flat list of cards sorted by recency. That's a timeline, not a memory system.

**Visited should show:**
- **Your regulars** (top, horizontal) — places you go back to. Visit count + lead dish + your reaction. This is already implemented and correct.
- **Recent visits** (main list) — but with richer context per card:
  - Your reaction (emoji)
  - What you ordered (not just the restaurant's dish list — YOUR dishes from that visit)
  - Your note (if any)
  - When you went
  - Whether you'd go back (implicit from reaction: ❤️ = yes, 👍 = probably, 😐 = probably not)
- **Incomplete visits** (gentle nudge) — visits where you logged a reaction but no dishes. "You went to Lucali 3 days ago — what did you have?" This is the "enrich later" prompt.

**How this influences future decisions:** Every visit logged in My Places feeds the recommendation engine. The more complete your visit data (reaction + dishes + notes), the better Home gets at recommending. My Places should make this connection visible: "12 places logged · powering your recommendations."

**Planned should stay minimal.** Green-bordered cards with "I went ✓" and "Remove" inline actions. This is a short-lived list — things should flow through it quickly (saved → planned → visited). If things linger here, nudge: "You planned Lucali 2 weeks ago — did you go?"

**Saved should stay minimal.** Orange-tinted cards with "Plan this →" action. Saved is the low-commitment bucket. Don't over-design it.

### Table

**The problem:** The current Table view shows member cards with stats (places shared, top cuisines, latest visit). This is heading toward "social profile" territory. The risk is that Table becomes a place you browse — looking at what your friends are doing — rather than a place that helps you understand *who to trust for what.*

**How users should understand "who to trust for what":**

Each table member should have a clear **trust signature** — not a profile, but a compact summary of what they're good for. Instead of:

> **Puneet** — 12 places · 8 loved · Top: Indian
> Latest: ❤️ Boiling Beijing · today

It should be:

> **Puneet** — Your Indian food authority
> Knows: Indian (6 spots, all loved), Chinese (3 spots), Casual eats
> Best rec: Boiling Beijing ("the fried rice changed me")
> 12 places logged

The framing shifts from "activity stats" to "expertise profile." You look at Table to understand: who do I ask about what? Puneet = Indian. Pragya = brunch. Jay = date night. This is useful when you're deciding, not when you're browsing.

**How context-specific trust shows up:**

Instead of static stats, Table should surface trust by context:
- "For Indian food → ask Puneet (6 spots, all loved)"
- "For date night → Pragya knows 3 great spots"
- "For under $20 → Jay has 5 picks"

These context slices are more useful than raw numbers. They answer the implicit question: "I need a recommendation for [X] — who at my table would know?"

**How this supports decisions without becoming a feed:**

Table should NOT show a timeline of activity. No "Puneet went to Boiling Beijing today" cards. That's a feed. Instead, Table is a reference: you visit it when you want to understand your trust network, not to see what happened recently. New activity from members should surface on Home (as the "trust dividend" mentioned in the core loop section), not on Table.

**Revised Table structure:**
- Header: "Your Table" + invite action
- Trust summary: "6 people · 47 places · 14 cuisines covered"
- Member cards with trust signatures (expertise-framed, not activity-framed)
- Tap member → their expertise detail: cuisines they know, their top spots per cuisine, their strongest recommendations
- Pending requests (if any)
- "Invite someone" prompt at bottom

---

## 5. Re-Home "Taste" (No Tab)

Taste preferences (favorite cuisines, dining frequency) are currently collected during onboarding and editable from the Profile. Removing the Taste tab means this intelligence needs to be *felt* everywhere without being *managed* anywhere prominent.

### How Taste Appears in Home

**Module: Recommendation Scoring**
The scoring engine already boosts picks matching your top cuisines (+2 points for taste match). This should remain and potentially strengthen — if you've explicitly said you love Indian food, Indian recommendations should get a meaningful boost, especially when table signals are ambiguous.

**Module: Reason Personalization**
The reason engine should incorporate taste: "Your kind of spot — Indian, and Puneet loved it" vs. just "Puneet loved it." When taste alignment and trust signal converge, the reason statement should call it out. This makes the recommendation feel personally calibrated, not just socially sourced.

**Module: Empty State Intelligence**
When the engine has few recommendations, taste preferences can drive the fallback: "We don't have a strong pick tonight, but you love Indian — here's a go-to." This is better than showing a generic empty state.

**Why:** Home is where decisions happen. Taste should silently steer those decisions toward places that match your palate, amplifying trust signals in cuisines you care about.

### How Taste Appears in Search

**Module: Query Expansion**
When you search "dinner," taste preferences should influence which cuisines surface first. If you love Indian and Japanese, those results lead. This is implicit — no UI element needed, just smarter ranking.

**Module: Pre-Search Shortcuts**
The pre-search state currently shows "Try searching" shortcuts. These should be taste-informed: if you love Italian and Thai, the shortcuts should feature those cuisines with your table's data. "Italian (3 spots from your table)" appears because you love Italian AND your table has signal there.

**Why:** Search should feel like it already knows what you like. Taste preferences reduce the search space to what's relevant for you.

### How Taste Appears in My Places

**Module: Visit Pattern Insights**
My Places should occasionally surface a one-line insight: "You've been to 7 Indian spots — more than anything else." This isn't a chart or a dashboard — it's a brief observation that reinforces your taste identity. It should appear subtly, perhaps below the summary line.

**Module: Go-To Curation**
Your regulars row should implicitly weight toward your taste preferences. If you have 8 regulars but 5 are Italian, the display order should reflect that — your most aligned spots first.

**Why:** My Places is your food history. Taste should be reflected in how that history is organized and surfaced, showing you patterns you might not have noticed.

### How Taste Appears in Table

**Module: Taste Overlap Indicators**
On each member card, show taste alignment: "Shares your love of Indian and Japanese" or "Covers cuisines you don't: French, Korean." This helps you understand not just who to trust, but who fills gaps in your own experience.

**Module: Table Taste Map**
A compact view showing what cuisines your table collectively covers vs. what you love. "Your table is strong in: Indian, Italian, Chinese. Gap: Thai (nobody's been to a Thai spot)." This motivates inviting the right people and identifies blind spots.

**Why:** Table is the trust layer. Taste overlap between you and your table members is a key signal for how much their recommendations matter to you personally.

---

## 6. Logging Flow Critique

**Current flow:** "I went here" → reaction (4 options) → dish checkboxes with per-dish mini-reactions → add custom dish → quick note → Save.

**What's overbuilt:**

Per-dish mini-reactions (loved/liked/fine/skip per dish) are too much granularity for the "capture first" philosophy. Most users will not rate 4 individual dishes at the point of logging. This is "enrich later" data, not "capture now" data.

The add-custom-dish input field during logging is good but should be even simpler — just a text field, no button. Type, hit return, done.

Dish checkboxes as a mandatory-feeling step is friction. If the restaurant has 6 dishes from your table's data, seeing 6 checkboxes feels like a form to fill out, not a quick log.

**Minimum required flow (capture first):**
1. Tap "I went here"
2. Pick a reaction: ❤️ 👍 😐 👎 (one tap)
3. Tap "Save"

That's it. Three taps. Reaction is the single highest-value signal for the recommendation engine. Everything else is bonus.

**What should be optional (available but not prompted):**
- Dish selection (expandable section, collapsed by default)
- Quick note (expandable, collapsed by default)
- Per-dish reactions (only available in "enrich later" flow from My Places)

**What to preserve:**
- The reaction step is critical — keep the 4-emoji selector, it's fast and expressive
- The "dishes from your table" list is valuable context — show it during logging but don't require interaction with it
- The note field captures high-value qualitative signal — keep it available but never required

**Redesigned logging flow:**
1. Tap "I went here" → immediately show reaction selector (full-width, impossible to miss)
2. User taps reaction → "Save" button appears, plus collapsed "Add details" section
3. If they tap "Save" → done. 2 taps total.
4. If they tap "Add details" → dish checkboxes + note field expand
5. After adding details → "Save"

The key insight: don't make the user *decide* to skip the optional stuff. Default to the fast path. Let them opt *in* to detail, not opt *out* of it.

---

## 7. What to Cut or Simplify

### Cut

**Moment chips.** They fragment sparse data, add cognitive overhead, and push toward a discovery-app framing. The recommendation engine should infer context (time of day, day of week) without user input.

**"New to Your Table" search results.** If nobody at your table has been somewhere, ForkBook has nothing useful to say about it. Showing unvetted results undermines the trust thesis. Replace with: "Your table hasn't tried [X] yet — worth asking them?"

**Per-dish mini-reactions during quick logging.** Too granular for the capture-first philosophy. Move to the "enrich later" flow in My Places.

**Carousel ("Or these picks").** Encourages passive browsing instead of active deciding. Replace with sequential hero promotion — one pick at a time, dismiss to see the next.

**Activity timeline in Table.** Member cards should show expertise, not recent activity. "Puneet went to X today" is feed behavior. "Puneet is your Indian food authority" is trust intelligence.

### Simplify

**The logging flow.** Reaction (one tap) + Save should be the default. Dishes and notes are "add details" — available but collapsed.

**Place Detail CTA bar.** Three buttons is fine, but the visual hierarchy should be 70/20/10 — "Go here" is unmistakable, "I went here" is visible, "Save" is understated.

**My Places segments.** Three tabs are fine but the Visited section needs focus. Regulars row + recent visits + incomplete visit nudges. Don't over-structure it.

**Table member cards.** Replace activity stats with trust signatures. "12 places · 8 loved · Top: Indian" becomes "Your Indian food authority — 6 spots, all loved."

### Risk of Becoming a Social App

The Table tab is the highest-risk surface. Any feature that shows *when* someone did something (timestamps, "today," "3d ago") pushes toward feed behavior. Table should be about understanding expertise, not tracking activity. Similarly, any notification that says "Puneet just logged a visit" is social-app territory. Keep notifications to decision-relevant signals only: "Puneet tried a new Indian spot — see their take?"

### Risk of Becoming a Review App

Per-dish mini-reactions and detailed note-taking during logging push toward review behavior. ForkBook is not a place to write reviews. It's a place to log a quick signal ("loved it") and optionally note what was good ("the fried rice"). The moment you're rating individual dishes on a 4-point scale, you're writing a review. Keep the signal fast and coarse — the recommendation engine doesn't need fine-grained dish ratings to work well.

---

## 8. Output

### Product Thesis

ForkBook is a decision engine for meals, powered by the taste of people you actually trust. It answers one question — "where should I eat?" — using the collective experience of your small, curated table of friends. Every feature should make that answer faster, more confident, and more personalized over time. It is not a discovery app, not a review platform, not a social feed. It is the friend who always knows where to go.

### Clean 4-Tab IA

| Tab | Job | Key Surfaces |
|-----|-----|-------------|
| **Home** | Decide where to eat | Hero recommendation, committed/planned state with cheat sheet, go-tos |
| **Search** | Query your table's knowledge | Person-led results from table, taste-informed shortcuts, honest empty states |
| **My Places** | Remember your food life | Regulars, recent visits with enrichment nudges, planned/saved queues |
| **Table** | Understand who you trust | Trust signatures per member, taste overlap, expertise by cuisine/context |

### Ideal Core Loop

```
DECIDE → COMMIT → ORDER → LOG → ENRICH → COMPOUND
  ↑                                            |
  └────────────────────────────────────────────┘

1. DECIDE   Open Home → see trusted pick → read reason + lead dish
2. COMMIT   Tap "Go here" → planned strip appears → cheat sheet ready
3. ORDER    At restaurant → glance at planned card → know what to get
4. LOG      After meal → "I went here" → tap reaction → Save (2 taps)
5. ENRICH   Next day → My Places nudges "What did you order at Lucali?"
6. COMPOUND Your log feeds the engine → your table sees your take → 
            their future recs improve → your future recs improve
```

### Top 10 Product/UX Changes

1. **Kill moment chips.** Infer time-of-day context in the scoring engine. Don't ask the user to classify their meal occasion.

2. **Replace carousel with sequential hero.** One recommendation at a time. "Not this?" advances to the next pick. No horizontal browsing.

3. **Expand planned strip into a cheat sheet.** When committed, show the 2-3 dishes to order with attribution. This is the most useful state of the Home screen.

4. **Simplify logging to 2 taps.** Reaction + Save as default. Dishes and notes as expandable "Add details." Per-dish mini-reactions moved to enrich-later flow.

5. **Reframe Search as "Ask your table."** Lead results with trust signal (person + conviction), not restaurant metadata. Remove "New to Your Table" section.

6. **Add enrichment nudges to My Places.** Surface incomplete visits and prompt for dish data. This is where detailed logging happens — not in the moment.

7. **Reframe Table members as trust signatures.** "Your Indian food authority" not "12 places · 8 loved." Expertise over activity.

8. **Embed taste intelligence system-wide.** Taste-informed scoring, reason personalization, search ranking, and taste overlap indicators on Table — all without a dedicated tab.

9. **Add trust dividends to Home.** Brief, one-line signals when your table logs new places. "Puneet tried 2 new spots this week" — creates compounding awareness.

10. **Make the hero card more opinionated.** One lead dish, one trust proof line, one clear CTA. Less information, more conviction.

### What to Keep
- Trust-first recommendation engine (scoring + reason generation)
- CommittedPick → planned strip → closure hero flow
- Context-aware detail page with CTA changes per context
- Three-segment My Places (Visited / Planned / Saved)
- Regulars/Go-tos horizontal row
- Inline edit mode for "I went here" (vs. separate page)
- Dark theme with fb* design tokens
- Dish gradient text for lead dishes

### What to Simplify
- Logging flow (2 taps minimum, details optional)
- Hero card information density (fewer signals, more conviction)
- Search result cards (person-led, not metadata-led)
- Table member cards (trust signatures, not activity stats)
- Place Detail proof section (clearer hierarchy, less visual noise)

### What to Remove
- Moment chips (all 6)
- Carousel ("Or these picks")
- "New to Your Table" search results
- Per-dish mini-reactions during logging
- Activity timestamps on Table member cards
- 5th tab (Taste) — already decided, but confirm removal from ContentView.swift
- QuickLogView.swift (dead code, already disconnected)

### What to Elevate
- The reason statement (make it the hero card's headline, not a subtitle)
- Lead dish recommendation ("Get the fried rice" should be unmissable)
- Trust proof ("Puneet loved it" should be prominent, not a footer line)
- The committed/planned state (most useful state of Home, deserves more real estate)
- Enrichment as a first-class flow (My Places should actively prompt for missing dish data)

### Revised Home Structure

```
┌─────────────────────────────────┐
│  Home                      [👤] │  ← Header + avatar
├─────────────────────────────────┤
│                                 │
│  IF COMMITTED:                  │
│  ┌─────────────────────────────┐│
│  │ ✓ YOU'RE GOING              ││
│  │ Lucali                      ││
│  │                             ││
│  │ Order:                      ││
│  │ 🍕 The calzone — Puneet ❤️  ││
│  │ 🥗 Arugula salad — Pragya 👍││
│  │                             ││
│  │ [I went here]   [Cancel]    ││
│  └─────────────────────────────┘│
│                                 │
│  NEXT UP                        │
│  ┌─────────────────────────────┐│
│  │ Puneet & Pragya both rec    ││  ← Reason as headline
│  │ the fried rice              ││
│  │                             ││
│  │ Boiling Beijing             ││  ← Name
│  │ 🍚 Get the fried rice      ││  ← Lead dish, gradient
│  │ Chinese · 0.8 mi · $$      ││  ← Meta (small)
│  │                             ││
│  │ [Go here]                   ││  ← Primary CTA
│  │ Not this? →                 ││  ← Advances to next pick
│  └─────────────────────────────┘│
│                                 │
│  IF NOT COMMITTED:              │
│  (Hero card is the top element) │
│                                 │
│  ── New from your table ──────  │
│  Puneet tried 2 spots · see →   │  ← Trust dividend (subtle)
│                                 │
│  YOUR GO-TOS                    │
│  [Lucali 4x] [Raku 3x] [...]   │  ← Compact row
│                                 │
└─────────────────────────────────┘
```

### Revised Search Strategy

```
┌─────────────────────────────────┐
│  🔍 Ask your table...           │  ← Reframed placeholder
├─────────────────────────────────┤
│                                 │
│  PRE-SEARCH:                    │
│  Recent: Boiling Beijing, pizza │
│                                 │
│  Your table knows about:        │
│  [Indian 6] [Italian 4]        │  ← Taste-informed tags
│  [Chinese 3] [Japanese 2]      │    with result counts
│                                 │
│  POST-SEARCH ("pizza"):         │
│                                 │
│  FROM YOUR TABLE                │
│  ┌─────────────────────────────┐│
│  │ Lucali — Puneet's go-to     ││  ← Person-led framing
│  │ (4 visits, ❤️)               ││
│  │ Get the calzone             ││
│  │ Italian · Park Slope        ││
│  └─────────────────────────────┘│
│  ┌─────────────────────────────┐│
│  │ Di Fara — You ❤️ (3 visits) ││
│  │ The square slice            ││
│  │ Italian · Midwood           ││
│  └─────────────────────────────┘│
│                                 │
│  If no results:                 │
│  "Your table hasn't tried any   │
│   pizza spots yet. Ask them?"   │
│  [Share with table]             │
│                                 │
└─────────────────────────────────┘
```

### Revised Place Detail Structure

```
┌─────────────────────────────────┐
│  ‹ Back                    ✕    │
├─────────────────────────────────┤
│                                 │
│  DECISION ZONE                  │
│  ─────────────────              │
│  Boiling Beijing                │  ← Name (large)
│  Puneet & Pragya both rec       │  ← Reason (primary, prominent)
│  the fried rice                 │
│  Chinese · East Village · $$    │  ← Meta (small, muted)
│  ●●● 3 from your table         │  ← Trust dots
│                                 │
│  ORDER ZONE                     │
│  ─────────────────              │
│  What to order                  │
│  🍚 Fried rice ← THE MOVE      │  ← Lead dish (gradient, large)
│     Puneet ❤️ · Aditya ❤️       │
│     "best fried rice in NYC"    │
│                                 │
│  🥟 Pork dumplings             │  ← Secondary dishes
│     Pragya 👍                   │
│  🍜 Dan dan noodles            │
│     You 👍 (last time)          │
│                                 │
│  PROOF ZONE                     │
│  ─────────────────              │
│  Puneet — ❤️ · 3 visits         │
│    "incredible every time"      │
│  Pragya — ❤️ · 2 visits         │
│  Aditya — 👍 · 1 visit          │
│                                 │
├─────────────────────────────────┤
│  [████ GO HERE ████]            │  ← Primary (dominant)
│  I went here    Save for later  │  ← Secondary + tertiary
└─────────────────────────────────┘
```

### Revised My Places Structure

```
┌─────────────────────────────────┐
│  My Places                      │
│  12 visited · 2 planned · 4    │
│  saved · powering your recs     │  ← Connection to engine
├─────────────────────────────────┤
│  [Visited] [Planned] [Saved]    │
├─────────────────────────────────┤
│                                 │
│  VISITED TAB:                   │
│                                 │
│  YOUR REGULARS                  │
│  [4× Lucali] [3× Raku] [...]   │
│                                 │
│  ADD DETAILS?                   │  ← Enrichment nudge
│  You went to Raku 3 days ago.   │
│  What did you order?  [Add →]   │
│                                 │
│  RECENT VISITS                  │
│  ┌─────────────────────────────┐│
│  │ ❤️ Boiling Beijing · 2d ago ││
│  │ 🍚 Fried rice, 🥟 Dumplings ││
│  │ "best fried rice ever"      ││
│  └─────────────────────────────┘│
│  ┌─────────────────────────────┐│
│  │ 👍 Raku · 5d ago            ││
│  │ (no dishes logged)          ││  ← Subtle incompleteness
│  └─────────────────────────────┘│
│                                 │
│  PLANNED TAB:                   │
│  (same as current — green       │
│   cards with I went ✓ / Remove) │
│                                 │
│  SAVED TAB:                     │
│  (same as current — orange      │
│   cards with Plan this →)       │
│                                 │
└─────────────────────────────────┘
```

### Revised Table Concept

```
┌─────────────────────────────────┐
│  Your Table                     │
│  6 people · 47 places ·        │
│  14 cuisines covered            │
├─────────────────────────────────┤
│                                 │
│  YOUR TABLE KNOWS               │
│  Indian (8) · Italian (6) ·    │  ← Collective coverage
│  Chinese (5) · Japanese (4)    │
│  Gap: Thai, Korean              │  ← Blind spots
│                                 │
│  MEMBERS                        │
│  ┌─────────────────────────────┐│
│  │ 🟠 Puneet                   ││
│  │ Your Indian food authority  ││  ← Trust signature
│  │ 6 Indian spots, all loved   ││
│  │ Also knows: Chinese, Casual ││
│  │ Best rec: Boiling Beijing   ││
│  │ Shares your taste in:       ││
│  │ Indian, Chinese             ││  ← Taste overlap
│  └─────────────────────────────┘│
│  ┌─────────────────────────────┐│
│  │ 🟣 Pragya                   ││
│  │ Your brunch & Italian guide ││
│  │ Best rec: Lucali            ││
│  └─────────────────────────────┘│
│                                 │
│  PENDING REQUESTS               │
│  (if any)                       │
│                                 │
│  [Invite someone to your table] │
│                                 │
└─────────────────────────────────┘
```

---

*This document is a product critique, not a specification. Implementation should adapt these principles to engineering constraints and test assumptions with real user behavior. The north star remains: avoid bad meals, trust your people.*
