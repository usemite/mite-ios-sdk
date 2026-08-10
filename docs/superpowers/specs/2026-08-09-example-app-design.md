# Mite iOS SDK — Example App Design

Date: 2026-08-09
Status: Approved

## Goal

Add an example iOS app to the repo. The app exercises the full v1 SDK
surface by hand: bug reports with an attachment, releases, identity,
quota callbacks, and the offline queue. Developers use it to test SDK
integration against a live or local Mite server.

## Decisions

- **Committed Xcode project.** The project lives in
  `Examples/MiteExample/MiteExample.xcodeproj`. No generator tool is
  necessary. The project uses the Xcode 16 synchronized-folder format,
  so new source files do not need project edits.
- **Local package reference.** The project references the SDK with the
  relative path `../..`.
- **SwiftUI, iOS 16 deployment target.** The SDK stays at iOS 15. The
  app uses iOS 16 because `PhotosPicker` needs it, and it removes a
  UIKit wrapper.
- **API key entered in the app.** A settings screen holds the key and
  the endpoint. The app stores them in `UserDefaults`. No secrets go
  into git.

## App structure

One `TabView` with four tabs.

### Report tab

- Text fields: title, description, steps to reproduce, app version.
- One image attachment through `PhotosPicker`. The app writes the
  picked image to a temporary file and passes a `MiteAttachment`.
- A Submit button calls `Mite.shared.submitBug`.
- The screen shows the result:
  - Success: the report id, plus dropped-attachment info when present.
  - Refused: the quota-refusal message, shown as a normal result.
  - Thrown `MiteError`: shown as an error.

### Releases tab

- A list from `Mite.shared.getReleases(platform: .ios)`.
- Pull-to-refresh. An inline error state.

### Identity tab

- Shows the current identity.
- A form calls `identify(IdentifyPayload(...))` with user id and email.
- Buttons call `logout()` and toggle `setIdentificationOptOut`.

### Settings tab

- Text fields: API key, endpoint URL.
- A toggle: enable offline queue.
- An Apply button calls `Mite.configure` again. A second call replaces
  the shared client, which the SDK permits.
- A log view shows each `onQuotaExceeded` callback.

## Config flow

At launch, the app reads the stored key, endpoint, and queue toggle
from `UserDefaults`, then calls `Mite.configure`. When no key is
stored, the app shows a banner that points to Settings.

## Error handling

Each tab shows errors inline or in an alert. Quota refusals show as
results, not errors. This demonstrates the SDK rule: a refusal is a
value.

## Verification

- Build with `xcodebuild` for the iOS simulator.
- Run the app in the simulator with Argent. Do a manual QA pass of
  each tab.

## Out of scope

- Unit tests and UI tests in the example app.
- A custom `MiteIdentityStorage` demo.
- Android, macOS, or visionOS targets.
