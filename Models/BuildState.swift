//
//  BuildState.swift
//  BuildkiteNotifier
//
//  Created by Brandyn Britton on 2025-10-20.
//

import Foundation

enum BuildState: String, Codable {
    case scheduled
    case running
    case passed
    case failed
    case blocked
    case canceled

    var color: String {
        switch self {
        case .scheduled:
            return "gray"
        case .running:
            return "yellow"
        case .passed:
            return "green"
        case .failed:
            return "red"
        case .blocked:
            return "orange"
        case .canceled:
            return "gray"
        }
    }

    var iconName: String {
        switch self {
        case .scheduled:
            return "clock.circle"
        case .running:
            return "arrow.circlepath"
        case .passed:
            return "checkmark.circle.fill"
        case .failed:
            return "xmark.circle.fill"
        case .blocked:
            return "pause.circle.fill"
        case .canceled:
            return "minus.circle.fill"
        }
    }

    var sortOrder: Int {
        switch self {
        case .running: return 0
        case .scheduled: return 1
        case .blocked: return 2
        case .passed: return 3
        case .failed: return 4
        case .canceled: return 5
        }
    }
}
