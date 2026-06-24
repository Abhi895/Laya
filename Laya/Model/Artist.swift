//
//  Artist.swift
//  Laya
//
//  Created by Abhi Reddy on 17/06/2026.
//

import Foundation

struct Artist: Codable, Identifiable {
    let id: String
    let name, city, genre, bio, quote : String
    let imageURL: URL
    // Asset-catalog name for this artist's portrait (e.g. "artistCard",
    // "artistCard2") — lets ArtistCard / the locked screen / the share
    // artifact all show the right photo instead of one hardcoded image.
    let imageName: String
    let spotifyArtistId: String?
}

extension Artist {
    // Falls back to a warm, generic thank-you if an artist has no curated
    // quote yet — the share artifact should never render bare quote marks
    // with nothing inside them.
    var displayQuote: String {
        quote.isEmpty ? Artist.defaultQuote : quote
    }

    static let defaultQuote = "Thank you for being part of this with me — it means more than you know."
}

#if DEBUG
extension Artist {
    static let mock = Artist(
        id: "artist-tayo-james",
        name: "Tayo James",
        city: "London",
        genre: "R&B / Soul",
        bio: "I grew up in London, making music from my bedroom. People say I sound like Brent Faiyaz \u{2014} I’ll take it.",
        quote: "These stems are the messy parts of my brain. Keep them safe.",
        imageURL: URL(string: "https://placeholder.com/artist.jpg")!,
        imageName: "artistCard",
        spotifyArtistId: nil
        )

    static let mockBubba = Artist(
        id: "artist-bubba-itb",
        name: "Bubba itb",
        city: "London",
        genre: "Alt R&B / Indie",
        bio: "Most of this started on a laptop in my room at 2am. I never meant for anyone to hear it, then I couldn't stop putting it out.",
        quote: "This is the closest I've gotten to actually saying it out loud.",
        imageURL: URL(string: "https://placeholder.com/artist-bubba.jpg")!,
        imageName: "artistCard2",
        spotifyArtistId: nil
        )
}
#endif
