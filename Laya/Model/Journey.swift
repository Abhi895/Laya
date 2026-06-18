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

#if DEBUG
extension Journey {
    static let mock = Journey(
        id: "journey-tayo-james",
        artistId: "artist-tayo-james",
        chapters: [.mockBackground, .mockMusic, .mockGoals]
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
}

extension JourneyVideo {
    static let mockBackgroundVideos: [JourneyVideo] = [
        JourneyVideo(
            id: "video-bg-1",
            videoURL: URL(string: "https://placeholder.com/video1.mp4")!,
            posterURL: nil,
            kind: .interview,
            title: "Growing up",
            spotifyTrackId: nil
        ),
        JourneyVideo(
            id: "video-bg-2",
            videoURL: URL(string: "https://placeholder.com/video2.mp4")!,
            posterURL: nil,
            kind: .bts,
            title: "In the studio",
            spotifyTrackId: nil
        )
    ]

    static let mockMusicVideos: [JourneyVideo] = [
        JourneyVideo(
            id: "video-music-1",
            videoURL: URL(string: "https://placeholder.com/video3.mp4")!,
            posterURL: nil,
            kind: .musicVideo,
            title: "Know it",
            spotifyTrackId: "spotify-track-123"
        ),
        JourneyVideo(
            id: "video-music-2",
            videoURL: URL(string: "https://placeholder.com/video4.mp4")!,
            posterURL: nil,
            kind: .live,
            title: "Heart of Darkness",
            spotifyTrackId: "spotify-track-456"
        )
    ]

    static let mockGoalsVideos: [JourneyVideo] = [
        JourneyVideo(
            id: "video-goals-1",
            videoURL: URL(string: "https://placeholder.com/video5.mp4")!,
            posterURL: nil,
            kind: .interview,
            title: "Making it big",
            spotifyTrackId: nil
        )
    ]
}
#endif
