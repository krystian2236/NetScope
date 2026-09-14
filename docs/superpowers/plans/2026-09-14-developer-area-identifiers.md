# Developer Area Identifiers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add always-visible, unique and copyable identifiers to the important NetScope Developer areas while leaving the App Store interface unchanged.

**Architecture:** A central typed `DeveloperAreaID` catalog owns the naming grammar and complete identifier inventory. A shared `DeveloperAreaTag` renders and copies identifiers only when `NETSCOPE_DEVELOPER_TOOLS` is compiled; Toolbox and Laboratory derive tool-specific identifiers from finite typed enums rather than arbitrary strings.

**Tech Stack:** Swift 6, SwiftUI, UIKit clipboard and accessibility APIs, Swift Testing, Xcode 27.

**Spec:** `docs/superpowers/specs/2026-09-14-developer-area-identifiers-design.md`

## Global Constraints

- Labels are always visible in NetScope Developer and have no visibility toggle.
- Labels never appear in the App Store build.
- Identifier grammar is uppercase ASCII words separated by hyphens.
- Cover main tabs, important sections and primary actions; do not label decorative text or repeated ordinary rows.
- Do not change scanning, command construction, laboratory answers or access tiers.
- Preserve all existing uncommitted work in `codex/lab-briefing-terminal`.
- Do not commit, push or merge without a separate explicit user selection.
- Build and test only against `NetScope — iPhone 17`, UDID `0058F185-AD3B-4AE6-83B9-337E482F17F2`.

---

### Task 1: Central identifier catalog and reusable tag

**Files:**
- Create: `NetScope/DeveloperAreaTag.swift`
- Modify: `NetScope.xcodeproj/project.pbxproj`
- Modify: `NetScopeTests/NetScopeTests.swift`

**Interfaces:**
- Produces: `DeveloperAreaID`, `DeveloperAreaTool`, `DeveloperToolboxPart`, `DeveloperLaboratoryPart`.
- Produces: `DeveloperAreaTag.init(_ area: DeveloperAreaID)`.
- Consumes: `NETSCOPE_DEVELOPER_TOOLS`, `UIPasteboard`, `UIAccessibility`.

- [ ] **Step 1: Add failing catalog tests**

Add a `DeveloperAreaIdentifierTests` suite:

```swift
@Suite("Developer area identifiers")
struct DeveloperAreaIdentifierTests {
  @Test("Known identifiers are unique and follow the grammar")
  func uniqueAndWellFormed() {
    let values = DeveloperAreaID.allKnown.map(\.rawValue)
    #expect(Set(values).count == values.count)
    #expect(values.allSatisfy {
      $0.range(of: #"^[A-Z0-9]+(?:-[A-Z0-9]+)+$"#,
               options: .regularExpression) != nil
    })
  }

  @Test("Every Toolbox tool has every required area")
  func toolboxMatrixIsComplete() {
    let values = Set(DeveloperAreaID.allKnown.map(\.rawValue))
    for tool in DeveloperAreaTool.allCases {
      for part in DeveloperToolboxPart.allCases {
        #expect(values.contains("TB-\(tool.rawValue)-\(part.rawValue)"))
      }
    }
  }

  @Test("Every Laboratory tool has every required flow area")
  func laboratoryMatrixIsComplete() {
    let values = Set(DeveloperAreaID.allKnown.map(\.rawValue))
    for tool in DeveloperAreaTool.allCases {
      for part in DeveloperLaboratoryPart.allCases {
        #expect(values.contains("LAB-\(tool.rawValue)-\(part.rawValue)"))
      }
    }
  }
}
```

- [ ] **Step 2: Run the tests and verify RED**

Run:

```zsh
xcodebuild -project NetScope.xcodeproj -scheme 'NetScope Developer' \
  -destination 'platform=iOS Simulator,id=0058F185-AD3B-4AE6-83B9-337E482F17F2' \
  -derivedDataPath /private/tmp/NetScope-566c-derived \
  -parallel-testing-enabled NO \
  -only-testing:NetScopeTests/DeveloperAreaIdentifierTests test
```

Expected: compilation fails because `DeveloperAreaID` and related types do not exist.

- [ ] **Step 3: Implement the typed identifier inventory**

Create these finite tool and part types:

```swift
enum DeveloperAreaTool: String, CaseIterable, Sendable {
  case nmap = "NMAP"
  case nuclei = "NUCLEI"
  case dig = "DIG"
  case curl = "CURL"
}

enum DeveloperToolboxPart: String, CaseIterable, Sendable {
  case entry = "ENTRY"
  case screen = "SCREEN"
  case command = "COMMAND"
  case fragments = "FRAGMENTS"
  case syntax = "SYNTAX"
  case sections = "SECTIONS"
  case options = "OPTIONS"
  case value = "VALUE"
  case messages = "MESSAGES"
}

enum DeveloperLaboratoryPart: String, CaseIterable, Sendable {
  case program = "PROGRAM"
  case missionList = "MISSION-LIST"
  case briefing = "BRIEFING"
  case terminal = "TERMINAL"
  case answer = "ANSWER"
  case result = "RESULT"
}

struct DeveloperAreaID: RawRepresentable, Hashable, Sendable {
  let rawValue: String

  static let navStart = Self(rawValue: "NAV-START")
  static let navToolbox = Self(rawValue: "NAV-TOOLBOX")
  static let navLaboratory = Self(rawValue: "NAV-LABORATORY")
  static let navCipherPath = Self(rawValue: "NAV-CIPHERPATH")

  static let startScreen = Self(rawValue: "START-SCREEN")
  static let startNetworkContext = Self(rawValue: "START-NETWORK-CONTEXT")
  static let startDevices = Self(rawValue: "START-DEVICES")
  static let startServices = Self(rawValue: "START-SERVICES")
  static let startScanWorkflow = Self(rawValue: "START-SCAN-WORKFLOW")
  static let startScanAction = Self(rawValue: "START-SCAN-ACTION")
  static let startScanResults = Self(rawValue: "START-SCAN-RESULTS")

  static let toolboxScreen = Self(rawValue: "TB-SCREEN")
  static let laboratoryScreen = Self(rawValue: "LAB-SCREEN")
  static let cpScreen = Self(rawValue: "CP-SCREEN")
  static let cpFeatures = Self(rawValue: "CP-FEATURES")
  static let cpIntegration = Self(rawValue: "CP-INTEGRATION")

  static func toolbox(_ tool: DeveloperAreaTool,
                      _ part: DeveloperToolboxPart) -> Self {
    .init(rawValue: "TB-\(tool.rawValue)-\(part.rawValue)")
  }

  static func laboratory(_ tool: DeveloperAreaTool,
                         _ part: DeveloperLaboratoryPart) -> Self {
    .init(rawValue: "LAB-\(tool.rawValue)-\(part.rawValue)")
  }

  static func learning(_ part: DeveloperLaboratoryPart) -> Self {
    .init(rawValue: "LAB-LEARNING-\(part.rawValue)")
  }

  static var allKnown: [Self] {
    let fixed: [Self] = [
      .navStart, .navToolbox, .navLaboratory, .navCipherPath,
      .startScreen, .startNetworkContext, .startDevices, .startServices,
      .startScanWorkflow, .startScanAction, .startScanResults,
      .toolboxScreen, .laboratoryScreen,
      .cpScreen, .cpFeatures, .cpIntegration,
    ]
    let toolbox = DeveloperAreaTool.allCases.flatMap { tool in
      DeveloperToolboxPart.allCases.map { DeveloperAreaID.toolbox(tool, $0) }
    }
    let laboratory = DeveloperAreaTool.allCases.flatMap { tool in
      DeveloperLaboratoryPart.allCases.map { DeveloperAreaID.laboratory(tool, $0) }
    }
    let learning = DeveloperLaboratoryPart.allCases.map(DeveloperAreaID.learning)
    return fixed + toolbox + laboratory + learning
  }
}
```

- [ ] **Step 4: Implement the shared Developer tag**

Add `DeveloperAreaTag` in the same file:

```swift
struct DeveloperAreaTag: View {
  let area: DeveloperAreaID
  @State private var copied = false

  init(_ area: DeveloperAreaID) { self.area = area }

  @ViewBuilder
  var body: some View {
    #if NETSCOPE_DEVELOPER_TOOLS
    Button {
      UIPasteboard.general.string = area.rawValue
      copied = true
      UIAccessibility.post(
        notification: .announcement,
        argument: "Skopiowano \(area.rawValue)"
      )
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
        copied = false
      }
    } label: {
      HStack(spacing: 4) {
        Text("[\(area.rawValue)]")
        if copied { Image(systemName: "checkmark") }
      }
      .font(.caption2.monospaced().weight(.bold))
      .foregroundStyle(.cyan)
      .padding(.horizontal, 6)
      .padding(.vertical, 3)
      .background(Color.cyan.opacity(0.1), in: Capsule())
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Obszar developerski \(area.rawValue)")
    .accessibilityHint("Kopiuje oznaczenie do schowka")
    #else
    EmptyView()
    #endif
  }
}
```

- [ ] **Step 5: Add the file to the application target**

Add `DeveloperAreaTag.swift` to the NetScope group and Sources build phase in
`project.pbxproj`. Do not change target membership of unrelated files.

- [ ] **Step 6: Run the focused tests and verify GREEN**

Repeat the command from Step 2. Expected: all three identifier tests pass.

- [ ] **Step 7: Review checkpoint**

Run `git diff --check` and review only the new file, project membership and
identifier tests. Stop without committing.

---

### Task 2: Migrate Toolbox to tool-specific identifiers

**Files:**
- Modify: `NetScope/ToolboxModel.swift`
- Modify: `NetScope/ToolboxView.swift`
- Modify: `NetScope/ToolLearningView.swift`
- Modify: `NetScopeTests/NetScopeTests.swift`

**Interfaces:**
- Consumes: `DeveloperAreaID.toolbox(_:_:)` and `DeveloperAreaTag` from Task 1.
- Produces: `DeveloperAreaTool.init?(toolID: String)` for the four supported catalogs.

- [ ] **Step 1: Replace the legacy stability test with tool-specific expectations**

```swift
@Test("Toolbox identifiers include their tool name")
func toolboxIdentifiersIncludeToolName() {
  #expect(DeveloperAreaID.toolbox(.nmap, .command).rawValue == "TB-NMAP-COMMAND")
  #expect(DeveloperAreaID.toolbox(.nuclei, .options).rawValue == "TB-NUCLEI-OPTIONS")
  #expect(DeveloperAreaID.toolbox(.dig, .syntax).rawValue == "TB-DIG-SYNTAX")
  #expect(DeveloperAreaID.toolbox(.curl, .messages).rawValue == "TB-CURL-MESSAGES")
  #expect(!DeveloperAreaID.allKnown.map(\.rawValue).contains("TB-COMMAND"))
}
```

- [ ] **Step 2: Run `ToolboxWorkflowTests` and verify RED**

Use the Task 1 command with
`-only-testing:NetScopeTests/ToolboxWorkflowTests`.

Expected: the old generic `ToolboxDeveloperArea` contract does not satisfy the
new assertions.

- [ ] **Step 3: Remove the Toolbox-only identifier enum**

Delete `ToolboxDeveloperArea` from `ToolboxModel.swift`. Keep `ToolboxEntry`
unchanged.

- [ ] **Step 4: Add typed tool mapping**

```swift
extension DeveloperAreaTool {
  init?(toolID: String) {
    switch toolID {
    case "nmap": self = .nmap
    case "nuclei": self = .nuclei
    case "dig": self = .dig
    case "curl": self = .curl
    default: return nil
    }
  }
}
```

- [ ] **Step 5: Label Toolbox entries and screens**

Add `TB-SCREEN` above the Toolbox information banner. Change `toolLink` to
accept `DeveloperAreaTool` and place the matching `ENTRY` tag above each card.
Pass the typed tool into `ToolLearningView` or derive it from `tool.id` once in
that view.

- [ ] **Step 6: Replace every generic Toolbox tag**

Replace the existing tags with:

```swift
DeveloperAreaTag(.toolbox(developerTool, .command))
DeveloperAreaTag(.toolbox(developerTool, .fragments))
DeveloperAreaTag(.toolbox(developerTool, .syntax))
DeveloperAreaTag(.toolbox(developerTool, .sections))
DeveloperAreaTag(.toolbox(developerTool, .options))
DeveloperAreaTag(.toolbox(developerTool, .value))
DeveloperAreaTag(.toolbox(developerTool, .messages))
```

Place `SCREEN` at the top of each `ToolLearningView`. Preserve the fixed
TB-COMMAND/TB-SYNTAX header order and all command-building behavior.

- [ ] **Step 7: Run focused Toolbox tests**

Run `ToolboxWorkflowTests`, `ToolCatalogBrowserTests` and
`ToolCommandCatalogTests`. Expected: all pass.

- [ ] **Step 8: Review checkpoint**

Run `git diff --check`; inspect only Toolbox identifier migration. Stop without
committing.

---

### Task 3: Label navigation, Start and CipherPath

**Files:**
- Modify: `NetScope/AppShellView.swift`
- Modify: `NetScope/ScannerView.swift`
- Modify: `NetScopeTests/NetScopeTests.swift`

**Interfaces:**
- Consumes: static `DeveloperAreaID` values and `DeveloperAreaTag`.
- Produces no new application behavior.

- [ ] **Step 1: Add static coverage assertions**

```swift
@Test("Primary tabs and Start areas have stable identifiers")
func primaryAreasAreStable() {
  #expect(DeveloperAreaID.navStart.rawValue == "NAV-START")
  #expect(DeveloperAreaID.navToolbox.rawValue == "NAV-TOOLBOX")
  #expect(DeveloperAreaID.navLaboratory.rawValue == "NAV-LABORATORY")
  #expect(DeveloperAreaID.navCipherPath.rawValue == "NAV-CIPHERPATH")
  #expect(DeveloperAreaID.startScanAction.rawValue == "START-SCAN-ACTION")
  #expect(DeveloperAreaID.cpIntegration.rawValue == "CP-INTEGRATION")
}
```

- [ ] **Step 2: Run `DeveloperAreaIdentifierTests` and verify RED**

Expected: one or more required static members do not exist until Task 1's
inventory is completed for these areas.

- [ ] **Step 3: Place navigation and Start labels**

Add the matching tags directly above these existing areas:

- root Start content: `NAV-START` and `START-SCREEN`;
- `NetworkHeaderCard`: `START-NETWORK-CONTEXT`;
- device and service destinations: `START-DEVICES`, `START-SERVICES`;
- `ScanWorkflowView`: `START-SCAN-WORKFLOW`;
- `ScanControlCard`: `START-SCAN-ACTION`;
- scan state/results region: `START-SCAN-RESULTS`.

Place `NAV-TOOLBOX` at the Toolbox root and the corresponding navigation tags
at the Laboratory and CipherPath roots. Do not attempt to overlay SwiftUI's
system tab bar.

- [ ] **Step 4: Label CipherPath sections**

In `CipherPathInfoView`, place `CP-SCREEN`, `CP-FEATURES` and `CP-INTEGRATION`
next to their corresponding list sections. Keep link behavior unchanged.

- [ ] **Step 5: Run focused tests and build Developer**

Run `DeveloperAreaIdentifierTests`, then:

```zsh
xcodebuild -project NetScope.xcodeproj -scheme 'NetScope Developer' \
  -destination 'platform=iOS Simulator,id=0058F185-AD3B-4AE6-83B9-337E482F17F2' \
  -derivedDataPath /private/tmp/NetScope-566c-derived build
```

Expected: tests and build succeed with no new compiler errors.

- [ ] **Step 6: Review checkpoint**

Run `git diff --check`; inspect only navigation, Start and CipherPath placement.
Stop without committing.

---

### Task 4: Label Laboratory programs and mission flow

**Files:**
- Modify: `NetScope/LaboratoryView.swift`
- Modify: `NetScope/LabProgramView.swift`
- Modify: `NetScope/TerminalLessonView.swift`
- Modify: `NetScopeTests/LabCurriculumTests.swift`

**Interfaces:**
- Consumes: `DeveloperAreaID.laboratory(_:_:)` and `DeveloperAreaTag`.
- Changes: `TerminalLessonView` receives `toolID: LabToolID? = nil`.

- [ ] **Step 1: Add Laboratory mapping tests**

```swift
@Test("Lab tools map to developer identifier tools")
func labToolsMapToDeveloperTools() {
  #expect(DeveloperAreaTool(.nmap) == .nmap)
  #expect(DeveloperAreaTool(.nuclei) == .nuclei)
  #expect(DeveloperAreaTool(.dig) == .dig)
  #expect(DeveloperAreaTool(.curl) == .curl)
}
```

Implement the initializer as a total switch over `LabToolID`; it must not use
capitalized display strings.

```swift
extension DeveloperAreaTool {
  init(_ tool: LabToolID) {
    switch tool {
    case .nmap: self = .nmap
    case .nuclei: self = .nuclei
    case .dig: self = .dig
    case .curl: self = .curl
    }
  }
}
```

- [ ] **Step 2: Run `LabCurriculumTests` and verify RED**

Expected: the `DeveloperAreaTool` initializer from `LabToolID` does not exist.

- [ ] **Step 3: Label Laboratory navigation and programs**

Add `NAV-LABORATORY` and `LAB-SCREEN` above the Laboratory section picker.
Add the tool-specific `PROGRAM` and `MISSION-LIST` tags in `LabProgramView`.
The generic learning list uses `LAB-LEARNING-MISSION-LIST`.

- [ ] **Step 4: Pass tool identity into mission screens**

Add `toolID: LabToolID? = nil` to `TerminalLessonView`. `LabProgramView` passes
`program.id`; the generic learning list keeps `nil`.

Resolve the identifiers through one computed property:

```swift
private func labArea(_ part: DeveloperLaboratoryPart) -> DeveloperAreaID {
  guard let toolID else {
    return .learning(part)
  }
  return .laboratory(DeveloperAreaTool(toolID), part)
}
```

The central catalog provides typed `LAB-LEARNING-*` values for this fallback.

- [ ] **Step 5: Label briefing and terminal content**

Place `BRIEFING` at the top of `briefingContent`; place `TERMINAL`, `ANSWER`
and `RESULT` above the corresponding existing terminal, response and completion
areas. Do not change command evaluation or progress state.

- [ ] **Step 6: Run Laboratory tests**

Run `LabCurriculumTests`, `VirtualLabEngineTests`, `NmapLabProgramTests`,
`NucleiLabProgramTests`, `DigLabProgramTests` and `CurlLabProgramTests`.
Expected: all pass.

- [ ] **Step 7: Review checkpoint**

Run `git diff --check`; inspect only Laboratory identifier placement and the
new typed parameter. Stop without committing.

---

### Task 5: Verify both variants and install Developer

**Files:**
- Verify only: all files changed by Tasks 1–4

**Interfaces:**
- Consumes the finished identifier catalog and placements.
- Produces verification evidence only.

- [ ] **Step 1: Run the full Developer test suite**

```zsh
xcodebuild -project NetScope.xcodeproj -scheme 'NetScope Developer' \
  -destination 'platform=iOS Simulator,id=0058F185-AD3B-4AE6-83B9-337E482F17F2' \
  -derivedDataPath /private/tmp/NetScope-566c-derived \
  -parallel-testing-enabled NO test
```

Expected: zero failed tests.

- [ ] **Step 2: Build App Store without signing**

```zsh
xcodebuild -project NetScope.xcodeproj -scheme 'NetScope App Store' \
  -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath /private/tmp/NetScope-566c-appstore-derived \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
```

Expected: `BUILD SUCCEEDED`; App Store compilation conditions do not contain
`NETSCOPE_DEVELOPER_TOOLS`.

- [ ] **Step 3: Run repository checks**

Run:

```zsh
git diff --check
zsh scripts/pre-push-check.sh
```

Expected: diff, bundle integrity and build checks report OK.

- [ ] **Step 4: Install and launch only NetScope Developer**

```zsh
xcrun simctl terminate 0058F185-AD3B-4AE6-83B9-337E482F17F2 pl.krystian.NetScope.dev 2>/dev/null || true
xcrun simctl install 0058F185-AD3B-4AE6-83B9-337E482F17F2 \
  /private/tmp/NetScope-566c-derived/Build/Products/Debug-Developer-iphonesimulator/NetScope.app
xcrun simctl launch 0058F185-AD3B-4AE6-83B9-337E482F17F2 pl.krystian.NetScope.dev
```

Do not shut down, reset or erase the simulator.

- [ ] **Step 5: Perform the manual UI matrix**

Verify:

- Start shows the navigation, screen, scan-action and results identifiers;
- every Toolbox entry has its own identifier;
- Nmap shows `TB-NMAP-COMMAND`, `FRAGMENTS`, `SYNTAX`, `SECTIONS`, `OPTIONS`,
  `VALUE` and `MESSAGES` in the correct locations;
- Nuclei, Dig and Curl use their own names rather than Nmap or generic names;
- Laboratory briefing and terminal identifiers match the selected tool;
- CipherPath shows `CP-SCREEN`, `CP-FEATURES` and `CP-INTEGRATION`;
- tapping a capsule copies the exact value;
- no tag covers a button or prevents scrolling;
- at the largest accessibility text size, long identifiers wrap without
  truncation and controls remain usable.

- [ ] **Step 6: Stop at the Git gate**

Report changed files and exact verification results. Do not commit or push until
the user explicitly selects the corresponding Git action.
