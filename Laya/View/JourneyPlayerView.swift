//
//  JourneyPlayerView.swift
//  Laya
//
//  Created by Abhi Reddy on 18/06/2026.
//

import SwiftUI
import UIKit

/// The chapter's video feed: a horizontally paging stack of the chapter's clips.
///
/// One `JourneyFeedManager` owns the AVPlayer pool; this view owns the scroll
/// position and the chrome (top progress = how far through the chapter, the
/// chapter eyebrow, and the per-clip title/kind + actions). When a clip finishes
/// the manager asks us to page to the next; after the last clip it reports the
/// chapter complete to the caller. The close (✕) button next to the chapter label
/// leaves the whole session — kept as an explicit control rather than a
/// swipe-down so it can't compete with the horizontal paging gesture.
///
/// 2026-07-28: deliberately stripped back to structural parity with the
/// reference this pager came from (`artist discoverer`) after #21 (video
/// blip on backward swipes) survived 4 fix attempts in one session — see
/// [[project_scrolling_minimal_reset]] for the full list of what was removed
/// and why. Three things were then deliberately re-added on top of that
/// minimal baseline: the bottom chrome's invisible/fade-in/hold/fade-out cycle
/// (`bottomBarOpacity`, independent of pause state); the auto-advance ink
/// transition (`breathOpacity`/`beginAutoAdvance`); and a narrow `scrollPhase`
/// guard on phantom-page completion only (`.scrollTargetBehavior(.paging)`
/// can commit `scrollID` to the phantom page before the finger lifts, which
/// without this guard let a still-reversible drag past halfway on the last
/// clip instantly complete the chapter). None of these three touch the
/// manual-swipe `setCurrent` path itself, which stays exactly as simple as
/// it was when #21 was fixed — R10's full gesture-phase seek-preservation
/// and the rest of the removed-feature list remain out, not re-added.
struct JourneyPlayerView: View {
    let chapter: Chapter
    let artist: Artist?
    /// Which clip to open on (resume pointer; 0 for a fresh chapter).
    let startIndex: Int
    /// True once the caller's entrance crossfade has actually finished — flips
    /// playback on. Starts false even on a fresh mount so the first clip's audio
    /// and frame advance wait for the screen to actually be visible, not just
    /// present in the view tree. See `JourneyFeedManager.allowPlayback()`.
    let isFullyPresented: Bool

    /// Leave the journey entirely (the ✕ button).
    var onDismiss: () -> Void
    /// Every clip in the chapter has been watched.
    var onChapterComplete: () -> Void
    /// A clip became current — caller persists the resume pointer only.
    var onVideoReached: (JourneyVideo) -> Void
    /// A clip played to its actual end — caller marks it watched.
    var onVideoCompleted: (JourneyVideo) -> Void

    @State private var manager = JourneyFeedManager()
    @State private var scrollID: Int?
    @State private var wired = false
    /// Flipped true when the ✕ is tapped. Removes the AVPlayerLayer from the
    /// hierarchy before the slide-down exit animation, preventing any bleed-through
    /// since AVPlayerLayer renders on a separate hardware surface.
    @State private var videoDetached = false
    /// Drives `bottomBar`'s invisible → fade in → hold → fade out cycle.
    /// Independent of pause state — see the `.onChange(of: manager.isPaused)`
    /// handler below.
    @State private var bottomBarOpacity: Double = 0
    @State private var chromeTask: Task<Void, Never>?
    /// Ink cover for the auto-advance transition (natural clip-end → next
    /// clip). 0 = clear, 1 = fully covered. Also drives `topBar`'s dim.
    @State private var breathOpacity: Double = 0
    /// Set right before `beginAutoAdvance`'s own silent `scrollID` jump, so
    /// `onChange(of: scrollID)` can tell that jump apart from a real manual
    /// swipe and skip re-activating a clip `setCurrentMuted` already handled.
    @State private var pendingAdvanceIndex: Int?
    /// Live gesture-phase tracking — used only to gate phantom-page
    /// completion (see `onChange(of: scrollID)`/`onScrollPhaseChange` below):
    /// `.scrollTargetBehavior(.paging)` can commit `scrollID` to the phantom
    /// page as soon as a drag crosses the paging threshold, well before the
    /// finger lifts — without this, dragging past halfway on the last clip
    /// instantly completed the chapter, even on a still-reversible drag.
    @State private var scrollPhase: ScrollPhase = .idle

    //TODO: Wire up share button

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.ink.ignoresSafeArea()
            // Gated to isFullyPresented — otherwise a fast swipe during the
            // entrance crossfade can trigger setCurrent (and its audio) before
            // the screen is actually visible, the same guarantee canPlay/
            // allowPlayback() already gives the first clip's own playback (R24),
            // just not yet extended to touch input on the feed itself.
            feed.ignoresSafeArea().allowsHitTesting(isFullyPresented)
            // Decorative only — must never intercept the horizontal paging drag.
            scrim.ignoresSafeArea().allowsHitTesting(false)
            bottomBar
                .padding(.horizontal, 22)
                .padding(.bottom, 38)
                .opacity(bottomBarOpacity)
                .allowsHitTesting(bottomBarOpacity > 0.01)
                .onChange(of: currentIndex) { _, _ in
                    if isFullyPresented { beginFreshChromeCycle() }
                }
                .onChange(of: isFullyPresented) { _, presented in
                    if presented { beginFreshChromeCycle() }
                }
                .onChange(of: manager.isPaused) { _, isPaused in
                    if isPaused {
                        chromeTask?.cancel()
                        bottomBarOpacity = 1   // snap visible, no fade, while paused
                    } else {
                        resumeChromeCycle()   // stays visible, fade-out timing restarts
                    }
                }
            // Auto-advance ink cover — sits below topBar so the close button
            // stays tappable through the whole transition (matches R30).
            Color.ink
                .ignoresSafeArea()
                .opacity(breathOpacity)
                .allowsHitTesting(breathOpacity > 0)
            topBar
                .opacity(1 - breathOpacity * 0.65)
                .allowsHitTesting(true)
        }
        .onAppear { setup() }
        .onDisappear { manager.teardown(); chromeTask?.cancel() }
        .onChange(of: isFullyPresented) { _, newValue in
            if newValue { manager.allowPlayback() }
        }
        .onChange(of: scrollID) { _, newValue in
            guard let newValue else { return }
            if newValue == pendingAdvanceIndex {
                // Our own silent jump from beginAutoAdvance — setCurrentMuted
                // already activated this clip, nothing more to do here.
                pendingAdvanceIndex = nil
                return
            }
            if newValue >= chapter.videos.count {
                // Phantom page — a fast drag can transiently reach it and
                // then reverse before release, so only complete once the
                // gesture is no longer live. If it's still live, the
                // .onScrollPhaseChange .idle backstop in `feed` re-checks
                // once the gesture actually settles.
                if !scrollPhase.isLive {
                    completePhantomPage()
                }
            } else {
                manager.setCurrent(index: newValue)
            }
        }
    }

    // MARK: - Bottom chrome fade

    private func beginFreshChromeCycle() {
        chromeTask?.cancel()
        bottomBarOpacity = 0
        chromeTask = Task {
            try? await Task.sleep(for: .seconds(0.8))   // stays invisible at least 0.8s
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.6)) { bottomBarOpacity = 1 }
            await holdThenFadeOut()
        }
    }

    private func resumeChromeCycle() {
        chromeTask?.cancel()
        // Already visible (the pause handler snapped it there) — just hold,
        // then fade out. No invisible/fade-in step on resume.
        chromeTask = Task { await holdThenFadeOut() }
    }

    private func holdThenFadeOut() async {
        try? await Task.sleep(for: .seconds(6))
        guard !Task.isCancelled else { return }
        withAnimation(.easeOut(duration: 0.6)) { bottomBarOpacity = 0 }
    }

    // MARK: - Auto-advance ink transition

    // Visual values reused as-is from R26 — already validated on-device
    // (earlier 0.22-0.4s durations tested too fast to read as a real fade).
    private let breathCover: Double = 0.6
    private let breathHold: Double = 0.2
    private let breathReveal: Double = 0.7
    // Audio comes back sharply, deliberately faster/harsher than the visual
    // reveal — a slow audio fade read as too soft alongside the ink lifting.
    private let audioFadeIn: Double = 0.15

    private func beginAutoAdvance(to next: Int) {
        guard pendingAdvanceIndex == nil else { return }
        Task {
            withAnimation(.easeInOut(duration: breathCover)) { breathOpacity = 1 }
            try? await Task.sleep(for: .seconds(breathCover))
            guard !Task.isCancelled else { return }
            pendingAdvanceIndex = next
            scrollID = next
            manager.setCurrentMuted(index: next)
            try? await Task.sleep(for: .seconds(breathHold))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: breathReveal)) { breathOpacity = 0 }
            manager.fadeInAudio(duration: audioFadeIn)
        }
    }

    // Single tap: toggle pause.
    private func handleTap(index: Int) {
        manager.togglePlay(index: index)
    }

    // MARK: - Feed

    private var feed: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(Array(chapter.videos.enumerated()), id: \.element.id) { index, _ in
                    VideoCell(index: index, manager: manager, videoDetached: videoDetached,
                              onTap: { handleTap(index: index) })
                        .containerRelativeFrame(.horizontal)
                        .id(index)
                }
                // Phantom page — swiping here triggers chapter complete, so the
                // user doesn't have to wait for the last clip to finish playing.
                Color.clear
                    .containerRelativeFrame(.horizontal)
                    .id(chapter.videos.count)
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $scrollID)
        .scrollIndicators(.hidden)
        .onScrollPhaseChange { _, newPhase in
            scrollPhase = newPhase
            // Backstop for the phantom page: if scrollID was already resting
            // there while still live, the onChange above never got a fresh
            // value to re-fire on. .idle is the one point scrollID is
            // guaranteed fully settled, so re-check here. completePhantomPage()
            // is guarded (videoDetached), so this is safe even if onChange
            // already handled it.
            if newPhase == .idle && scrollID == chapter.videos.count {
                completePhantomPage()
            }
        }
    }

    // MARK: - Scrim & chrome

    // Darkens top and bottom so the overlaid text stays legible over video. The
    // bottom band is taller and heavier than the top — it has to carry the
    // performance label + track title over bright video frames.
    private var scrim: some View {
        LinearGradient(
            stops: [
                .init(color: .black.opacity(0.75), location: 0.0),
                .init(color: .black.opacity(0.4), location: 0.2),
                .init(color: .clear, location: 0.6),
                .init(color: .black.opacity(0.55), location: 0.85),
                .init(color: .black.opacity(0.8), location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var topBar: some View {
        VStack(spacing: 0) {
            ProgressBar(progress: manager.chapterProgressFraction)
                .frame(height: 2)
                .padding(.horizontal, 22)
                .padding(.top, 12)
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    chapterEyebrow
                    clipCounter
                }
                Spacer()
                #if DEBUG
                skipButton
                #endif
                closeButton
            }
            .padding(.horizontal, 22)
            .padding(.top, 8) // space below the progress bar (2pt bar + 6pt gap)
            Spacer(minLength: 0)
        }
    }

    // "II • Music" — Antic Didone, cream. Matches the home / chapter markers.
    private var chapterEyebrow: some View {
        Text(chapterLabel)
            .font(.layaDisplay(18))
            .foregroundStyle(.cream)
    }

    // "1 of 5" — answers the information gap of a segmented bar without the
    // gamification cost. Quiet enough to not compete with the chapter label.
    private var clipCounter: some View {
        Text("\(currentIndex + 1) of \(chapter.videos.count)")
            .font(.layaBody(12, weight: .regular))
            .tracking(1.5)
            .textCase(.uppercase)
            .foregroundStyle(.cream.opacity(0.45))
            .animation(.easeInOut(duration: 0.25), value: currentIndex)
    }

    #if DEBUG
    // Marks the current clip watched and advances exactly one clip — same
    // path a real finish takes (calls into chapter-complete on the last
    // clip) — so progress bars can be exercised one clip at a time without
    // waiting for real playback. Only present in DEBUG builds.
    private var skipButton: some View {
        Button {
            manager.skipCurrent()
        } label: {
            Text("Skip")
                .font(.layaBody(13, weight: .regular))
                .foregroundStyle(.cream.opacity(0.5))
                .padding(8)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    #endif

    // Explicit exit from the whole session. Sits next to the chapter label so it
    // reads as "leave this chapter" and never competes with the paging drag.
    private var closeButton: some View {
        Button {
            guard !videoDetached else { return }
            // Cut audio and detach the video layer before handing off to
            // ContentView's slide-down animation. This prevents the AVPlayerLayer
            // from rendering during the exit (it renders on a separate hardware
            // surface and could show through if the view slides/fades).
            manager.pauseAll()
            videoDetached = true
            onDismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.cream.opacity(0.5))
                .padding(8)
                .contentShape(Rectangle())
        }
        .buttonStyle(HapticOnlyButtonStyle())
    }

    private var bottomBar: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 7) {
                Text(performanceLabel)
                    .font(.layaBody(15, weight: .regular))
                    .tracking(2)
                    .textCase(.uppercase)
                    .foregroundStyle(.copper)

                Text(trackTitle)
                    .layaTitle(34)
                    .foregroundStyle(.cream)
                    .lineLimit(2)
                    .minimumScaleFactor(0.65)

                if let secondary = currentVideo?.secondaryArtist {
                    Text(secondary)
                        .font(.layaBody(13, weight: .light))
                        .foregroundStyle(.cream.opacity(0.55))
                }
            }
            .id(currentIndex) // re-renders the labels as paging changes the clip
            .transition(.opacity)

            Spacer(minLength: 16)

            VStack(spacing: 16) {
                if let trackId = currentVideo?.spotifyTrackId {
                    SpotifyButton { openSpotify(trackId: trackId) }
                }
                ShareButton {}
            }
        }
        .animation(.easeInOut(duration: 0.25), value: currentIndex)
    }

    // MARK: - Setup

    private func setup() {
        guard !wired else { return }
        wired = true
        manager.onAdvanceRequest = { next in beginAutoAdvance(to: next) }
        manager.onChapterComplete = completeChapter
        manager.onVideoReached = onVideoReached
        manager.onVideoCompleted = onVideoCompleted
        manager.start(videos: chapter.videos, startIndex: startIndex)
        if isFullyPresented {
            manager.allowPlayback()
            beginFreshChromeCycle()
        }
        scrollID = startIndex
    }

    private func openSpotify(trackId: String) {
        let native = URL(string: "spotify:track:\(trackId)")!
        let web = URL(string: "https://open.spotify.com/track/\(trackId)")!
        UIApplication.shared.open(native) { success in
            if !success { UIApplication.shared.open(web) }
        }
    }

    private func completeChapter() {
        guard !videoDetached else { return }
        // Match the explicit close path: remove the hardware-backed video layer
        // before the opacity transition to the completion screen begins, so the
        // hand-off is composed entirely by SwiftUI.
        manager.pauseAll()
        videoDetached = true
        onChapterComplete()
    }

    /// Reached the phantom page — mark the last clip completed and hand off
    /// to chapter-complete. Guarded by `videoDetached` independently of
    /// `completeChapter()`'s own guard, because `onVideoCompleted` isn't
    /// gated there.
    private func completePhantomPage() {
        guard !videoDetached else { return }
        if let last = chapter.videos.last { onVideoCompleted(last) }
        completeChapter()
    }

    // MARK: - Derived values

    private var currentIndex: Int { min(scrollID ?? startIndex, max(0, chapter.videos.count - 1)) }

    private var currentVideo: JourneyVideo? {
        chapter.videos.indices.contains(currentIndex) ? chapter.videos[currentIndex] : nil
    }

    private var chapterLabel: String {
        "\(romanNumeral(chapter.index + 1)) • \(chapter.title)"
    }

    private var performanceLabel: String {
        switch currentVideo.flatMap(\.kind) {
        case .live:       return "Live Performance"
        case .musicVideo: return "Music Video"
        case .cover:      return "Cover"
        case .interview:  return "Interview"
        case .bts:        return "Behind the Scenes"
        case .qAndA:      return "Q&A"
        case .none:       return chapter.title
        }
    }

    private var trackTitle: String { currentVideo?.title ?? "" }

}

// Only used in this file — SwiftUI's ScrollPhase has no built-in "still a live
// gesture" predicate (its own `isScrolling` is true for decelerating/animating
// too, which we deliberately treat as already-committed here).
private extension ScrollPhase {
    var isLive: Bool { self == .tracking || self == .interacting }
}

// MARK: - Video cell

// One full-screen page: an ink base, and the video layer once it exists.
// Tap toggles play/pause. Structurally identical to the reference app's own
// VideoCell — no poster/thumbnail layer, no gesture-phase awareness.
private struct VideoCell: View {
    let index: Int
    let manager: JourneyFeedManager
    /// When true the AVPlayerLayer is removed from the hierarchy. Set just before
    /// the dismiss crossfade fires so the layer can't bleed through the UIView
    /// alpha animation (AVPlayerLayer renders on its own hardware surface).
    let videoDetached: Bool
    let onTap: () -> Void

    var body: some View {
        ZStack {
            Color.ink

            // Mount the layer as soon as the player exists. AVPlayerLayer is
            // transparent until the first frame arrives, so ink shows through
            // during buffering. Gated on videoDetached so the layer is gone
            // before the parent UIView fades during the dismiss crossfade.
            if let player = manager.player(at: index), !videoDetached {
                VideoPlayerLayerView(player: player)
            }

            if manager.isPaused && index == manager.currentIndex {
                Image(systemName: "play.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.cream.opacity(0.7))
                    .shadow(color: .ink, radius: 12, y: 4)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }
}

// MARK: - Progress bar

private struct ProgressBar: View {
    let progress: Double // 0...1

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.cream.opacity(0.25))
                Capsule()
                    .fill(Color.cream)
                    .frame(width: geo.size.width * max(0, min(progress, 1)))
            }
        }
        // 0.15s linear provides slight overlap between 0.1s timer updates,
        // absorbing timer jitter without introducing perceptible lag.
        .animation(.easeInOut(duration: 0.15), value: progress)
    }
}

// MARK: - Buttons

private struct SpotifyButton: View {
    let action: () -> Void

    var body: some View {
        CircleButton(action: action) {
            Image("spotify")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(.cream)
                .padding(9)
        }
        .accessibilityLabel("Save to Spotify")
    }
}

private struct ShareButton: View {
    let action: () -> Void

    var body: some View {
        CircleButton(action: action) {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(.cream)
                .offset(y: -1)
        }
        .accessibilityLabel("Share")
    }
}

// Shared circular treatment: thin cream ring, transparent fill, cream icon.
// Frame is the full 44×44pt minimum tap target (Apple HIG) — the ring itself
// can stay visually smaller via the icon's own padding, but the tappable
// area shouldn't be.
private struct CircleButton<Icon: View>: View {
    let action: () -> Void
    let icon: Icon

    init(action: @escaping () -> Void, @ViewBuilder icon: () -> Icon) {
        self.action = action
        self.icon = icon()
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .stroke(Color.cream.opacity(0.85), lineWidth: 1)
                icon
            }
            .frame(width: 44, height: 44)
        }
        .buttonStyle(PressableButtonStyle())
    }
}

#if DEBUG
#Preview {
    JourneyPlayerView(
        chapter: .mockBackground,
        artist: .mock,
        startIndex: 0,
        isFullyPresented: true,
        onDismiss: {},
        onChapterComplete: {},
        onVideoReached: { _ in },
        onVideoCompleted: { _ in }
    )
}
#endif
