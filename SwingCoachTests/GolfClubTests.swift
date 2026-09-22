//
//  GolfClubTests.swift
//  SwingCoachTests
//

import Testing
@testable import SwingCoach

/// GolfClub's raw values are persisted verbatim in SwingSession.club. This
/// golden map pins every case to its literal raw string so a future
/// rename/split fails loudly here instead of silently orphaning stored rows
/// (plan: club-tracking ADR, Risk "Taxonomy evolution").
struct GolfClubTests {

    @Test func goldenRawValueMap() {
        #expect(GolfClub.driver.rawValue == "driver")
        #expect(GolfClub.wood3.rawValue == "wood3")
        #expect(GolfClub.wood5.rawValue == "wood5")
        #expect(GolfClub.hybrid.rawValue == "hybrid")
        #expect(GolfClub.iron4.rawValue == "iron4")
        #expect(GolfClub.iron5.rawValue == "iron5")
        #expect(GolfClub.iron6.rawValue == "iron6")
        #expect(GolfClub.iron7.rawValue == "iron7")
        #expect(GolfClub.iron8.rawValue == "iron8")
        #expect(GolfClub.iron9.rawValue == "iron9")
        #expect(GolfClub.pitchingWedge.rawValue == "pitchingWedge")
        #expect(GolfClub.gapWedge.rawValue == "gapWedge")
        #expect(GolfClub.sandWedge.rawValue == "sandWedge")
        #expect(GolfClub.lobWedge.rawValue == "lobWedge")
        #expect(GolfClub.putter.rawValue == "putter")
    }

    @Test func allFifteenCasesArePresent() {
        #expect(GolfClub.allCases.count == 15)
    }

    @Test func everyCaseHasANonEmptyDisplayName() {
        for club in GolfClub.allCases {
            #expect(!club.displayName.isEmpty)
        }
    }

    @Test func unrecognizedRawValueYieldsNil() {
        #expect(GolfClub(rawValue: "nonsense") == nil)
    }
}
