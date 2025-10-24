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
class StatusBarController: ObservableObject {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var buildMonitor: BuildMonitor
    private var cancellables = Set<AnyCancellable>()

    init(buildMonitor: BuildMonitor) {
        self.buildMonitor = buildMonitor
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
        popover.contentViewController = NSHostingController(rootView: MenuView(buildMonitor: buildMonitor))
    }

    private func observeBuildMonitor() {
        // Combine both publishers to update status bar with build and count
        Publishers.CombineLatest(buildMonitor.$focusedBuild, buildMonitor.$activeBuilds)
            .sink { [weak self] build, activeBuilds in
                self?.updateStatusBar(for: build, activeCount: activeBuilds.count)
            }
            .store(in: &cancellables)
    }

    private func updateStatusBar(for build: Build?, activeCount: Int) {
        guard let button = statusItem.button else { return }

        if let build = build {
            // Use colored emoji/text for better visibility
            let (emoji, statusText) = getStatusDisplay(for: build.state)

            // Create attributed string with emoji, build number, and status text
            let attributedString = NSMutableAttributedString()

            // Add colored emoji
            let emojiAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 14)
            ]
            attributedString.append(NSAttributedString(string: emoji, attributes: emojiAttributes))

            // Add build number in bold - using system default color
            let buildNumberAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 11, weight: .semibold)
            ]
            attributedString.append(NSAttributedString(string: " #\(build.buildNumber)", attributes: buildNumberAttributes))

            // Add status text - using system default color
            let textAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 11)
            ]
            attributedString.append(NSAttributedString(string: " \(statusText)", attributes: textAttributes))

            // Add badge count if multiple builds - using system default color
            if activeCount > 1 {
                let badgeAttributes: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 10, weight: .medium)
                ]
                attributedString.append(NSAttributedString(string: " (\(activeCount))", attributes: badgeAttributes))
            }

            button.image = nil
            button.attributedTitle = attributedString
        } else {
            // Idle state
            button.image = nil
            button.attributedTitle = NSAttributedString(
                string: "⚪️ Idle",
                attributes: [.font: NSFont.systemFont(ofSize: 11)]
            )
        }
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

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            if let button = statusItem.button {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                // Ensure popover dismisses when clicking outside
                NSApp.activate(ignoringOtherApps: true)
            }
        }
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
