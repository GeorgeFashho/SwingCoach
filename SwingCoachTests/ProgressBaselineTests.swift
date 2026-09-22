//
//  ProgressBaselineTests.swift
//  SwingCoachTests
//

import Foundation
import Testing
@testable import SwingCoach

/// ProgressBaseline persists the "Reset Progress" cutoff as a UserDefaults
/// double (timeIntervalSinceReferenceDate); nil means no reset yet (count
/// everything). Backed by UserDefaults.standard (mirrors Handedness.stored),
/// so each test sets/clears the key itself to avoid cross-test pollution.
/// .serialized: these tests share that one process-global key and race if
/// run concurrently with each other. Nested under PersistenceStateSuite so
/// serialization also spans the other suites sharing that key (see
/// PersistenceStateSuite.swift) — @MainActor keeps it from running off the
/// main actor, where it could interleave with the other @MainActor suites.
extension PersistenceStateSuite {
    @Suite(.serialized)
    @MainActor
    struct ProgressBaselineTests {

        @Test func defaultsToNilWhenUnset() {
            ProgressBaseline.date = nil
            #expect(ProgressBaseline.date == nil)
        }

        @Test func roundTripsDate() {
            // A 2026-era instant, not the reference date, so the raw == 0
            // sentinel is never exercised.
            let date = Date(timeIntervalSinceReferenceDate: 789_000_000)
            ProgressBaseline.date = date
            defer { ProgressBaseline.date = nil }

            #expect(ProgressBaseline.date == date)
        }

        @Test func settingNilClearsIt() {
            ProgressBaseline.date = Date(timeIntervalSinceReferenceDate: 789_000_000)
            ProgressBaseline.date = nil
            #expect(ProgressBaseline.date == nil)
        }
    }
}
