//
//  StatusBarController.swift
//  BuildkiteNotifier
//
//  Created by Brandyn Britton on 2025-10-20.
//

import AppKit
import SwiftUI
import Combine

@MainActor
class StatusBarController: NSObject, ObservableObject {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var buildMonitor: BuildMonitor
    private var cancellables = Set<AnyCancellable>()

    init(buildMonitor: BuildMonitor) {
        self.buildMonitor = buildMonitor
        super.init()
        setupStatusItem()
        setupPopover()
        observeBuildMonitor()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: "Build Status")
            button.action = #selector(togglePopover)
            button.target = self
        }
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 360, height: 500)
        popover.behavior = .transient
        popover.delegate = self
        popover.contentViewController = NSHostingController(rootView: MenuView(buildMonitor: buildMonitor))
    }

    private func observeBuildMonitor() {
        buildMonitor.$trackedBuilds
            .debounce(for: .milliseconds(50), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.popover.isShown {
                    self.refreshPopover()
                } else {
                    self.updateStatusBar()
                }
            }
            .store(in: &cancellables)
    }

    private func refreshPopover() {
        guard popover.isShown else { return }
        popover.contentViewController = NSHostingController(rootView: MenuView(buildMonitor: buildMonitor))
    }

    private func updateStatusBar() {
        let builds = buildMonitor.trackedBuilds
        let runningBuilds = builds.filter { $0.state == .running }
        let completedBuilds = builds.filter { $0.isCompleted }

        let attributedString = NSMutableAttributedString()
        let emojiAttrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 14)]
        let textAttrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 11, weight: .medium)]

        if runningBuilds.count == 1 {
            let build = runningBuilds[0]
            let emoji = getStatusDisplay(for: build.state).emoji
            let branch = truncateBranch(build.branch, maxLength: 25)
            attributedString.append(NSAttributedString(string: emoji + " ", attributes: emojiAttrs))
            attributedString.append(NSAttributedString(string: branch, attributes: textAttrs))
        } else if runningBuilds.count > 1 {
            let emoji = getStatusDisplay(for: .running).emoji
            attributedString.append(NSAttributedString(string: emoji + " ", attributes: emojiAttrs))
            attributedString.append(NSAttributedString(string: "\(runningBuilds.count) running", attributes: textAttrs))
        } else if let lastCompleted = completedBuilds.first {
            let emoji = getStatusDisplay(for: lastCompleted.state).emoji
            let branch = truncateBranch(lastCompleted.branch, maxLength: 25)
            attributedString.append(NSAttributedString(string: emoji + " ", attributes: emojiAttrs))
            attributedString.append(NSAttributedString(string: branch, attributes: textAttrs))
        } else {
            attributedString.append(NSAttributedString(string: "⚪️ ", attributes: emojiAttrs))
            attributedString.append(NSAttributedString(string: "No builds", attributes: textAttrs))
        }

        statusItem.button?.attributedTitle = attributedString
        statusItem.button?.image = nil
    }

    private func getStatusDisplay(for state: BuildState) -> (emoji: String, text: String) {
        switch state {
        case .scheduled:
            return ("⚪️", "Scheduled")
        case .running:
            return ("🟡", "Running")
        case .passed:
            return ("🟢", "Passed")
        case .failed:
            return ("🔴", "Failed")
        case .blocked:
            return ("🟠", "Blocked")
        case .canceled:
            return ("⚫️", "Canceled")
        }
    }

    private func truncateBranch(_ branch: String, maxLength: Int) -> String {
        if branch.count <= maxLength { return branch }
        return String(branch.prefix(maxLength - 1)) + "…"
    }

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
            // Status bar update handled by popoverDidClose delegate
        } else {
            if let button = statusItem.button {
                // Recreate content to ensure fresh SwiftUI state
                popover.contentViewController = NSHostingController(rootView: MenuView(buildMonitor: buildMonitor))
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                // Ensure popover becomes key window so buttons respond to first click
                NSApp.activate(ignoringOtherApps: true)
                popover.contentViewController?.view.window?.makeKey()
            }
        }
    }
}

// MARK: - NSPopoverDelegate
extension StatusBarController: NSPopoverDelegate {
    func popoverDidClose(_ notification: Notification) {
        // Update status bar when popover closes (handles both manual close and transient auto-close)
        updateStatusBar()
    }
}

extension NSColor {
    static func from(_ colorName: String) -> NSColor {
        switch colorName {
        case "green":
            return .systemGreen
        case "yellow":
            return .systemYellow
        case "red":
            return .systemRed
        case "orange":
            return .systemOrange
        case "gray":
            return .systemGray
        default:
            return .labelColor
        }
    }
}
