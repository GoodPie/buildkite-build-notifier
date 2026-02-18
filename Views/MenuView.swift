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
    @State private var showingSettings: Bool = false
    @State private var expandedBuildId: String? = nil

    private var activeBuilds: [Build] {
        buildMonitor.trackedBuilds.filter { $0.isActive }
    }

    private var completedBuilds: [Build] {
        buildMonitor.trackedBuilds.filter { $0.isCompleted }
    }

    private var hasBothGroups: Bool {
        !activeBuilds.isEmpty && !completedBuilds.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // Error banner
            if let error = buildMonitor.errorState {
                ErrorBanner(message: error, onDismiss: {
                    buildMonitor.errorState = nil
                })
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

            // Welcome view - not polling and no builds
            if !buildMonitor.isPolling && buildMonitor.trackedBuilds.isEmpty {
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

            // Empty state - polling but no builds tracked
            if buildMonitor.isPolling && buildMonitor.hasCompletedFirstFetch && buildMonitor.trackedBuilds.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No builds tracked")
                        .font(.headline)
                    Text("Your active builds will appear here, or paste a Buildkite URL below to track a specific build.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity)
                .padding()
            }

            // Build list
            if !buildMonitor.trackedBuilds.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        // Active builds
                        if !activeBuilds.isEmpty {
                            if hasBothGroups {
                                Text("ACTIVE")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 12)
                                    .padding(.top, 8)
                                    .padding(.bottom, 2)
                            }

                            ForEach(activeBuilds) { build in
                                BuildCardView(
                                    build: build,
                                    isExpanded: expandedBuildId == build.id,
                                    onTap: { toggleExpansion(build.id) },
                                    onRemove: { buildMonitor.removeBuild(id: build.id) }
                                )
                                .padding(.horizontal, 8)
                            }
                        }

                        // Completed builds
                        if !completedBuilds.isEmpty {
                            if hasBothGroups {
                                Text("COMPLETED")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 12)
                                    .padding(.top, 8)
                                    .padding(.bottom, 2)
                            }

                            ForEach(completedBuilds) { build in
                                BuildCardView(
                                    build: build,
                                    isExpanded: expandedBuildId == build.id,
                                    onTap: { toggleExpansion(build.id) },
                                    onRemove: { buildMonitor.removeBuild(id: build.id) }
                                )
                                .padding(.horizontal, 8)
                            }

                            // Clear Completed button when 2+ completed
                            if completedBuilds.count >= 2 {
                                Button("Clear Completed") {
                                    buildMonitor.clearCompleted()
                                }
                                .buttonStyle(.bordered)
                                .tint(.red)
                                .font(.caption)
                                .controlSize(.small)
                                .padding(.horizontal, 12)
                                .padding(.top, 4)
                                .padding(.bottom, 8)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Divider()

            // Always-visible Add by URL section
            HStack(spacing: 6) {
                TextField("Paste Buildkite URL...", text: $buildURL)
                    .textFieldStyle(.plain)
                    .font(.caption)
                    .padding(6)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(6)
                    .onSubmit { addBuild() }

                Button("Add") { addBuild() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(buildURL.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Footer buttons
            HStack {
                Button("Settings") { showingSettings = true }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                Spacer()

                Button("Quit") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(width: 360)
        .sheet(isPresented: $showingSettings) {
            SettingsView(buildMonitor: buildMonitor)
                .interactiveDismissDisabled(false)
        }
    }

    private func toggleExpansion(_ buildId: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if expandedBuildId == buildId {
                expandedBuildId = nil
            } else {
                expandedBuildId = buildId
            }
        }
    }

    private func addBuild() {
        let trimmed = buildURL.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        Task {
            await buildMonitor.addBuild(url: trimmed)
            buildURL = ""
        }
    }
}

// MARK: - BuildCardView

struct BuildCardView: View {
    let build: Build
    let isExpanded: Bool
    let onTap: () -> Void
    let onRemove: () -> Void

    @State private var isHovering: Bool = false
    @State private var currentDuration: TimeInterval?
    @State private var timer: Timer?
    @State private var isCommitExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Always visible (collapsed) row
            HStack(alignment: .top, spacing: 8) {
                // State icon
                Image(systemName: build.state.iconName)
                    .foregroundColor(Color.from(build.state.color))
                    .frame(width: 16, alignment: .center)
                    .padding(.top, 2)

                // Branch + pipeline
                VStack(alignment: .leading, spacing: 2) {
                    Text(build.branch)
                        .font(.body)
                        .fontWeight(.semibold)
                        .lineLimit(1)

                    Text(build.pipelineName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Duration
                if let duration = currentDuration {
                    Text(Build.formatDuration(duration))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .padding(.top, 2)
                }

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .animation(.easeInOut(duration: 0.2), value: isExpanded)
                    .padding(.top, 2)
            }
            .contentShape(Rectangle())
            .onTapGesture { onTap() }

            // Expanded detail
            if isExpanded {
                Divider()
                    .padding(.vertical, 6)

                VStack(alignment: .leading, spacing: 8) {
                    // Commit message
                    Text(build.commitMessage)
                        .font(.caption)
                        .lineLimit(isCommitExpanded ? nil : 2)
                        .onTapGesture { isCommitExpanded.toggle() }

                    // Build steps
                    if let steps = build.steps, !steps.isEmpty {
                        BuildStepsSection(build: build)
                    }

                    // Action buttons
                    HStack(spacing: 8) {
                        if let url = URL(string: build.webUrl) {
                            Link(destination: url) {
                                Text("Open in Buildkite")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }

                        Button("Remove") {
                            onRemove()
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                        .controlSize(.small)
                    }
                }
                .padding(.leading, 24)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .quaternarySystemFill).opacity(isHovering ? 1.0 : 0.5))
        )
        .onHover { hovering in
            isHovering = hovering
        }
        .onAppear {
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
        .onChange(of: build.state) { _, _ in
            if build.isCompleted {
                stopTimer()
                currentDuration = build.runningDuration
            }
        }
    }

    private func startTimer() {
        stopTimer()
        currentDuration = build.runningDuration

        // Only start live timer for active builds with a startedAt date
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

// MARK: - ErrorBanner

struct ErrorBanner: View {
    let message: String
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.yellow)
            Text(message)
                .font(.caption)
            Spacer()
            if let onDismiss = onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(Color.yellow.opacity(0.2))
    }
}

// MARK: - Build Step Views

struct BuildStepRowView: View {
    let step: BuildStep
    var indented: Bool = false

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: step.iconName)
                .foregroundColor(Color.from(step.iconColor))
                .frame(width: 16)

            Text(step.displayName)
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
        .padding(.leading, indented ? 24 : 4)
        .padding(.trailing, 4)
        .background(step.isRunning ? Color.yellow.opacity(0.1) : Color.clear)
        .cornerRadius(4)
    }
}

// MARK: - Collapsible Build Steps

struct BuildStepGroupHeaderView: View {
    let group: BuildStepGroup
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 8) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .frame(width: 10)

                Image(systemName: group.aggregateIcon)
                    .foregroundColor(Color.from(group.aggregateColor))
                    .frame(width: 16)

                Text(group.displayTitle)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                Spacer()

                Text("\(group.stepCount)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.15))
                    .cornerRadius(8)

                if !isExpanded {
                    Text(group.summaryText)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
        .background(group.hasRunningStep ? Color.yellow.opacity(0.1) : Color.clear)
        .cornerRadius(4)
    }
}

struct CollapsibleBuildStepGroupView: View {
    let group: BuildStepGroup
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            BuildStepGroupHeaderView(
                group: group,
                isExpanded: isExpanded,
                onToggle: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }
            )

            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(group.steps.sorted { $0.order < $1.order }) { step in
                        BuildStepRowView(step: step, indented: true)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

struct BuildStepsSection: View {
    let build: Build
    @State private var expandedGroups: Set<String>

    init(build: Build) {
        self.build = build
        // Default all groups to expanded
        _expandedGroups = State(initialValue: Set(build.groupedSteps.map { $0.id }))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Build Steps")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fontWeight(.semibold)

                Spacer()

                Button(expandedGroups.isEmpty ? "Expand All" : "Collapse All") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if expandedGroups.isEmpty {
                            expandedGroups = Set(build.groupedSteps.map { $0.id })
                        } else {
                            expandedGroups.removeAll()
                        }
                    }
                }
                .font(.caption2)
                .foregroundColor(.secondary)
                .buttonStyle(.plain)
            }

            ForEach(build.groupedSteps) { group in
                CollapsibleBuildStepGroupView(
                    group: group,
                    isExpanded: Binding(
                        get: { expandedGroups.contains(group.id) },
                        set: { isExpanded in
                            if isExpanded {
                                expandedGroups.insert(group.id)
                            } else {
                                expandedGroups.remove(group.id)
                            }
                        }
                    )
                )
            }
        }
    }
}

// MARK: - Color Extension

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
