//
//  BuildStep.swift
//  BuildkiteNotifier
//
//  Created by Brandyn Britton on 2025-10-21.
//

import Foundation

struct BuildStep: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let state: String  // pending, running, passed, failed, canceled
    let exitStatus: Int?
    let order: Int

    // Computed properties
    var isPending: Bool {
        state == "pending" || state == "scheduled" || state == "waiting"
    }

    var isRunning: Bool {
        state == "running" || state == "assigned"
    }

    var isPassed: Bool {
        state == "passed"
    }

    var isFailed: Bool {
        state == "failed"
    }

    var iconName: String {
        if isPassed {
            return "checkmark.circle.fill"
        } else if isFailed {
            return "xmark.circle.fill"
        } else if isRunning {
            return "arrow.triangle.2.circlepath.circle.fill"
        } else {
            return "circle"
        }
    }

    var iconColor: String {
        if isPassed {
            return "green"
        } else if isFailed {
            return "red"
        } else if isRunning {
            return "yellow"
        } else {
            return "gray"
        }
    }
}
