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
    // Chapter to open the session on — updated either by HomeReturnView (first
    // visit) or by the session's dismiss callback (subsequent visits, which knows
    // exactly where the user left off even when the mock service isn't shared).
    @State private var pendingChapter: Chapter = .mockBackground
    @State private var isResume = false
    // Bumped each time we present a new session, giving JourneySessionView a
    // fresh identity. This prevents SwiftUI reversing an in-progress removal
    // animation when the user taps Continue before the spring finishes settling.
    @State private var sessionKey = UUID()

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
                    onContinue: { chapter in
                        // Use the chapter the session reported on dismiss (set by
                        // the onFinished callback below) so we resume exactly where
                        // the user left off. Fall back to HomeReturnView's computed
                        // chapter only on the very first visit (no prior dismiss).
                        if !isResume {
                            // First-ever continue: HomeReturnView's chapter is correct.
                            pendingChapter = chapter
                            isResume = true
                        }
                        // Otherwise pendingChapter / isResume were already set by the
                        // session's dismiss callback and reflect the true resume point.
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
                    onFinished: { chapter, resume in
                        // Store where the user left off so the next Continue tap
                        // starts on the right chapter without needing a shared service.
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
