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
            return "circle.fill"
        case .running:
            return "circle.fill"
        case .passed:
            return "checkmark.circle.fill"
        case .failed:
            return "xmark.circle.fill"
        case .blocked:
            return "pause.circle.fill"
        case .canceled:
            return "circle.fill"
        }
    }
}
