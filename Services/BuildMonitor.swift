//
//  BuildMonitor.swift
//  BuildkiteNotifier
//
//  Created by Brandyn Britton on 2025-10-20.
//

import Foundation
import Combine
import os

@MainActor
class BuildMonitor: ObservableObject {
    @Published var trackedBuilds: [Build] = []
    @Published var errorState: String?
    @Published var isPolling: Bool = false
    @Published var lastUpdateTime: Date?
    @Published var hasCompletedFirstFetch: Bool = false  // Track if we've fetched at least once

    let diagnosticLog = DiagnosticLog()

    private let api = BuildkiteAPI()
    private lazy var notificationService = NotificationService(diagnosticLog: diagnosticLog)
    private var pollingTimer: Timer?
    private var userId: String?
    private var orgSlug: String?
    private var manuallyAddedBuildRefs: [(org: String, pipeline: String, number: Int)] = []  // Track manually added builds for polling
    private var dismissedBuildIDs: Set<String> = []  // Builds explicitly removed by user, skip on re-fetch

    var badgeCount: Int {
        trackedBuilds.filter { $0.isActive }.count
    }

    /// Configure the API connection with authentication token and organization
    /// - Parameters:
    ///   - apiToken: Buildkite API token (stored in Keychain)
    ///   - orgSlug: Organization slug identifier
    func configure(apiToken: String, orgSlug: String) {
        self.api.setToken(apiToken)
        self.orgSlug = orgSlug
    }

    /// Start monitoring builds by fetching user ID and initiating polling
    /// Sets isPolling = true and starts the polling timer
    func startMonitoring() async {
        guard !isPolling else { return }

        // Fetch user ID first
        do {
            let user = try await api.fetchUser()
            self.userId = user.id
            isPolling = true
            diagnosticLog.log(code: .monitoringStarted, message: "Monitoring started", level: .info)
            await fetchBuilds()
            startPollingTimer()
        } catch {
            handleError(error)
        }
    }

    func stopMonitoring() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        isPolling = false
        diagnosticLog.log(code: .monitoringStopped, message: "Monitoring stopped", level: .info)
    }

    private func startPollingTimer() {
        let interval = UserDefaults.standard.integer(forKey: "pollingInterval")
        let pollingInterval = interval > 0 ? TimeInterval(interval) : 30.0

        pollingTimer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
            Task {
                await self?.fetchBuilds()
            }
        }
    }

    private func fetchBuilds() async {
        guard let userId = userId, let orgSlug = orgSlug else { return }

        do {
            // Fetch user's builds
            let userBuilds = try await api.fetchUserBuilds(orgSlug: orgSlug, userId: userId)

            // Fetch manually added builds
            let manualBuilds = await fetchManuallyAddedBuilds()

            // Merge both lists (remove duplicates by ID)
            var allBuilds = userBuilds
            for manualBuild in manualBuilds {
                if !allBuilds.contains(where: { $0.id == manualBuild.id }) {
                    allBuilds.append(manualBuild)
                }
            }

            updateBuilds(newBuilds: allBuilds)
            errorState = nil
            lastUpdateTime = Date()
        } catch {
            handleError(error)
        }
    }

    private func fetchManuallyAddedBuilds() async -> [Build] {
        var manualBuilds: [Build] = []

        for ref in manuallyAddedBuildRefs {
            do {
                var build = try await api.fetchBuild(
                    org: ref.org,
                    pipeline: ref.pipeline,
                    number: ref.number
                )
                build.addedManually = true
                manualBuilds.append(build)
            } catch {
                // Build might have been deleted or is inaccessible
                // Continue with other builds
                Logger.monitor.warning("Failed to fetch manually added build: \(error.localizedDescription)")
            }
        }

        return manualBuilds
    }

    // MARK: - Sort Helper

    private func sortBuilds(_ builds: [Build]) -> [Build] {
        builds.sorted { a, b in
            let orderA = a.state.sortOrder
            let orderB = b.state.sortOrder
            if orderA != orderB { return orderA < orderB }
            let dateA = a.startedAt ?? a.createdAt
            let dateB = b.startedAt ?? b.createdAt
            return dateA > dateB
        }
    }

    // MARK: - Build State Updates

    /// Update build state from API response
    /// - Merges new builds into tracked builds (update existing, add new)
    /// - Detects state changes and notifies on completion
    /// - Re-sorts the list and caps completed builds at 20
    private func updateBuilds(newBuilds: [Build]) {
        var updatedBuilds = trackedBuilds

        for var newBuild in newBuilds {
            if dismissedBuildIDs.contains(newBuild.id) { continue }
            if let existingIndex = updatedBuilds.firstIndex(where: { $0.id == newBuild.id }) {
                let existing = updatedBuilds[existingIndex]
                if existing.addedManually { newBuild.addedManually = true }
                if existing.state != newBuild.state {
                    notificationService.sendNotification(for: newBuild, oldState: existing.state)
                }
                updatedBuilds[existingIndex] = newBuild
            } else {
                updatedBuilds.append(newBuild)
            }
        }

        let active = updatedBuilds.filter { $0.isActive }
        let completed = updatedBuilds.filter { $0.isCompleted }
        let cappedCompleted = Array(completed.prefix(20))

        trackedBuilds = sortBuilds(active + cappedCompleted)
        hasCompletedFirstFetch = true
    }

    // MARK: - Build Management

    func removeBuild(id: String) {
        dismissedBuildIDs.insert(id)
        if let build = trackedBuilds.first(where: { $0.id == id }), build.addedManually {
            manuallyAddedBuildRefs.removeAll {
                $0.org == build.organizationSlug && $0.pipeline == build.pipelineSlug && $0.number == build.buildNumber
            }
        }
        trackedBuilds.removeAll { $0.id == id }
    }

    func clearCompleted() {
        let completed = trackedBuilds.filter { $0.isCompleted }
        dismissedBuildIDs.formUnion(completed.map { $0.id })
        for build in completed where build.addedManually {
            manuallyAddedBuildRefs.removeAll {
                $0.org == build.organizationSlug && $0.pipeline == build.pipelineSlug && $0.number == build.buildNumber
            }
        }
        trackedBuilds.removeAll { $0.isCompleted }
    }

    func addBuild(url: String) async {
        guard let parsed = URLParser.parse(url) else {
            errorState = "[BN-URL] Invalid Buildkite URL format"
            diagnosticLog.log(code: .invalidURL, message: "Invalid Buildkite URL format", level: .warning)
            Logger.monitor.warning("Invalid Buildkite URL format provided")
            return
        }

        let ref = (org: parsed.org, pipeline: parsed.pipeline, number: parsed.number)
        guard !manuallyAddedBuildRefs.contains(where: { $0.org == ref.org && $0.pipeline == ref.pipeline && $0.number == ref.number }) else {
            errorState = "[BN-DUP] Build is already being tracked"
            diagnosticLog.log(code: .duplicateBuild, message: "Build is already being tracked", level: .warning)
            return
        }

        do {
            var build = try await api.fetchBuild(org: parsed.org, pipeline: parsed.pipeline, number: parsed.number)
            build.addedManually = true
            dismissedBuildIDs.remove(build.id)
            manuallyAddedBuildRefs.append(ref)

            if !trackedBuilds.contains(where: { $0.id == build.id }) {
                trackedBuilds.append(build)
                trackedBuilds = sortBuilds(trackedBuilds)
            }
            hasCompletedFirstFetch = true
            errorState = nil
        } catch {
            handleError(error)
        }
    }

    // MARK: - Error Handling

    private func handleError(_ error: Error) {
        if let apiError = error as? APIError {
            let code = DiagnosticCode.from(apiError)
            let message: String
            let detail: String?
            let level: DiagnosticLevel

            switch apiError {
            case .unauthorized:
                message = "API token is invalid or expired. Click Settings to update."
                detail = nil
                level = .error
                stopMonitoring()
            case .organizationNotFound:
                message = "Organization not found. Check Settings."
                detail = nil
                level = .error
                stopMonitoring()
            case .networkError(let underlyingError):
                message = "Network error: \(underlyingError.localizedDescription). Retrying..."
                detail = String(describing: underlyingError)
                level = .warning
            case .rateLimited:
                message = "Buildkite API rate limit reached. Increase polling interval."
                detail = nil
                level = .warning
            case .buildNotFound:
                message = "Build not found. It may have been deleted."
                detail = nil
                level = .warning
            case .invalidResponse:
                message = "Invalid API response. Check your network connection."
                detail = nil
                level = .error
            case .decodingError(let underlyingError):
                message = "Failed to parse API response: \(underlyingError.localizedDescription)"
                detail = String(describing: underlyingError)
                level = .error
            }

            errorState = "[\(code.rawValue)] \(message)"
            diagnosticLog.log(code: code, message: message, detail: detail, level: level)
            Logger.api.error("[\(code.rawValue)] \(message)")
        } else {
            let message = "Unknown error: \(error.localizedDescription)"
            errorState = "[BN-UNK] \(message)"
            diagnosticLog.log(code: .unknown, message: message, detail: String(describing: error), level: .error)
            Logger.monitor.error("[BN-UNK] \(message)")
        }
    }
}
