# Mite iOS SDK v1 — Design

Date: 2026-08-09
Status: Approved

## Goal

A native Swift SDK for iOS apps. It mirrors the core of the React Native
`mite-sdk`. Version 1 ships bug reporting and releases. It does not ship
shake detection, feature requests, store review, What's New, or UI.

## Decisions

- Distribution: Swift Package Manager only.
- Minimum iOS: 15. Swift 5.9.
- API shape: instance (`MiteClient`) plus a shared singleton entry (`Mite`).
- UI: none. API only.
- Offline queue: in-memory only, same as the RN SDK.
- No third-party dependencies. `URLSession` + `Codable`.
- The package also declares macOS as a platform so `swift test` runs on a
  Mac host. UIKit use is guarded with `#if canImport(UIKit)`. iOS is the
  only supported deployment target.

## Public surface

- `MiteConfig` — `apiKey`, `endpoint` (default `https://intent-okapi-412.convex.site`),
  `timeout` (5 s), `maxRetries` (0), `anonymousId` override,
  `identificationOptOut` (false), `enableOfflineQueue` (true),
  `onQuotaExceeded` closure.
- `MiteClient` (actor) — `submitBug`, `identify`, `logout`,
  `setIdentificationOptOut`, `getReleases`, `flushOfflineQueue`,
  `anonymousId`, `userIdentifier`, `isIdentificationOptedOut`,
  `pendingRequestCount`. All async.
- `Mite` — `Mite.configure(_:)` creates the shared instance. `Mite.shared`
  returns it. `Mite.reset()` clears it (tests).
- `SubmitBugResult` — `.success(report:droppedAttachments:)` or
  `.refused(MiteQuotaRefusal)`. A quota refusal never throws. Network
  faults and bad configuration throw `MiteError`.
- Models: `BugReportPayload`, `BugReportResponse`, `MiteAttachment`
  (local file URL + type + name), `Release`, `ReleasePlatform`,
  `IdentifyPayload`, `IdentifyResponse`, `MiteQuotaRefusal`, `MiteQuota`,
  `MiteQuotaCode`.
- `MiteIdentityStorage` protocol. Default implementation uses
  `UserDefaults`.

## Internal units

- `APIClient` — `URLSession` wrapper. JSON in and out. Bearer auth header.
  Retries only network faults and HTTP 5xx. Exponential backoff:
  `min(1000 * 2^(n+1), 10000)` ms, same as RN. Never retries 4xx.
- Quota parsing — HTTP 402 with body `{error, code, quota:{limit, used,
  resets_at}}` becomes `MiteQuotaRefusal`. Codes: `REPORT_QUOTA_EXCEEDED`
  (has `resets_at`), `STORAGE_QUOTA_EXCEEDED`. One function owns the wire
  format.
- `OfflineQueue` (actor) — in-memory. Flush each 30 s and on demand.
  Max 100 items (drop oldest). Max age 24 h. Max 5 retries per item.
  A quota refusal drops the item at once and calls back to the owner.
- `DeviceInfo` — flat `[String: String]`. Keys follow the RN SDK where
  possible: `brand`, `manufacturer`, `modelName`, `modelId`,
  `deviceName`, `deviceType`, `osName`, `osVersion`, `isDevice`,
  `totalMemory`, `supportedCpuArchitectures`.
- `IdentityStore` — persists `anonymousId` (`anon_<UUID>`),
  `userIdentifier`, and the opt-out flag under one JSON key,
  `@mite/sdk-identity`, same as RN.

## Bug report flow

1. If a remembered report-quota refusal is still in force, return
   `.refused` and send nothing. The gate clears at `resetsAt`.
2. Upload attachments one by one: `POST /api/v1/upload-url`, then upload
   the file bytes to the returned URL. A `REPORT_QUOTA_EXCEEDED` refusal
   stops everything. A `STORAGE_QUOTA_EXCEEDED` refusal stops uploads but
   the report still goes out, with the dropped count in the result.
3. `POST /api/v1/bug-reports` with the payload, identity fields, and
   device info (unless opted out). A 402 becomes `.refused`.
4. On a network fault with the queue on: queue the report without
   attachments, then rethrow.

## Identity flow

- On init, read persisted identity from storage. Config overrides win.
- `identify` posts to `/api/v1/identify`, then persists the new state.
- `logout` clears the user identifier locally, persists, then syncs in
  the background. Sync failures are ignored.
- Opt-out removes the user identifier and stops the SDK from sending
  user ids, contact fields, metadata, and device info.

## Releases

- `getReleases(platform:limit:)` calls `GET /api/v1/releases` with query
  parameters. Returns `[Release]`.

## Error model

- `MiteError`: `missingAPIKey(action)`, `network(URLError)`,
  `server(status:body:)`, `decoding(Error)`, `invalidResponse`.
- Quota refusals are values, not errors.

## Testing

XCTest. A `URLProtocol` stub fakes the server. Coverage: retry policy,
quota parsing, the quota gate, submit success and refusal, attachment
drop rules, queue enqueue/flush/drop, identity persistence
(`UserDefaults` with a test suite name).
