//
//  Enums.swift
//  SwingCoach
//

import Foundation

/// The camera angle a swing was recorded from. Each angle enables a
/// different set of biomechanical checks (see plan section 3).
enum CameraAngle: String, Codable, CaseIterable, Identifiable {
    case faceOn
    case downTheLine

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .faceOn: "Face-On"
        case .downTheLine: "Down-the-Line"
        }
    }

    var explanation: String {
        switch self {
        case .faceOn:
            "The camera faces your chest, about 8–10 feet away at hand height. Best for seeing side-to-side movement: head stability, hip motion, and shoulder turn."
        case .downTheLine:
            "The camera sits behind you, looking toward the target, about 8–10 feet away at hand height. Best for seeing your posture and how well you keep it during the swing."
        }
    }
}

enum Handedness: String, Codable, CaseIterable {
    case right
    case left
}
