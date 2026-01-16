//
//  BuildStepGroup.swift
//  BuildkiteNotifier
//
//  Created by Brandyn Britton on 2025-10-21.
//

import Foundation

struct BuildStepGroup: Identifiable {
    let id: String  // The emoji prefix or "Other"
    let emojiPrefix: String?  // nil for "Other" group
    let steps: [BuildStep]

    // MARK: - Display Properties

    var displayTitle: String {
        if let prefix = emojiPrefix {
            let formatted = prefix.replacingOccurrences(of: "_", with: " ").capitalized
            if formatted.count > 20 {
                return String(formatted.prefix(17)) + "..."
            }
            return formatted
        }
        return "Other Steps"
    }

    var stepCount: Int {
        steps.count
    }

    // MARK: - Aggregated Status

    var hasRunningStep: Bool {
        steps.contains { $0.isRunning }
    }

    var hasFailedStep: Bool {
        steps.contains { $0.isFailed }
    }

    var allPassed: Bool {
        steps.allSatisfy { $0.isPassed }
    }

    var allPending: Bool {
        steps.allSatisfy { $0.isPending }
    }

    var aggregateIcon: String {
        if hasRunningStep {
            return "arrow.triangle.2.circlepath.circle.fill"
        } else if hasFailedStep {
            return "xmark.circle.fill"
        } else if allPassed {
            return "checkmark.circle.fill"
        } else {
            return "circle"
        }
    }

    var aggregateColor: String {
        if hasRunningStep {
            return "yellow"
        } else if hasFailedStep {
            return "red"
        } else if allPassed {
            return "green"
        } else {
            return "gray"
        }
    }

    // MARK: - Summary Counts

    var passedCount: Int {
        steps.filter { $0.isPassed }.count
    }

    var failedCount: Int {
        steps.filter { $0.isFailed }.count
    }

    var runningCount: Int {
        steps.filter { $0.isRunning }.count
    }

    var pendingCount: Int {
        steps.filter { $0.isPending }.count
    }

    var summaryText: String {
        var parts: [String] = []
        if runningCount > 0 { parts.append("\(runningCount) running") }
        if failedCount > 0 { parts.append("\(failedCount) failed") }
        if passedCount > 0 { parts.append("\(passedCount) passed") }
        if pendingCount > 0 { parts.append("\(pendingCount) pending") }
        return parts.isEmpty ? "No steps" : parts.joined(separator: ", ")
    }
}
