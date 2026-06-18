//
//  JourneyPlayerView.swift
//  Laya
//
//  Created by Abhi Reddy on 18/06/2026.
//

import SwiftUI

struct JourneyPlayerView: View {
    // The data backing the screen, loaded from the assignment service.
    @State private var artist: Artist?
    @State private var chapter: Chapter?
    @State private var video: JourneyVideo?
    @State private var chapterCount = 0

    // Swappable for the real service later.
    private let service: AssignmentServing

    init(service: AssignmentServing) {
        self.service = service
        LayaFontRegistration.registerAll()
    }

    #if DEBUG
    // Convenience for previews — defaults to the mock assignment.
    init() {
        self.service = MockAssignmentService()
        LayaFontRegistration.registerAll()
    }
    #endif

    var body: some View {
        ZStack(alignment: .bottom) {
            background.ignoresSafeArea()
            scrim.ignoresSafeArea()
            content
        }
        .background(Color.ink.ignoresSafeArea())
        .task { await load() }
    }

    // MARK: - Background

    private var background: some View {
        // Poster never resolves (placeholder URL) — the ink colour fills behind it.
        AsyncImage(url: video?.posterURL ?? artist?.imageURL) { image in
            image
                .resizable()
                .scaledToFill()
        } placeholder: {
            Color.ink
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    // Darkens top and bottom so the overlaid text stays legible.
    private var scrim: some View {
        LinearGradient(
            colors: [
                .black.opacity(0.55),
                .clear,
                .clear,
                .black.opacity(0.75)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Foreground content

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            ProgressBar(progress: progressFraction)
                .frame(height: 2)
                .padding(.horizontal, 22)
                .padding(.bottom, 16)

            chapterEyebrow
                .padding(.horizontal, 22)

            Spacer(minLength: 0)

            bottomBar
                .padding(.horizontal, 22)
        }
        .padding(.top, 12)
        .padding(.bottom, 48)
    }

    // "Chapter II — Music" — Antic Didone, cream.
    private var chapterEyebrow: some View {
        Text(chapterLabel)
            .font(.layaBody(13))
            .foregroundStyle(.cream)
    }

    private var bottomBar: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                // Video kind label — Inter regular, copper.
                Text(performanceLabel)
                    .font(.layaBody(15, weight: .regular))
                    .tracking(2)
                    .textCase(.uppercase)
                    .foregroundStyle(.copper)

                // Video title — Antic Didone, cream.
                Text(trackTitle)
                    .layaTitle(34)
                    .foregroundStyle(.cream)
            }

            Spacer(minLength: 16)

            VStack(spacing: 16) {
                if video?.spotifyTrackId != nil {
                    SpotifyButton {}
                }
                ShareButton {}
            }
        }
    }

    // MARK: - Derived values (pulled from the mock service)

    private var chapterLabel: String {
        guard let chapter else { return "" }
        return " \(romanNumeral(chapter.index + 1)) • \(chapter.title)"
    }

    private var performanceLabel: String {
        guard let video else { return "" }
        switch video.kind {
        case .live:       return "Live Performance"
        case .musicVideo: return "Music Video"
        case .cover:      return "Cover"
        case .interview:  return "Interview"
        case .bts:        return "Behind the Scenes"
        }
    }

    private var trackTitle: String {
        video?.title ?? ""
    }

    private var progressFraction: Double {
        guard let chapter, chapterCount > 0 else { return 0 }
        return Double(chapter.index + 1) / Double(chapterCount)
    }

    private func romanNumeral(_ value: Int) -> String {
        switch value {
        case 1: return "I"
        case 2: return "II"
        case 3: return "III"
        default: return "\(value)"
        }
    }

    // MARK: - Loading

    private func load() async {
        do {
            let package = try await service.fetchCurrentAssignment(for: "user-mock")
            artist = package.artist
            chapterCount = package.journey.chapters.count
            // The screen shows the "Music" chapter's live performance clip.
            let musicChapter = package.journey.chapters.first { $0.index == 1 }
                ?? package.journey.chapters.first
            chapter = musicChapter
            // The chapter's live performance — "Heart of Darkness" in the mock.
            video = musicChapter?.videos.first { $0.kind == .live }
                ?? musicChapter?.videos.first
        } catch {
            // No-op for now — UI-only screen.
        }
    }
}

// MARK: - Progress bar

private struct ProgressBar: View {
    let progress: Double // 0...1

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.cream.opacity(0.25))
                Capsule()
                    .fill(Color.cream)
                    .frame(width: geo.size.width * max(0, min(progress, 1)))
            }
        }
    }
}

// MARK: - Buttons

private struct SpotifyButton: View {
    let action: () -> Void

    var body: some View {
        CircleButton(action: action) {
            Image("spotify")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(.cream)
                .padding(9)
        }
    }
}

private struct ShareButton: View {
    let action: () -> Void

    var body: some View {
        CircleButton(action: action) {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(.cream)
                .offset(y: -1)
        }
    }
}

// Shared circular treatment: thin cream ring, transparent fill, cream icon.
private struct CircleButton<Icon: View>: View {
    let action: () -> Void
    let icon: Icon

    init(action: @escaping () -> Void, @ViewBuilder icon: () -> Icon) {
        self.action = action
        self.icon = icon()
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .stroke(Color.cream.opacity(0.85), lineWidth: 1)
                icon
            }
            .frame(width: 42, height: 42)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    JourneyPlayerView()
}
