//
//  BuildkiteNotifierApp.swift
//  BuildkiteNotifier
//
//  Created by Brandyn Britton on 9/10/2025.
//  Updated by Brandyn Britton on 2025-10-20.
//

import SwiftUI

@main
struct BuildkiteNotifierApp: App {
    @StateObject private var buildMonitor = BuildMonitor()
    @StateObject private var statusBarController: StatusBarController

    init() {
        let monitor = BuildMonitor()
        _buildMonitor = StateObject(wrappedValue: monitor)
        _statusBarController = StateObject(wrappedValue: StatusBarController(buildMonitor: monitor))

        // Auto-start monitoring if credentials are configured
        Task { @MainActor in
            if let apiToken = KeychainHelper.shared.load(key: "buildkite-api-token"),
               let orgSlug = UserDefaults.standard.string(forKey: "organizationSlug"),
               !apiToken.isEmpty, !orgSlug.isEmpty {
                monitor.configure(apiToken: apiToken, orgSlug: orgSlug)
                await monitor.startMonitoring()
            }
        }
    }

    var body: some Scene {
        Settings {
            SettingsView(buildMonitor: buildMonitor)
        }
    }
}
