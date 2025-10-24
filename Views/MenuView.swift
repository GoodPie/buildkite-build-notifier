//
//  MenuView.swift
//  BuildkiteNotifier
//
//  Created by Brandyn Britton on 2025-10-20.
//

import SwiftUI

struct MenuView: View {
    @ObservedObject var buildMonitor: BuildMonitor
    @State private var buildURL: String = ""
    @State private var showingAddURL: Bool = false
    @State private var showingSettings: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Error banner
            if let error = buildMonitor.errorState {
                ErrorBanner(message: error)
            }

            // Loading state - show only until first API response
            if buildMonitor.isPolling && !buildMonitor.hasCompletedFirstFetch {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading builds...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            }

            // First launch / no configuration message
            if !buildMonitor.isPolling && buildMonitor.focusedBuild == nil && buildMonitor.activeBuilds.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "gear")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("Welcome to Buildkite Notifier")
                        .font(.headline)
                    Text("Configure your API token and organization in Settings to get started.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity)
                .padding()
            }

            // Focused build section
            if let focused = buildMonitor.focusedBuild {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Focused Build")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Spacer()

                        Button("Clear Focus") {
                            buildMonitor.clearFocus()
                        }
                        .font(.caption)
                        .foregroundColor(.red)
                    }

                    BuildDetailView(build: focused)
                }
                .padding()

                Divider()
            }

            // Other active builds (not focused, not in previously focused)
            let otherActiveBuilds = buildMonitor.activeBuilds.filter { build in
                build.id != buildMonitor.focusedBuild?.id &&
                !buildMonitor.previouslyFocusedBuilds.contains(where: { $0.id == build.id })
            }

            if !otherActiveBuilds.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Other Active Builds")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ForEach(otherActiveBuilds) { build in
                        BuildRowView(build: build, showFocusButton: true, onFocus: {
                            buildMonitor.switchFocus(to: build)
                        })
                    }
                }
                .padding()

                Divider()
            }

            // Previously Focused Builds (completed builds that were focused)
            if !buildMonitor.previouslyFocusedBuilds.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Previously Focused")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Spacer()

                        Button("Clear All") {
                            buildMonitor.clearCompleted()
                        }
                        .font(.caption)
                    }

                    ForEach(buildMonitor.previouslyFocusedBuilds) { build in
                        BuildRowView(
                            build: build,
                            showFocusButton: true,
                            showRemoveButton: true,
                            onFocus: {
                                buildMonitor.switchFocus(to: build)
                            },
                            onRemove: {
                                buildMonitor.removePreviouslyFocused(build)
                            }
                        )
                    }
                }
                .padding()

                Divider()
            }

            // Add by URL section
            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Button(showingAddURL ? "Cancel" : "Add by URL") {
                    showingAddURL.toggle()
                    if !showingAddURL {
                        buildURL = ""
                    }
                }
                .font(.caption)

                if showingAddURL {
                    HStack {
                        TextField("https://buildkite.com/org/pipeline/builds/123", text: $buildURL)
                            .textFieldStyle(.roundedBorder)
                            .font(.caption)

                        Button("Add") {
                            Task {
                                await buildMonitor.addBuild(url: buildURL)
                                buildURL = ""
                                showingAddURL = false
                            }
                        }
                        .font(.caption)
                        .disabled(buildURL.isEmpty)
                    }
                }
            }
            .padding()

            // Actions
            Divider()

            HStack {
                Button("Settings") {
                    showingSettings = true
                }

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding()
        }
        .frame(width: 360)
        .sheet(isPresented: $showingSettings) {
            SettingsView(buildMonitor: buildMonitor)
                .interactiveDismissDisabled(false)
        }
    }
}

struct ErrorBanner: View {
    let message: String

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.yellow)
            Text(message)
                .font(.caption)
            Spacer()
        }
        .padding(8)
        .background(Color.yellow.opacity(0.2))
    }
}

struct BuildDetailView: View {
    let build: Build
    @State private var currentDuration: TimeInterval?
    @State private var timer: Timer?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: build.state.iconName)
                    .foregroundColor(Color.from(build.state.color))
                Text(build.displayTitle)
                    .font(.headline)

                Spacer()

                // Show duration for active or completed builds
                if let duration = currentDuration {
                    Text(Build.formatDuration(duration))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                }
            }

            Text(build.branch)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text(build.commitMessage)
                .font(.caption)
                .lineLimit(2)
                .foregroundColor(.primary)

            Link(destination: URL(string: build.webUrl)!) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.right.square")
                        .font(.caption)
                    Text("Open in Buildkite")
                        .font(.caption)
                }
            }

            // Build Steps (if available)
            if let steps = build.steps, !steps.isEmpty {
                Divider()
                    .padding(.vertical, 4)

                Text("Build Steps")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fontWeight(.semibold)

                ForEach(steps.sorted(by: { $0.order < $1.order })) { step in
                    BuildStepRowView(step: step)
                }
            }
        }
        .onAppear {
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
        .onChange(of: build.id) { _, _ in
            startTimer()
        }
        .onChange(of: build.state) { _, _ in
            // Stop timer when build completes and freeze at completion time
            if build.isCompleted {
                stopTimer()
                currentDuration = build.runningDuration
            }
        }
    }

    private func startTimer() {
        stopTimer()
        currentDuration = build.runningDuration

        // Only start timer if build is running (not completed)
        if build.isActive, build.startedAt != nil {
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                if let started = build.startedAt {
                    if let finished = build.finishedAt {
                        currentDuration = finished.timeIntervalSince(started)
                    } else {
                        currentDuration = Date().timeIntervalSince(started)
                    }
                }
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

struct BuildRowView: View {
    let build: Build
    var showFocusButton: Bool = true
    var showRemoveButton: Bool = false
    var onFocus: (() -> Void)?
    var onRemove: (() -> Void)?
    @State private var currentDuration: TimeInterval?
    @State private var timer: Timer?

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: build.state.iconName)
                .foregroundColor(Color.from(build.state.color))
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(build.displayTitle)
                    .font(.subheadline)
                HStack(spacing: 4) {
                    Text(build.branch)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if let duration = currentDuration {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(Build.formatDuration(duration))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            if showFocusButton, let onFocus = onFocus {
                Button("Focus") {
                    onFocus()
                }
                .font(.caption)
                .buttonStyle(.borderless)
            }

            if showRemoveButton, let onRemove = onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Remove from list")
            }
        }
        .onAppear {
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
        .onChange(of: build.id) { _, _ in
            startTimer()
        }
        .onChange(of: build.state) { _, _ in
            // Stop timer when build completes and freeze at completion time
            if build.isCompleted {
                stopTimer()
                currentDuration = build.runningDuration
            }
        }
    }

    private func startTimer() {
        stopTimer()
        currentDuration = build.runningDuration

        // Only start timer if build is running (not completed)
        if build.isActive, build.startedAt != nil {
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                if let started = build.startedAt {
                    if let finished = build.finishedAt {
                        currentDuration = finished.timeIntervalSince(started)
                    } else {
                        currentDuration = Date().timeIntervalSince(started)
                    }
                }
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

struct BuildStepRowView: View {
    let step: BuildStep

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: step.iconName)
                .foregroundColor(Color.from(step.iconColor))
                .frame(width: 16)

            Text(step.name)
                .font(.caption)
                .foregroundColor(step.isRunning ? .primary : .secondary)
                .fontWeight(step.isRunning ? .semibold : .regular)

            Spacer()

            if let exitStatus = step.exitStatus {
                Text("Exit: \(exitStatus)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background(step.isRunning ? Color.yellow.opacity(0.1) : Color.clear)
        .cornerRadius(4)
    }
}

extension Color {
    static func from(_ colorName: String) -> Color {
        switch colorName {
        case "green":
            return .green
        case "yellow":
            return .yellow
        case "red":
            return .red
        case "orange":
            return .orange
        case "gray":
            return .gray
        default:
            return .primary
        }
    }
}

