[![Xcode - Build and Analyze](https://github.com/GoodPie/buildkite-build-notifier/actions/workflows/objective-c-xcode.yml/badge.svg?branch=main)](https://github.com/GoodPie/buildkite-build-notifier/actions/workflows/objective-c-xcode.yml)

# Buildkite Notifier (macOS)

A lightweight macOS menu bar app that monitors your Buildkite builds and surfaces status at a glance with a popover UI.

This was a one-day project to explore Buildkite so there's a lot of work left.


## Features

- Menu bar status with live build state and active build count badge
- Focus a specific build to track prominently
- View other active builds and previously focused completed builds
- Real-time duration timers for running builds and steps
- Add builds by pasting a Buildkite build URL
- One-click link to open a build in Buildkite
- Settings to configure API token, organization slug, and polling interval
- Connection test to validate credentials and org access
- Secure storage of API token in Keychain

## Installation

### Homebrew

```
brew tap GoodPie/tap
brew install --cask buildkite-notifier
```

### Building

1. Clone the repository:

```
https://github.com/GoodPie/buildkite-build-notifier.git
```

2. Open the project in xcode
3. Run and build the project.

### Troubleshooting

- This app is not signed. You'll get a notification that Mac couldn't verify this app
  - Don't click "Move to trash" on the dialog. Click "Done" --> Go to System Settings --> Privacy and Security --> Scroll down --> "Open App Anyway"

## Running 

1. The app will open in the menu bar and have the status `idle`
2. Click the menu bar icon and select "Settings"
3. Enter your API key
4. Enter the name of your organisation
5. Test the connection 
6. Click Save

Now when a pipeline is running that you have been assigned to, you'll get a notification and see the status update in the menu bar.

### Create your API Key

1. Navigate to Buildkite: https://buildkite.com/user/api-access-tokens
2. Click "New API Access Token"
3. Add `Read Permissions` for.:
  - Read Builds (`read_builds`)
  - Read User (`read_user`)  
4. Select the organisation access you wish to grant
5. Click "Create New API Access Token"

### Verify Notification Settings

1. Open System Settings
2. Find "Build Kite Notifier"
3. Check notifications are enabled
