//
//  NotificationService.swift
//  BuildkiteNotifier
//
//  Created by Brandyn Britton on 2025-10-20.
//

import Foundation
import UserNotifications

/// Notification service for macOS system notifications
/// Handles notification permissions and build state change notifications
/// Notification logic:
/// - Focused builds: Notify on ALL state changes (scheduled, running, passed, failed, blocked)
/// - Non-focused builds: Notify ONLY on completion (passed, failed, canceled)
class NotificationService {
    private let center = UNUserNotificationCenter.current()

    init() {
        requestAuthorization()
    }

    /// Request notification permissions from the user on initialization
    private func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Notification authorization error: \(error)")
            }
        }
    }

    func sendNotification(for build: Build, oldState: BuildState, isFocused: Bool) {
        // Focused builds: notify on all state changes
        // Non-focused: notify only on completion
        if !isFocused && !build.isCompleted {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = build.pipelineName
        content.subtitle = build.branch
        content.body = notificationMessage(for: build, oldState: oldState)
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Immediate delivery
        )

        center.add(request) { error in
            if let error = error {
                print("Notification error: \(error)")
            }
        }
    }

    private func notificationMessage(for build: Build, oldState: BuildState) -> String {
        switch build.state {
        case .scheduled:
            return "Build #\(build.buildNumber) scheduled"
        case .running:
            return "Build #\(build.buildNumber) started"
        case .passed:
            return "Build #\(build.buildNumber) passed ✅"
        case .failed:
            return "Build #\(build.buildNumber) failed ❌"
        case .blocked:
            return "Build #\(build.buildNumber) blocked (waiting for approval)"
        case .canceled:
            return "Build #\(build.buildNumber) canceled"
        }
    }
}
