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
/// Notification logic: Notify on build completion only (passed, failed, canceled)
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

    func sendNotification(for build: Build, oldState: BuildState) {
        // Only notify on build completion
        guard build.isCompleted else { return }

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
        case .passed:
            return "\(build.branch) passed"
        case .failed:
            return "\(build.branch) failed"
        case .canceled:
            return "\(build.branch) canceled"
        case .skipped:
            return "\(build.branch) was skipped"
        case .notRun:
            return "\(build.branch) did not run"
        case .waitingFailed:
            return "\(build.branch) waiting failed"
        default:
            return "\(build.branch) - \(build.state.displayName)"
        }
    }
}
