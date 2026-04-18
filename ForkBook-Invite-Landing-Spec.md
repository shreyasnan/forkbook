# ForkBook — Invite Link Landing Spec

**Status:** Draft v1
**Owner:** Shreyas
**Last updated:** 2026-04-16

---

## Background

ForkBook's growth loop is invite-driven: every new user comes in through a link from someone they trust. That link is the first impression of the product, and for new users it's the first impression of the app entirely. The landing experience needs to teach the product, justify the install, and convert.

This spec captures the design decisions for the invite landing experience and the underlying graph model that supports it.

---

## Committed product decisions

These are the foundational decisions the rest of the spec builds on. Treat as locked unless explicitly revisited.

1. **Auto-mutual on accept.** When B accepts A's invite, A and B are added to each other's tables in a single step. No directional opt-in, no "pending" state. The framing is "you joined each other's tables."
2. **Users manage their own table after accept.** Anyone in your table can be removed at any time, no notification to the other party. This is the trust release valve — the product can promise "no strangers" because removal is one tap.
3. **Trust weighting is phase 2.** v1 treats every connection as equal weight. Per-person trust sliders, "close friends" tiers, and weighted recommendation surfacing are deferred until we have signal that the unweighted graph isn't good enough.
4. **Per-log visibility is roadmap, not launch.** v1: when you log a place, it's visible to everyone in your table. Per-entry "share with X but not Y" controls are a known future ask but not in v1 scope.
5. **Reusable invite links.** Each user has one permanent invite link. Tapping it always lands on that user's invite landing page; no per-recipient links, no expiry, no single-use codes. (The existing 6-character code system stays as a fallback for manual entry.)

---

## User flows

### New user (no app installed)

1. User taps Pragya's invite link in iMessage / WhatsApp / email.
2. Branch.io intercepts → opens Safari → renders Branch-hosted landing OR our hosted web landing (TBD: see open questions). Landing shows the Variant A design described below.
3. User taps **Start my table** → routed to App Store.
4. User installs and opens the app.
5. Branch SDK delivers the deferred deep link payload (inviter user ID + invite code).
6. App routes user through signup (Sign in with Apple / Google).
7. On signup completion: server adds Pragya to user's table, adds user to Pragya's table (auto-mutual), sends Pragya a notification "X joined your table."
8. User lands in main app with Pragya already in their table. No celebration sheet — the home screen renders with Pragya's recent activity already visible, which IS the payoff.

### Existing user (app installed, signed in)

1. User taps Pragya's invite link.
2. iOS Universal Link intercept opens ForkBook directly (no Safari detour).
3. App parses the payload, resolves Pragya's user ID.
4. **Silent auto-add**: server runs the same auto-mutual transaction. No modal, no full-screen interrupt.
5. App shows a toast at the top of the current screen: **"Pragya is now in your table"** with subtle action affordance.
6. First time only: home feed shows an inline banner explaining "When someone you trust joins your table, their picks show up here. Tap to manage your table." (Dismissible, never shown again.)

### Existing user (app installed, signed out)

1. Universal Link opens app, lands on sign-in screen.
2. After sign-in, the pending invite payload is consumed and the existing-user flow above resumes from step 3.

### Edge cases

- **Already in each other's tables.** Toast says "You're already in Pragya's table" and routes to her profile. No-op on the graph.
- **Self-tap (user taps their own invite link).** Show a friendly "This is your invite link — share it with people you trust" with a copy/share affordance.
- **Desktop / non-iOS.** Web landing still renders the Variant A design but the CTA reads "Get the app" with App Store + (future) Play Store badges. Branch handles deferred link delivery.
- **Inviter has been deleted / deactivated.** Landing falls back to a generic "Welcome to ForkBook" version with no inviter peek; signup flow proceeds normally without auto-mutual.

---

## Landing page design — Variant A (Showroom)

The landing page is for the **new-user web flow**. Existing users never see it (toast pattern handles them).

### Layout, top to bottom

**Header**
- 72×72 circular avatar with inviter's initial, warm-sand gradient fill (`fbWarm` → darker warm). Anchors the page on a person, not a brand.
- Headline: **"Pragya invited you to ForkBook"** — large, heavy weight, two lines.
- Subhead: **"Restaurant picks from the people you trust."** — muted, single line.

**Peek section ("A look at Pragya's table")**
- Section label in muted uppercase: **"A LOOK AT PRAGYA'S TABLE"**
- Subtitle in smaller muted text: **"Her 5 friends · 33 places they've loved"** — teaches the "table" concept implicitly without a glossary moment.
- Three cards, each showing a restaurant Pragya's table has loved:
  - Restaurant name (bold)
  - Cuisine · neighborhood (muted)
  - Trust signal in warm-sand: **"Loved by 4 in her table"** / **"Pragya & 2 others"** / **"3 people loved this"**
- Cards are visual-only (no taps). They sell the signal type, not specific restaurants.

**Bridge line**
- Centered, italic-leaning muted text: **"This is the kind of signal you'll start seeing."** — sets the expectation that the user's own table will produce its own signal, not that they're getting access to Pragya's recs.

**Reassurance card**
- Soft warm-sand background (`fbWarm.opacity(0.08)`), warm-sand stroke.
- Title: **"Pragya's in your table — you're in hers"** (sets the auto-mutual expectation up front, no surprise after install).
- Body: **"Add more people you trust, remove anyone anytime. No strangers, no public reviews, no ads."**

**CTAs**
- Primary: **"Start my table"** — warm-sand (`fbWarm`) background, dark-brown text, full width. Intentionally *not* the orange→pink dish gradient used elsewhere in the app: the landing's palette is built on trust / human signals, and the warm-sand primary keeps the page coherent rather than snapping to a promotional-feeling color at the moment of conversion.
- Secondary: **"Already on ForkBook? Sign in"** — muted text link below.

**Footer**
- Tiny muted copy: "By tapping Start my table, you agree to ForkBook's Terms and Privacy Policy."

### Why this design

- **Showroom, not menu.** We're not letting the new user browse Pragya's table. We're showing three carefully picked tiles to communicate what the signal feels like.
- **Warm-sand throughout, no dish gradient.** The orange/pink gradient is the app's "delicious thing to eat" color — the dish/recommendation energy. The invite landing is about trusting a *person*, not about food yet, so the whole surface (trust signals, reassurance card, and primary CTA) stays in warm-sand. The dish gradient first appears after signup, where it belongs.
- **Auto-mutual disclosed up front.** "Pragya's in your table — you're in hers" means there's no surprise post-install. People who don't want mutual can bail before installing.
- **No table count brag.** "Her 5 friends · 33 places" is a teaching line, not a flex. We deliberately don't say "Join 50,000 foodies" or anything growth-marketing-flavored.

---

## Existing-user toast design

When an existing signed-in user taps an invite link:

- Toast slides in from top, sits below status bar.
- Capsule shape, dark surface, fbBorder stroke.
- Avatar (24px) + text: **"Pragya is now in your table"**
- Auto-dismisses after ~4s. Tap to open Pragya's profile.
- No haptic on first invite of session; subtle haptic on subsequent.

First-time inline banner on home (one-time only):
- "When someone you trust joins your table, their picks show up here."
- Dismiss button. Stored in UserDefaults / Firestore user prefs.

---

## Non-goals (v1)

- Personalized landing copy beyond inviter name and avatar (no "Pragya thinks you'll love…" auto-recs).
- Algorithmic friend suggestions ("People you may know"). The graph is IRL-only by design.
- Public profiles, public reviews, follower counts.
- Per-log visibility controls.
- Trust weighting / "close friends" tier.
- Web app (the landing is web, but the product is iOS-only at v1).
- Single-use or expiring invite codes.

---

## Open technical questions

- **Branch.io vs. self-hosted web landing.** Branch can host the landing or we can host it on a forkbook.app subdomain and use Branch only for deferred deep linking. Self-hosted gives us full design control but adds infra.
- **Universal Link domain.** Need to register `forkbook.app/invite/...` with Apple App Site Association file. Decide whether invite paths live at `/invite/{code}` or `/i/{code}`.
- **Branch SDK install impact.** Branch adds ~1MB and runs on every cold start. Acceptable for the deferred-link payoff but worth noting.
- **Code → user ID resolution.** Existing `DeepLinkManager` uses a 6-char code. Server-side, code maps to inviter user ID. Need to confirm Firestore `invite_codes` collection schema is in place.
- **Rate limiting.** Should we rate-limit acceptances per user per day? Probably yes (anti-abuse), but trivial number (e.g., 50/day).

---

## Success metrics (v1 launch)

- **Landing → install conversion**: % of users who tap the landing CTA and complete App Store install + open. Target: >25%.
- **Install → first connection**: % of installs where auto-mutual completes successfully. Target: >95% (this is mostly an infra reliability metric).
- **First connection → second connection within 7 days**: % of new users who invite at least one more person within their first week. Target: >40% (this is the loop closing).
- **Toast acknowledgment rate (existing users)**: % of toast impressions that get tapped. Diagnostic, not a target — tells us if the surface is too quiet.

---

## Out of scope for this spec

- Notification copy when someone joins your table (separate notif spec).
- Onboarding flow after signup (handled by `InviteOnboardingView` — but note that view is misnamed and should be renamed `WelcomeOnboardingView` since it's not actually invite-related).
- Server-side auto-mutual transaction details (separate backend spec).
