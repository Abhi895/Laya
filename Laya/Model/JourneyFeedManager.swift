//
//  JourneyFeedManager.swift
//  Laya
//
//  Created by Abhi Reddy on 19/06/2026.
//

import Foundation
import AVFoundation
import Observation
import UIKit

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
/// expressed as a request back to the view (`onAdvanceRequest`) so there's a
/// single code path for both user paging and end-of-clip paging.
@MainActor
@Observable
final class JourneyFeedManager {
    /// Indices whose player has reached `.readyToPlay` — drives the poster→video
    /// crossfade in each cell so there's no black flash on first frame.
    private(set) var readyIndices: Set<Int> = []
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
    /// Frame-zero thumbnail for each clip, keyed by index — the real poster,
    /// generated locally so it always matches the clip it sits under (unlike
    /// a generic artist photo, which reads as a mismatch flash on cut).
    private(set) var thumbnails: [Int: UIImage] = [:]
    /// Last frame actually displayed by a clip that has played and then
    /// stopped being current (manual swipe away or auto-advance), keyed by
    /// index. Preferred over `thumbnails` (always frame-zero) as the cell's
    /// fallback poster so a clip freezes on its real position instead of
    /// rewinding to its first frame if the AVPlayerLayer goes momentarily
    /// transparent mid-transition.
    private(set) var lastFrames: [Int: UIImage] = [:]
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
    @ObservationIgnored private var statusObservations: [Int: NSKeyValueObservation] = [:]
    @ObservationIgnored private var endObservers: [Int: NSObjectProtocol] = [:]
    @ObservationIgnored private var loadTasks: [Int: Task<Void, Never>] = [:]
    @ObservationIgnored private var thumbnailTasks: [Int: Task<Void, Never>] = [:]
    @ObservationIgnored private var lastFrameTasks: [Int: Task<Void, Never>] = [:]
    @ObservationIgnored private var fadeTasks: [Int: Task<Void, Never>] = [:]
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
        fadeIn(index: currentIndex)
        if timeObserver == nil {
            installTimeObserver(on: player, index: currentIndex)
        }
    }

    /// Make `index` the active clip: pause the others, restart this one from the
    /// top, and play. Safe to call before the player exists (it'll auto-play once
    /// it's ready). Pass `autoplay: false` to seek/prep the clip without starting
    /// it — used by the auto-advance ink-dip breath, which needs the clip ready
    /// while still fully covered, and only calls `beginPlayback()` once the cover
    /// has cleared.
    func setCurrent(index: Int, autoplay: Bool = true) {
        guard videos.indices.contains(index) else { return }
        // Remove the old periodic observer before installing a new one.
        if let old = timeObserver { players[currentIndex]?.removeTimeObserver(old) }
        timeObserver = nil
        let previousIndex = currentIndex
        // Index must be set BEFORE playbackFraction so the observation that fires
        // on playbackFraction = 0 sees the new index — preventing a one-frame
        // overshoot on the progress bar at clip boundaries.
        currentIndex = index
        playbackFraction = 0
        isPaused = false
        // Only the outgoing clip was actually making sound — it gets a fade-out.
        // Everything else is already silent, so a hard pause is a no-op for them.
        for (i, player) in players where i != index && i != previousIndex {
            player.pause()
        }
        if previousIndex != index {
            captureLastFrame(index: previousIndex)
            fadeOutAndPause(index: previousIndex)
        }
        if let player = players[index] {
            player.seek(to: .zero)
            if autoplay {
                fadeIn(index: index)
                installTimeObserver(on: player, index: index)
            }
        }
        onVideoReached?(videos[index])
    }

    /// Starts playback of the already-current clip that was primed silently via
    /// `setCurrent(index:autoplay:false)` — called once the ink-dip's cover has
    /// cleared. Same prep/play split as `allowPlayback()`, applied per
    /// intra-chapter transition instead of once at chapter entrance.
    func beginPlayback() {
        guard let player = players[currentIndex] else { return }
        fadeIn(index: currentIndex)
        if timeObserver == nil {
            installTimeObserver(on: player, index: currentIndex)
        }
    }

    /// Ramps volume 0→1 over ~180ms and starts playback immediately (the video
    /// cut stays instant — only the audio is softened, which is what actually
    /// reads as "abrupt" at a clip boundary).
    private func fadeIn(index: Int) {
        guard let player = players[index] else { return }
        fadeTasks[index]?.cancel()
        player.volume = 0
        player.play()
        fadeTasks[index] = Task { [weak self] in
            let steps = 6
            for step in 1...steps {
                if Task.isCancelled { return }
                player.volume = Float(step) / Float(steps)
                try? await Task.sleep(for: .milliseconds(30))
            }
            guard !Task.isCancelled else { return }
            self?.fadeTasks[index] = nil
        }
    }

    /// Ramps volume to 0 over ~180ms, then pauses and resets volume to 1 so the
    /// player is ready to fade in cleanly next time it becomes current.
    private func fadeOutAndPause(index: Int) {
        guard let player = players[index] else { return }
        fadeTasks[index]?.cancel()
        let startVolume = player.volume
        fadeTasks[index] = Task { [weak self] in
            let steps = 6
            for step in 1...steps {
                if Task.isCancelled { return }
                player.volume = startVolume * (1 - Float(step) / Float(steps))
                try? await Task.sleep(for: .milliseconds(30))
            }
            guard !Task.isCancelled else { return }
            player.pause()
            player.volume = 1
            self?.fadeTasks[index] = nil
        }
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
        fadeTasks.values.forEach { $0.cancel() }
        fadeTasks.removeAll()
        for player in players.values { player.pause() }
    }

    func teardown() {
        if let old = timeObserver { players[currentIndex]?.removeTimeObserver(old) }
        timeObserver = nil
        loadTasks.values.forEach { $0.cancel() }
        thumbnailTasks.values.forEach { $0.cancel() }
        lastFrameTasks.values.forEach { $0.cancel() }
        fadeTasks.values.forEach { $0.cancel() }
        statusObservations.values.forEach { $0.invalidate() }
        endObservers.values.forEach { NotificationCenter.default.removeObserver($0) }
        players.values.forEach { $0.pause() }
        loadTasks.removeAll()
        thumbnailTasks.removeAll()
        lastFrameTasks.removeAll()
        fadeTasks.removeAll()
        statusObservations.removeAll()
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
            let player = AVPlayer(playerItem: item)
            // We advance manually on end-of-item, so don't let the player loop or
            // freeze the last frame in a way that swallows the end notification.
            player.actionAtItemEnd = .pause
            self.players[index] = player
            self.observeReady(item: item, index: index)
            self.observeEnd(item: item, index: index)
            self.loadTasks[index] = nil
            self.generateThumbnail(asset: asset, index: index)
            // If the user is already sitting on this page, start it the moment
            // it lands. Also install the time observer — setCurrent ran before
            // the player existed so it couldn't install it then.
            if index == self.currentIndex && !self.isPaused && self.canPlay {
                self.fadeIn(index: index)
                if self.timeObserver == nil {
                    self.installTimeObserver(on: player, index: index)
                }
            }
        }
    }

    /// Grabs the exact frame the clip was showing right as it stops being
    /// current, so a cell that goes momentarily transparent mid-swipe (see
    /// VideoCell) reveals a matching freeze-frame instead of rewinding to
    /// frame-zero. Skipped for clips barely into playback — the frame-zero
    /// thumbnail already covers that case.
    private func captureLastFrame(index: Int) {
        guard let player = players[index], let item = player.currentItem else { return }
        let time = player.currentTime()
        guard time.seconds > 0.05 else { return }
        let generator = AVAssetImageGenerator(asset: item.asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        lastFrameTasks[index]?.cancel()
        lastFrameTasks[index] = Task { [weak self] in
            guard let result = try? await generator.image(at: time) else { return }
            guard let self, !Task.isCancelled else { return }
            self.lastFrames[index] = UIImage(cgImage: result.image)
            self.lastFrameTasks[index] = nil
        }
    }

    /// Grabs the clip's frame-zero image so `VideoCell` has a poster that
    /// actually matches the clip underneath, instead of falling back to a
    /// generic artist photo.
    private func generateThumbnail(asset: AVURLAsset, index: Int) {
        thumbnailTasks[index] = Task { [weak self] in
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.requestedTimeToleranceBefore = .zero
            generator.requestedTimeToleranceAfter = .zero
            guard let result = try? await generator.image(at: .zero) else { return }
            guard let self, !Task.isCancelled else { return }
            self.thumbnails[index] = UIImage(cgImage: result.image)
            self.thumbnailTasks[index] = nil
        }
    }

    private func observeReady(item: AVPlayerItem, index: Int) {
        statusObservations[index] = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            guard item.status == .readyToPlay else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.readyIndices.insert(index)
                if index == self.currentIndex && !self.isPaused && self.canPlay {
                    self.fadeIn(index: index)
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
