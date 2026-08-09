# Mite iOS SDK

Native Swift SDK for Mite. Bug reporting and releases for iOS apps.

- Swift Package Manager, iOS 15+, no dependencies.
- `async/await` API. All state lives in an actor.
- A plan quota refusal is a value, not a thrown error.
- An in-memory offline queue retries bug reports after network faults.

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

## Releases

```swift
let releases = try await Mite.shared.getReleases(platform: .ios, limit: 10)
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
