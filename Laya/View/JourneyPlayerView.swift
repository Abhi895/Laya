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
    /// Controls the fadeable chrome layer (everything except the ✕).
    @State private var showChrome = true
    @State private var chromeTask: Task<Void, Never>?
    
    //TODO: Wire up share button
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Color.ink.ignoresSafeArea()
            feed.ignoresSafeArea()
            // Decorative only — must never intercept the horizontal paging drag.
            scrim.ignoresSafeArea().allowsHitTesting(false)
            chrome
                .opacity(showChrome ? 1 : 0)
                .allowsHitTesting(showChrome)
            // Progress bar persists when chrome fades but dims — still anchors
            // position in the chapter without competing with the video.
            VStack(spacing: 0) {
                ProgressBar(progress: manager.chapterProgressFraction)
                    .frame(height: 2)
                    .padding(.horizontal, 22)
                    .padding(.top, 12)
                Spacer(minLength: 0)
            }
            .opacity(showChrome ? 1 : 0.35)
            .animation(.easeOut(duration: 0.5), value: showChrome)
            .allowsHitTesting(false)
        }
        .onAppear { setup() }
        .onDisappear { manager.teardown(); chromeTask?.cancel() }
        .onChange(of: scrollID) { oldValue, newValue in
            if let newValue {
                if newValue >= chapter.videos.count {
                    // User swiped past the last clip — same outcome as it playing to its end.
                    if let last = chapter.videos.last { onVideoCompleted(last) }
                    completeChapter()
                } else {
                    manager.setCurrent(index: newValue)
                    if oldValue != nil { revealChrome() }
                }
            }
        }
    }
    
    // Shows chrome briefly then fades — used on clip change and after resume.
    // Does not hide if the player is paused when the timer fires.
    private func revealChrome() {
        chromeTask?.cancel()
        withAnimation(.easeOut(duration: 0.2)) { showChrome = true }
        chromeTask = Task {
            try? await Task.sleep(for: .seconds(6))
            guard !Task.isCancelled, !manager.isPaused else { return }
            withAnimation(.easeOut(duration: 0.5)) { showChrome = false }
        }
    }

    // Single tap: toggle pause. Pausing snaps chrome in instantly (no animation)
    // so the UI responds at the same speed as the user's intent. Resuming uses
    // revealChrome so there's a 3-second window to see what's playing before
    // the chrome fades back out.
    private func handleTap(index: Int) {
        let willPause = !manager.isPaused
        manager.togglePlay(index: index)
        if willPause {
            chromeTask?.cancel()
            showChrome = true   // instant snap — no withAnimation wrapper
        } else {
            revealChrome()
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
                .init(color: .black.opacity(0.85), location: 0.0),
                .init(color: .black.opacity(0.5), location: 0.3),
                .init(color: .clear, location: 0.6),
                .init(color: .black.opacity(0.55), location: 0.7),
                .init(color: .black.opacity(0.9), location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var chrome: some View {
        VStack(alignment: .leading, spacing: 0) {
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
            .padding(.top, 8) // space below the always-visible progress bar (2pt bar + 6pt gap)

            Spacer(minLength: 0)

            bottomBar
                .padding(.horizontal, 22)
        }
        .padding(.top, 12)
        .padding(.bottom, 38)
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
            VStack(alignment: .leading, spacing: 6) {
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
        manager.onAdvanceRequest = { next in
            withAnimation(.easeInOut(duration: 0.5)) { scrollID = next }
        }
        manager.onChapterComplete = completeChapter
        manager.onVideoReached = onVideoReached
        manager.onVideoCompleted = onVideoCompleted
        manager.start(videos: chapter.videos, startIndex: startIndex)
        scrollID = startIndex
        // Start the initial hide timer directly — onChange fires immediately after
        // and would reset a revealChrome() call, making the effective window only
        // ~2 s after the 0.9 s insertion animation. 5 s here gives ~4 s of clearly
        // visible chrome once the view is fully opaque.
        chromeTask = Task {
            try? await Task.sleep(for: .seconds(8))
            guard !Task.isCancelled, !manager.isPaused else { return }
            withAnimation(.easeOut(duration: 0.5)) { showChrome = false }
        }
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

            // Poster placeholder beneath the video. Falls back to the artist
            // image, then ink, when no poster URL resolves.
            AsyncImage(url: video.posterURL ?? artist?.imageURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color.ink
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
        onDismiss: {},
        onChapterComplete: {},
        onVideoReached: { _ in },
        onVideoCompleted: { _ in }
    )
}
#endif
