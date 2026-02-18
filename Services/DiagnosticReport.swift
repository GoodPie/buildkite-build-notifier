//
//  DiagnosticReport.swift
//  BuildkiteNotifier
//

import Foundation

@MainActor
struct DiagnosticReport {

    static func generate(buildMonitor: BuildMonitor, diagnosticLog: DiagnosticLog) -> String {
        var lines: [String] = []

        let divider = String(repeating: "-", count: 40)

        // Header
        lines.append("BuildkiteNotifier Diagnostic Report")
        lines.append(divider)

        // App info
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
        lines.append("App Version: \(appVersion) (\(buildNumber))")

        // macOS info
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        lines.append("macOS: \(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)")

        // Architecture
        #if arch(arm64)
        lines.append("Architecture: arm64")
        #elseif arch(x86_64)
        lines.append("Architecture: x86_64")
        #else
        lines.append("Architecture: unknown")
        #endif

        // Process uptime
        let uptime = ProcessInfo.processInfo.systemUptime
        let uptimeMinutes = Int(uptime) / 60
        let uptimeHours = uptimeMinutes / 60
        let remainingMinutes = uptimeMinutes % 60
        lines.append("Process Uptime: \(uptimeHours)h \(remainingMinutes)m")

        lines.append("")
        lines.append("Configuration")
        lines.append(divider)

        // Config state (no sensitive values)
        let hasToken = KeychainHelper.shared.load(key: "buildkite-api-token") != nil
        let hasOrg = UserDefaults.standard.string(forKey: "organizationSlug") != nil
        lines.append("API Token Configured: \(hasToken ? "yes" : "no")")
        lines.append("Organization Configured: \(hasOrg ? "yes" : "no")")

        let interval = UserDefaults.standard.integer(forKey: "pollingInterval")
        let pollingInterval = interval > 0 ? interval : 30
        lines.append("Polling Interval: \(pollingInterval)s")
        lines.append("Polling Active: \(buildMonitor.isPolling ? "yes" : "no")")

        lines.append("")
        lines.append("Build State")
        lines.append(divider)

        let totalBuilds = buildMonitor.trackedBuilds.count
        let activeBuilds = buildMonitor.trackedBuilds.filter { $0.isActive }.count
        let completedBuilds = buildMonitor.trackedBuilds.filter { $0.isCompleted }.count
        lines.append("Total Tracked: \(totalBuilds)")
        lines.append("Active: \(activeBuilds)")
        lines.append("Completed: \(completedBuilds)")

        if let lastUpdate = buildMonitor.lastUpdateTime {
            let formatter = ISO8601DateFormatter()
            lines.append("Last Update: \(formatter.string(from: lastUpdate))")
        } else {
            lines.append("Last Update: never")
        }

        if let errorState = buildMonitor.errorState {
            lines.append("Current Error: \(errorState)")
        }

        lines.append("")
        lines.append("Recent Log (last 20)")
        lines.append(divider)

        let recentEntries = Array(diagnosticLog.entries.suffix(20))
        if recentEntries.isEmpty {
            lines.append("(none)")
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "HH:mm:ss"

            for entry in recentEntries {
                let time = dateFormatter.string(from: entry.timestamp)
                let levelLabel = entry.level.rawValue.uppercased()
                var line = "[\(time)] [\(levelLabel)] [\(entry.code.rawValue)] \(entry.message)"
                if let detail = entry.detail {
                    line += " | \(detail)"
                }
                lines.append(line)
            }
        }

        lines.append("")
        lines.append(divider)
        let formatter = ISO8601DateFormatter()
        lines.append("Generated: \(formatter.string(from: Date()))")

        return lines.joined(separator: "\n")
    }
}
