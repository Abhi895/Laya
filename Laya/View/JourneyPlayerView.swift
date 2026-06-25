//
//  JourneyPlayerView.swift
//  Laya
//
//  Created by Abhi Reddy on 18/06/2026.
//

import SwiftUI

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

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.ink.ignoresSafeArea()
            feed.ignoresSafeArea()
            // Decorative only — must never intercept the horizontal paging drag.
            scrim.ignoresSafeArea().allowsHitTesting(false)
            content
        }
        .onAppear { setup() }
        .onDisappear { manager.teardown() }
        .onChange(of: scrollID) { _, newValue in
            if let newValue { manager.setCurrent(index: newValue) }
        }
    }

    // MARK: - Feed

    private var feed: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(Array(chapter.videos.enumerated()), id: \.element.id) { index, video in
                    VideoCell(index: index, video: video, artist: artist,
                              manager: manager, videoDetached: videoDetached)
                        .containerRelativeFrame(.horizontal)
                        .id(index)
                }
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
                .init(color: .clear, location: 0.22),
                .init(color: .clear, location: 0.66),
                .init(color: .black.opacity(0.55), location: 0.86),
                .init(color: .black.opacity(0.9), location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            ProgressBar(progress: progressFraction)
                .frame(height: 2)
                .padding(.horizontal, 22)
                .padding(.bottom, 6)

            HStack(alignment: .center) {
                chapterEyebrow
                Spacer()
                #if DEBUG
                skipButton
                #endif
                closeButton
            }
            .padding(.horizontal, 22)

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
            Haptics.tap()
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
        .buttonStyle(.plain)
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
            }
            .id(currentIndex) // re-renders the labels as paging changes the clip
            .transition(.opacity)

            Spacer(minLength: 16)

            VStack(spacing: 16) {
                if currentVideo?.spotifyTrackId != nil {
                    SpotifyButton {}
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

    private var currentIndex: Int { scrollID ?? startIndex }

    private var currentVideo: JourneyVideo? {
        chapter.videos.indices.contains(currentIndex) ? chapter.videos[currentIndex] : nil
    }

    private var chapterLabel: String {
        " \(romanNumeral(chapter.index + 1)) • \(chapter.title)"
    }

    private var performanceLabel: String {
        switch currentVideo?.kind {
        case .live:       return "Live Performance"
        case .musicVideo: return "Music Video"
        case .cover:      return "Cover"
        case .interview:  return "Interview"
        case .bts:        return "Behind the Scenes"
        case .none:       return ""
        }
    }

    private var trackTitle: String { currentVideo?.title ?? "" }

    // How far through *this chapter* the user is — clip position within the
    // chapter, not the chapter's position in the journey.
    private var progressFraction: Double {
        guard !chapter.videos.isEmpty else { return 0 }
        return Double(currentIndex + 1) / Double(chapter.videos.count)
    }
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
        .onTapGesture { manager.togglePlay(index: index) }
    }
}

// MARK: - Progress bar

//TODO: segment the progress bar and show completion within each video in the chapter in each segemnt

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
        .animation(.easeInOut(duration: 0.3), value: progress)
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
