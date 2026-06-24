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
        spotifyArtistId: nil
        )
}
#endif
