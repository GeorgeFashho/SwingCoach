//
//  ClubLabelTests.swift
//  SwingCoachTests
//

import Testing
@testable import SwingCoach

/// clubLabel is the three-way display helper used by History rows and
/// Playback: a never-set club and an unrecognized raw string must read
/// visibly differently ("Unspecified" vs "Other"), never collapsed together
/// (plan Risk "Taxonomy evolution").
@MainActor
struct ClubLabelTests {

    private func makeSession() -> SwingSession {
        SwingSession(cameraAngle: .faceOn, videoFileName: "swing.mov", duration: 1.0)
    }

    @Test func nilClubReadsAsUnspecified() {
        let session = makeSession()
        #expect(session.clubLabel == "Unspecified")
    }

    @Test func recognizedRawReadsAsDisplayName() {
        let session = makeSession()
        session.golfClub = .pitchingWedge
        #expect(session.clubLabel == GolfClub.pitchingWedge.displayName)
    }

    @Test func unrecognizedRawReadsAsOther() {
        let session = makeSession()
        session.club = "some-old-unrecognized-value"
        #expect(session.clubLabel == "Other")
    }
}
