//
//  Artist.swift
//  Laya
//
//  Created by Abhi Reddy on 17/06/2026.
//

import Foundation

struct Artist: Codable, Identifiable {
    let id: String
    let name, city, genre, bio : String
    let imageURL: URL
    let spotifyArtistId: String?
}

#if DEBUG
extension Artist {
    static let mock = Artist(
        id: "artist-tayo-james",
        name: "Tayo James",
        city: "London",
        genre: "R&B / Soul",
        bio: "I grew up in London, making music from my bedroom. People say I sound like Brent Faiyaz - I’ll take it.",
        imageURL: URL(string: "https://placeholder.com/artist.jpg")!,
        spotifyArtistId: nil
        )
}
#endif
