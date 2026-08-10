# Mite Example App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a committed SwiftUI example app in `Examples/MiteExample` that exercises the full Mite SDK v1 surface against a live server.

**Architecture:** A four-tab SwiftUI app (Report, Releases, Identity, Settings) with one shared `AppSettings` object. `AppSettings` persists the API key, endpoint, and offline-queue toggle in `UserDefaults` and calls `Mite.configure` at launch and on Apply. The Xcode project uses the Xcode 16 synchronized-folder format and references the SDK package with the relative path `../..`.

**Tech Stack:** SwiftUI, PhotosUI (`PhotosPicker`), Swift Package Manager local reference, `xcodebuild` for verification.

## Global Constraints

- Example app deployment target: iOS 16.0. The SDK package stays at iOS 15.
- The project file is `Examples/MiteExample/MiteExample.xcodeproj` with `objectVersion = 77` (Xcode 16 synchronized folders).
- The SDK is referenced only through the local package path `../..`. No remote dependency.
- No secrets in git. The API key is entered in the app and stored in `UserDefaults`.
- No unit tests or UI tests in the example app (spec: out of scope). Verification is `xcodebuild` plus a manual simulator QA pass.
- Build command for every task:

  ```bash
  xcodebuild -project Examples/MiteExample/MiteExample.xcodeproj \
    -scheme MiteExample \
    -destination 'generic/platform=iOS Simulator' \
    CODE_SIGNING_ALLOWED=NO build
  ```

- Commits use conventional-commit messages.
- SDK API facts used below (do not guess others): `Mite.configure(_:)` replaces the shared client; `MiteClient` is an actor, so `anonymousId`, `userIdentifier`, and `isIdentificationOptedOut` need `await`; `submitBug` returns `SubmitBugResult` (`.success(report:droppedAttachments:)` / `.refused(MiteQuotaRefusal)`); `getReleases(platform:limit:)` returns `[Release]`; `identify(_:)` returns `IdentifyResponse` with `id: String`, `created: Bool`; `MiteQuotaRefusal` has `code.rawValue` and `message`.

---

### Task 1: Xcode project scaffold, app entry, AppSettings, tab shell

**Files:**
- Create: `Examples/MiteExample/MiteExample.xcodeproj/project.pbxproj`
- Create: `Examples/MiteExample/MiteExample.xcodeproj/xcshareddata/xcschemes/MiteExample.xcscheme`
- Create: `Examples/MiteExample/MiteExample/MiteExampleApp.swift`
- Create: `Examples/MiteExample/MiteExample/AppSettings.swift`
- Create: `Examples/MiteExample/MiteExample/ContentView.swift`
- Modify: `.gitignore`

**Interfaces:**
- Consumes: `Mite.configure(_:)`, `MiteConfig`, `MiteQuotaRefusal` from the SDK.
- Produces: `AppSettings` (`@MainActor final class`, `ObservableObject`) with `@Published var apiKey: String`, `@Published var endpoint: String`, `@Published var offlineQueueEnabled: Bool`, `@Published var quotaLog: [String]`, `var isConfigured: Bool`, `func apply()`. `ContentView` expects `ReportView`, `ReleasesView`, `IdentityView`, `SettingsView` types to exist; Task 1 creates placeholder versions that later tasks replace file-by-file.

- [ ] **Step 1: Add Xcode user files to .gitignore**

Append to `.gitignore`:

```
xcuserdata/
```

- [ ] **Step 2: Write the project file**

Create `Examples/MiteExample/MiteExample.xcodeproj/project.pbxproj` with exactly:

```
// !$*UTF8*$!
{
	archiveVersion = 1;
	classes = {
	};
	objectVersion = 77;
	objects = {

/* Begin PBXBuildFile section */
		4D4954450000000000000001 /* Mite in Frameworks */ = {isa = PBXBuildFile; productRef = 4D4954450000000000000002 /* Mite */; };
/* End PBXBuildFile section */

/* Begin PBXFileSystemSynchronizedRootGroup section */
		4D4954450000000000000003 /* MiteExample */ = {
			isa = PBXFileSystemSynchronizedRootGroup;
			explicitFileTypes = {
			};
			explicitFolders = (
			);
			path = MiteExample;
			sourceTree = "<group>";
		};
/* End PBXFileSystemSynchronizedRootGroup section */

/* Begin PBXFrameworksBuildPhase section */
		4D4954450000000000000004 /* Frameworks */ = {
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
				4D4954450000000000000001 /* Mite in Frameworks */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
		4D4954450000000000000005 = {
			isa = PBXGroup;
			children = (
				4D4954450000000000000003 /* MiteExample */,
				4D4954450000000000000006 /* Products */,
			);
			sourceTree = "<group>";
		};
		4D4954450000000000000006 /* Products */ = {
			isa = PBXGroup;
			children = (
				4D4954450000000000000007 /* MiteExample.app */,
			);
			name = Products;
			sourceTree = "<group>";
		};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		4D4954450000000000000008 /* MiteExample */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = 4D4954450000000000000012 /* Build configuration list for PBXNativeTarget "MiteExample" */;
			buildPhases = (
				4D495445000000000000000B /* Sources */,
				4D4954450000000000000004 /* Frameworks */,
				4D495445000000000000000C /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			fileSystemSynchronizedGroups = (
				4D4954450000000000000003 /* MiteExample */,
			);
			name = MiteExample;
			packageProductDependencies = (
				4D4954450000000000000002 /* Mite */,
			);
			productName = MiteExample;
			productReference = 4D4954450000000000000007 /* MiteExample.app */;
			productType = "com.apple.product-type.application";
		};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		4D495445000000000000000A /* Project object */ = {
			isa = PBXProject;
			attributes = {
				BuildIndependentTargetsInParallel = 1;
				LastSwiftUpdateCheck = 1600;
				LastUpgradeCheck = 1600;
				TargetAttributes = {
					4D4954450000000000000008 = {
						CreatedOnToolsVersion = 16.0;
					};
				};
			};
			buildConfigurationList = 4D4954450000000000000011 /* Build configuration list for PBXProject "MiteExample" */;
			developmentRegion = en;
			hasScannedForEncodings = 0;
			knownRegions = (
				en,
				Base,
			);
			mainGroup = 4D4954450000000000000005;
			minimizedProjectReferenceProxies = 1;
			packageReferences = (
				4D4954450000000000000009 /* XCLocalSwiftPackageReference "../.." */,
			);
			preferredProjectObjectVersion = 77;
			productRefGroup = 4D4954450000000000000006 /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				4D4954450000000000000008 /* MiteExample */,
			);
		};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
		4D495445000000000000000C /* Resources */ = {
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
		4D495445000000000000000B /* Sources */ = {
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
		4D495445000000000000000D /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ENABLE_MODULES = YES;
				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_TESTABILITY = YES;
				GCC_OPTIMIZATION_LEVEL = 0;
				GCC_PREPROCESSOR_DEFINITIONS = (
					"DEBUG=1",
					"$(inherited)",
				);
				IPHONEOS_DEPLOYMENT_TARGET = 16.0;
				ONLY_ACTIVE_ARCH = YES;
				SDKROOT = iphoneos;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
				SWIFT_VERSION = 5.0;
			};
			name = Debug;
		};
		4D495445000000000000000E /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ENABLE_MODULES = YES;
				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				ENABLE_NS_ASSERTIONS = NO;
				IPHONEOS_DEPLOYMENT_TARGET = 16.0;
				SDKROOT = iphoneos;
				SWIFT_COMPILATION_MODE = wholemodule;
				SWIFT_VERSION = 5.0;
				VALIDATE_PRODUCT = YES;
			};
			name = Release;
		};
		4D495445000000000000000F /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				ENABLE_PREVIEWS = YES;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
				INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
				INFOPLIST_KEY_UILaunchScreen_Generation = YES;
				INFOPLIST_KEY_UISupportedInterfaceOrientations = UIInterfaceOrientationPortrait;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.usemite.MiteExample;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = YES;
				TARGETED_DEVICE_FAMILY = "1,2";
			};
			name = Debug;
		};
		4D4954450000000000000010 /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				ENABLE_PREVIEWS = YES;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
				INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
				INFOPLIST_KEY_UILaunchScreen_Generation = YES;
				INFOPLIST_KEY_UISupportedInterfaceOrientations = UIInterfaceOrientationPortrait;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.usemite.MiteExample;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = YES;
				TARGETED_DEVICE_FAMILY = "1,2";
			};
			name = Release;
		};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		4D4954450000000000000011 /* Build configuration list for PBXProject "MiteExample" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				4D495445000000000000000D /* Debug */,
				4D495445000000000000000E /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
		4D4954450000000000000012 /* Build configuration list for PBXNativeTarget "MiteExample" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				4D495445000000000000000F /* Debug */,
				4D4954450000000000000010 /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
/* End XCConfigurationList section */

/* Begin XCLocalSwiftPackageReference section */
		4D4954450000000000000009 /* XCLocalSwiftPackageReference "../.." */ = {
			isa = XCLocalSwiftPackageReference;
			relativePath = "../..";
		};
/* End XCLocalSwiftPackageReference section */

/* Begin XCSwiftPackageProductDependency section */
		4D4954450000000000000002 /* Mite */ = {
			isa = XCSwiftPackageProductDependency;
			productName = Mite;
		};
/* End XCSwiftPackageProductDependency section */
	};
	rootObject = 4D495445000000000000000A /* Project object */;
}
```

- [ ] **Step 3: Write the shared scheme**

Create `Examples/MiteExample/MiteExample.xcodeproj/xcshareddata/xcschemes/MiteExample.xcscheme` with exactly:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1600"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "4D4954450000000000000008"
               BuildableName = "MiteExample.app"
               BlueprintName = "MiteExample"
               ReferencedContainer = "container:MiteExample.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
      </Testables>
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "4D4954450000000000000008"
            BuildableName = "MiteExample.app"
            BlueprintName = "MiteExample"
            ReferencedContainer = "container:MiteExample.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
```

- [ ] **Step 4: Write the app entry point**

Create `Examples/MiteExample/MiteExample/MiteExampleApp.swift`:

```swift
import SwiftUI

@main
struct MiteExampleApp: App {
    @StateObject private var settings = AppSettings()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
        }
    }
}
```

- [ ] **Step 5: Write AppSettings**

Create `Examples/MiteExample/MiteExample/AppSettings.swift`:

```swift
import Foundation
import Mite

/// App-side configuration. Persists to UserDefaults and applies the
/// values to the SDK through Mite.configure.
@MainActor
final class AppSettings: ObservableObject {
    @Published var apiKey: String
    @Published var endpoint: String
    @Published var offlineQueueEnabled: Bool
    /// One line per onQuotaExceeded callback, newest last.
    @Published var quotaLog: [String] = []

    private let defaults = UserDefaults.standard

    var isConfigured: Bool {
        !apiKey.trimmingCharacters(in: .whitespaces).isEmpty
    }

    init() {
        apiKey = defaults.string(forKey: "example.apiKey") ?? ""
        endpoint = defaults.string(forKey: "example.endpoint")
            ?? MiteConfig.defaultEndpoint.absoluteString
        offlineQueueEnabled = defaults.object(forKey: "example.offlineQueue") as? Bool ?? true
        apply()
    }

    /// Saves the current values and replaces the shared SDK client.
    func apply() {
        defaults.set(apiKey, forKey: "example.apiKey")
        defaults.set(endpoint, forKey: "example.endpoint")
        defaults.set(offlineQueueEnabled, forKey: "example.offlineQueue")

        let key = apiKey.trimmingCharacters(in: .whitespaces)
        Mite.configure(MiteConfig(
            apiKey: key.isEmpty ? nil : key,
            endpoint: URL(string: endpoint) ?? MiteConfig.defaultEndpoint,
            enableOfflineQueue: offlineQueueEnabled,
            onQuotaExceeded: { [weak self] refusal in
                Task { @MainActor in
                    self?.quotaLog.append("\(refusal.code.rawValue): \(refusal.message)")
                }
            }
        ))
    }
}
```

- [ ] **Step 6: Write ContentView with placeholder tabs**

Create `Examples/MiteExample/MiteExample/ContentView.swift`. The four tab views are placeholders in this task; Tasks 2–5 create the real files and this file does not change again:

```swift
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        TabView {
            ReportView()
                .tabItem { Label("Report", systemImage: "ladybug") }
            ReleasesView()
                .tabItem { Label("Releases", systemImage: "shippingbox") }
            IdentityView()
                .tabItem { Label("Identity", systemImage: "person.crop.circle") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .safeAreaInset(edge: .top) {
            if !settings.isConfigured {
                Text("No API key set. Open the Settings tab.")
                    .font(.footnote)
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .background(.yellow.opacity(0.3))
            }
        }
    }
}
```

Also add the four placeholder views in one temporary file `Examples/MiteExample/MiteExample/PlaceholderViews.swift`:

```swift
import SwiftUI

// Temporary placeholders. Tasks 2-5 replace these with real files.
// Each task deletes its placeholder from this file; Task 5 deletes the file.
struct ReportView: View { var body: some View { Text("Report") } }
struct ReleasesView: View { var body: some View { Text("Releases") } }
struct IdentityView: View { var body: some View { Text("Identity") } }
struct SettingsView: View { var body: some View { Text("Settings") } }
```

- [ ] **Step 7: Build**

Run the global build command. Expected: `BUILD SUCCEEDED`.

- [ ] **Step 8: Commit**

```bash
git add .gitignore Examples docs
git commit -m "feat: add example app scaffold with tab shell and settings model"
```

---

### Task 2: Settings tab

**Files:**
- Create: `Examples/MiteExample/MiteExample/SettingsView.swift`
- Modify: `Examples/MiteExample/MiteExample/PlaceholderViews.swift` (remove the `SettingsView` placeholder)

**Interfaces:**
- Consumes: `AppSettings` from Task 1 (`apiKey`, `endpoint`, `offlineQueueEnabled`, `quotaLog`, `apply()`).
- Produces: `struct SettingsView: View`.

- [ ] **Step 1: Write SettingsView**

Create `Examples/MiteExample/MiteExample/SettingsView.swift`:

```swift
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var showApplied = false

    var body: some View {
        NavigationView {
            Form {
                Section("Server") {
                    TextField("API key (mite_...)", text: $settings.apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Endpoint URL", text: $settings.endpoint)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    Toggle("Offline queue", isOn: $settings.offlineQueueEnabled)
                    Button("Apply") {
                        settings.apply()
                        showApplied = true
                    }
                }
                Section("Quota callbacks") {
                    if settings.quotaLog.isEmpty {
                        Text("No quota refusals yet.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(Array(settings.quotaLog.enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(.caption.monospaced())
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .alert("Configuration applied", isPresented: $showApplied) {
                Button("OK", role: .cancel) {}
            }
        }
    }
}
```

- [ ] **Step 2: Remove the SettingsView placeholder**

In `PlaceholderViews.swift`, delete the line `struct SettingsView: View { var body: some View { Text("Settings") } }`.

- [ ] **Step 3: Build**

Run the global build command. Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Commit**

```bash
git add Examples
git commit -m "feat: add settings tab with SDK configuration and quota log"
```

---

### Task 3: Report tab

**Files:**
- Create: `Examples/MiteExample/MiteExample/ReportView.swift`
- Modify: `Examples/MiteExample/MiteExample/PlaceholderViews.swift` (remove the `ReportView` placeholder)

**Interfaces:**
- Consumes: `Mite.shared.submitBug(_:)`, `BugReportPayload`, `MiteAttachment`, `SubmitBugResult` from the SDK.
- Produces: `struct ReportView: View`.

- [ ] **Step 1: Write ReportView**

Create `Examples/MiteExample/MiteExample/ReportView.swift`:

```swift
import SwiftUI
import PhotosUI
import Mite

struct ReportView: View {
    @State private var title = ""
    @State private var details = ""
    @State private var steps = ""
    @State private var appVersion = "1.0.0"
    @State private var pickedItem: PhotosPickerItem?
    @State private var attachmentURL: URL?
    @State private var isSubmitting = false
    @State private var resultText: String?
    @State private var errorText: String?

    var body: some View {
        NavigationView {
            Form {
                Section("Bug") {
                    TextField("Title", text: $title)
                    TextField("Description", text: $details, axis: .vertical)
                        .lineLimit(3...6)
                    TextField("Steps to reproduce", text: $steps, axis: .vertical)
                        .lineLimit(2...4)
                    TextField("App version", text: $appVersion)
                }
                Section("Attachment") {
                    PhotosPicker("Pick image", selection: $pickedItem, matching: .images)
                    if attachmentURL != nil {
                        Label("1 image attached", systemImage: "paperclip")
                    }
                }
                Section {
                    Button(isSubmitting ? "Submitting…" : "Submit") {
                        submit()
                    }
                    .disabled(isSubmitting || title.isEmpty || details.isEmpty)
                }
                if let resultText {
                    Section("Result") {
                        Text(resultText)
                    }
                }
            }
            .navigationTitle("Report")
            .onChange(of: pickedItem) { item in
                loadAttachment(item)
            }
            .alert(
                "Error",
                isPresented: Binding(
                    get: { errorText != nil },
                    set: { if !$0 { errorText = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorText ?? "")
            }
        }
    }

    private func loadAttachment(_ item: PhotosPickerItem?) {
        guard let item else {
            attachmentURL = nil
            return
        }
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self) else { return }
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("mite-attachment.jpg")
            try? data.write(to: url)
            attachmentURL = url
        }
    }

    private func submit() {
        isSubmitting = true
        resultText = nil
        let payload = BugReportPayload(
            title: title,
            description: details,
            stepsToReproduce: steps.isEmpty ? nil : steps,
            appVersion: appVersion.isEmpty ? nil : appVersion,
            attachments: attachmentURL.map {
                [MiteAttachment(fileURL: $0, contentType: "image/jpeg")]
            }
        )
        Task {
            defer { isSubmitting = false }
            do {
                let result = try await Mite.shared.submitBug(payload)
                resultText = message(for: result)
            } catch {
                errorText = String(describing: error)
            }
        }
    }

    private func message(for result: SubmitBugResult) -> String {
        switch result {
        case let .success(report, dropped):
            var text = "Created report \(report.id) (status: \(report.status))."
            if let dropped {
                text += "\n\(dropped.count) attachment(s) did not upload: \(dropped.refusal.message)"
            }
            return text
        case let .refused(refusal):
            return "Refused (\(refusal.code.rawValue)): \(refusal.message)"
        }
    }
}
```

- [ ] **Step 2: Remove the ReportView placeholder**

In `PlaceholderViews.swift`, delete the line `struct ReportView: View { var body: some View { Text("Report") } }`.

- [ ] **Step 3: Build**

Run the global build command. Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Commit**

```bash
git add Examples
git commit -m "feat: add bug report tab with photo attachment"
```

---

### Task 4: Releases tab

**Files:**
- Create: `Examples/MiteExample/MiteExample/ReleasesView.swift`
- Modify: `Examples/MiteExample/MiteExample/PlaceholderViews.swift` (remove the `ReleasesView` placeholder)

**Interfaces:**
- Consumes: `Mite.shared.getReleases(platform:limit:)`, `Release` from the SDK.
- Produces: `struct ReleasesView: View`.

- [ ] **Step 1: Write ReleasesView**

Create `Examples/MiteExample/MiteExample/ReleasesView.swift`:

```swift
import SwiftUI
import Mite

struct ReleasesView: View {
    @State private var releases: [Release] = []
    @State private var errorText: String?
    @State private var isLoading = false

    var body: some View {
        NavigationView {
            List {
                if let errorText {
                    Text(errorText)
                        .foregroundColor(.red)
                }
                ForEach(releases, id: \.id) { release in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(release.version) (\(release.versionCode))")
                            .font(.headline)
                        Text(release.platform.rawValue)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if let notes = release.notes {
                            Text(notes)
                                .font(.subheadline)
                        }
                    }
                }
                if releases.isEmpty && errorText == nil && !isLoading {
                    Text("No releases. Pull to refresh.")
                        .foregroundColor(.secondary)
                }
            }
            .refreshable { await load() }
            .task { await load() }
            .navigationTitle("Releases")
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        errorText = nil
        do {
            releases = try await Mite.shared.getReleases(platform: .ios, limit: 20)
        } catch {
            errorText = String(describing: error)
        }
    }
}
```

- [ ] **Step 2: Remove the ReleasesView placeholder**

In `PlaceholderViews.swift`, delete the line `struct ReleasesView: View { var body: some View { Text("Releases") } }`.

- [ ] **Step 3: Build**

Run the global build command. Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Commit**

```bash
git add Examples
git commit -m "feat: add releases tab with pull-to-refresh"
```

---

### Task 5: Identity tab

**Files:**
- Create: `Examples/MiteExample/MiteExample/IdentityView.swift`
- Delete: `Examples/MiteExample/MiteExample/PlaceholderViews.swift` (the `IdentityView` placeholder is the last one)

**Interfaces:**
- Consumes: `Mite.shared.identify(_:)`, `logout()`, `setIdentificationOptOut(_:)`, and the awaited actor properties `anonymousId`, `userIdentifier`, `isIdentificationOptedOut`; `Mite.sharedIfConfigured`; `IdentifyPayload`, `IdentifyResponse` from the SDK.
- Produces: `struct IdentityView: View`.

- [ ] **Step 1: Write IdentityView**

Create `Examples/MiteExample/MiteExample/IdentityView.swift`:

```swift
import SwiftUI
import Mite

struct IdentityView: View {
    @State private var anonymousId = ""
    @State private var userIdentifier: String?
    @State private var optedOut = false
    @State private var formUserId = ""
    @State private var formEmail = ""
    @State private var statusText: String?
    @State private var errorText: String?

    var body: some View {
        NavigationView {
            Form {
                Section("Current identity") {
                    LabeledContent("Anonymous id", value: anonymousId)
                    LabeledContent("User", value: userIdentifier ?? "none")
                }
                Section("Identify") {
                    TextField("User identifier", text: $formUserId)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Email", text: $formEmail)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.emailAddress)
                    Button("Identify") {
                        identify()
                    }
                    .disabled(formUserId.isEmpty)
                }
                Section("Privacy") {
                    Toggle("Identification opt-out", isOn: $optedOut)
                        .onChange(of: optedOut) { value in
                            setOptOut(value)
                        }
                    Button("Log out", role: .destructive) {
                        logout()
                    }
                }
                if let statusText {
                    Section("Status") {
                        Text(statusText)
                    }
                }
            }
            .navigationTitle("Identity")
            .task { await refresh() }
            .alert(
                "Error",
                isPresented: Binding(
                    get: { errorText != nil },
                    set: { if !$0 { errorText = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorText ?? "")
            }
        }
    }

    private func refresh() async {
        guard let client = Mite.sharedIfConfigured else { return }
        anonymousId = await client.anonymousId
        userIdentifier = await client.userIdentifier
        optedOut = await client.isIdentificationOptedOut
    }

    private func identify() {
        Task {
            do {
                let response = try await Mite.shared.identify(IdentifyPayload(
                    userIdentifier: formUserId,
                    email: formEmail.isEmpty ? nil : formEmail
                ))
                statusText = "Identified (id: \(response.id), created: \(response.created))"
                await refresh()
            } catch {
                errorText = String(describing: error)
            }
        }
    }

    private func logout() {
        Task {
            await Mite.shared.logout()
            statusText = "Logged out."
            await refresh()
        }
    }

    private func setOptOut(_ value: Bool) {
        Task {
            await Mite.shared.setIdentificationOptOut(value)
            statusText = value ? "Identification opted out." : "Identification allowed."
            await refresh()
        }
    }
}
```

- [ ] **Step 2: Delete PlaceholderViews.swift**

```bash
rm Examples/MiteExample/MiteExample/PlaceholderViews.swift
```

- [ ] **Step 3: Build**

Run the global build command. Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Commit**

```bash
git add -A Examples
git commit -m "feat: add identity tab with identify, logout, and opt-out"
```

---

### Task 6: README section

**Files:**
- Modify: `README.md` (add a section after "Development")

**Interfaces:**
- Consumes: nothing.
- Produces: documentation only.

- [ ] **Step 1: Add the example app section**

Append to `README.md` after the "Development" section:

```markdown
## Example app

An example app is in `Examples/MiteExample`. It exercises bug reports
with an attachment, releases, identity, quota callbacks, and the
offline queue.

1. Open `Examples/MiteExample/MiteExample.xcodeproj` in Xcode 16 or later.
2. Run the `MiteExample` scheme on an iOS 16+ simulator.
3. Open the Settings tab. Enter your API key. Tap Apply.

Or build from the command line:

​```bash
xcodebuild -project Examples/MiteExample/MiteExample.xcodeproj \
  -scheme MiteExample \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
​```
```

(Remove the zero-width characters before the inner code fence markers; they only keep this plan's fence intact.)

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: document the example app"
```

---

### Task 7: Manual QA in the simulator

**Files:** none (verification only).

**Interfaces:**
- Consumes: the built app from Tasks 1–5.

- [ ] **Step 1: Build for a concrete simulator and install**

Use Argent (`list-devices`, `boot-device`) to boot an iOS simulator. Then:

```bash
xcodebuild -project Examples/MiteExample/MiteExample.xcodeproj \
  -scheme MiteExample \
  -destination 'platform=iOS Simulator,name=<booted device name>' \
  -derivedDataPath /tmp/mite-example-dd \
  CODE_SIGNING_ALLOWED=NO build
xcrun simctl install <udid> /tmp/mite-example-dd/Build/Products/Debug-iphonesimulator/MiteExample.app
```

- [ ] **Step 2: Launch and walk the tabs**

Launch with Argent `launch-app` (bundle id `com.usemite.MiteExample`). Use `describe` before every tap. Verify:

1. The "No API key set" banner shows on first launch.
2. Settings: enter a key and tap Apply; the alert shows; the banner goes away after the key is set.
3. Report: fill title and description, submit, and read the result (a real server answer, a quota refusal, or a shown error — any of the three proves the wiring).
4. Releases: pull to refresh; a list or an inline error shows.
5. Identity: the anonymous id shows as `anon_<uuid>`; identify, log out, and toggle opt-out; the status line updates.

- [ ] **Step 3: Report QA results**

No commit. Report what passed and what failed, with screenshots.
