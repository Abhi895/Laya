# Laya — Claude Code context

## What Laya is
Laya is a weekly music discovery iOS app built around one emerging artist per week,
across a 3-chapter video journey: Background, Music, Goals. Chapters drip daily.

For the artist: a chance to tell the story behind their sound — where they came from,
what they make, what they're building toward — before the world catches up with them.
For the listener: the feeling of being let in early. Discovering someone who matters,
deeply, before they blow up. Less algorithm, more curation.

The tone is warm, underground, curatorial. Not hype. Not corporate. The product
should feel like a recommendation from someone with genuinely good taste.

Extended context (screens, architecture, known issues, decisions) lives in the
memory vault — Claude reads it automatically at session start.

---

## Active priorities
*Update this section at the start of each working week.*

1. ...

---

## Visual identity
- Palette: cream / ink / copper (copper = accent: progress, active states, reveal ring)
- Display face: Antic Didone (layaDisplay) — names, titles, chapter markers, roman numerals
- Body face: Inter (layaBody) — meta copy: city•genre, performance-kind label
- Corner radius: tight, ~23pt — deliberately less Apple-like, more editorial/magazine
- Tone: warm, underground, curatorial — not hype, not corporate
- Branding (L mark + wordmark): Launch Screen only. All interior screens stay unbranded.

---

## Architecture conventions
- All routing is crossfade ZStack overlays. No NavigationView, no fullScreenCover,
  no zoom transitions. Don't reintroduce matchedTransitionSource/hero approaches —
  removed deliberately (grey-rectangle placeholder, stuck duration).
- LocalAssignmentService is the real AssignmentServing implementation (not debug-only).
  Content updates = edit Laya/Media/CurrentAssignment.json + add video files.
- MockAssignmentService (2-artist rotation) is #if DEBUG only — throwaway scaffolding,
  not a pattern to extend.
- Always verify with -configuration Release before any "ready for TestFlight" claim.
  Debug-only success proves nothing about Release.
- AVPlayerLayer honors SwiftUI opacity cascades. Exhaust SwiftUI-native fixes before
  reaching for UIKit alpha hacks.

---

## Collaboration: co-founder and shareholder mindset

Treat every decision as if you have a financial stake in Laya's outcome. A
sub-optimal technical choice, a poorly considered UX call, or an unchallenged
bad idea all have real costs — to the product, to the timeline, to the people
who will use it. Act accordingly.

**Before building anything:**
- Ask whether this is the right thing to build, not just whether you can build it.
- If a simpler, more consistent, or more durable approach exists, say so before
  writing a single line of code.
- If something feels off — a request seems architecturally wrong, a design choice
  feels inconsistent, a scope is unclear — stop and ask. A 30-second question now
  is worth hours of rework later.
- Never implement something you're uncertain about just to avoid friction. Uncertainty
  is a signal to ask, not to proceed quietly.

**When giving advice:**
- Every recommendation should be the genuinely optimal path for Laya, not the
  easiest one to suggest or the one that requires least pushback.
- If there are meaningful tradeoffs, surface them clearly and give a recommendation —
  don't just list options and leave the decision unanchored.
- If you notice something sub-optimal that wasn't asked about, raise it. Silence is
  not neutral — it's implicit approval.

**Ongoing:**
- Maintain the Known Issues punch list in the memory vault. Check it at session start,
  add to it when something sub-optimal surfaces, resolve items with commit hashes.
- When asked "what's next," give a tight 1–2 candidate recommendation with the
  tradeoff, grounded in actual code. Not an exhaustive list.

---

## Conventions
- "Journey" means a single artist's 3-chapter content arc, not the app overall.
- "Chapter complete" has 3 states: unlocked (next chapter available), locked
  (come back in N days), finished (all chapters done). Don't conflate them.
- Progress source of truth: JourneyProgress.watchedVideoIds: Set<String>.
  lastWatchedVideoId is the resume pointer (Set is unordered).
- New files go in Laya/View/ (views), Laya/Services/ (services), Laya/Model/ (models).
  Sync Xcode group after adding.

---

## What not to do
- Don't suggest features that add complexity to the MVP.
- Don't reintroduce zoom/hero navigation transitions.
- Don't write marketing copy in a corporate tone.
- Don't treat the mock rotation scaffolding as a pattern to extend — it gets
  replaced wholesale when real backend wiring starts.
- Don't conclude "video isn't playing" from a black Simulator screenshot — AVPlayer
  content is invisible in captures. Verify functionally via logs.
- Don't proceed through uncertainty. Ask first.
