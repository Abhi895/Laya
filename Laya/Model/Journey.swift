import Foundation

// Journey (one per artist — the content package)
struct Journey: Codable, Identifiable {

    // Unique identifier for the journey
    let id: String
    // The associated artist's identifier
    let artistId: String
    // Ordered chapters (v1 expects exactly 3)
    let chapters: [Chapter]

}

extension Journey {
    /// True once every chapter has been watched — the single source of truth
    /// for "is the whole journey done", shared by every screen that needs to
    /// answer that question rather than each inferring it its own way.
    func isComplete(_ watched: Set<String>) -> Bool {
        chapters.isComplete(watched)
    }
}

extension Array where Element == Chapter {
    /// Same check as `Journey.isComplete`, for call sites that only hold the
    /// flat chapter list rather than the whole `Journey`.
    func isComplete(_ watched: Set<String>) -> Bool {
        !isEmpty && allSatisfy { $0.isComplete(watched) }
    }

    /// The chapter the user should land on, given how many chapters they've
    /// reached (index one past the last chapter completed). Clamps so an
    /// index at or beyond the end resolves to the last chapter. Derived
    /// purely from the monotonic furthest-reached marker, never from
    /// per-clip watched state — a partially skipped earlier chapter can't
    /// pull this backward.
    func chapter(furthestReached index: Int) -> Chapter? {
        guard !isEmpty else { return nil }
        return self[Swift.min(Swift.max(index, 0), count - 1)]
    }

    /// The chapter Home should show as current: normally just the furthest
    /// one reached. But once every chapter has been passed through at least
    /// once (`index >= count`), an earlier chapter can still hold a genuine,
    /// never-healed watch gap — e.g. "Skip for demo" jumping past it, or a
    /// clip abandoned mid-play. Without routing back to that gap, the
    /// journey could never honestly satisfy `isComplete` and Home would
    /// strand the user on a later chapter forever. Only applies at the end —
    /// mid-journey, this must stay pure furthest-reached, or forward
    /// progress would silently revert to an earlier chapter again.
    func currentChapter(furthestReached index: Int, watched: Set<String>) -> Chapter? {
        if index >= count, let gap = first(where: { !$0.isComplete(watched) }) {
            return gap
        }
        return chapter(furthestReached: index)
    }
}

#if DEBUG
extension Journey {
    static let mock = Journey(
        id: "journey-tayo-james",
        artistId: "artist-tayo-james",
        chapters: [.mockBackground, .mockMusic, .mockGoals]
    )

    static let mockBubba = Journey(
        id: "journey-bubba-itb",
        artistId: "artist-bubba-itb",
        chapters: [.mockBubbaBackground, .mockBubbaMusic, .mockBubbaGoals]
    )
}

extension Chapter {
    static let mockBackground = Chapter(
        id: "chapter-background",
        index: 0,
        title: "Background",
        subtitle: "Where Tayo began.",
        unlockOffsetDays: 0,
        videos: JourneyVideo.mockBackgroundVideos
    )

    static let mockMusic = Chapter(
        id: "chapter-music",
        index: 1,
        title: "Music",
        subtitle: "The sound that defines him.",
        unlockOffsetDays: 2,
        videos: JourneyVideo.mockMusicVideos
    )

    static let mockGoals = Chapter(
        id: "chapter-goals",
        index: 2,
        title: "Goals",
        subtitle: "Where he's headed.",
        unlockOffsetDays: 5,
        videos: JourneyVideo.mockGoalsVideos
    )

    static let mockBubbaBackground = Chapter(
        id: "chapter-bubba-background",
        index: 0,
        title: "Background",
        subtitle: "Where Bubba began.",
        unlockOffsetDays: 0,
        videos: JourneyVideo.mockBubbaBackgroundVideos
    )

    static let mockBubbaMusic = Chapter(
        id: "chapter-bubba-music",
        index: 1,
        title: "Music",
        subtitle: "The sound Bubba's known for.",
        unlockOffsetDays: 2,
        videos: JourneyVideo.mockBubbaMusicVideos
    )

    static let mockBubbaGoals = Chapter(
        id: "chapter-bubba-goals",
        index: 2,
        title: "Goals",
        subtitle: "Where Bubba's headed.",
        unlockOffsetDays: 5,
        videos: JourneyVideo.mockBubbaGoalsVideos
    )
}

extension JourneyVideo {
    // Public W3C / Blender sample clips so the player is actually exercisable in
    // DEBUG builds/previews. Swap for real (HLS) sources when the catalog is wired.
    static let mockBackgroundVideos: [JourneyVideo] = [
        JourneyVideo(
            id: "video-bg-1",
            videoURL: URL(string: "https://media.w3.org/2010/05/video/movie_300.mp4")!,
            posterURL: nil,
            kind: .interview,
            title: "Growing up",
            spotifyTrackId: nil, secondaryArtist: nil        ),
        JourneyVideo(
            id: "video-bg-2",
            videoURL: URL(string: "https://media.w3.org/2010/05/bunny/trailer.mp4")!,
            posterURL: nil,
            kind: .bts,
            title: "In the studio",
            spotifyTrackId: nil, secondaryArtist: nil        )
    ]

    static let mockMusicVideos: [JourneyVideo] = [
        JourneyVideo(
            id: "video-music-1",
            videoURL: URL(string: "https://media.w3.org/2010/05/sintel/trailer.mp4")!,
            posterURL: nil,
            kind: .musicVideo,
            title: "Know it",
            spotifyTrackId: "spotify-track-123",
            secondaryArtist: nil
        ),
        JourneyVideo(
            id: "video-music-2",
            videoURL: URL(string: "https://media.w3.org/2010/05/bunny/trailer.mp4")!,
            posterURL: nil,
            kind: .live,
            title: "Heart of Darkness",
            spotifyTrackId: "spotify-track-456",
            secondaryArtist: nil
        )
    ]

    static let mockGoalsVideos: [JourneyVideo] = [
        JourneyVideo(
            id: "video-goals-1",
            videoURL: URL(string: "https://media.w3.org/2010/05/sintel/trailer.mp4")!,
            posterURL: nil,
            kind: .interview,
            title: "Making it big",
            spotifyTrackId: nil, secondaryArtist: nil        )
    ]

    // Bubba's journey reuses the same bundled/sample sources as Tayo's —
    // no new media exists yet, only new ids so progress between the two
    // journeys never collides.
    static let mockBubbaBackgroundVideos: [JourneyVideo] = [
        JourneyVideo(
            id: "video-bubba-bg-1",
            videoURL: URL(string: "https://media.w3.org/2010/05/video/movie_300.mp4")!,
            posterURL: nil,
            kind: .interview,
            title: "Growing up",
            spotifyTrackId: nil, secondaryArtist: nil        ),
        JourneyVideo(
            id: "video-bubba-bg-2",
            videoURL: URL(string: "https://media.w3.org/2010/05/bunny/trailer.mp4")!,
            posterURL: nil,
            kind: .bts,
            title: "In the studio",
            spotifyTrackId: nil, secondaryArtist: nil        )
    ]

    static let mockBubbaMusicVideos: [JourneyVideo] = [
        JourneyVideo(
            id: "video-bubba-music-1",
            videoURL: URL(string: "https://media.w3.org/2010/05/sintel/trailer.mp4")!,
            posterURL: nil,
            kind: .musicVideo,
            title: "Know it",
            spotifyTrackId: "spotify-track-123",
            secondaryArtist: nil
        ),
        JourneyVideo(
            id: "video-bubba-music-2",
            videoURL: URL(string: "https://media.w3.org/2010/05/bunny/trailer.mp4")!,
            posterURL: nil,
            kind: .live,
            title: "Heart of Darkness",
            spotifyTrackId: "spotify-track-456",
            secondaryArtist: nil
        )
    ]

    static let mockBubbaGoalsVideos: [JourneyVideo] = [
        JourneyVideo(
            id: "video-bubba-goals-1",
            videoURL: URL(string: "https://media.w3.org/2010/05/sintel/trailer.mp4")!,
            posterURL: nil,
            kind: .interview,
            title: "Making it big",
            spotifyTrackId: nil, secondaryArtist: nil        )
    ]
}
#endif

