//
//  User.swift
//  Laya
//
//  Created by Abhi Reddy on 17/06/2026.
//

import Foundation

struct User: Codable, Identifiable {
    let id: String
    let displayName: String?
    let authProvider: AuthProvider
    let tasteProfile: [String] // ignore for now
    let followedArtistIds: [String]
    let createdAt: Date
    
}

