//
//  OnboardingStateTests.swift
//  SwingCoachTests
//

import Foundation
import Testing
@testable import SwingCoach

/// Onboarding shows exactly once: on a fresh install the flag is unset and
/// the flow appears; after Get Started it never auto-shows again.
struct OnboardingStateTests {

    @Test func onboardingShowsOnFirstLaunch() throws {
        let suiteName = "OnboardingStateTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        #expect(OnboardingState.shouldShow(in: defaults))
    }

    @Test func onboardingStopsShowingOnceMarkedSeen() throws {
        let suiteName = "OnboardingStateTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        OnboardingState.markSeen(in: defaults)

        #expect(!OnboardingState.shouldShow(in: defaults))
    }
}
