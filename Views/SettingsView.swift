//
//  SettingsView.swift
//  BuildkiteNotifier
//
//  Created by Brandyn Britton on 2025-10-20.
//  Updated: 2025-10-22 - UX Refinement
//

import SwiftUI

// MARK: - Supporting Components

/// Inline help text component matching macOS Settings style
struct HelpText: View {
    let text: String
    var linkText: String? = nil
    var linkURL: String? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)

            if let linkText = linkText, let linkURL = linkURL {
                Link(linkText, destination: URL(string: linkURL)!)
                    .font(.caption)
            }
        }
    }
}

/// Validation message component (errors and success states)
struct ValidationMessage: View {
    enum MessageType {
        case error
        case success
        case info

        var color: Color {
            switch self {
            case .error: return .red
            case .success: return .green
            case .info: return .blue
            }
        }

        var icon: String {
            switch self {
            case .error: return "exclamationmark.circle.fill"
            case .success: return "checkmark.circle.fill"
            case .info: return "info.circle.fill"
            }
        }
    }

    let message: String
    let type: MessageType

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: type.icon)
                .font(.caption)
                .foregroundColor(type.color)
            Text(message)
                .font(.caption)
                .foregroundColor(type.color)
        }
        .padding(.vertical, 4)
    }
}

/// Secure field with show/hide toggle
struct SecureFieldWithToggle: View {
    let label: String
    @Binding var text: String
    @State private var isSecure: Bool = true

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .foregroundColor(.secondary)
                .font(.body)

            Group {
                if isSecure {
                    SecureField(label, text: $text)
                } else {
                    TextField(label, text: $text)
                }
            }
            .textFieldStyle(.plain)

            Button(action: { isSecure.toggle() }) {
                Image(systemName: isSecure ? "eye.fill" : "eye.slash.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help(isSecure ? "Show token" : "Hide token")
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @ObservedObject var buildMonitor: BuildMonitor
    @Environment(\.dismiss) var dismiss

    @State private var apiToken: String = ""
    @State private var organizationSlug: String = ""
    @State private var pollingInterval: Int = 30

    // Validation states
    @State private var orgSlugError: String? = nil
    @State private var connectionTestState: ConnectionTestState = .idle
    @State private var hasUnsavedChanges: Bool = false
    @State private var showingDiscardAlert: Bool = false

    enum ConnectionTestState {
        case idle
        case testing
        case success(userName: String)
        case failure(message: String)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Main content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // API Connection Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("API Connection")
                            .font(.headline)
                            .foregroundColor(.primary)

                        // API Token Field
                        VStack(alignment: .leading, spacing: 6) {
                            Text("API Token")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            SecureFieldWithToggle(label: "Enter your API token", text: $apiToken)
                                .onChange(of: apiToken) { _, _ in hasUnsavedChanges = true }

                            HelpText(
                                text: "Stored securely in Keychain. ",
                                linkText: "Create a token →",
                                linkURL: "https://buildkite.com/user/api-access-tokens"
                            )
                        }

                        // Organization Slug Field
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Organization")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            TextField("your-organization", text: $organizationSlug)
                                .textFieldStyle(.plain)
                                .padding(8)
                                .background(Color(NSColor.controlBackgroundColor))
                                .cornerRadius(6)
                                .onChange(of: organizationSlug) { _, newValue in
                                    hasUnsavedChanges = true
                                    validateOrgSlug(newValue)
                                }

                            if let error = orgSlugError {
                                ValidationMessage(message: error, type: .error)
                            } else {
                                HelpText(text: "Found in your Buildkite URL (e.g., 'acme-corp')")
                            }
                        }

                        // Connection Test Button
                        testConnectionSection
                    }

                    Divider()

                    // Behavior Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Behavior")
                            .font(.headline)
                            .foregroundColor(.primary)

                        HStack {
                            Text("Polling Interval")
                                .font(.subheadline)

                            Spacer()

                            Picker("", selection: $pollingInterval) {
                                Text("15 seconds").tag(15)
                                Text("30 seconds").tag(30)
                                Text("1 minute").tag(60)
                                Text("2 minutes").tag(120)
                            }
                            .labelsHidden()
                            .frame(width: 150)
                            .onChange(of: pollingInterval) { _, _ in hasUnsavedChanges = true }
                        }

                        HelpText(text: "How often to check for build updates (30 seconds recommended)")
                    }
                }
                .padding(20)
            }

            // Bottom Button Bar
            Divider()

            HStack {
                Button("Cancel") {
                    handleCancel()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save") {
                    saveSettings()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(orgSlugError != nil || apiToken.isEmpty || organizationSlug.isEmpty)
            }
            .padding(16)
        }
        .frame(width: 500, height: 480)
        .alert("Discard Changes?", isPresented: $showingDiscardAlert) {
            Button("Keep Editing", role: .cancel) { }
            Button("Discard", role: .destructive) {
                dismiss()
            }
        } message: {
            Text("Your API credentials won't be saved.")
        }
        .onAppear {
            loadSettings()
        }
    }

    // MARK: - Connection Test Section

    @ViewBuilder
    private var testConnectionSection: some View {
        HStack {
            Button(action: testConnection) {
                HStack(spacing: 6) {
                    if case .testing = connectionTestState {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 14, height: 14)
                    } else {
                        Image(systemName: "network")
                            .font(.caption)
                    }
                    Text("Test Connection")
                        .font(.subheadline)
                }
            }
            .disabled(apiToken.isEmpty || organizationSlug.isEmpty || orgSlugError != nil)

            Spacer()

            // Connection status
            switch connectionTestState {
            case .idle:
                EmptyView()
            case .testing:
                Text("Testing...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            case .success(let userName):
                ValidationMessage(message: "Connected as \(userName)", type: .success)
            case .failure(let message):
                ValidationMessage(message: message, type: .error)
            }
        }
    }

    // MARK: - Actions

    private func loadSettings() {
        apiToken = KeychainHelper.shared.load(key: "buildkite-api-token") ?? ""
        organizationSlug = UserDefaults.standard.string(forKey: "organizationSlug") ?? ""
        pollingInterval = UserDefaults.standard.integer(forKey: "pollingInterval")
        if pollingInterval == 0 {
            pollingInterval = 30
        }
        hasUnsavedChanges = false
    }

    private func saveSettings() {
        _ = KeychainHelper.shared.save(key: "buildkite-api-token", value: apiToken)
        UserDefaults.standard.set(organizationSlug, forKey: "organizationSlug")
        UserDefaults.standard.set(pollingInterval, forKey: "pollingInterval")

        buildMonitor.configure(apiToken: apiToken, orgSlug: organizationSlug)
        buildMonitor.stopMonitoring()
        Task {
            await buildMonitor.startMonitoring()
        }

        hasUnsavedChanges = false
        dismiss()
    }

    private func handleCancel() {
        if hasUnsavedChanges {
            showingDiscardAlert = true
        } else {
            dismiss()
        }
    }

    private func validateOrgSlug(_ slug: String) {
        // Organization slugs must be lowercase alphanumeric + hyphens
        let pattern = "^[a-z0-9-]+$"
        let regex = try? NSRegularExpression(pattern: pattern, options: [])

        if slug.isEmpty {
            orgSlugError = nil
            return
        }

        if regex?.firstMatch(in: slug, options: [], range: NSRange(location: 0, length: slug.utf16.count)) == nil {
            orgSlugError = "Use lowercase letters, numbers, and hyphens only"
        } else {
            orgSlugError = nil
        }
    }

    private func testConnection() {
        connectionTestState = .testing

        Task {
            do {
                // Create temporary API instance for testing
                let testAPI = BuildkiteAPI()
                testAPI.setToken(apiToken)

                // Test 1: Fetch user info
                let user = try await testAPI.fetchUser()

                // Test 2: Try to fetch builds for org (to verify org exists)
                _ = try await testAPI.fetchUserBuilds(orgSlug: organizationSlug, userId: user.id, perPage: 1)

                await MainActor.run {
                    connectionTestState = .success(userName: user.name ?? user.email ?? "Unknown")
                }
            } catch let error as APIError {
                await MainActor.run {
                    switch error {
                    case .unauthorized:
                        connectionTestState = .failure(message: "Invalid API token")
                    case .organizationNotFound:
                        connectionTestState = .failure(message: "Organization not found")
                    case .networkError:
                        connectionTestState = .failure(message: "Network error")
                    case .rateLimited:
                        connectionTestState = .failure(message: "Rate limited")
                    default:
                        connectionTestState = .failure(message: "Connection failed")
                    }
                }
            } catch {
                await MainActor.run {
                    connectionTestState = .failure(message: "Unknown error")
                }
            }
        }
    }
}
