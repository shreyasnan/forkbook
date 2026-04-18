# ForkBook — Screen Text Audit

A pass across the four test screens (Home, Search, My Places, AddPlace flow) looking for copy that is either redundant, overly explanatory, or duplicative of signals the user can already see. Grouped by screen, with a short recommendation for each item.

The theme across all four screens: we over-explain. A good heuristic — if the label tells the user what the UI already shows, or tells them how the app "thinks," cut it.

## 1. Home

### Committed pick card ("Your plan")
File: `HomeTestView.swift` ~L220–L267

- **Eyebrow "YOUR PLAN"** — keep. Anchors the card.
- **Meta line: "Italian · Saved 3h ago"** — cut the "Saved" prefix. Just show "3h ago". We already know it's saved because the card exists.
- **"Don't forget the <dish>"** — too chatty. Change to just `<dish>` (styled prominently like a hero-dish), or `"Get the <dish>"` to match the language used elsewhere. Removes the finger-wag.
- **"Did you end up going?"** — cut entirely. The three buttons (Yes, Not yet, Changed my mind) already convey the question. Header + 3 clear CTAs is enough.
- **"Yes — log my visit"** → `"Yes"` or `"Log visit"`. Picking one verb is cleaner.

### Empty state
File: `HomeTestView.swift` ~L420–L471

There are up to **four** variants of the 2-line empty state based on whether the user has logs and friends. Most users will only ever see one. They're also long:

- **"Log a few places or invite your circle — ForkBook gets sharper with every entry."** — collapse to `"Log a few places to get picks."` The "sharper with every entry" is marketing copy that the empty state doesn't need.
- **"Your circle has logs, but we need yours too. Add a place you've been."** — `"Add a place you've been to get picks."` One sentence, action-first.
- **"Your circle hasn't logged anything recent. Nudge them to share what they've been eating."** — `"Your circle is quiet. Nudge them to log."` Cuts the prose.
- **"Use the Search tab to find a place, then tap 'I went here' to log it."** — this is instructional scaffolding. Keep only if the title is ambiguous; otherwise cut. A cleaner title like `"Add your first place"` paired with a single CTA-style line is enough.

Empty state usually only needs: a short title + one action. Two lines of body copy + a nudge line is three too many.

### "PICKS YOU MAY LIKE FOR <TIME>" section header + subhead
File: `HomeTestView.swift` ~L406–L418, L117–L132

- The uppercase label + "New to you" subhead read as two stacked explanations. Either pick the implied framing in the eyebrow (`"NEW PICKS FOR DINNER"`) or keep "PICKS YOU MAY LIKE" without the subhead. Right now they fight each other.

### Hero card eyebrows
File: `HomeTestView.swift` ~L1331–L1347

- **"YOUR TABLE'S PICK FOR DINNER"** — `"YOUR TABLE · DINNER"` reads cleaner.
- **"YOUR TABLE KEEPS ORDERING THIS"** — fine, but long. `"YOUR TABLE ORDERS THIS"` is tighter.
- **"FRESH FROM YOUR TABLE"** — fine.
- **"STRONG PICK"** — vague. Consider cutting entirely when we have no better eyebrow; a missing eyebrow is better than filler.

### Detail sheet: "FROM YOUR TABLE" / changed-confidence chip
File: `HomeTestView.swift` ~L820–L830

- Changed-confidence phrases like `"+3 logs this week"`, `"Back here this week"` — these are good. Keep.
- But paired with the per-friend breakdown right above, they become redundant when the per-friend rows already show recency like "yesterday", "3 days ago". Hide the chip when friend breakdown is showing.

## 2. Search

### Default state section heading
File: `SearchTestView.swift` ~L353

- **"WHAT SOUNDS GOOD?"** — fine, but the placeholder in the search bar (`"What are you in the mood for?"`) already asks the same question. One of them can go. Keep the placeholder (it's higher-signal), drop the heading.

### No-results copy
File: `SearchTestView.swift` ~L779–L792

- **"Nothing from your table"** title + **"No one in your table has logged a match. Try a different dish, cuisine, or neighborhood."** — compress to title: `"No matches"` + body: `"Try a different dish or cuisine."` We don't need to re-explain the data model.

### Detail sheet: trust line
File: `SearchTestView.swift` ~L849

- `"Picked by Pragya & Puneet"` / `"Picked by 3 from your table"` — good. Keep.
- But when it's stacked above the dish and reasoning text, the detail sheet has 4+ lines of prose before any action. Consider moving the trust line to directly follow the restaurant name as a subtitle instead of floating between the dish and the CTA.

### "I went here" → "Save for later" cluster
File: `SearchTestView.swift` ~L886–L924

- Three CTAs stacked is a lot. The tertiary `"Save for later"` is rarely used and crowds the decision space. Consider dropping it or surfacing it as a long-press gesture on "Go here". One primary + one secondary reads cleaner.

### "Also try: <dish>"
File: `SearchTestView.swift` ~L552, L842

- Good prefix. But when the hero dish is already highlighted in warm accent, `"Also try"` becomes the only thing on the line. Consider inline: `"<hero> · <second>"` (dot-separated) or just drop if the second dish name is generic.

## 3. My Places

### Header block (already cut previously)
- Subtitle was removed. Good.

### Search helper cycling text
File: `MyPlacesTestView.swift` ~L167–L178

- **"Try: 'ramen', 'best in SF', or 'where should I take Maya'"** — three examples is one too many. Two feels less like a feature demo: `"Try: 'ramen' or 'best in SF'"`. The "where should I take Maya" example teaches the social-context pattern, but it's also the most likely to confuse.

### Empty state
File: `MyPlacesTestView.swift` ~L190–L203

- **"Add places you've been and ForkBook will help you remember what you loved."** — cut the "help you remember what you loved" — it's marketing. `"Add places you've been."` is enough.

### Ask ForkBook escalation row
File: `MyPlacesTestView.swift` ~L325–L332

- The row shows title "Ask ForkBook" and quoted query below it. The quoted query is redundant with what the user just typed in the search bar — they already see it there. Consider dropping the subtitle and just showing "Ask ForkBook" with the arrow.

### "No matches" / "Nothing in your places matches — ask above to look broader"
File: `MyPlacesTestView.swift` ~L282–L291

- These two variants are nearly identical. One line, either `"No matches"` or `"No matches — try a different query."` Cut the "ask above" callout; the Ask row already does that work visually.

### Place detail: "Get the <lead> +2 more"
File: `MyPlacesTestView.swift` ~L542, L656–L661

- Good. Keep.

### "Also try: <dish1>, <dish2>"
File: `MyPlacesTestView.swift` ~L661

- When shown alongside the lead dish line above, you end up with:
    - "Get the Spicy Garlic Miso Ramen"
    - "Also try: Avocado Roll, Agedashi Tofu"
- Two lines of dish guidance feels heavy. Consider collapsing to: `"Spicy Garlic Miso · Avocado · Agedashi"` — tighter, dot-separated rhythm matches the Home hero card.

## 4. AddPlaceTestFlow (log a meal)

### Step 1: "What did you have?" header
File: `AddPlaceTestFlow.swift` ~L173–L188

- **Subtitle is the restaurant name** — good. Keep.
- No cuts here.

### "SELECTED DISHES" section label
File: `AddPlaceTestFlow.swift` ~L205

- Cut. If there are rows below the chip cloud, the user already knows what they are. Adding an uppercase label just because we have space isn't necessary. A blank 20pt gap is enough separation.

### State pills: "Amazing / Okay / Skip"
File: `AddPlaceTestFlow.swift` ~L346–L348

- Fine. Keep.

### Step 2: "Anything to remember?"
File: `AddPlaceTestFlow.swift` ~L397–L403

- **"Optional · a note for next time"** — cut. The title itself is optional-sounding ("Anything to remember?" invites nothing as a valid answer) and the TextEditor placeholder "Rich broth, perfect egg…" shows the intent. Two pieces of supporting copy for one field is too much.

### Note suggestions
File: `AddPlaceTestFlow.swift` ~L437–L439

- **"Jay ordered for us", "Great quick lunch spot", "Skip the ramen next time"** — 3 suggestions is fine. If trimming, drop "Skip the ramen next time" — it's a negative framing and the note field's whole point is remembering what to get, not what to skip.

### Step 3: "Saved" screen
File: `AddPlaceTestFlow.swift` ~L508–L567

- **"Saved"** (title) + restaurant name + **"Added to your places"** (subtitle) — drop "Added to your places". The "Saved" title + checkmark + restaurant name already communicate that. Three lines of text on a confirmation screen is too much.
- **"You keep coming back here"** + **"Mark as go-to"** + **"Not now"** — keep. This is a real decision moment.

### Go-to nudge: "Mark as go-to" / "Not now"
- Keep. Clean pair.

## Cross-cutting patterns to watch

1. **Explaining the app's logic.** Phrases like "ForkBook gets sharper with every entry" and "New to you" subheads narrate what the app is doing. Users don't need narration.
2. **Double-prompting.** Header + subheader + placeholder often triple-ask the same question. Pick one.
3. **Three CTAs stacked.** Most detail sheets have Primary + Secondary + Tertiary. Tertiary is almost always unused and takes up decision space. Default to two.
4. **Uppercase labels on every section.** Useful for scanability on dense screens. But when a section is one-card-tall, the label is just visual noise. Use uppercase labels only when they group 2+ items.
5. **Negative framing.** "No one has logged", "Nothing in your places matches", "Skip the ramen next time" — several negatives across the UI. Rewording to neutral or affirmative reads less defensive.

## Suggested first round of cuts (high confidence, low risk)

If I had to pick 10 things to cut first, these would have the clearest wins with the least interpretive risk:

1. Home committed pick — drop "Did you end up going?" prompt line.
2. Home committed pick — drop "Saved" prefix in the meta line.
3. Home empty state — rewrite four variants as one-line calls to action each.
4. Home section subhead "New to you" — drop.
5. Search default heading "WHAT SOUNDS GOOD?" — drop (placeholder carries it).
6. Search no-results — compress to title + one-line body.
7. My Places empty-state body — drop second half of the sentence.
8. My Places search helper — drop the third example.
9. AddPlace step 2 — drop "Optional · a note for next time".
10. AddPlace saved screen — drop "Added to your places".
