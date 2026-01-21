# Buildkite Notifier (macOS)

A lightweight macOS menu bar app that monitors your Buildkite builds and surfaces status at a glance with a popover UI.

This was a one-day project to explore Buildkite so there's a lot of work left.

## Running

1. Clone the repository:

```
https://github.com/GoodPie/buildkite-build-notifier.git
```

2. Open the project in xcode
3. Run and build the project. 
4. The app will open in the menu bar and have the status `idle`
5. Click the menu bar icon and select "Settings"
6. Enter your API key
7. Enter the name of your organisation
8. Test the connection 
9. Click Save

Now when a pipeline is running that you have been assigned to, you'll get a notification and see the status update in the menu bar.

### Create your API Key

1. Navigate to Buildkite: https://buildkite.com/user/api-access-tokens
2. Click "New API Access Token"
3. Select all `READ` permissions checked (will refine this down later)
4. Select the organisation access you wish to grant
5. Click "Create New API Access Token"

## Overview

Buildkite Notifier sits in the macOS menu bar and keeps you informed about your personal Buildkite activity. It shows your focused build, other active builds, and recently completed focused builds. You can quickly open builds in Buildkite, switch focus, and manage your list — all from a compact SwiftUI popover.

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
