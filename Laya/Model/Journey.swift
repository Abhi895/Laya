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
            // Bundled 1080x1920 portrait clip so the first page genuinely fills a
            // phone screen edge-to-edge (the remote samples are letterboxed 16:9).
            videoURL: Bundle.main.url(forResource: "portrait_sample", withExtension: "mp4")!,
            posterURL: nil,
            kind: .interview,
            title: "Growing up",
            spotifyTrackId: nil        ),
        JourneyVideo(
            id: "video-bg-2",
            videoURL: URL(string: "https://media.w3.org/2010/05/bunny/trailer.mp4")!,
            posterURL: nil,
            kind: .bts,
            title: "In the studio",
            spotifyTrackId: nil        )
    ]

    static let mockMusicVideos: [JourneyVideo] = [
        JourneyVideo(
            id: "video-music-1",
            // Bundled clip — same source as background-1, confirmed to play on device.
            videoURL: Bundle.main.url(forResource: "portrait_sample", withExtension: "mp4")!,
            posterURL: nil,
            kind: .musicVideo,
            title: "Know it",
            spotifyTrackId: "spotify-track-123"
        ),
        JourneyVideo(
            id: "video-music-2",
            videoURL: URL(string: "https://media.w3.org/2010/05/bunny/trailer.mp4")!,
            posterURL: nil,
            kind: .live,
            title: "Heart of Darkness",
            spotifyTrackId: "spotify-track-456"
        )
    ]

    static let mockGoalsVideos: [JourneyVideo] = [
        JourneyVideo(
            id: "video-goals-1",
            videoURL: URL(string: "https://media.w3.org/2010/05/sintel/trailer.mp4")!,
            posterURL: nil,
            kind: .interview,
            title: "Making it big",
            spotifyTrackId: nil        )
    ]

    // Bubba's journey reuses the same bundled/sample sources as Tayo's —
    // no new media exists yet, only new ids so progress between the two
    // journeys never collides.
    static let mockBubbaBackgroundVideos: [JourneyVideo] = [
        JourneyVideo(
            id: "video-bubba-bg-1",
            videoURL: Bundle.main.url(forResource: "portrait_sample", withExtension: "mp4")!,
            posterURL: nil,
            kind: .interview,
            title: "Growing up",
            spotifyTrackId: nil        ),
        JourneyVideo(
            id: "video-bubba-bg-2",
            videoURL: URL(string: "https://media.w3.org/2010/05/bunny/trailer.mp4")!,
            posterURL: nil,
            kind: .bts,
            title: "In the studio",
            spotifyTrackId: nil        )
    ]

    static let mockBubbaMusicVideos: [JourneyVideo] = [
        JourneyVideo(
            id: "video-bubba-music-1",
            videoURL: Bundle.main.url(forResource: "portrait_sample", withExtension: "mp4")!,
            posterURL: nil,
            kind: .musicVideo,
            title: "Know it",
            spotifyTrackId: "spotify-track-123"
        ),
        JourneyVideo(
            id: "video-bubba-music-2",
            videoURL: URL(string: "https://media.w3.org/2010/05/bunny/trailer.mp4")!,
            posterURL: nil,
            kind: .live,
            title: "Heart of Darkness",
            spotifyTrackId: "spotify-track-456"
        )
    ]

    static let mockBubbaGoalsVideos: [JourneyVideo] = [
        JourneyVideo(
            id: "video-bubba-goals-1",
            videoURL: URL(string: "https://media.w3.org/2010/05/sintel/trailer.mp4")!,
            posterURL: nil,
            kind: .interview,
            title: "Making it big",
            spotifyTrackId: nil        )
    ]
}
#endif

