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
    /// Drives `bottomBar` (title/track info, action buttons) — fully hides
    /// and reveals. Starts false — the first clip of a chapter plays with
    /// bottomBar hidden until `revealChromeForEntrance()` brings it in after
    /// a short delay, so the viewer's first look isn't immediately overlaid
    /// with the title.
    @State private var showChrome = false
    /// Drives `topBar` (progress bar, eyebrow, counter, close button)
    /// separately from `showChrome` — it only ever dims to 0.35, never fully
    /// hides, and stays tappable regardless. Deliberately NOT tied to a manual
    /// swipe's dip or the entrance delay — those are active-navigation
    /// moments with the video still visible, so topBar stays fully bright
    /// through them. The auto-advance breath is the one exception: the whole
    /// screen goes to opaque ink there, so topBar dims in step with it too
    /// (see beginAutoAdvance) — a bright topBar floating over blank ink would
    /// read as a glitch, not "still active." Otherwise this only becomes true
    /// when `scheduleChromeAutoHide()`'s idle timer actually fires with no
    /// interaction; every other chrome-reveal path resets it back to
    /// false immediately.
    @State private var topBarDimmed = false
    @State private var chromeTask: Task<Void, Never>?
    /// Drives the ink-dip "breath" between auto-advanced clips (not manual
    /// swipes) — see beginAutoAdvance(). 0 = clear, 1 = fully covered.
    @State private var breathOpacity: Double = 0
    @State private var isBreathing = false
    @State private var breathTask: Task<Void, Never>?
    /// Set right before the breath's own silent scrollID jump, so onChange(of:
    /// scrollID) can tell that jump apart from a real manual swipe and skip
    /// autoplay (beginAutoAdvance starts playback itself once the cover clears).
    @State private var pendingAutoplayHoldIndex: Int?

    //TODO: Wire up share button
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Color.ink.ignoresSafeArea()
            feed.ignoresSafeArea()
            // Decorative only — must never intercept the horizontal paging drag.
            scrim.ignoresSafeArea().allowsHitTesting(false)
            // Lower chrome: per-clip title/track info + action buttons. Fully
            // hides — this is the part that benefits from disappearing before
            // its content changes (see revealChrome's swipe dip).
            bottomBar
                .padding(.horizontal, 22)
                .padding(.bottom, 38)
                .opacity(showChrome ? 1 : 0)
                .allowsHitTesting(showChrome)
            // Auto-advance breath — covers video and bottomBar; topBar (below)
            // stays dimly visible through it, same as it always has.
            Color.ink
                .ignoresSafeArea()
                .opacity(breathOpacity)
                .allowsHitTesting(isBreathing)
            // Upper chrome: progress bar, eyebrow, counter, close button.
            // Orientation info and the exit — never fully hides, only dims,
            // matching the progress bar's original "anchors position without
            // competing with the video" design. Hit-testing is never gated on
            // showChrome: the close button (and debug skip button) must stay
            // tappable even while dimmed, so leaving is never functionally
            // blocked, only visually quiet.
            topBar
                .opacity(topBarDimmed ? 0.35 : 1)
                .animation(.easeOut(duration: 0.5), value: topBarDimmed)
                .allowsHitTesting(true)
        }
        .onAppear { setup() }
        .onDisappear { manager.teardown(); chromeTask?.cancel(); breathTask?.cancel() }
        .onChange(of: isFullyPresented) { _, newValue in
            if newValue {
                manager.allowPlayback()
                revealChromeForEntrance()
            }
        }
        .onChange(of: scrollID) { oldValue, newValue in
            if let newValue {
                if newValue >= chapter.videos.count {
                    // User swiped past the last clip — same outcome as it playing to its end.
                    if let last = chapter.videos.last { onVideoCompleted(last) }
                    completeChapter()
                } else {
                    // The breath's own silent prep-jump shouldn't autoplay, or reveal
                    // chrome, here — beginAutoAdvance() starts playback and fades
                    // chrome in itself once the cover clears, in sync with the ink.
                    let isBreathJump = newValue == pendingAutoplayHoldIndex
                    if isBreathJump { pendingAutoplayHoldIndex = nil }
                    manager.setCurrent(index: newValue, autoplay: !isBreathJump)
                    if oldValue != nil && !isBreathJump { revealChrome() }
                }
            }
        }
    }

    // MARK: - Auto-advance breath

    // Cover → hold → reveal, ~1.2s total, matching the chapter-entrance
    // crossfade's own duration — confirmed by testing that the underlying
    // withAnimation mechanism was never broken (the progress bar's dim and
    // chrome's passive auto-hide both animate correctly), the earlier
    // 0.22-0.4s durations were just too fast to read as a real fade. Reveal
    // is set to 0.5s to match the app's own confirmed-working chrome
    // auto-hide fade duration (scheduleChromeAutoHide, below) rather than a
    // guess. Only auto-advance goes through this; manual swipes stay exactly
    // as instant as before.
    private let breathCover: Double = 0.6
    private let breathHold: Double = 0.2
    private let breathReveal: Double = 0.7

    private func beginAutoAdvance(to next: Int) {
        guard !isBreathing else { return }
        isBreathing = true
        chromeTask?.cancel()
        breathTask = Task {
            withAnimation(.easeInOut(duration: breathCover)) { breathOpacity = 1 }
            try? await Task.sleep(for: .seconds(breathCover))
            guard !Task.isCancelled else { isBreathing = false; return }

            // Fully covered now — jump with no animation (imperceptible under
            // the ink) and prep the next clip silently. Chrome stays hidden
            // through the hold so its reveal can be synced to the ink lifting
            // below, instead of fading in early and finishing invisibly
            // underneath it (which is what made it feel like it "just appeared").
            // topBar dims too — unlike a manual swipe, the whole screen is
            // covered here, so a bright topBar floating over blank ink would
            // look like a glitch rather than "still active." Dimming keeps it
            // reading as a quiet, still presence through the pause, same as
            // before topBar and bottomBar were split into separate tiers.
            pendingAutoplayHoldIndex = next
            scrollID = next
            showChrome = false
            topBarDimmed = true

            try? await Task.sleep(for: .seconds(breathHold))
            guard !Task.isCancelled else { isBreathing = false; return }

            manager.beginPlayback()
            // Same withAnimation call, same duration — chrome fades in exactly
            // as the ink fades out, so the two read as one continuous reveal.
            withAnimation(.easeInOut(duration: breathReveal)) {
                breathOpacity = 0
                showChrome = true
                topBarDimmed = false
            }
            try? await Task.sleep(for: .seconds(breathReveal))
            isBreathing = false
            scheduleChromeAutoHide()
        }
    }

    // Chrome always dips out and back in on a manual page change, even if it
    // was already visible — guarantees the label content is never overwritten
    // in place (old title swapped for new while fully opaque, which is what
    // made a manual swipe's text feel like it "suddenly changed"). Mirrors the
    // auto-advance breath's hide→hold→reveal cadence above, but shorter and
    // without an ink cover: the video keeps paging exactly as fast as the
    // user's swipe, only the metadata layer takes a beat before showing the
    // (already-updated) new content. Also used after resume, where the same
    // "dip in the new state" framing applies.
    private let chromeSwipeFadeOut: Double = 0.2
    private let chromeSwipeHold: Double = 0.2
    private let chromeSwipeFadeIn: Double = 0.5

    private func revealChrome() {
        chromeTask?.cancel()
        // Swiping is active navigation, not idle — topBar never dips for
        // this, it just un-dims immediately if a prior idle timeout had
        // already dimmed it.
        withAnimation(.easeOut(duration: 0.3)) { topBarDimmed = false }
        chromeTask = Task {
            withAnimation(.easeOut(duration: chromeSwipeFadeOut)) { showChrome = false }
            try? await Task.sleep(for: .seconds(chromeSwipeFadeOut))
            guard !Task.isCancelled else { return }
            try? await Task.sleep(for: .seconds(chromeSwipeHold))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: chromeSwipeFadeIn)) { showChrome = true }
            try? await Task.sleep(for: .seconds(chromeSwipeFadeIn))
            guard !Task.isCancelled else { return }
            scheduleChromeAutoHide()
        }
    }

    /// How long the first clip of a chapter plays with only a dimmed topBar —
    /// no bottomBar title/track info — once it's actually visible, before
    /// bottomBar fades in too. Gives the viewer's first look at the artist a
    /// beat before the title overlays it, matching the "stepping into
    /// something immersive" framing of the entrance crossfade itself.
    /// bottomBar is guaranteed already-hidden here (showChrome starts false),
    /// so unlike revealChrome() there's no fade-out step needed — just a
    /// delay, then a fade-in.
    private let entranceChromeDelay: Double = 0.4

    private func revealChromeForEntrance() {
        chromeTask?.cancel()
        chromeTask = Task {
            try? await Task.sleep(for: .seconds(entranceChromeDelay))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.5)) { showChrome = true }
            try? await Task.sleep(for: .seconds(0.5))
            guard !Task.isCancelled else { return }
            scheduleChromeAutoHide()
        }
    }

    private func scheduleChromeAutoHide() {
        chromeTask = Task {
            try? await Task.sleep(for: .seconds(6))
            guard !Task.isCancelled, !manager.isPaused else { return }
            withAnimation(.easeOut(duration: 0.5)) {
                showChrome = false
                topBarDimmed = true
            }
        }
    }

    // Single tap: toggle pause. Pausing snaps chrome in instantly (no animation)
    // so the UI responds at the same speed as the user's intent. Resuming uses
    // revealChrome so there's a 3-second window to see what's playing before
    // the chrome fades back out.
    private func handleTap(index: Int) {
        let willPause = !manager.isPaused
        if willPause {
            withAnimation(.easeOut(duration: 0.2)) {
                manager.togglePlay(index: index)
            }
            chromeTask?.cancel()
            showChrome = true   // instant snap — no withAnimation wrapper
            topBarDimmed = false
        } else {
            // Both mutations must land in the SAME withAnimation transaction.
            // Calling this, then separately calling revealChrome() (which does
            // its own withAnimation) right after, put two back-to-back
            // transactions in the same SwiftUI update batch — only one actually
            // drove the committed animation, so the play icon's fade-out
            // (governed by the first transaction) silently lost its animation.
            chromeTask?.cancel()
            withAnimation(.easeOut(duration: 0.35)) {
                manager.togglePlay(index: index)
                showChrome = true
                topBarDimmed = false
            }
            scheduleChromeAutoHide()
        }
    }

    // MARK: - Feed

    private var feed: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(Array(chapter.videos.enumerated()), id: \.element.id) { index, video in
                    VideoCell(index: index, video: video, artist: artist,
                              manager: manager, videoDetached: videoDetached,
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
            revealChromeForEntrance()
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

// MARK: - Video cell

// One full-screen page: an ink base, the poster (until ready), and the video
// layer that crossfades in on `.readyToPlay`. Tap toggles play/pause.
private struct VideoCell: View {
    let index: Int
    let video: JourneyVideo
    let artist: Artist?
    let manager: JourneyFeedManager
    /// When true the AVPlayerLayer is removed from the hierarchy. Set just before
    /// the dismiss crossfade fires so the layer can't bleed through the UIView
    /// alpha animation (AVPlayerLayer renders on its own hardware surface).
    let videoDetached: Bool
    let onTap: () -> Void

    var body: some View {
        ZStack {
            Color.ink

            // Poster placeholder beneath the video. Once this clip has actually
            // played and stopped being current, prefer the exact frame it was
            // last showing (manager.lastFrames) — this is what a slow manual
            // swipe exposes if the AVPlayerLayer goes momentarily transparent
            // mid-drag, so the outgoing clip stays frozen in place instead of
            // visibly rewinding to its first frame. Before that, fall back to
            // the clip's own frame-zero thumbnail (matches what's about to play,
            // so a cut never flashes unrelated content), then a remote poster,
            // then the artist image, then ink while it's still generating.
            // Gated on videoDetached too — once the video layer is pulled
            // (chapter-complete or dismiss), showing a poster in its place would
            // just swap one flash for another; falling back to plain ink here
            // blends into both this view's own base and the ink completion
            // screen it's fading toward.
            if videoDetached {
                EmptyView()
            } else if let frame = manager.lastFrames[index] ?? manager.thumbnails[index] {
                Image(uiImage: frame)
                    .resizable()
                    .scaledToFill()
            } else {
                AsyncImage(url: video.posterURL ?? artist?.imageURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color.ink
                }
            }

            // Mount the layer as soon as the player exists. AVPlayerLayer is
            // transparent until the first frame arrives, so the poster beneath
            // shows through during buffering — no explicit opacity gate needed
            // (the readyIndices gate was fragile and could leave clips hidden).
            // Gated on videoDetached so the layer is gone before the parent
            // UIView fades during the dismiss crossfade.
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
