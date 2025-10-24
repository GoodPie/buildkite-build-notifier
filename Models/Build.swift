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
        state == .scheduled || state == .running || state == .blocked
    }

    var isCompleted: Bool {
        state == .passed || state == .failed || state == .canceled
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
}
