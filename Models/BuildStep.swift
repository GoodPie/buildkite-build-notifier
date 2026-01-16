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

    // MARK: - Emoji Prefix Parsing

    /// The emoji prefix code extracted from the step name (e.g., "docker" from ":docker: Build")
    var emojiPrefix: String? {
        let pattern = #"^:([a-zA-Z0-9_+-]+):\s*"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: name, range: NSRange(name.startIndex..., in: name)),
              let prefixRange = Range(match.range(at: 1), in: name) else {
            return nil
        }
        return String(name[prefixRange])
    }

    /// The step name with emoji prefix stripped (e.g., "Build image" from ":docker: Build image")
    var displayName: String {
        let pattern = #"^:([a-zA-Z0-9_+-]+):\s*"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: name, range: NSRange(name.startIndex..., in: name)),
              let fullMatchRange = Range(match.range, in: name) else {
            return name
        }
        let stripped = String(name[fullMatchRange.upperBound...])
        return stripped.isEmpty ? "(Unnamed step)" : stripped
    }

    /// Group key for sorting - returns emoji prefix or "Other" for ungrouped steps
    var groupKey: String {
        emojiPrefix ?? "Other"
    }
}
