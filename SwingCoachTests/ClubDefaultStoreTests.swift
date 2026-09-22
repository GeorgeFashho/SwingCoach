//
//  ClubDefaultStoreTests.swift
//  SwingCoachTests
//

import Foundation
import Testing
@testable import SwingCoach

/// GolfClub.storedDefault is backed by UserDefaults.standard (mirrors
/// Handedness.stored / ProgressBaseline.date), so each test clears the key
/// itself to avoid cross-test pollution. .serialized: these tests share
/// that one process-global key and would race if run concurrently with
/// each other. Nested under PersistenceStateSuite (whose .serialized applies
/// recursively) because CaptureClubTests shares this same "lastUsedClub" key
/// — per-suite .serialized only serializes WITHIN a suite, not across it and
/// a sibling suite, so both must nest under the same serialized parent (see
/// PersistenceStateSuite.swift).
extension PersistenceStateSuite {
@Suite(.serialized)
struct ClubDefaultStoreTests {

    private func clearStoredDefault() {
        UserDefaults.standard.removeObject(forKey: GolfClub.storageKey)
    }

    @Test func defaultsToIron7WhenUnset() {
        clearStoredDefault()
        defer { clearStoredDefault() }

        #expect(GolfClub.storedDefault == .iron7)
    }

    @Test func setStoredDefaultRoundTrips() {
        clearStoredDefault()
        defer { clearStoredDefault() }

        GolfClub.setStoredDefault(.driver)
        #expect(GolfClub.storedDefault == .driver)
    }
}
}
