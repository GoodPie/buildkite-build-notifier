# Buildkite Notifier (macOS)

A lightweight macOS menu bar app that monitors your Buildkite builds and surfaces status at a glance with a popover UI.

## Overview

Buildkite Notifier sits in the macOS menu bar and keeps you informed about your personal Buildkite activity. It shows your focused build, other active builds, and recently completed focused builds. You can quickly open builds in Buildkite, switch focus, and manage your list — all from a compact SwiftUI popover.

- Platform: macOS (menu bar app)
- Minimum macOS: 14+ (adjust if needed)
- Xcode: 26.0+
- Swift: 6+
- Technologies: SwiftUI, AppKit (NSStatusBar, NSPopover), Combine, Swift Concurrency (async/await), Keychain, UserDefaults

## Features

- Menu bar status with live build state (emoji/text) and active build count badge
- Focus a specific build to track prominently
- View other active builds and previously focused completed builds
- Real-time duration timers for running builds and steps
- Add builds by pasting a Buildkite build URL
- One-click link to open a build in Buildkite
- Settings to configure API token, organization slug, and polling interval
- Connection test to validate credentials and org access
- Secure storage of API token in Keychain

## Architecture

- App entry: `BuildkiteNotifierApp` initializes a shared `BuildMonitor` and a `StatusBarController`
- Status bar and popover: `StatusBarController` (AppKit) owns `NSStatusItem` and `NSPopover`, hosts SwiftUI `MenuView`
- UI: SwiftUI views (`MenuView`, `BuildDetailView`, `BuildRowView`, `BuildStepRowView`, `SettingsView`)
- State management: Observable objects with Combine publishers (e.g., `buildMonitor.$focusedBuild`, `buildMonitor.$activeBuilds`)
- Async work: Swift Concurrency (async/await) for network polling and timers
- Persistence/config: Keychain for API token, `UserDefaults` for organization slug and polling interval
- Networking: `BuildkiteAPI` (async) with domain types like `Build`, `BuildStep`, `BuildState`, `User` (see source)

## Project Structure

- BuildkiteNotifierApp.swift — App entry and lifecycle
- StatusBarController.swift — NSStatusItem, NSPopover, and status title updates
- MenuView.swift — Popover content showing focused/active/previous builds and actions
- SettingsView.swift — Credentials, polling, and connection test UI
- Models/ — Domain models such as `Build`, `BuildStep`, `BuildState`
- Services/ — `BuildkiteAPI`, `KeychainHelper` and related networking/helpers
- Resources/ — Assets, strings (if any)
- Tests/ — Unit tests (Swift Testing or XCTest)

Note: Some folders/files may be named slightly differently in your repo; adjust as needed.

## Getting Started

### Prerequisites

- Xcode 26.0.1 or later
- macOS 14+ SDK
- A Buildkite account and API access token

### Clone

