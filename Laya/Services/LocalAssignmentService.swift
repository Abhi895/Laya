//
//  LocalAssignmentService.swift
//  Laya
//
//  Created by Abhi Reddy on 25/06/2026.
//

import Foundation

/// The real `AssignmentServing` implementation — available in every build
/// configuration, unlike `MockAssignmentService` (DEBUG-only). Reads a
/// single bundled JSON manifest describing "this week's" artist/journey/
/// videos, resolves each video to either a locally-bundled file or a remote
/// URL, and persists watched-video progress to disk so it survives the app
/// being relaunched (the one thing the mock store never did).
///
/// No backend: pushing a new week's assignment means updating
/// `CurrentAssignment.json` (and any new bundled video files) and shipping a
/// new build — a deliberate MVP simplification, not an oversight. The
/// `AssignmentServing` boundary already existed for exactly this swap.
struct LocalAssignmentService: AssignmentServing {
    private static let manifestResource = "CurrentAssignment"

    func fetchCurrentAssignment(for userId: String) async throws -> AssignmentPackage {
        let manifest = try Self.loadManifest()
        let artist = manifest.artist.toModel()
        let journey = try manifest.journey.toModel()

        let assignmentId = "assignment-\(journey.id)"
        let progress =
        LocalProgressStore.shared.progress(for: assignmentId)
        let assignment = WeeklyAssignment(
            id: assignmentId,
            userId: userId,
            journeyId: journey.id,
            weekStartDate: LocalProgressStore.shared.journeyStartDate(for: journey.id),
            assignedAt: Date(),
            progress: progress
        )
        return AssignmentPackage(assignment: assignment, journey: journey, artist: artist)
    }

    func updateProgress(_ progress: JourneyProgress, assignmentId: String) async throws {
        LocalProgressStore.shared.set(progress, for: assignmentId)
    }

    @MainActor func resetAllProgress() {
        LocalProgressStore.shared.reset()
    }

    func completeChapter(index: Int, assignmentId: String) async throws {
        // No-op — every screen derives chapter/journey completion from
        // watchedVideoIds (Chapter.isComplete / Journey.isComplete) rather
        // than a separate stored flag, so there's nothing extra to persist.
    }

    private static func loadManifest() throws -> AssignmentManifest {
        guard let url = Bundle.main.url(forResource: manifestResource, withExtension: "json") else {
            throw LocalAssignmentError.manifestMissing
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(AssignmentManifest.self, from: data)
    }

    // Debug-only conveniences mirroring MockAssignmentService's, but
    // operating on this service's real (persisted) store, so the existing
    // debug chips keep working against whichever service ContentView wires
    // up.
    #if DEBUG
    @MainActor
    static func resetProgress() {
        LocalProgressStore.shared.reset()
    }

    @MainActor
    static func skipToFinished() {
        guard let manifest = try? loadManifest(), let journey = try? manifest.journey.toModel() else { return }
        let chapters = journey.chapters
        let watched = Set(chapters.dropLast().flatMap { $0.videos.map(\.id) })
        LocalProgressStore.shared.set(
            JourneyProgress(
                watchedVideoIds: watched,
                lastWatchedVideoId: chapters.dropLast().last?.videos.last?.id,
                completedAt: nil
            ),
            for: "assignment-\(journey.id)"
        )
    }
    #endif
}

enum LocalAssignmentError: Error {
    case manifestMissing
    case videoFileMissing(String)
}

// MARK: - JSON schema

private struct AssignmentManifest: Codable {
    let artist: ArtistDTO
    let journey: JourneyDTO
}

private struct ArtistDTO: Codable {
    let id, name, city, genre, bio, quote: String
    let imageName: String
    let spotifyArtistId: String?

    func toModel() -> Artist {
        Artist(
            id: id, name: name, city: city, genre: genre, bio: bio, quote: quote,
            imageURL: URL(string: "https://laya.app/placeholder")!,
            imageName: imageName,
            spotifyArtistId: spotifyArtistId
        )
    }
}

private struct JourneyDTO: Codable {
    let id: String
    let artistId: String
    let chapters: [ChapterDTO]

    func toModel() throws -> Journey {
        Journey(id: id, artistId: artistId, chapters: try chapters.map { try $0.toModel() })
    }
}

private struct ChapterDTO: Codable {
    let id: String
    let index: Int
    let title: String
    let subtitle: String
    let unlockOffsetDays: Int
    let videos: [JourneyVideoDTO]

    func toModel() throws -> Chapter {
        Chapter(
            id: id, index: index, title: title, subtitle: subtitle,
            unlockOffsetDays: unlockOffsetDays,
            videos: try videos.map { try $0.toModel() }
        )
    }
}

private struct JourneyVideoDTO: Codable {
    let id: String
    /// Exactly one of these two should be present — whichever is, is what
    /// gets resolved to the real videoURL. Local for bundled artist
    /// content; remote as a fallback while real files aren't ready yet.
    let localFilename: String?
    let remoteURL: String?
    let posterRemoteURL: String?
    let kind: JourneyVideo.Kind?
    let title: String
    let spotifyTrackId: String?
    let secondaryArtist: String?

    func toModel() throws -> JourneyVideo {
        let resolvedURL: URL
        if let localFilename {
            let parts = localFilename.split(separator: ".", maxSplits: 1)
            guard parts.count == 2,
                  let url = Bundle.main.url(forResource: String(parts[0]), withExtension: String(parts[1])) else {
                throw LocalAssignmentError.videoFileMissing(localFilename)
            }
            resolvedURL = url
        } else if let remoteURL, let url = URL(string: remoteURL) {
            resolvedURL = url
        } else {
            throw LocalAssignmentError.videoFileMissing(id)
        }
        return JourneyVideo(
            id: id,
            videoURL: resolvedURL,
            posterURL: posterRemoteURL.flatMap { URL(string: $0) },
            kind: kind,
            title: title,
            spotifyTrackId: spotifyTrackId,
            secondaryArtist: secondaryArtist
        )
    }
}

// MARK: - Persistence

/// Disk-backed (UserDefaults + Codable) progress store, keyed by assignment
/// id — replaces the mock's in-memory-only dictionary, which lost all
/// progress the moment the app process was killed or evicted in the
/// background.
@MainActor
private final class LocalProgressStore {
    static let shared = LocalProgressStore()
    private let defaultsKey = "laya.localProgress.v1"
    private var progress: [String: JourneyProgress]

    private init() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode([String: JourneyProgress].self, from: data) {
            progress = decoded
        } else {
            progress = [:]
        }
    }

    func progress(for assignmentId: String) -> JourneyProgress {
        progress[assignmentId] ?? JourneyProgress(watchedVideoIds: [], lastWatchedVideoId: nil, completedAt: nil)
    }

    func set(_ value: JourneyProgress, for assignmentId: String) {
        progress[assignmentId] = value
        persist()
    }

    func reset() {
        progress.removeAll()
        persist()
        UserDefaults.standard.dictionaryRepresentation().keys
            .filter { $0.hasPrefix("laya.journeyStart.") }
            .forEach { UserDefaults.standard.removeObject(forKey: $0) }
    }

    func journeyStartDate(for journeyId: String) -> Date {
        let key = "laya.journeyStart.\(journeyId)"
        if let stored = UserDefaults.standard.object(forKey: key) as? Date { return stored }
        let now = Date()
        UserDefaults.standard.set(now, forKey: key)
        return now
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(progress) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }
}

/// A stable per-device identifier, persisted on first use — stands in for
/// real per-user auth until that exists.
enum DeviceIdentity {
    static var userId: String {
        let key = "laya.deviceUserId"
        if let existing = UserDefaults.standard.string(forKey: key) { return existing }
        let fresh = UUID().uuidString
        UserDefaults.standard.set(fresh, forKey: key)
        return fresh
    }
}
