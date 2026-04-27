# CLAUDE.md

Behavioral guidelines for working on the ForkBook iOS codebase.

---

## ForkBook-Specific Guidelines

### Architecture

ForkBook uses **plain SwiftUI state management** — not formal MVVM. There are no ViewModel classes. The pattern throughout the codebase is:

- **`RestaurantStore`** (`ObservableObject`) — single source of truth for local restaurant data, passed via `@EnvironmentObject`
- **`AuthService.shared` / `FirestoreService.shared`** — `@MainActor` singleton `ObservableObject`s for auth and remote data, observed via `@ObservedObject`
- **`@State`** — local, ephemeral view state (form fields, sheet flags, loading booleans)
- **Logic** lives in the store/service layer or in private view methods — not in separate ViewModel types

New views should follow this same pattern. Don't introduce ViewModel classes, Combine pipelines, or additional abstraction layers unless there's a clear, discussed reason to do so.

### Swift Concurrency

The codebase uses **`async/await`** throughout. Remote calls are wrapped in `Task { await … }` from view lifecycle hooks (`.task`, `.onAppear`, button actions). Classes that touch UI are annotated `@MainActor`. Errors are handled with `do/catch` or `try?` depending on whether the failure needs to surface to the user.

New code should match this pattern. Don't introduce Combine, callback closures, or DispatchQueue-based async unless integrating with an SDK that requires it.

### Previews

Every new view file should include a `#Preview` block. Existing views all have them. Previews should pass `.preferredColorScheme(.dark)` and inject any required environment objects (e.g., `.environmentObject(RestaurantStore())`).

### Testing

There is no formal test target. "Verified" means:
- Manually confirmed in Simulator against clearly stated acceptance criteria, **or**
- Acceptance criteria are written out explicitly so someone else can verify them

Do not write XCTest cases unless a test target is added. Do define acceptance criteria in plain language before implementing non-trivial features.

---

## General Guidelines

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Define what valid/invalid looks like, then implement"
- "Fix the bug" → "Describe the exact broken behavior, then fix it"
- "Refactor X" → "State what should be identical before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.
