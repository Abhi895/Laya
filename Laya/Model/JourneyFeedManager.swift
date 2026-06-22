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

    /// Page the feed to this index (fired when a clip plays to its end and a
    /// next clip exists). The view animates `scrollPosition` to it.
    var onAdvanceRequest: ((Int) -> Void)?
    /// The last clip finished — the chapter is done.
    var onChapterComplete: (() -> Void)?
    /// A clip became the current one — used to record watched / resume state.
    var onVideoReached: ((JourneyVideo) -> Void)?

    @ObservationIgnored private var videos: [JourneyVideo] = []
    @ObservationIgnored private(set) var currentIndex = 0
    @ObservationIgnored private var started = false

    /// Observed (not `@ObservationIgnored`): when a clip's player is created
    /// asynchronously, the assignment into this dict is what invalidates the
    /// corresponding `VideoCell` so it mounts the `AVPlayerLayer`. Without
    /// observation the cell would never re-render and the video stays blank.
    private var players: [Int: AVPlayer] = [:]
    @ObservationIgnored private var statusObservations: [Int: NSKeyValueObservation] = [:]
    @ObservationIgnored private var endObservers: [Int: NSObjectProtocol] = [:]
    @ObservationIgnored private var loadTasks: [Int: Task<Void, Never>] = [:]

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

    /// Make `index` the active clip: pause the others, restart this one from the
    /// top, and play. Safe to call before the player exists (it'll auto-play once
    /// it's ready).
    func setCurrent(index: Int) {
        guard videos.indices.contains(index) else { return }
        currentIndex = index
        isPaused = false
        for (i, player) in players where i != index { player.pause() }
        if let player = players[index] {
            player.seek(to: .zero)
            player.play()
        }
        onVideoReached?(videos[index])
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
        loadTasks.values.forEach { $0.cancel() }
        statusObservations.values.forEach { $0.invalidate() }
        endObservers.values.forEach { NotificationCenter.default.removeObserver($0) }
        players.values.forEach { $0.pause() }
        loadTasks.removeAll()
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
            if Task.isCancelled { return }
            guard let self else { return }
            let item = AVPlayerItem(asset: asset)
            let player = AVPlayer(playerItem: item)
            // We advance manually on end-of-item, so don't let the player loop or
            // freeze the last frame in a way that swallows the end notification.
            player.actionAtItemEnd = .pause
            self.players[index] = player
            self.observeReady(item: item, index: index)
            self.observeEnd(item: item, index: index)
            self.loadTasks[index] = nil
            // If the user is already sitting on this page, start it the moment
            // it lands.
            if index == self.currentIndex && !self.isPaused {
                player.play()
            }
        }
    }

    private func observeReady(item: AVPlayerItem, index: Int) {
        statusObservations[index] = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            guard item.status == .readyToPlay else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.readyIndices.insert(index)
                if index == self.currentIndex && !self.isPaused {
                    self.players[index]?.play()
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
            Task { @MainActor [weak self] in self?.handleEnd(index: index) }
        }
    }

    private func handleEnd(index: Int) {
        // Only the visible clip drives advancement.
        guard index == currentIndex else { return }
        let next = index + 1
        if next < videos.count {
            onAdvanceRequest?(next)
        } else {
            onChapterComplete?()
        }
    }
}
