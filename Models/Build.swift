//
//  Build.swift
//  BuildkiteNotifier
//
//  Created by Brandyn Britton on 2025-10-20.
//

import Foundation

struct Build: Codable, Identifiable, Equatable {
    let id: String
    let buildNumber: Int
    let pipelineSlug: String
    let pipelineName: String
    let organizationSlug: String
    let branch: String
    let commitMessage: String
    let commitSha: String
    let state: BuildState
    let webUrl: String
    let createdAt: Date
    let startedAt: Date?
    let finishedAt: Date?
    var addedManually: Bool
    var lastNotifiedState: BuildState?
    var steps: [BuildStep]?  // Optional build steps (jobs)

    // Computed properties
    var isActive: Bool {
        switch state {
        case .scheduled, .running, .blocked, .canceling, .waiting, .unknown:
            return true
        case .passed, .failed, .canceled, .skipped, .notRun, .waitingFailed:
            return false
        }
    }

    var isCompleted: Bool {
        switch state {
        case .passed, .failed, .canceled, .skipped, .notRun, .waitingFailed:
            return true
        case .scheduled, .running, .blocked, .canceling, .waiting, .unknown:
            return false
        }
    }

    var displayTitle: String {
        "\(pipelineName) #\(buildNumber)"
    }

    var shortCommitSha: String {
        String(commitSha.prefix(7))
    }

    var duration: TimeInterval? {
        guard let started = startedAt, let finished = finishedAt else {
            return nil
        }
        return finished.timeIntervalSince(started)
    }

    var runningDuration: TimeInterval? {
        guard let started = startedAt else { return nil }
        if let finished = finishedAt {
            return finished.timeIntervalSince(started)
        }
        // Still running - calculate from now
        return Date().timeIntervalSince(started)
    }

    var formattedDuration: String? {
        guard let duration = runningDuration else { return nil }
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }

    // Helper to format a given duration (for live updates)
    static func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }

    // MARK: - Grouped Steps

    /// Steps grouped by emoji prefix, maintaining order based on first step appearance
    var groupedSteps: [BuildStepGroup] {
        guard let steps = steps, !steps.isEmpty else { return [] }

        // Sort steps by order first
        let sortedSteps = steps.sorted { $0.order < $1.order }

        // Group by emoji prefix while preserving order of first appearance
        var groupDict: [String: [BuildStep]] = [:]
        var groupOrder: [String] = []

        for step in sortedSteps {
            let key = step.groupKey
            if groupDict[key] == nil {
                groupDict[key] = []
                groupOrder.append(key)
            }
            groupDict[key]?.append(step)
        }

        // Build groups in order of first appearance
        return groupOrder.compactMap { key -> BuildStepGroup? in
            guard let groupSteps = groupDict[key] else { return nil }
            return BuildStepGroup(
                id: key,
                emojiPrefix: key == "Other" ? nil : key,
                steps: groupSteps
            )
        }
    }
}
