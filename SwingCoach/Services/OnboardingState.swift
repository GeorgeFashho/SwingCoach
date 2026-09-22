//
//  OnboardingState.swift
//  SwingCoach
//

import Foundation

/// Tracks whether the intro flow has been shown, so onboarding appears once
/// on first launch and can be replayed from Settings. nonisolated so the
/// test target (no MainActor default) can exercise it directly.
nonisolated enum OnboardingState {

    static let storageKey = "hasSeenOnboarding"

    static func shouldShow(in defaults: UserDefaults = .standard) -> Bool {
        !defaults.bool(forKey: storageKey)
    }

    static func markSeen(in defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: storageKey)
    }
}
