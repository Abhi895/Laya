//
//  RootView.swift
//  Laya
//
//  Created by Abhi Reddy on 19/06/2026.
//

import SwiftUI

/// The app's home router. It chooses between onboarding, the first reveal flow,
/// and the return screen, then crossfades the chapter intro over the active home.
struct ContentView: View {
    // Two persisted flags drive the app's front door:
    //  • hasCompletedOnboarding — set once the user authenticates (Spotify/guest).
    //  • hasBegunJourney        — set once the user taps "Begin". Latched by
    //    ChapterIntroView after its entry crossfade fully covers Home, so the
    //    HomeView → HomeReturnView swap behind it is invisible.
    // First launch → onboarding; after auth → the reveal (HomeView); after begin →
    // the return screen (HomeReturnView), on this launch and every future launch.
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("hasBegunJourney") private var hasBegunJourney = false

    @State private var showSession = false
    // Chapter to open the session on — updated either by HomeReturnView (when
    // the user taps Continue) or by the session's dismiss callback (when a
    // session ends), both reading from the same underlying progress.
    @State private var pendingChapter: Chapter = .placeholder
    @State private var isResume = false
    // Bumped each time we present a new session, giving JourneySessionView a
    // fresh identity. This prevents SwiftUI reversing an in-progress removal
    // animation when the user taps Continue before the spring finishes settling.
    @State private var sessionKey = UUID()

    // The one real (non-debug) AssignmentServing implementation — available
    // in every build configuration, unlike MockAssignmentService. Wiring it
    // explicitly here (rather than relying on each view's DEBUG-only
    // default initializer) is what makes a Release build actually work.
    private let assignmentService = LocalAssignmentService()

    var body: some View {
        ZStack {
            if !hasCompletedOnboarding {
                OnboardingAuthView(
                    onSpotify: completeOnboarding,
                    onGuest: completeOnboarding
                )
                .transition(.opacity)
            } else if hasBegunJourney {
                HomeReturnView(
                    service: assignmentService,
                    isSessionActive: showSession,
                    onContinue: { chapter, resume in
                        // HomeReturnView holds the real watched-progress data, so it's
                        // the authority on both which chapter is current and whether
                        // it's already partway watched — just trust what it reports.
                        pendingChapter = chapter
                        isResume = resume
                        presentIntro()
                    }
                )
                .transition(.opacity)
            } else {
                // Begin only triggers the overlay — not the latch. ChapterIntroView
                // flips hasBegunJourney once its entry crossfade fully covers Home,
                // so the HomeView → HomeReturnView swap behind it is invisible and
                // the Begin button's press animation isn't cut short by a view swap.
                HomeView(
                    service: assignmentService,
                    onBegin: { chapter in
                        pendingChapter = chapter
                        isResume = false
                        presentIntro()
                    },
                    onReset: resetToOnboarding
                )
                .transition(.opacity)
            }

            // The journey session (chapter intro → player → completion) crossfades
            // in over the home screen. On entry, a slow opacity transition (1.1s)
            // makes it feel like entering something immersive. On exit, the session
            // slides downward and fades with a spring — the metaphor is "leaving
            // the storybook" and returning to everyday life beneath.
            if showSession {
                JourneySessionView(
                    initialChapter: pendingChapter,
                    isResume: isResume,
                    service: assignmentService,
                    onFinished: { chapter, resume in
                        // Store where the user left off so the next Continue tap
                        // starts on the right chapter.
                        pendingChapter = chapter
                        isResume = resume
                        dismissSession()
                    }
                )
                .id(sessionKey)
                .transition(.asymmetric(
                    insertion: .opacity,
                    removal: .move(edge: .bottom).combined(with: .opacity)
                ))
                .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.75), value: hasCompletedOnboarding)
        .animation(.easeInOut(duration: 0.75), value: hasBegunJourney)
    }

    // Spotify/guest both land here: the user has authenticated, so move off
    // onboarding to the first-visit reveal (HomeView).
    private func completeOnboarding() {
        showSession = false
        hasCompletedOnboarding = true
    }

    private func resetToOnboarding() {
        showSession = false
        hasBegunJourney = false
        hasCompletedOnboarding = false
    }

    private func presentIntro() {
        // New identity every time so SwiftUI always starts a fresh insertion
        // transition, even if the previous session's removal spring is still in
        // progress (which would otherwise reverse, "sliding" the old view back up).
        sessionKey = UUID()
        // Slow crossfade in — the user is *entering* the journey.
        withAnimation(.easeInOut(duration: 1.1)) {
            showSession = true
        }
    }

    private func dismissSession() {
        // Slide the session down and fade it out, revealing the cream home beneath.
        // The downward motion is the key metaphor: "leaving the storybook" to
        // return to everyday life. Spring-based so it feels physical and decisive.
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
            showSession = false
        }
    }
}

#if DEBUG
#Preview {
    ContentView()
}
#endif
