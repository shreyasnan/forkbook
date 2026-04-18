# ForkBook — Remaining Views Redesign Spec

## Status Map

| View | Status | Notes |
|------|--------|-------|
| HomeTestView | ✅ Done | Hero card decision surface + ALSO GREAT |
| SearchTestView | ✅ Done | Decision-engine search with Best Match / From Table / Worth Trying |
| MyPlacesTestView | ✅ Done | Memory-first cards, verdicts |
| AddPlaceTestFlow | ✅ Done | Dish-first logging with Amazing/Okay/Skip |
| **LaunchScreenView** | 🔴 Needs redesign | Current: generic splash with orange circle |
| **SignInView** | 🔴 Needs redesign | Current: generic auth screen |
| **InviteOnboardingView** | 🔴 Needs redesign | Current: feature list + cuisine grid |
| **TableView** | 🟡 Needs polish | Current: functional but not aligned with new design language |
| **ProfileView** | 🟡 Needs polish | Current: functional, decent structure, needs visual alignment |

---

## 1. LaunchScreenView (App Start / Splash)

### What it is now
Orange circle with fork.knife SF Symbol, "ForkBook" in rounded bold, "Your restaurant journal" subtitle. Spring scale-in animation. Generic, could be any food app.

### What it should be

**Philosophy:** The first 1.5 seconds set the emotional tone. This isn't a loading screen — it's the opening frame of the experience. It should feel premium, dark, warm, and private. Not "food app" — "your inner circle for food."

**Visual:**
- Background: pure black (#000000), no gradients
- Center element: the word "ForkBook" in 32pt heavy, tracking -0.5, white — no icon, no circle, no fork.knife symbol
- Below the name: a single warm line like "Where your table eats" or "Your table's picks" in 14pt medium, warmAccent (#C4A882), opacity 0.7
- No logo icon. The name IS the brand. Let it breathe
- Entry animation: fade from black over 0.4s, slight scale from 0.97 → 1.0 with ease-out. Understated, not bouncy
- Exit: crossfade to SignInView or ContentView over 0.3s

**What to avoid:**
- Orange circles, gradient icons, SF Symbols
- Rounded/playful fonts — use system heavy, same as the rest of the app
- "Your restaurant journal" — that's a utility description, not a feeling
- Bouncy spring animations — this is a premium dark app, not a kids' game

---

## 2. SignInView (Authentication)

### What it is now
Orange circle icon, "ForkBook" in rounded bold, "Discover restaurants through people you trust" subtitle, Apple Sign-In button, "Continue as Guest" secondary button. Standard auth layout.

### What it should be

**Philosophy:** This screen's job is one thing: get you signed in. It should feel like walking into a private club — dark, minimal, confident. Not "sign up for our product."

**Layout (top to bottom):**
- Top 40% of screen: breathing room. Just the name
  - "ForkBook" — 34pt heavy, tracking -0.5, white, centered
  - Below: "Your table's picks" — 15pt medium, warmAccent (#C4A882), opacity 0.7
  - Generous top padding (~40% from top of screen)
- Bottom cluster (anchored to bottom safe area + 50pt):
  - Apple Sign-In button — full width at horizontal padding 32, height 52, white style, cornerRadius 14
  - 12pt gap
  - "Continue as Guest" — 14pt medium, dimGray (#6B6B70), plain text button (no background, no border)
  - Error text if present: 13pt, fbRed, below guest button
- No feature highlights, no illustrations, no icons

**Design tokens:**
- Background: pure black
- No card backgrounds, no surfaces — just black
- The only color besides white and gray is the warm accent tagline
- Apple button uses .whiteOutline style for better contrast on dark

**What to avoid:**
- Feature descriptions or value props — that's onboarding's job
- Orange circles or gradient icons
- FBPrimaryButtonStyle for Apple button — use native SignInWithAppleButton
- Multiple CTAs competing for attention

---

## 3. InviteOnboardingView (First-Launch Flow)

### What it is now
Three steps: Welcome (icon + feature list) → Light Prefs (cuisine grid with numbered chips) → First Action. Uses orange gradient circle, bullet-point features in a card, emoji-heavy cuisine grid. Functional but feels like a setup wizard.

### What it should be

**Philosophy:** Onboarding should feel like a friend explaining how this works over dinner — warm, quick, not a product tour. Three screens max. The goal: understand the concept (trust-based recs), tell us one thing about yourself (what you eat), then get into the app.

### Step 0: Welcome

**Layout:**
- Full black background
- Centered vertically (slight top bias):
  - "Welcome, {firstName}" — 28pt heavy, white
  - 8pt gap
  - "ForkBook is how your table decides where to eat." — 16pt medium, mutedGray (#8E8E93), centered, max 2 lines
  - 32pt gap
  - Three short value lines, no cards, no icons:
    - "Your friends log where they eat" — 14pt medium, dimGray
    - "You see what they actually recommend" — 14pt medium, dimGray
    - "No strangers. No algorithms. Just your people." — 14pt medium, warmAccent, opacity 0.8
  - These three lines are left-aligned within a centered block, 10pt line spacing between them
- Bottom: "Get started" button — full width, warmAccent fill 0.18, warmAccent border 0.35, 16pt bold white text, cornerRadius 14
- Below button: "Skip" in 13pt dimGray, plain

**What's different:**
- No icon/logo at all — they already saw it on LaunchScreen and SignIn
- No feature cards with SF Symbols — those feel like an App Store listing
- The three value lines ARE the explanation, delivered in plain language
- The last line in warm accent creates a subtle emotional anchor

### Step 1: What do you eat?

**Layout:**
- "What do you eat?" — 24pt heavy, white, left-aligned, padded horizontal 20
- "Pick a few. Helps us match you." — 14pt medium, mutedGray, below title
- 20pt gap
- Cuisine chips in a 3-column grid:
  - Selected: warmAccent.opacity(0.15) fill, warmAccent.opacity(0.4) border, white text
  - Unselected: cardBg (#131517) fill, white.opacity(0.05) border, mutedGray text
  - Each chip: cuisine name only — 14pt semibold, no emojis, no numbering
  - Subtle scale animation on tap (0.96 → 1.0)
- Bottom: "Continue" / "Skip" same button pattern as Step 0

**What's different:**
- No emojis on cuisine chips — cleaner, more premium
- No numbered selection order — unnecessary complexity
- warmAccent selection color matches the app's trust/warm palette instead of orange
- Title is left-aligned, not centered — matches the app's editorial feel

### Step 2: You're in

**Layout:**
- Centered vertically:
  - "You're in." — 28pt heavy, warmAccent
  - 8pt gap
  - "Log a place you've been, or see what your table recommends." — 15pt medium, mutedGray, centered
  - 28pt gap
  - Two buttons stacked:
    - "Log your first place" — primary CTA (warmAccent fill 0.18, border 0.35)
    - "Explore recommendations" — secondary (white 0.05 fill, white 0.08 border, #B0B0B4 text)
- Both buttons dismiss onboarding. First one also opens AddPlaceTestFlow after dismissal.

**What's different:**
- No "invite friends" step here — that's TableView's job
- Two clear entry points into the app instead of one generic "Done"
- "You're in." in warm accent feels like acceptance, not completion

---

## 4. TableView (Table Tab)

### What it is now
Header with "Table" + subtitle + orange Invite button. Three-segment picker (People/Trust/Recent). People panel shows invite module + person rows with trust summaries. Trust panel shows cuisine-grouped trust cards. Recent panel shows timeline of activity. PersonDetailView as fullScreenCover.

### What it should be

**Philosophy:** The Table tab answers: "Who do I trust for food?" It should feel like looking at your inner circle, not a social network. Small, tight, high-trust. Every person visible should make you think "yeah, I'd eat where they eat."

### Header
- "Table" — 26pt heavy, tracking -0.5 (matches other tabs)
- No subtitle — the tab name is enough
- Invite button: "Invite" in 13pt bold, warmAccent color, warmAccent.opacity(0.12) fill, no "+" icon, capsule shape

### Remove segment picker
The People/Trust/Recent segmentation adds complexity without value. Merge into one scrollable view:
- Section 1: Your people (the members)
- Section 2: Invite module (if < 3 members)
- Section 3: Recent from your table (last 5 activities)

### Person Card (replaces person row)
Each table member gets a card, not a list row:
- Card background: cardBg (#131517), cornerRadius 16, white.opacity(0.05) border
- Layout:
  - Top row: Avatar (32pt, RingedAvatarView) + Name (16pt bold, white) + "Best for: {cuisine}" tag (11pt, warmAccent.opacity(0.7), right-aligned)
  - Below name: Trust summary — "12 places · Loves Japanese" — 13pt medium, dimGray
  - Below that: Their latest rec — "Get the Omakase at Ju-Ni" — 14pt semibold, warmAccent — this is the most useful signal
  - If no recs yet: "No recommendations yet" in 13pt dimGray italic
- Tap → PersonDetailView (keep existing, polish later)

### Invite Module (contextual)
Only show when table has < 3 members:
- "Your table works better with 3-5 people." — 14pt medium, mutedGray
- "Invite by text" button — 13pt semibold, white, cardBg fill, fbBorder border
- Minimal — not a banner, just a quiet nudge

### Recent Activity
- Section label: "RECENT" — 11pt bold, tracking 1.4, mutedGray
- Simple timeline of last 5 entries from table members:
  - "{Name} logged {Restaurant}" — 14pt medium, #B0B0B4
  - "{timeAgo}" — 12pt, dimGray, right-aligned
  - Thin divider (white 0.03) between rows
- Tap a row → that restaurant's detail

### PersonDetailView (polish pass)
Keep existing structure but align tokens:
- Use warmAccent for cuisine tags and dish highlights
- Use the same CTA hierarchy (warm primary / neutral secondary / minimal tertiary)
- Trust summary uses same 12pt medium warmAccent.opacity(0.8) pattern as HomeTestView trust lines

---

## 5. ProfileView (Your Taste Identity)

### What it is now
Header with large avatar + name + username. Stats row (places/dishes/cuisines). Taste Profile hero card. "At a glance" section. "Known for" section. Table contribution. Settings. Comprehensive but busy — tries to show everything at once.

### What it should be

**Philosophy:** Profile isn't settings. It's your food identity — what you eat, what you're known for, what your table trusts you on. Think of it as "your food reputation" — concise, glanceable, useful.

### Header (simplified)
- Back chevron (top-left, standard navigation)
- Centered: Avatar (64pt, RingedAvatarView with warm accent ring instead of gradient)
- Below avatar: Display name — 22pt heavy, white
- Below name: "@username" — 14pt medium, dimGray
- Below username: Member since — 12pt, dimGray.opacity(0.7)
- No edit icon on avatar — tap avatar to edit (sheet)
- 24pt bottom padding, then thin divider (white 0.04)

### Stats Row (keep, refine)
Three stats in a row, evenly spaced:
- Number: 20pt heavy, white
- Label: 12pt medium, dimGray
- Stats: "Places" / "Dishes" / "Cuisines"
- No card background — just the numbers floating on black
- 20pt padding below, thin divider

### Your Taste (replaces Taste Profile card + At a Glance)
Merge these into one clean section:
- Section label: "YOUR TASTE" — 11pt bold, tracking 1.4, mutedGray
- Top cuisines as horizontal chips (same style as search mood chips):
  - Chip: cuisine name, 14pt semibold, warmAccent, warmAccent.opacity(0.12) fill, warmAccent.opacity(0.3) border
  - Max 5, horizontal scroll if needed
- Below chips: "You eat {cuisine1} most, followed by {cuisine2}" — 14pt medium, #B0B0B4
  - This is a generated natural-language line, not a chart
- Tap "Edit" (13pt, dimGray, top-right of section) → cuisine preferences sheet

### Known For (keep, refine)
- Section label: "KNOWN FOR" — 11pt bold, tracking 1.4, mutedGray
- 2-3 lines, each: "{Dish} at {Place}" — 15pt semibold, warmAccent for dish, #B0B0B4 for "at {Place}"
- These are dishes you've rated Amazing that others in your table haven't logged
- If none: "Log more places to build your reputation" — 14pt, dimGray

### Table Contribution (simplify)
- Section label: "YOUR TABLE IMPACT" — 11pt bold, tracking 1.4, mutedGray
- Single stat line: "You've helped your table discover {N} places" — 15pt medium, #B0B0B4
- Below: "{N} of your recommendations were visited by others" — 14pt, dimGray
- No cards, no complex layouts — just two meaningful numbers

### Settings (keep minimal)
- Section label: "SETTINGS" — 11pt bold, tracking 1.4, dimGray
- Simple list:
  - "Edit preferences" — 15pt, #B0B0B4
  - "Sign out" — 15pt, fbRed.opacity(0.8)
- No icons, no chevrons, just text buttons with 14pt vertical padding between

---

## Design Principles (Apply to All)

1. **Warm accent (#C4A882) is the trust color** — use it for dish names, trust signals, recommendations, and primary CTAs across all views
2. **Orange (#FF7A45) is deprecated as primary accent** — only appears in legacy views and the dish gradient
3. **Cards use cardBg (#131517)** with white.opacity(0.05) border, cornerRadius 16
4. **Section labels: 11pt bold, tracking 1.4, mutedGray** — consistent everywhere
5. **Press style: scale 0.985, brightness 0.015, 120ms ease** — same on all tappable cards
6. **No emojis in the UI** — they undermine the premium feel
7. **Haptic on every tap** — light for cards, medium for primary CTAs
8. **Text hierarchy: heavy for names, bold for directives, semibold for secondary, medium for supporting, regular never used**
