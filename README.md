# Laya

One artist. One journey. Every week.

Laya is an iOS app for intentional music discovery. Each week, one emerging
artist is presented through a finite, curated sequence of 10–20 short-form
videos across 3 chapters — **Background**, **Music**, **Goals** — drip-released
daily. Listeners go deep on one artist at a time instead of scrolling an
infinite feed; artists get focused exposure to people who actually want to
discover new music.

This is a private, pre-launch product repo (currently in TestFlight beta),
not an open-source project — there's no contribution flow here.

## Stack

- SwiftUI, iOS 26+
- No backend yet — content is served from a bundled JSON manifest + local
  video assets (`LocalAssignmentService`)
- No external dependencies beyond Apple frameworks (AVFoundation for
  playback, Firebase for auth — see `GoogleService-Info.plist`)

## Getting started

1. Open `Laya.xcodeproj` in Xcode.
2. Select the `Laya` scheme and run on a simulator or device (iOS 26+).
3. Debug builds boot straight into the current assignment; a few `#if DEBUG`
   gestures (triple-tap reset, etc.) are available for manual testing.

Always verify with `-configuration Release` before treating anything as
TestFlight-ready — debug-only success doesn't prove Release behaves the same.

## Project layout

```
Laya/
  Model/          Artist, Journey, Chapter, JourneyVideo, WeeklyAssignment, ...
  Services/        AssignmentServing protocol + LocalAssignmentService (real),
                    MockAssignmentService (#if DEBUG scaffolding only)
  View/            All screens and components (crossfade ZStack routing —
                    no NavigationView, no fullScreenCover, no zoom transitions)
  DemoMedia/       Bundled video assets, organized <Artist>/<Chapter>/
  CurrentAssignment.json   The live weekly assignment (edit this + add video
                    files to ship new content)
```

## Content pipeline

There's no CMS. Shipping a new artist/week means:

1. Add video files under `Laya/DemoMedia/<Artist>/<Chapter>/`.
2. Edit `Laya/CurrentAssignment.json` to point at them (chapters, ordering,
   Spotify track IDs, etc.).
3. Rebuild — the bundle flattens the folder structure regardless of on-disk
   nesting depth.

`CurrentAssignment.json` is hand-edited and unforgiving: `kind` is a
strict-match enum (one bad value fails the *entire* journey load, not just
one clip), and `spotifyTrackId` must be a bare ID, not a full Spotify URL.

## Architecture conventions

- All routing is crossfade `ZStack` + opacity overlays. Zoom/hero navigation
  transitions were removed deliberately and shouldn't come back.
- `LocalAssignmentService` is the real, shipping implementation of
  `AssignmentServing` — not a stub.
- `MockAssignmentService` is throwaway `#if DEBUG` scaffolding for a 2-artist
  rotation, not a pattern to extend.
- Progress source of truth is `JourneyProgress.watchedVideoIds: Set<String>`;
  `lastWatchedVideoId` is only the resume pointer.

See `CLAUDE.md` for the full set of working conventions this codebase
follows (visual identity, naming, what not to do).
