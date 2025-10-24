//
//  BuildMonitor.swift
//  BuildkiteNotifier
//
//  Created by Brandyn Britton on 2025-10-20.
//

import Foundation
import Combine

@MainActor
class BuildMonitor: ObservableObject {
    @Published var focusedBuild: Build?
    @Published var activeBuilds: [Build] = []
    @Published var completedBuilds: [Build] = []
    @Published var previouslyFocusedBuilds: [Build] = []  // New: builds that were focused and completed
    @Published var errorState: String?
    @Published var isPolling: Bool = false
    @Published var lastUpdateTime: Date?
    @Published var hasCompletedFirstFetch: Bool = false  // Track if we've fetched at least once

    private let api = BuildkiteAPI()
    private let notificationService = NotificationService()
    private var pollingTimer: Timer?
    private var userId: String?
    private var orgSlug: String?
    private var focusHistory: Set<String> = []  // Track which build IDs have been focused
    private var manuallyAddedBuildRefs: [(org: String, pipeline: String, number: Int)] = []  // Track manually added builds for polling

    var badgeCount: Int {
        activeBuilds.count
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
                print("Failed to fetch manually added build \(ref.org)/\(ref.pipeline)/#\(ref.number): \(error)")
            }
        }

        return manualBuilds
    }

    /// Update build state from API response
    /// State flow:
    /// 1. Detect state changes and trigger notifications
    /// 2. Update activeBuilds and completedBuilds arrays
    /// 3. Auto-focus first active build if no focus exists
    /// 4. Update focused build data if it's in the new builds
    /// 5. Restore focused build from UserDefaults if needed
    private func updateBuilds(newBuilds: [Build]) {
        // Separate active and completed
        let active = newBuilds.filter { $0.isActive }
        let completed = newBuilds.filter { $0.isCompleted }

        // Detect state changes for notifications
        for newBuild in newBuilds {
            if let oldBuild = (activeBuilds + completedBuilds).first(where: { $0.id == newBuild.id }),
               oldBuild.state != newBuild.state {
                notificationService.sendNotification(
                    for: newBuild,
                    oldState: oldBuild.state,
                    isFocused: newBuild.id == focusedBuild?.id
                )

                // If focused build just completed, move to previously focused
                if newBuild.id == focusedBuild?.id && newBuild.isCompleted {
                    if !previouslyFocusedBuilds.contains(where: { $0.id == newBuild.id }) {
                        previouslyFocusedBuilds.insert(newBuild, at: 0)
                    }
                }
            }
        }

        // Update active builds
        activeBuilds = active

        // Only show completed builds that were never focused in "Recently Completed"
        // Limit to 50 most recent to prevent memory bloat
        var filteredCompleted = completed.filter { !focusHistory.contains($0.id) }
        if filteredCompleted.count > 50 {
            filteredCompleted = Array(filteredCompleted.prefix(50))
        }
        completedBuilds = filteredCompleted

        // Update previously focused builds with latest data
        for (index, prevBuild) in previouslyFocusedBuilds.enumerated() {
            if let updated = completed.first(where: { $0.id == prevBuild.id }) {
                previouslyFocusedBuilds[index] = updated
            }
        }

        // Auto-focus if no focused build
        if focusedBuild == nil, let firstActive = active.first {
            focusedBuild = firstActive
            focusHistory.insert(firstActive.id)
            UserDefaults.standard.set(firstActive.id, forKey: "focusedBuildId")
        }

        // Update focused build if it's in new builds
        if let focused = focusedBuild,
           let updated = newBuilds.first(where: { $0.id == focused.id }) {
            focusedBuild = updated
        }

        // Restore focused build from UserDefaults if needed
        if focusedBuild == nil,
           let savedId = UserDefaults.standard.string(forKey: "focusedBuildId"),
           let saved = newBuilds.first(where: { $0.id == savedId }) {
            focusedBuild = saved
            focusHistory.insert(saved.id)
        }

        // Mark that we've completed at least one fetch
        hasCompletedFirstFetch = true
    }

    private func handleError(_ error: Error) {
        print("DEBUG: handleError called with: \(error)")
        if let apiError = error as? APIError {
            switch apiError {
            case .unauthorized:
                errorState = "API token is invalid or expired. Click Settings to update."
                stopMonitoring()
            case .organizationNotFound:
                errorState = "Organization not found. Check Settings."
                stopMonitoring()
            case .networkError(let underlyingError):
                errorState = "Network error: \(underlyingError.localizedDescription). Retrying..."
                print("DEBUG: Network error details: \(underlyingError)")
            case .rateLimited:
                errorState = "Buildkite API rate limit reached. Increase polling interval."
            case .buildNotFound:
                errorState = "Build not found. It may have been deleted."
            case .invalidResponse:
                errorState = "Invalid API response. Check your network connection."
            case .decodingError(let underlyingError):
                errorState = "Failed to parse API response: \(underlyingError.localizedDescription)"
                print("DEBUG: Decoding error details: \(underlyingError)")
            }
        } else {
            errorState = "Unknown error: \(error.localizedDescription)"
        }
    }

    func switchFocus(to build: Build) {
        // Remove from previouslyFocusedBuilds if it's there (re-focusing)
        previouslyFocusedBuilds.removeAll { $0.id == build.id }

        focusedBuild = build
        focusHistory.insert(build.id)  // Track that this build was focused
        UserDefaults.standard.set(build.id, forKey: "focusedBuildId")
    }

    func clearFocus() {
        // If there's a focused build, always move it to previously focused
        if let focused = focusedBuild {
            if !previouslyFocusedBuilds.contains(where: { $0.id == focused.id }) {
                previouslyFocusedBuilds.insert(focused, at: 0)
            }
        }

        focusedBuild = nil
        UserDefaults.standard.removeObject(forKey: "focusedBuildId")
    }

    func removePreviouslyFocused(_ build: Build) {
        previouslyFocusedBuilds.removeAll { $0.id == build.id }
        focusHistory.remove(build.id)
    }

    func clearCompleted() {
        completedBuilds.removeAll()
        previouslyFocusedBuilds.removeAll()
        focusHistory.removeAll()
    }

    func addBuild(url: String) async {
        guard let (org, pipeline, number) = URLParser.parse(url) else {
            await MainActor.run {
                errorState = "Invalid Buildkite URL format. Expected: https://buildkite.com/org/pipeline/builds/123"
            }
            return
        }

        do {
            print("DEBUG: Fetching build from \(org)/\(pipeline)/#\(number)")
            var build = try await api.fetchBuild(org: org, pipeline: pipeline, number: number)
            print("DEBUG: Successfully fetched build: \(build.id)")
            build.addedManually = true

            await MainActor.run {
                // Store reference for future polling
                if !manuallyAddedBuildRefs.contains(where: { $0.org == org && $0.pipeline == pipeline && $0.number == number }) {
                    manuallyAddedBuildRefs.append((org, pipeline, number))
                }

                // Check if build already exists
                let alreadyExists = activeBuilds.contains(where: { $0.id == build.id }) ||
                                   completedBuilds.contains(where: { $0.id == build.id }) ||
                                   previouslyFocusedBuilds.contains(where: { $0.id == build.id })

                if !alreadyExists {
                    if build.isActive {
                        // Insert at the beginning of active builds
                        activeBuilds.insert(build, at: 0)

                        // Auto-focus if no current focus
                        if focusedBuild == nil {
                            focusedBuild = build
                            focusHistory.insert(build.id)
                            UserDefaults.standard.set(build.id, forKey: "focusedBuildId")
                        }
                    } else if build.isCompleted {
                        // Manually added completed builds go to "Previously Focused" (user explicitly wants to see them)
                        previouslyFocusedBuilds.insert(build, at: 0)
                        focusHistory.insert(build.id)  // Mark as focused so it stays visible
                    }
                }
                hasCompletedFirstFetch = true  // We've successfully fetched a build
                errorState = nil
            }
        } catch {
            print("DEBUG: Error fetching build: \(error)")
            await MainActor.run {
                handleError(error)
            }
        }
    }
}
