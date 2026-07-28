//
//  JourneyFeedManager.swift
//  Laya
//
//  Created by Abhi Reddy on 19/06/2026.
//

import Foundation
import AVFoundation
import Observation

/// Owns the AVPlayer pool for a single chapter's horizontal video feed.
///
/// A chapter is only 2–5 clips, so — unlike the infinite vertical feed this
/// pattern came from — every video is preloaded up front and nothing is ever
/// evicted. There's no looping: each clip plays once, and when the *current*
/// clip reaches the end the manager either pages to the next one or, on the last
/// clip, reports the chapter complete.
///
/// The view stays the scroll authority: it owns the `scrollPosition` and tells
/// the manager which index is current via `setCurrent(index:)`. Auto-advance is
/// expressed as a request back to the view (`onAdvanceRequest`), which activates
/// the next clip via `setCurrentMuted(index:)`/`fadeInAudio(duration:)` instead —
/// a deliberately separate path from manual-swipe `setCurrent`, so the auto-advance
/// ink transition's extra choreography never touches the manual-swipe path.
///
/// 2026-07-28: deliberately stripped back to structural parity with the
/// reference this pattern came from (`artist discoverer`) after #21 (video
/// blip on backward swipes) survived 4 fix attempts in one session — see
/// [[project_scrolling_minimal_reset]] for the full removed-feature list.
/// `setCurrentMuted`/`fadeInAudio` were then added back on top of that
/// minimal baseline specifically to support `JourneyPlayerView`'s auto-advance
/// ink transition; manual-swipe `setCurrent` is untouched by that addition.
@MainActor
@Observable
final class JourneyFeedManager {
    /// True while the current clip is user-paused (tap to toggle), so the play
    /// glyph can show.
    private(set) var isPaused = false
    /// 0→1 fraction of the current clip's playback time — updated ~10×/sec by a
    /// periodic time observer and used to drive smooth progress bar fill.
    private(set) var playbackFraction: Double = 0
    /// Duration in seconds for each clip, keyed by index. Populated as each
    /// clip's asset finishes loading. Used by the view to compute time-based
    /// chapter progress (elapsed / total) at a constant fill rate.
    private(set) var durations: [Int: Double] = [:]
    /// Elapsed chapter time divided by total chapter duration — moves at a
    /// constant rate regardless of individual clip lengths. Falls back to
    /// clip-count fraction while durations are still loading.
    /// Re-evaluates only when `playbackFraction` or `durations` change;
    /// `currentIndex` is @ObservationIgnored but is always set before
    /// `playbackFraction` in setCurrent, so both are in sync on each eval.
    var chapterProgressFraction: Double {
        guard !videos.isEmpty else { return 0 }
        let n = videos.count
        guard durations.count == n else {
            return Double(currentIndex) / Double(n)
        }
        let total = (0..<n).compactMap { durations[$0] }.reduce(0, +)
        guard total > 0 else { return Double(currentIndex) / Double(n) }
        let completed = (0..<currentIndex).compactMap { durations[$0] }.reduce(0.0, +)
        let current = (durations[currentIndex] ?? 0) * playbackFraction
        return (completed + current) / total
    }

    /// Page the feed to this index (fired when a clip plays to its end and a
    /// next clip exists). The view animates `scrollPosition` to it.
    var onAdvanceRequest: ((Int) -> Void)?
    /// The last clip finished — the chapter is done.
    var onChapterComplete: (() -> Void)?
    /// A clip became the current one — used only to record the resume
    /// pointer (where to drop back in), not to mark it watched. Reaching a
    /// clip isn't the same as finishing it.
    var onVideoReached: ((JourneyVideo) -> Void)?
    /// A clip played to its actual end — this is what marks it watched.
    var onVideoCompleted: ((JourneyVideo) -> Void)?

    @ObservationIgnored private var videos: [JourneyVideo] = []
    @ObservationIgnored private(set) var currentIndex = 0
    @ObservationIgnored private var started = false
    /// Gates the *first* clip's playback (audio + frame advance) separately from
    /// preloading. The chapter fades in over a slow crossfade owned by the parent
    /// view — preloading during that fade is desirable (assets are ready the
    /// moment it lands), but starting playback then is not: audio ignores the
    /// SwiftUI opacity animation entirely, so sound would start while the screen
    /// is still fading in. Set true via `allowPlayback()` once the caller's
    /// transition has actually finished. Mid-chapter paging (`setCurrent`) is
    /// unaffected — the user can't page a view that isn't visible yet.
    @ObservationIgnored private var canPlay = false

    /// Observed (not `@ObservationIgnored`): when a clip's player is created
    /// asynchronously, the assignment into this dict is what invalidates the
    /// corresponding `VideoCell` so it mounts the `AVPlayerLayer`. Without
    /// observation the cell would never re-render and the video stays blank.
    private var players: [Int: AVPlayer] = [:]
    @ObservationIgnored private var endObservers: [Int: NSObjectProtocol] = [:]
    @ObservationIgnored private var loadTasks: [Int: Task<Void, Never>] = [:]
    @ObservationIgnored private var timeObserver: Any?

    // MARK: - Lifecycle

    /// Preload every clip in the chapter and begin playing `startIndex`.
    func start(videos: [JourneyVideo], startIndex: Int) {
        guard !started else { return }
        started = true
        self.videos = videos
        currentIndex = min(max(0, startIndex), max(0, videos.count - 1))
        configureAudioSession()
        for index in videos.indices { preload(index: index) }
    }

    func player(at index: Int) -> AVPlayer? { players[index] }

    /// Signals that the chapter is actually visible now — releases the first
    /// clip to start playing if it was already preloaded and waiting.
    func allowPlayback() {
        guard !canPlay else { return }
        canPlay = true
        guard let player = players[currentIndex], !isPaused else { return }
        player.play()
        if timeObserver == nil {
            installTimeObserver(on: player, index: currentIndex)
        }
    }

    /// Make `index` the active clip: pause the others, restart this one from
    /// the top, and play. Safe to call before the player exists (it'll
    /// auto-play once it's ready).
    func setCurrent(index: Int) { activate(index: index, muted: false) }

    /// Auto-advance path only — primes the next clip silently (volume 0) so
    /// the view's ink cover can hide it landing before the reveal fades
    /// audio up via `fadeInAudio(duration:)`. Manual-swipe `setCurrent`
    /// never calls this.
    func setCurrentMuted(index: Int) { activate(index: index, muted: true) }

    /// Ramps the current clip's volume 0→1 — pairs with `setCurrentMuted`.
    func fadeInAudio(duration: Double) {
        guard let player = players[currentIndex] else { return }
        Task {
            let steps = 6
            for step in 1...steps {
                if Task.isCancelled { return }
                player.volume = Float(step) / Float(steps)
                try? await Task.sleep(for: .seconds(duration / Double(steps)))
            }
        }
    }

    private func activate(index: Int, muted: Bool) {
        guard videos.indices.contains(index) else { return }
        if let old = timeObserver { players[currentIndex]?.removeTimeObserver(old) }
        timeObserver = nil
        currentIndex = index
        playbackFraction = 0
        isPaused = false
        for player in players.values { player.pause() }
        if let player = players[index] {
            player.seek(to: .zero)
            player.volume = muted ? 0 : 1
            player.play()
            installTimeObserver(on: player, index: index)
        }
        onVideoReached?(videos[index])
    }

    private func installTimeObserver(on player: AVPlayer, index: Int) {
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self, self.currentIndex == index,
                  let item = player.currentItem,
                  item.duration.isNumeric, item.duration.seconds > 0 else { return }
            self.playbackFraction = min(time.seconds / item.duration.seconds, 1)
        }
    }

    /// Tap-to-toggle on the current clip.
    func togglePlay(index: Int) {
        guard index == currentIndex, let player = players[index] else { return }
        if player.timeControlStatus == .playing {
            player.pause()
            isPaused = true
        } else {
            player.play()
            isPaused = false
        }
    }

    func pauseAll() {
        for player in players.values { player.pause() }
    }

    func teardown() {
        if let old = timeObserver { players[currentIndex]?.removeTimeObserver(old) }
        timeObserver = nil
        loadTasks.values.forEach { $0.cancel() }
        endObservers.values.forEach { NotificationCenter.default.removeObserver($0) }
        players.values.forEach { $0.pause() }
        loadTasks.removeAll()
        endObservers.removeAll()
        players.removeAll()
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    // MARK: - Loading

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback)
        try? session.setActive(true)
    }

    /// How long before a clip's natural end its own audio ramps to silence —
    /// applied once, at load time, via the clip's own `AVAudioMix` (see
    /// `preload`). Matches `JourneyPlayerView.breathCover` so the auto-advance
    /// ink cover finishes rising roughly as the outgoing clip's audio finishes
    /// fading, though this fires for *every* clip reaching its end, not just
    /// auto-advanced ones. A player-level volume Task (wall-clock, not synced
    /// to playback position) can't do this correctly — the clip has already
    /// auto-paused (`actionAtItemEnd = .pause`) the instant it truly ends, so
    /// anything triggered afterward has nothing left to fade.
    private static let fadeOutTail: Double = 0.6

    private func preload(index: Int) {
        guard players[index] == nil, loadTasks[index] == nil else { return }
        let url = videos[index].videoURL
        loadTasks[index] = Task { [weak self] in
            let asset = AVURLAsset(url: url)
            _ = try? await asset.load(.isPlayable)
            let rawDur = (try? await asset.load(.duration)) ?? .indefinite
            if Task.isCancelled { return }
            guard let self else { return }
            if rawDur.isNumeric && rawDur.seconds > 0 {
                self.durations[index] = rawDur.seconds
            }
            let item = AVPlayerItem(asset: asset)
            if rawDur.isNumeric && rawDur.seconds > Self.fadeOutTail,
               let audioTracks = try? await asset.loadTracks(withMediaType: .audio),
               !audioTracks.isEmpty {
                let mix = AVMutableAudioMix()
                let fadeStart = CMTime(seconds: rawDur.seconds - Self.fadeOutTail, preferredTimescale: 600)
                let fadeRange = CMTimeRange(start: fadeStart, duration: CMTime(seconds: Self.fadeOutTail, preferredTimescale: 600))
                mix.inputParameters = audioTracks.map { track in
                    let params = AVMutableAudioMixInputParameters(track: track)
                    params.setVolumeRamp(fromStartVolume: 1, toEndVolume: 0, timeRange: fadeRange)
                    return params
                }
                item.audioMix = mix
            }
            let player = AVPlayer(playerItem: item)
            // We advance manually on end-of-item, so don't let the player loop or
            // freeze the last frame in a way that swallows the end notification.
            player.actionAtItemEnd = .pause
            self.players[index] = player
            self.observeEnd(item: item, index: index)
            self.loadTasks[index] = nil
            // If the user is already sitting on this page, start it the moment
            // it lands. Also install the time observer — setCurrent ran before
            // the player existed so it couldn't install it then.
            if index == self.currentIndex && !self.isPaused && self.canPlay {
                player.play()
                if self.timeObserver == nil {
                    self.installTimeObserver(on: player, index: index)
                }
            }
        }
    }

    private func observeEnd(item: AVPlayerItem, index: Int) {
        endObservers[index] = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            // Already on the main queue (queue: .main above) — no need for an
            // extra Task hop, which just adds a needless suspension point.
            self?.handleEnd(index: index)
        }
    }

    private func handleEnd(index: Int) {
        // Only the visible clip drives advancement.
        guard index == currentIndex else { return }
        onVideoCompleted?(videos[index])
        let next = index + 1
        if next < videos.count {
            onAdvanceRequest?(next)
        } else {
            onChapterComplete?()
        }
    }

    /// Testing aid — simulates the current clip finishing right now: marks it
    /// watched and advances exactly like a real end-of-clip would (or
    /// completes the chapter, on the last clip), instead of jumping straight
    /// to chapter-complete regardless of position. Lets the progress bars be
    /// exercised one clip at a time without waiting for real playback.
    func skipCurrent() {
        handleEnd(index: currentIndex)
    }
}
