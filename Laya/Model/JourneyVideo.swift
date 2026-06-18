import Foundation

// Video item within a Chapter
struct JourneyVideo: Codable, Identifiable {
    enum Kind: String, Codable {
        case interview
        case cover
        case live
        case musicVideo
        case bts
    }

    // Unique identifier for the video
    let id: String
    // Remote URL to the video asset
    let videoURL: URL
    // Optional poster/thumbnail image URL
    let posterURL: URL?
    // Type of the video clip
    let kind: Kind
    // Title of the video clip
    let title: String
    // Optional Spotify track ID (for music-kind clips)
    let spotifyTrackId: String?
}
