# iSH + Mac SSH Shortcuts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace duplicated dashboard actions with one entry to a searchable, copy-only library of safe iSH and macOS SSH diagnostic commands.

**Architecture:** Add pure Swift shortcut models and a deterministic command builder in a focused source file, then render them in a separate SwiftUI library view. Dashboard and Nmap provide navigation only; no SSH client, command execution, secrets, or external dependency is introduced.

**Tech Stack:** Swift 5, SwiftUI, UIKit pasteboard, XCTest/Swift Testing, Xcode 27, iOS 17+

**Spec:** `docs/superpowers/specs/2026-09-11-ish-ssh-shortcuts-design.md`

## Global Constraints

- NetScope only prepares and copies commands; it never opens SSH or executes shell commands.
- Store only optional SSH username and Mac host in `UserDefaults`; never store passwords or private keys.
- Accept only private IPv4 addresses/subnets through `ISHTargetValidator` for network scan targets.
- Do not add destructive commands, `sudo`, password attacks, exploits, firewall changes, or service mutations.
- Keep the five bottom tabs and preserve Porty, Ping and Bonjour under Usługi.
- Commands and technical details are collapsed by default.
- Biblioteka pozostaje wyszukiwalna według nazwy, opisu i kategorii.
- Porty, Ping i Bonjour pozostają dostępne w sekcji Usługi.
- No new third-party dependency.

---

### Task 1: Pure shortcut catalogue and safe command builder

**Files:**
- Create: `NetScope/SSHShortcutLibrary.swift`
- Modify: `NetScope.xcodeproj/project.pbxproj`
- Test: `NetScopeTests/NetScopeTests.swift`

**Interfaces:**
- Consumes: `ISHTargetValidator.isPrivate(_:) -> Bool` and `NmapGuideStep` from `NetScope/ISHToolkit.swift`.
- Produces: `SSHShortcutCategory`, `SSHExecutionPlace`, `SSHShortcutID`, `SSHShortcut`, `SSHShortcutContext`, `SSHShortcutResolution`, and `SSHShortcutLibrary.resolve(_:context:)`.

- [ ] **Step 1: Write failing catalogue-order and missing-configuration tests**

Add to `NetScopeTests/NetScopeTests.swift`:

```swift
func testSSHShortcutCategoriesFollowWorkflowOrder() {
  XCTAssertEqual(
    SSHShortcutCategory.allCases.map(\.title),
    ["Połączenie z Maciem", "Informacje o sieci", "Wykrywanie urządzeń",
     "DNS i nazwy", "Porty i usługi", "Raporty"]
  )
}

func testSSHLoginRequiresUsernameAndHost() {
  let result = SSHShortcutLibrary.resolve(
    .connect,
    context: SSHShortcutContext(username: "", host: "", target: nil)
  )
  XCTAssertEqual(result, .blocked("Uzupełnij użytkownika i host Maca."))
}
```

- [ ] **Step 2: Run the focused build and verify it fails**

Run:

```bash
xcodebuild -project NetScope.xcodeproj -scheme NetScope \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /private/tmp/NetScopeSSHShortcuts \
  CODE_SIGNING_ALLOWED=NO OTHER_SWIFT_FLAGS=-disable-sandbox build-for-testing
```

Expected: failure because `SSHShortcutCategory`, `SSHShortcutLibrary`, and related types do not exist.

- [ ] **Step 3: Implement the typed catalogue**

Create `NetScope/SSHShortcutLibrary.swift` with these exact public-to-module shapes:

```swift
import Foundation

enum SSHShortcutCategory: Int, CaseIterable, Identifiable, Sendable {
  case connection, networkInfo, discovery, dns, ports, reports
  var id: Self { self }
  var title: String {
    ["Połączenie z Maciem", "Informacje o sieci", "Wykrywanie urządzeń",
     "DNS i nazwy", "Porty i usługi", "Raporty"][rawValue]
  }
}

enum SSHExecutionPlace: String, Sendable {
  case beforeSSH = "Wklej w iSH przed SSH"
  case onMac = "Wklej po zalogowaniu na Maca"
}

enum SSHShortcutID: String, CaseIterable, Identifiable, Sendable {
  case connect, disconnect, macIPv4, gateway, dnsServers, neighbors
  case discoverHosts, reverseDNS, commonPorts, serviceVersions, detailedHost
  case createReportDirectory, listReports
  var id: Self { self }
}

struct SSHShortcut: Identifiable, Equatable, Sendable {
  let id: SSHShortcutID
  let category: SSHShortcutCategory
  let title: String
  let summary: String
  let place: SSHExecutionPlace
}

struct SSHShortcutContext: Equatable, Sendable {
  let username: String
  let host: String
  let target: String?
}

enum SSHShortcutResolution: Equatable, Sendable {
  case command(String)
  case blocked(String)
}
```

Implement `SSHShortcutLibrary.shortcuts` as a fixed list in category order and `resolve(_:context:)`. The connection command must be constructed only after validating username and host as single safe tokens:

```swift
private static let safeToken = /^[A-Za-z0-9._-]+$/

private static func connection(_ context: SSHShortcutContext) -> SSHShortcutResolution {
  guard !context.username.isEmpty, !context.host.isEmpty else {
    return .blocked("Uzupełnij użytkownika i host Maca.")
  }
  guard context.username.wholeMatch(of: safeToken) != nil,
        context.host.wholeMatch(of: safeToken) != nil else {
    return .blocked("Użytkownik lub host zawiera niedozwolone znaki.")
  }
  return .command("ssh \(context.username)@\(context.host)")
}
```

Target-dependent commands must return `.blocked("Wybierz prywatny adres lub podsieć.")` unless `ISHTargetValidator.isPrivate(target)` is true. Use read-only macOS commands (`ipconfig getifaddr en0`, `route -n get default`, `scutil --dns`, `arp -a`, `dscacheutil -q host -a ip_address`) and existing unprivileged Nmap flags.

Resolve every identifier to the following exact command template:

| Identifier | Place | Command |
|---|---|---|
| `connect` | before SSH | `ssh USER@HOST` after safe-token validation |
| `disconnect` | on Mac | `exit` |
| `macIPv4` | on Mac | `ipconfig getifaddr en0` |
| `gateway` | on Mac | `route -n get default` |
| `dnsServers` | on Mac | `scutil --dns` |
| `neighbors` | on Mac | `arp -a` |
| `discoverHosts` | on Mac | `nmap -sn 'TARGET'` |
| `reverseDNS` | on Mac | `dscacheutil -q host -a ip_address 'TARGET'` |
| `commonPorts` | on Mac | `nmap --unprivileged -sT -Pn --open -p '22,53,80,443,445,548,631,9100' 'TARGET'` |
| `serviceVersions` | on Mac | `nmap --unprivileged -sT -Pn -sV --version-light --open -p '22,53,80,443,445,548,631,9100' 'TARGET'` |
| `detailedHost` | on Mac | `nmap --unprivileged -sT -Pn -sV --version-light --open --reason -p '22,53,80,443,445,548,631,9100' 'TARGET'` |
| `createReportDirectory` | on Mac | `mkdir -p "$HOME/Documents/NetScope"` |
| `listReports` | on Mac | `find "$HOME/Documents/NetScope" -maxdepth 1 -type f -print` |

Replace `TARGET` only after private-target validation and single-quote it with the same escaping rule already used by `ISHCommandBuilder`. The UI description for `createReportDirectory` must explicitly say that running it creates a folder; all other entries are read-only.

Add `SSHShortcutLibrary.swift` to the app target's Sources build phase in `project.pbxproj`.

- [ ] **Step 4: Add exact security tests and run the focused test build**

Add:

```swift
func testSSHConnectionRejectsShellMetacharacters() {
  let result = SSHShortcutLibrary.resolve(
    .connect,
    context: SSHShortcutContext(username: "user;id", host: "mac.local", target: nil)
  )
  XCTAssertEqual(result, .blocked("Użytkownik lub host zawiera niedozwolone znaki."))
}

func testSSHDiscoveryRejectsPublicTarget() {
  let result = SSHShortcutLibrary.resolve(
    .discoverHosts,
    context: SSHShortcutContext(username: "krystian", host: "mac.local", target: "8.8.8.8")
  )
  XCTAssertEqual(result, .blocked("Wybierz prywatny adres lub podsieć."))
}
```

Run the Step 2 command. Expected: `TEST BUILD SUCCEEDED`.

- [ ] **Step 5: Commit only Task 1 paths**

```bash
git add NetScope/SSHShortcutLibrary.swift NetScopeTests/NetScopeTests.swift NetScope.xcodeproj/project.pbxproj
git commit -m "feat: add safe SSH shortcut catalogue"
```

Expected: signed commit succeeds; if GPG is unavailable, stop and report the signing blocker instead of disabling signing.

---

### Task 2: Searchable copy-only shortcut library screen

**Files:**
- Create: `NetScope/SSHShortcutLibraryView.swift`
- Modify: `NetScope.xcodeproj/project.pbxproj`
- Test: `NetScopeTests/NetScopeTests.swift`

**Interfaces:**
- Consumes: all types produced by Task 1, `NetworkContext?`, `[NetworkDevice]`, `ToolCard`, and `InfoBanner`.
- Produces: `SSHShortcutLibraryView(context:devices:preferredShortcut:)` and pure `SSHShortcutSearch.filter(_:query:)`.

- [ ] **Step 1: Write the failing search test**

```swift
func testSSHShortcutSearchMatchesTitleSummaryAndCategory() {
  let all = SSHShortcutLibrary.shortcuts
  XCTAssertEqual(SSHShortcutSearch.filter(all, query: "DNS").map(\.id), [.dnsServers, .reverseDNS])
  XCTAssertEqual(SSHShortcutSearch.filter(all, query: "raport").map(\.category), [.reports, .reports])
  XCTAssertEqual(SSHShortcutSearch.filter(all, query: "").count, all.count)
}
```

- [ ] **Step 2: Run the focused build and verify the missing-type failure**

Run the Task 1 build command. Expected: failure for missing `SSHShortcutSearch`.

- [ ] **Step 3: Implement search and the library view**

Create `NetScope/SSHShortcutLibraryView.swift` containing:

```swift
enum SSHShortcutSearch {
  static func filter(_ shortcuts: [SSHShortcut], query: String) -> [SSHShortcut] {
    let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !term.isEmpty else { return shortcuts }
    return shortcuts.filter {
      $0.title.localizedCaseInsensitiveContains(term)
        || $0.summary.localizedCaseInsensitiveContains(term)
        || $0.category.title.localizedCaseInsensitiveContains(term)
    }
  }
}
```

Define the view with:

```swift
struct SSHShortcutLibraryView: View {
  let context: NetworkContext?
  let devices: [NetworkDevice]
  let preferredShortcut: SSHShortcutID?
  @AppStorage("NetScope.sshUsername") private var username = ""
  @AppStorage("NetScope.sshHost") private var host = ""
  @State private var target: String
  @State private var query = ""
  @State private var copiedID: SSHShortcutID?
  @AppStorage("NetScope.nmapCompletedSteps") private var completedSteps = 0
}
```

The screen must contain:

- an `InfoBanner` stating that NetScope only copies commands,
- a collapsed `DisclosureGroup("Jak przygotować iSH i Maca")` with the five spec requirements,
- text fields for username and Mac host plus `Button("Wyczyść dane")`,
- a private-target picker populated from `context.scanRangeDescription` and device addresses,
- grouped shortcut cards filtered with `SSHShortcutSearch`,
- collapsed command text and a `Kopiuj` button for `.command`,
- a lock icon and resolution message for `.blocked`,
- `.searchable(text: $query, prompt: "Nazwa, opis lub kategoria")`.

Copy with `UIPasteboard.general.string = command`; set `copiedID` and announce only `Skopiowano`, never `Wykonano`. Add accessibility labels and hints to fields, disclosure controls, target picker, and copy buttons.

When `preferredShortcut` corresponds to a `NmapGuideStep.shortcutID`, display `Button("Oznacz etap jako wykonany")` beneath that shortcut. Its action is `completedSteps = max(completedSteps, step.rawValue + 1)`; copying alone must never advance progress.

Add the new file to the app target in `project.pbxproj`.

- [ ] **Step 4: Run test build and visually compile all view states**

Run the Task 1 build command. Expected: `TEST BUILD SUCCEEDED`, no SwiftUI generic or accessibility compilation errors.

- [ ] **Step 5: Commit only Task 2 paths**

```bash
git add NetScope/SSHShortcutLibraryView.swift NetScopeTests/NetScopeTests.swift NetScope.xcodeproj/project.pbxproj
git commit -m "feat: add searchable iSH SSH shortcut screen"
```

Expected: signed commit succeeds, otherwise preserve signing policy and report the blocker.

---

### Task 3: Replace duplicated dashboard actions with one entry card

**Files:**
- Modify: `NetScope/DashboardView.swift`

**Interfaces:**
- Consumes: `SSHShortcutLibraryView(context:devices:preferredShortcut:)` from Task 2.
- Produces: one dashboard navigation card titled `iSH + Mac przez SSH`; removes the private `QuickActionButton` type if unused.

- [ ] **Step 1: Add a source-integrity assertion for dashboard copy**

Extend `scripts/test-project-integrity.sh` with exact checks:

```bash
grep -q 'title: "iSH + Mac przez SSH"' "$ROOT/NetScope/DashboardView.swift"
if grep -q 'Text("Szybkie działania")' "$ROOT/NetScope/DashboardView.swift"; then
  echo "Dashboard nadal dubluje dolną nawigację" >&2
  exit 1
fi
```

Run `./scripts/test-project-integrity.sh`. Expected: failure because the new card is absent and old quick actions remain.

- [ ] **Step 2: Replace `quickActions` with one NavigationLink card**

Keep the existing `quickActions` placement in the dashboard stack, but replace its content with:

```swift
NavigationLink {
  SSHShortcutLibraryView(
    context: scanner.context,
    devices: scanner.devices,
    preferredShortcut: nil
  )
} label: {
  ToolCard(
    icon: "terminal.fill",
    title: "iSH + Mac przez SSH",
    subtitle: "Bezpieczne skróty do skopiowania na iPhonie"
  ) {
    HStack {
      Text("Wymaga iSH oraz dostępu SSH do Twojego Maca")
      Spacer()
      Image(systemName: "chevron.right")
    }
    .font(.caption)
    .foregroundStyle(.secondary)
  }
}
.buttonStyle(.plain)
```

Delete `QuickActionButton` only after `rg -n 'QuickActionButton' NetScope` shows no remaining consumers.

- [ ] **Step 3: Run integrity and test build**

Run:

```bash
./scripts/test-project-integrity.sh
xcodebuild -project NetScope.xcodeproj -scheme NetScope \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /private/tmp/NetScopeSSHShortcuts \
  CODE_SIGNING_ALLOWED=NO OTHER_SWIFT_FLAGS=-disable-sandbox build-for-testing
```

Expected: `Integralność bundle: OK` and `TEST BUILD SUCCEEDED`.

- [ ] **Step 4: Commit dashboard and integrity check**

```bash
git add NetScope/DashboardView.swift scripts/test-project-integrity.sh
git commit -m "feat: simplify dashboard SSH entry"
```

---

### Task 4: Link five Nmap stages to matching shortcuts

**Files:**
- Modify: `NetScope/ISHToolkit.swift`
- Modify: `NetScope/ISHToolkitView.swift`
- Test: `NetScopeTests/NetScopeTests.swift`

**Interfaces:**
- Consumes: `SSHShortcutID` from Task 1 and `SSHShortcutLibraryView` from Task 2.
- Produces: `NmapGuideStep.shortcutID: SSHShortcutID` and navigation from each available stage to the matching library shortcut.

- [ ] **Step 1: Write the failing Nmap mapping test**

```swift
func testNmapStepsMapToOrderedSSHShortcuts() {
  XCTAssertEqual(
    NmapGuideStep.allCases.map(\.shortcutID),
    [.discoverHosts, .reverseDNS, .commonPorts, .serviceVersions, .detailedHost]
  )
}
```

- [ ] **Step 2: Run the test build and verify it fails**

Run the Task 1 build command. Expected: failure because `NmapGuideStep.shortcutID` does not exist.

- [ ] **Step 3: Add the mapping and redirect guide navigation**

Add to `NmapGuideStep`:

```swift
var shortcutID: SSHShortcutID {
  switch self {
  case .discovery: .discoverHosts
  case .names: .reverseDNS
  case .commonPorts: .commonPorts
  case .services: .serviceVersions
  case .detailed: .detailedHost
  }
}
```

In `NmapGuideView.stepCard`, replace the destination with:

```swift
SSHShortcutLibraryView(
  context: scanner.context,
  devices: scanner.devices,
  preferredShortcut: step.shortcutID
)
```

The library view scrolls or highlights the preferred card but does not expand command text automatically. Preserve the existing manual stage completion control in the library view for Nmap shortcuts.

- [ ] **Step 4: Run mapping tests and full test build**

Run the Task 1 build command. Expected: `TEST BUILD SUCCEEDED` and the new mapping test compiles.

- [ ] **Step 5: Commit Task 4 paths**

```bash
git add NetScope/ISHToolkit.swift NetScope/ISHToolkitView.swift NetScopeTests/NetScopeTests.swift
git commit -m "feat: connect Nmap stages to SSH shortcuts"
```

---

### Task 5: End-to-end verification and App Store release checks

**Files:**
- Verify only: all modified files

**Interfaces:**
- Consumes: completed Tasks 1–4.
- Produces: evidence that commands are copy-only, existing services remain reachable, tests build/run, and Release bundle remains valid.

- [ ] **Step 1: Verify scope and patch cleanliness**

```bash
git diff --check
git status --short
rg -n 'Szybkie działania|QuickActionButton|Process\(|NSTask|NMSSH|Citadel' NetScope
rg -n 'PortScannerView|DiagnosticsView|ServicesView' NetScope/AppShellView.swift
```

Expected: no whitespace errors; no command-execution/SSH-client APIs; Porty, Ping and Bonjour destinations remain present.

- [ ] **Step 2: Build all tests for the simulator**

```bash
xcodebuild -project NetScope.xcodeproj -scheme NetScope \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /private/tmp/NetScopeSSHFinal \
  CODE_SIGNING_ALLOWED=NO OTHER_SWIFT_FLAGS=-disable-sandbox build-for-testing
```

Expected: `TEST BUILD SUCCEEDED`.

- [ ] **Step 3: Execute tests on iPhone 18 Pro**

In Xcode select scheme `NetScope`, destination `iPhone 18 Pro`, then press Command-U. Expected: all XCTest and Swift Testing cases pass with zero failures. If `CoreSimulatorService` fails again, report execution as unverified; do not convert a build-only result into a passed runtime test.

- [ ] **Step 4: Perform manual simulator walkthrough**

Run the app and verify:

1. Start has one `iSH + Mac przez SSH` card and no duplicate tab shortcuts.
2. Empty username/host blocks Connect with the exact explanation.
3. Valid username/host produces a copyable SSH command.
4. Search `DNS` returns DNS-related shortcuts.
5. Public target is rejected; a private target enables network shortcuts.
6. Command details start collapsed and Copy changes only to `Skopiowano`.
7. Each Nmap stage opens its matching shortcut.
8. Porty, Ping and Bonjour still open from Usługi.

- [ ] **Step 5: Build and validate the Release bundle**

```bash
./scripts/test-project-integrity.sh
```

Expected: Release `BUILD SUCCEEDED`, PrivacyInfo copied into the bundle, store validation completes, and `Integralność bundle: OK`.

- [ ] **Step 6: Record final status without touching unrelated work**

```bash
git status --short
git log -5 --oneline
```

Report separately: implemented behavior, test-build result, executed-test result, Release result, simulator walkthrough, and any GPG/CoreSimulator blocker. Do not stage, revert, or delete unrelated user changes.
