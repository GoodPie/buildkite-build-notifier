//
//  BuildState.swift
//  BuildkiteNotifier
//
//  Created by Brandyn Britton on 2025-10-20.
//

import Foundation

enum BuildState: Equatable, Hashable {
    case scheduled
    case running
    case passed
    case failed
    case blocked
    case canceled
    case canceling
    case skipped
    case notRun
    case waiting
    case waitingFailed
    case unknown(String)

    // MARK: - Display

    var displayName: String {
        switch self {
        case .scheduled: return "Scheduled"
        case .running: return "Running"
        case .passed: return "Passed"
        case .failed: return "Failed"
        case .blocked: return "Blocked"
        case .canceled: return "Canceled"
        case .canceling: return "Canceling"
        case .skipped: return "Skipped"
        case .notRun: return "Not Run"
        case .waiting: return "Waiting"
        case .waitingFailed: return "Waiting Failed"
        case .unknown(let raw):
            return raw.split(separator: "_")
                .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
                .joined(separator: " ")
        }
    }

    var color: String {
        switch self {
        case .scheduled: return "gray"
        case .running: return "yellow"
        case .passed: return "green"
        case .failed: return "red"
        case .blocked: return "orange"
        case .canceled: return "gray"
        case .canceling: return "gray"
        case .skipped: return "gray"
        case .notRun: return "gray"
        case .waiting: return "gray"
        case .waitingFailed: return "red"
        case .unknown: return "gray"
        }
    }

    var iconName: String {
        switch self {
        case .scheduled: return "clock.circle"
        case .running: return "arrow.circlepath"
        case .passed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .blocked: return "pause.circle.fill"
        case .canceled: return "minus.circle.fill"
        case .canceling: return "minus.circle"
        case .skipped: return "arrow.right.circle"
        case .notRun: return "circle.slash"
        case .waiting: return "clock.circle"
        case .waitingFailed: return "xmark.circle.fill"
        case .unknown: return "questionmark.circle"
        }
    }

    var sortOrder: Int {
        switch self {
        case .running: return 0
        case .scheduled: return 1
        case .blocked: return 2
        case .waiting: return 3
        case .passed: return 4
        case .canceling: return 5
        case .failed: return 6
        case .canceled: return 7
        case .waitingFailed: return 8
        case .skipped: return 9
        case .notRun: return 10
        case .unknown: return 11
        }
    }
}

// MARK: - RawRepresentable

extension BuildState: RawRepresentable {
    init(rawValue: String) {
        switch rawValue {
        case "scheduled": self = .scheduled
        case "running": self = .running
        case "passed": self = .passed
        case "failed": self = .failed
        case "blocked": self = .blocked
        case "canceled": self = .canceled
        case "canceling": self = .canceling
        case "skipped": self = .skipped
        case "not_run": self = .notRun
        case "waiting": self = .waiting
        case "waiting_failed": self = .waitingFailed
        default: self = .unknown(rawValue)
        }
    }

    var rawValue: String {
        switch self {
        case .scheduled: return "scheduled"
        case .running: return "running"
        case .passed: return "passed"
        case .failed: return "failed"
        case .blocked: return "blocked"
        case .canceled: return "canceled"
        case .canceling: return "canceling"
        case .skipped: return "skipped"
        case .notRun: return "not_run"
        case .waiting: return "waiting"
        case .waitingFailed: return "waiting_failed"
        case .unknown(let raw): return raw
        }
    }
}

// MARK: - Codable

extension BuildState: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self.init(rawValue: raw)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
