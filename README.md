# Mite iOS SDK

Native Swift SDK for Mite. Bug reporting, releases, and in-app announcements
for iOS apps.

- Swift Package Manager, iOS 15+, no dependencies.
- `async/await` API. Client state is actor-isolated.
- A plan quota refusal is a value, not a thrown error.
- An in-memory offline queue retries bug reports after network faults.
- Reports carry the current screen, the last error and the network state.

## Install

Add the package in Xcode, or in `Package.swift`:

```swift
.package(url: "https://github.com/usemite/mite-ios-sdk.git", from: "0.1.0")
```

## Configure

```swift
import Mite

Mite.configure(MiteConfig(apiKey: "mite_your_api_key"))
```

You can also create your own instance with `MiteClient(config:)`.

## Submit a bug report

```swift
let result = try await Mite.shared.submitBug(BugReportPayload(
    title: "Crash on login",
    description: "The app closes after I tap Sign In.",
    stepsToReproduce: "1. Open app\n2. Tap Sign In",
    appVersion: "1.4.2",
    attachments: [MiteAttachment(fileURL: screenshotURL, contentType: "image/png")]
))

switch result {
case .success(let report, let dropped):
    print("Report \(report.id) created")
    if let dropped {
        print("\(dropped.count) attachment(s) did not upload: \(dropped.refusal.message)")
    }
case .refused(let refusal):
    print("Plan limit reached: \(refusal.message)")
}
```

Network faults throw `MiteError`. When the offline queue is on (default),
a report that fails with a network fault is queued and retried each 30
seconds. Attachments are not queued.

## Triage context

Every bug report carries the current screen, the last recorded error and the
network state as named keys inside `environment`: `current_route`,
`last_error_message`, `last_error_stack` and `network_state`. A key you pass
in `BugReportPayload.environment` yourself wins over the collected value, and
an unknown value is left out.

```swift
Mite.shared.recordScreen("Checkout")
Mite.shared.recordError(error)
```

In SwiftUI, record the screen as the view appears:

```swift
CheckoutView()
    .miteScreen("Checkout")
```

Network state is read with `NWPathMonitor` as `wifi`, `cellular`, `wired`,
`other` or `none`, with a `/offline` suffix while the path is unsatisfied.
An uncaught exception is persisted and rides on the first report after the
crash. Turn either source off with `MiteConfig(monitorNetworkState:)` and
`MiteConfig(captureUncaughtExceptions:)`.

## Releases

```swift
let releases = try await Mite.shared.getReleases(platform: .ios, limit: 10)
```

## Announcements

Mount the SwiftUI popup once near the root of your app. It fetches the newest
active iOS announcement and shows it once per device:

```swift
ContentView()
    .miteAnnouncementPopup()
```

To let users re-open the latest announcement, own a controller and pass it to
the modifier:

```swift
@StateObject private var announcements = MiteAnnouncementController()

var body: some View {
    ContentView()
        .miteAnnouncementPopup(controller: announcements)
        .toolbar {
            Button("Latest announcement") { announcements.show() }
        }
}
```

The popup renders Markdown, follows the system appearance, and opens an
optional CTA URL. Dismissed IDs are kept in the configured
`MiteIdentityStorage` under `@mite/sdk-seen-announcements`.

The lower-level API is also available for custom interfaces:

```swift
let active = try await Mite.shared.getAnnouncements(platform: .ios, limit: 5)
let seen = await Mite.shared.getSeenAnnouncementIds()
await Mite.shared.markAnnouncementSeen(active[0].id)
await Mite.shared.clearSeenAnnouncements()
```

## Identity

```swift
try await Mite.shared.identify(IdentifyPayload(
    userIdentifier: "user-123",
    email: "user@example.com"
))

await Mite.shared.logout()
await Mite.shared.setIdentificationOptOut(true)
```

The SDK keeps a stable anonymous id (`anon_<uuid>`) in `UserDefaults`.
Pass your own `MiteIdentityStorage` in `MiteConfig` to store it elsewhere.
When identification is opted out, the SDK sends no user ids, contact
fields, metadata, or device info.

## Quota callbacks

```swift
Mite.configure(MiteConfig(
    apiKey: "mite_your_api_key",
    onQuotaExceeded: { refusal in
        print("Quota: \(refusal.code) — \(refusal.message)")
    }
))
```

## Development

```bash
swift test
```

The design spec is in
[docs/superpowers/specs/2026-08-09-mite-ios-sdk-v1-design.md](docs/superpowers/specs/2026-08-09-mite-ios-sdk-v1-design.md).

## Example app

An example app is in `Examples/MiteExample`. It exercises bug reports
with an attachment, releases, identity, quota callbacks, and the
offline queue.

1. Open `Examples/MiteExample/MiteExample.xcodeproj` in Xcode 16 or later.
2. Run the `MiteExample` scheme on an iOS 16+ simulator.
3. Open the Settings tab. Enter your API key. Tap Apply.

Or build from the command line:

```bash
xcodebuild -project Examples/MiteExample/MiteExample.xcodeproj \
  -scheme MiteExample \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```
