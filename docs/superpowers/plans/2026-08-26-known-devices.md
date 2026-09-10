# Known Devices Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Persist every device from a successful local-network scan on the iPhone and let users assign a custom name and trusted/unknown status.

**Architecture:** A focused `KnownDeviceStore` owns a JSON registry in Application Support and is shared from `AppShellView` with the scanner and views. Scan-derived updates merge into records only after successful completion, while user-managed names and trust states are preserved. Existing scanner and detail screens project current scan devices through matching saved records.

**Tech Stack:** Swift, SwiftUI, Foundation, Observation through the project’s existing `ObservableObject` pattern, Swift Testing, Xcode build system

**Spec:** `docs/superpowers/specs/2026-08-26-known-devices-design.md`

## Global Constraints

- Store registry data only on the device; do not add networking, accounts, analytics, or iCloud.
- Identify a record by local network identifier plus IPv4 address; hostname is metadata only.
- Merge only after a full successful scan; cancelled and failed scans must not update the registry.
- Preserve custom name, trust status, record identifier, and first-seen date during scan merges.
- Treat “new” as transient state for the latest successful scan, not as a persisted trust status.
- Do not describe unknown devices as malicious or as confirmed threats.
- Do not add background scans, notifications, notes, automatic expiry, port-change reporting, or a separate registry screen.
- Keep unrelated working-tree changes intact, especially the existing edits in `NetScope/NetworkToolsModel.swift` and Xcode project metadata.

## File Map

- Create `NetScope/KnownDeviceStore.swift`: record identity, registry persistence, merging, editing, corrupt-file recovery, and storage errors.
- Modify `NetScope/Models.swift`: make `DeviceKind` codable and add display-name projection helpers that do not couple scanner data to SwiftUI.
- Modify `NetScope/NetworkScanner.swift`: inject the shared store, merge successful results, and expose transient new-device keys.
- Modify `NetScope/AppShellView.swift`: create and distribute the shared store and present recoverable persistence errors.
- Modify `NetScope/ScannerView.swift`: project saved metadata into rows, filters, and detail navigation.
- Modify `NetScope/SupportingViews.swift`: status badge and editable “My Device” detail section.
- Modify `NetScope/DashboardView.swift`: show the new/unknown count from the latest scan.
- Modify `NetScope/NetScopeApp.swift` only if the project’s app entry point needs a storage-loading hook after Task 2; otherwise leave it untouched.
- Modify `NetScopeTests/NetScopeTests.swift`: add Swift Testing suites while retaining existing XCTest coverage unchanged.

---

### Task 1: Saved Device Identity and Presentation Model

**Files:**
- Modify: `NetScope/Models.swift`
- Test: `NetScopeTests/NetScopeTests.swift`

**Interfaces:**
- Consumes: existing `NetworkDevice`, `NetworkContext`, and `DeviceKind`.
- Produces: `KnownDeviceKey`, `DeviceTrustStatus`, `KnownDeviceRecord`, and `NetworkDevice.displayName(using:)`.

- [ ] **Step 1: Add failing Swift Testing coverage for identity and display-name priority**

Add `import Testing` next to the existing test imports and append this suite without removing the XCTest class:

```swift
@Suite("Known device model")
struct KnownDeviceModelTests {
  @Test("Identity includes network and address")
  func identityIncludesNetworkAndAddress() {
    let home = KnownDeviceKey(networkID: "192.168.1.0/24", address: "192.168.1.20")
    let office = KnownDeviceKey(networkID: "10.0.0.0/24", address: "192.168.1.20")

    #expect(home != office)
  }

  @Test("Custom name takes priority over DNS and inferred kind")
  func customNameTakesPriority() {
    let device = NetworkDevice(
      address: "192.168.1.44",
      hostname: "printer.local",
      openPorts: [631],
      lastSeen: Date(timeIntervalSince1970: 10)
    )
    let record = KnownDeviceRecord(
      id: UUID(),
      key: KnownDeviceKey(networkID: "192.168.1.0/24", address: device.address),
      hostname: device.hostname,
      customName: "Drukarka w biurze",
      trustStatus: .trusted,
      firstSeen: Date(timeIntervalSince1970: 1),
      lastSeen: Date(timeIntervalSince1970: 10),
      openPorts: device.openPorts,
      kind: device.kind
    )

    #expect(device.displayName(using: record) == "Drukarka w biurze")
  }

  @Test("Blank custom name falls back to DNS")
  func blankNameFallsBackToDNS() {
    let device = NetworkDevice(
      address: "192.168.1.44",
      hostname: "printer.local",
      openPorts: [631],
      lastSeen: Date(timeIntervalSince1970: 10)
    )
    let record = KnownDeviceRecord(
      id: UUID(),
      key: KnownDeviceKey(networkID: "192.168.1.0/24", address: device.address),
      hostname: device.hostname,
      customName: "   ",
      trustStatus: .unknown,
      firstSeen: Date(timeIntervalSince1970: 1),
      lastSeen: Date(timeIntervalSince1970: 10),
      openPorts: device.openPorts,
      kind: device.kind
    )

    #expect(device.displayName(using: record) == "printer.local")
  }
}
```

- [ ] **Step 2: Run the focused tests and confirm the expected compile failure**

Use Xcode’s test runner for the `NetScopeTests` target. Expected: compilation fails because `KnownDeviceKey`, `KnownDeviceRecord`, `DeviceTrustStatus`, and `displayName(using:)` do not exist.

- [ ] **Step 3: Add the minimal Codable value types and display projection**

In `Models.swift`, change `DeviceKind` to conform to `Codable`, then add:

```swift
struct KnownDeviceKey: Codable, Hashable, Sendable {
  let networkID: String
  let address: String
}

enum DeviceTrustStatus: String, Codable, Sendable {
  case trusted
  case unknown
}

struct KnownDeviceRecord: Codable, Identifiable, Equatable, Sendable {
  let id: UUID
  let key: KnownDeviceKey
  var hostname: String?
  var customName: String?
  var trustStatus: DeviceTrustStatus
  let firstSeen: Date
  var lastSeen: Date
  var openPorts: [UInt16]
  var kind: DeviceKind

  var normalizedCustomName: String? {
    guard let customName else { return nil }
    let trimmed = customName.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }
}

extension NetworkDevice {
  func displayName(using record: KnownDeviceRecord?) -> String {
    if let customName = record?.normalizedCustomName {
      return customName
    }
    if let hostname, !hostname.isEmpty, hostname != address {
      return hostname
    }
    return kind.title
  }
}
```

- [ ] **Step 4: Run the focused model suite**

Use Xcode’s test runner for `KnownDeviceModelTests`. Expected: all three tests pass and existing XCTest tests still compile.

- [ ] **Step 5: Refresh Xcode diagnostics for both changed files**

Run `XcodeRefreshCodeIssuesInFile` for `NetScope/NetScope/Models.swift` and `NetScope/NetScopeTests/NetScopeTests.swift`. Expected: no new issues.

- [ ] **Step 6: Commit the model boundary**

```bash
git add NetScope/Models.swift NetScopeTests/NetScopeTests.swift
git commit -m "feat: add known device model"
```

---

### Task 2: Local JSON Registry Store

**Files:**
- Create: `NetScope/KnownDeviceStore.swift`
- Test: `NetScopeTests/NetScopeTests.swift`

**Interfaces:**
- Consumes: `KnownDeviceKey`, `KnownDeviceRecord`, `DeviceTrustStatus`, `NetworkDevice`.
- Produces: `@MainActor final class KnownDeviceStore: ObservableObject` with `records`, `errorMessage`, `record(for:networkID:)`, `merge(devices:networkID:at:)`, `rename(_:customName:)`, `setTrust(_:status:)`, `remove(_:)`, and `clearError()`.

- [ ] **Step 1: Add failing tests for merge semantics and network separation**

Append a MainActor-isolated suite:

```swift
@MainActor
@Suite("Known device store")
struct KnownDeviceStoreTests {
  private func temporaryURL() -> URL {
    FileManager.default.temporaryDirectory
      .appending(path: UUID().uuidString)
      .appendingPathExtension("json")
  }

  @Test("Merge inserts unknown device and returns its key as new")
  func mergeInsertsUnknownDevice() throws {
    let url = temporaryURL()
    defer { try? FileManager.default.removeItem(at: url) }
    let store = KnownDeviceStore(fileURL: url)
    let device = NetworkDevice(
      address: "192.168.1.44",
      hostname: "printer.local",
      openPorts: [631],
      lastSeen: Date(timeIntervalSince1970: 10)
    )

    let inserted = store.merge(
      devices: [device],
      networkID: "192.168.1.0/24",
      at: Date(timeIntervalSince1970: 10)
    )

    let key = KnownDeviceKey(networkID: "192.168.1.0/24", address: device.address)
    #expect(inserted == [key])
    #expect(store.records.first?.trustStatus == .unknown)
    #expect(store.records.first?.firstSeen == Date(timeIntervalSince1970: 10))
  }

  @Test("Merge preserves user fields and first seen")
  func mergePreservesUserFields() throws {
    let url = temporaryURL()
    defer { try? FileManager.default.removeItem(at: url) }
    let store = KnownDeviceStore(fileURL: url)
    let key = KnownDeviceKey(networkID: "192.168.1.0/24", address: "192.168.1.44")
    let first = NetworkDevice(
      address: key.address,
      hostname: "old.local",
      openPorts: [80],
      lastSeen: Date(timeIntervalSince1970: 10)
    )
    store.merge(devices: [first], networkID: key.networkID, at: Date(timeIntervalSince1970: 10))
    store.rename(key, customName: "Salon")
    store.setTrust(key, status: .trusted)

    let updated = NetworkDevice(
      address: key.address,
      hostname: "new.local",
      openPorts: [80, 443],
      lastSeen: Date(timeIntervalSince1970: 20)
    )
    let inserted = store.merge(
      devices: [updated], networkID: key.networkID, at: Date(timeIntervalSince1970: 20)
    )
    let record = store.record(for: updated, networkID: key.networkID)

    #expect(inserted.isEmpty)
    #expect(record?.customName == "Salon")
    #expect(record?.trustStatus == .trusted)
    #expect(record?.firstSeen == Date(timeIntervalSince1970: 10))
    #expect(record?.lastSeen == Date(timeIntervalSince1970: 20))
    #expect(record?.openPorts == [80, 443])
  }

  @Test("Same address on another network creates another record")
  func sameAddressOnAnotherNetwork() throws {
    let url = temporaryURL()
    defer { try? FileManager.default.removeItem(at: url) }
    let store = KnownDeviceStore(fileURL: url)
    let device = NetworkDevice(
      address: "192.168.1.44",
      hostname: nil,
      openPorts: [80],
      lastSeen: Date(timeIntervalSince1970: 10)
    )

    store.merge(devices: [device], networkID: "home", at: Date(timeIntervalSince1970: 10))
    store.merge(devices: [device], networkID: "office", at: Date(timeIntervalSince1970: 20))

    #expect(store.records.count == 2)
  }
}
```

- [ ] **Step 2: Run the store suite and verify failure**

Use Xcode’s test runner for `KnownDeviceStoreTests`. Expected: compilation fails because `KnownDeviceStore` does not exist.

- [ ] **Step 3: Implement the store and atomic persistence**

Create `KnownDeviceStore.swift` with this public surface and behavior:

```swift
import Foundation

@MainActor
final class KnownDeviceStore: ObservableObject {
  @Published private(set) var records: [KnownDeviceRecord] = []
  @Published private(set) var errorMessage: String?

  private let fileURL: URL
  private let fileManager: FileManager

  init(
    fileURL: URL = KnownDeviceStore.defaultFileURL,
    fileManager: FileManager = .default
  ) {
    self.fileURL = fileURL
    self.fileManager = fileManager
    load()
  }

  func record(for device: NetworkDevice, networkID: String) -> KnownDeviceRecord? {
    record(for: KnownDeviceKey(networkID: networkID, address: device.address))
  }

  func record(for key: KnownDeviceKey) -> KnownDeviceRecord? {
    records.first { $0.key == key }
  }

  @discardableResult
  func merge(
    devices: [NetworkDevice],
    networkID: String,
    at date: Date = .now
  ) -> Set<KnownDeviceKey> {
    var inserted: Set<KnownDeviceKey> = []
    for device in devices {
      let key = KnownDeviceKey(networkID: networkID, address: device.address)
      if let index = records.firstIndex(where: { $0.key == key }) {
        records[index].hostname = device.hostname
        records[index].lastSeen = date
        records[index].openPorts = device.openPorts
        records[index].kind = device.kind
      } else {
        records.append(
          KnownDeviceRecord(
            id: UUID(),
            key: key,
            hostname: device.hostname,
            customName: nil,
            trustStatus: .unknown,
            firstSeen: date,
            lastSeen: date,
            openPorts: device.openPorts,
            kind: device.kind
          )
        )
        inserted.insert(key)
      }
    }
    persist()
    return inserted
  }

  func rename(_ key: KnownDeviceKey, customName: String) {
    guard let index = records.firstIndex(where: { $0.key == key }) else { return }
    let trimmed = customName.trimmingCharacters(in: .whitespacesAndNewlines)
    records[index].customName = trimmed.isEmpty ? nil : trimmed
    persist()
  }

  func setTrust(_ key: KnownDeviceKey, status: DeviceTrustStatus) {
    guard let index = records.firstIndex(where: { $0.key == key }) else { return }
    records[index].trustStatus = status
    persist()
  }

  func remove(_ key: KnownDeviceKey) {
    records.removeAll { $0.key == key }
    persist()
  }

  func clearError() {
    errorMessage = nil
  }
}
```

Complete the same file with:

- `defaultFileURL` under Application Support in a `NetScope` subdirectory;
- `load()` using `JSONDecoder`;
- `persist()` creating the parent directory and using `Data.write(to:options: .atomic)`;
- corrupt-file recovery that moves the invalid file to a sibling name containing `.corrupt-<timestamp>` before resetting `records`;
- Polish user-facing error text that says saved-device data could not be loaded or saved without describing unknown devices as threats.

- [ ] **Step 4: Add persistence round-trip and corrupt-file tests**

Add to `KnownDeviceStoreTests`:

```swift
@Test("Records survive a JSON round trip")
func persistenceRoundTrip() throws {
  let url = temporaryURL()
  defer { try? FileManager.default.removeItem(at: url) }
  let device = NetworkDevice(
    address: "192.168.1.20",
    hostname: "mac.local",
    openPorts: [22],
    lastSeen: Date(timeIntervalSince1970: 10)
  )
  let firstStore = KnownDeviceStore(fileURL: url)
  firstStore.merge(devices: [device], networkID: "home", at: Date(timeIntervalSince1970: 10))
  firstStore.rename(KnownDeviceKey(networkID: "home", address: device.address), customName: "Mac")

  let reloaded = KnownDeviceStore(fileURL: url)

  #expect(reloaded.records.count == 1)
  #expect(reloaded.records.first?.customName == "Mac")
}

@Test("Corrupt JSON starts an empty registry and reports recovery")
func corruptJSONRecovery() throws {
  let url = temporaryURL()
  try Data("not-json".utf8).write(to: url)
  defer {
    try? FileManager.default.removeItem(at: url)
    let siblings = try? FileManager.default.contentsOfDirectory(
      at: url.deletingLastPathComponent(),
      includingPropertiesForKeys: nil
    )
    for sibling in siblings ?? [] where sibling.lastPathComponent.hasPrefix(url.lastPathComponent + ".corrupt-") {
      try? FileManager.default.removeItem(at: sibling)
    }
  }

  let store = KnownDeviceStore(fileURL: url)

  #expect(store.records.isEmpty)
  #expect(store.errorMessage != nil)
}
```

- [ ] **Step 5: Run all store tests and refresh diagnostics**

Run `KnownDeviceStoreTests`, then refresh issues for `NetScope/NetScope/KnownDeviceStore.swift` and the test file. Expected: all store tests pass and no new diagnostics appear.

- [ ] **Step 6: Commit the persistence layer**

```bash
git add NetScope/KnownDeviceStore.swift NetScopeTests/NetScopeTests.swift NetScope.xcodeproj/project.pbxproj
git commit -m "feat: persist known devices locally"
```

Include `project.pbxproj` only if Xcode explicitly changes it to add the new Swift source; do not stage other Xcode metadata.

---

### Task 3: Successful-Scan Registry Integration

**Files:**
- Modify: `NetScope/NetworkScanner.swift`
- Modify: `NetScope/AppShellView.swift`
- Test: `NetScopeTests/NetScopeTests.swift`

**Interfaces:**
- Consumes: `KnownDeviceStore.merge(devices:networkID:at:)` and `KnownDeviceKey`.
- Produces: `NetworkScanner.init(knownDeviceStore:)`, `knownDeviceStore`, `newDeviceKeys`, `networkID`, and `completeRegistryMerge(devices:networkID:at:)`.

- [ ] **Step 1: Add failing tests for successful-only merge state**

Append:

```swift
@MainActor
@Suite("Scanner registry integration")
struct ScannerRegistryIntegrationTests {
  @Test("Completed results merge and expose transient new keys")
  func completedResultsMerge() throws {
    let url = FileManager.default.temporaryDirectory
      .appending(path: UUID().uuidString)
      .appendingPathExtension("json")
    defer { try? FileManager.default.removeItem(at: url) }
    let store = KnownDeviceStore(fileURL: url)
    let scanner = NetworkScanner(knownDeviceStore: store)
    let device = NetworkDevice(
      address: "192.168.1.20",
      hostname: nil,
      openPorts: [80],
      lastSeen: Date(timeIntervalSince1970: 10)
    )

    scanner.completeRegistryMerge(
      devices: [device],
      networkID: "192.168.1.0/24",
      at: Date(timeIntervalSince1970: 10)
    )

    let key = KnownDeviceKey(networkID: "192.168.1.0/24", address: device.address)
    #expect(store.records.count == 1)
    #expect(scanner.newDeviceKeys == [key])
  }

  @Test("Creating a scanner does not mutate the registry")
  func scannerCreationDoesNotMerge() throws {
    let url = FileManager.default.temporaryDirectory
      .appending(path: UUID().uuidString)
      .appendingPathExtension("json")
    defer { try? FileManager.default.removeItem(at: url) }
    let store = KnownDeviceStore(fileURL: url)

    _ = NetworkScanner(knownDeviceStore: store)

    #expect(store.records.isEmpty)
  }
}
```

- [ ] **Step 2: Run the integration suite and verify compile failure**

Use Xcode’s test runner for `ScannerRegistryIntegrationTests`. Expected: failure because the injected initializer, `newDeviceKeys`, and `completeRegistryMerge` do not exist.

- [ ] **Step 3: Inject the store and isolate the successful completion hook**

Add to `NetworkScanner`:

```swift
@Published private(set) var newDeviceKeys: Set<KnownDeviceKey> = []
let knownDeviceStore: KnownDeviceStore

init(knownDeviceStore: KnownDeviceStore) {
  self.knownDeviceStore = knownDeviceStore
  loadHistory()
}

var networkID: String? {
  context?.scanRangeDescription
}

func completeRegistryMerge(
  devices: [NetworkDevice],
  networkID: String,
  at date: Date
) {
  newDeviceKeys = knownDeviceStore.merge(
    devices: devices,
    networkID: networkID,
    at: date
  )
}
```

At the beginning of `scan()`, reset `newDeviceKeys = []`. In the existing successful path, after the loop has completed and before setting `.finished`, call:

```swift
completeRegistryMerge(
  devices: devices,
  networkID: context.scanRangeDescription,
  at: finishedAt
)
```

Do not call this helper from missing-context, public-address, cancellation, or failure exits. Keep registry merging after all scan work so partial results are never persisted.

- [ ] **Step 4: Create and distribute the shared store in `AppShellView`**

Replace the scanner’s direct state initialization with an initializer that constructs one store and passes the same instance to the scanner:

```swift
@StateObject private var knownDeviceStore: KnownDeviceStore
@StateObject private var scanner: NetworkScanner

init() {
  let store = KnownDeviceStore()
  _knownDeviceStore = StateObject(wrappedValue: store)
  _scanner = StateObject(wrappedValue: NetworkScanner(knownDeviceStore: store))
}
```

Keep `NetworkToolsModel` and all tab state unchanged. Pass `knownDeviceStore` into `DashboardView` and `ScannerView` using the interfaces introduced in Tasks 4 and 5; temporarily add their parameters without changing presentation if needed to keep the build compiling.

- [ ] **Step 5: Run integration tests and full existing test target**

Run `ScannerRegistryIntegrationTests`, then the entire `NetScopeTests` target. Expected: integration tests and all pre-existing tests pass. Confirm cancellation still exits before the new merge call by inspecting the control flow around the existing `cancellationRequested` branch.

- [ ] **Step 6: Commit scanner integration**

```bash
git add NetScope/NetworkScanner.swift NetScope/AppShellView.swift NetScopeTests/NetScopeTests.swift
git commit -m "feat: remember devices after completed scans"
```

---

### Task 4: Scanner Rows, Status Filter, and Device Editing

**Files:**
- Modify: `NetScope/ScannerView.swift`
- Modify: `NetScope/SupportingViews.swift`
- Test: `NetScopeTests/NetScopeTests.swift`

**Interfaces:**
- Consumes: `KnownDeviceStore`, `KnownDeviceRecord`, `KnownDeviceKey`, `NetworkScanner.networkID`, and `NetworkScanner.newDeviceKeys`.
- Produces: store-aware `ScannerView`, `DeviceRow`, and `DeviceDetailView`; `DeviceRegistryStatus`; filtering for new/unknown records.

- [ ] **Step 1: Add failing model tests for UI status derivation**

Add `DeviceRegistryStatus` tests to `KnownDeviceModelTests`:

```swift
@Test("New status takes priority for current scan")
func newStatusTakesPriority() {
  let key = KnownDeviceKey(networkID: "home", address: "192.168.1.20")
  let record = KnownDeviceRecord(
    id: UUID(),
    key: key,
    hostname: nil,
    customName: nil,
    trustStatus: .trusted,
    firstSeen: .now,
    lastSeen: .now,
    openPorts: [80],
    kind: .unknown
  )

  #expect(DeviceRegistryStatus(record: record, isNew: true) == .new)
  #expect(DeviceRegistryStatus(record: record, isNew: false) == .trusted)
  #expect(DeviceRegistryStatus(record: nil, isNew: false) == .unknown)
}
```

- [ ] **Step 2: Run the focused test and verify failure**

Run `KnownDeviceModelTests`. Expected: compilation fails because `DeviceRegistryStatus` does not exist.

- [ ] **Step 3: Add the presentation status model**

In `Models.swift`, add:

```swift
enum DeviceRegistryStatus: Equatable, Sendable {
  case new
  case trusted
  case unknown

  init(record: KnownDeviceRecord?, isNew: Bool) {
    if isNew {
      self = .new
    } else if record?.trustStatus == .trusted {
      self = .trusted
    } else {
      self = .unknown
    }
  }

  var title: String {
    switch self {
    case .new: "Nowe"
    case .trusted: "Zaufane"
    case .unknown: "Nieznane"
    }
  }
}
```

- [ ] **Step 4: Make scanner filtering and navigation store-aware**

Change `ScannerView` to accept:

```swift
@ObservedObject var scanner: NetworkScanner
@ObservedObject var knownDeviceStore: KnownDeviceStore
```

Add helpers that derive the current `KnownDeviceKey`, matching record, and status from `scanner.networkID`. Extend `DeviceFilter` with `case unknown` and change its matching API to receive `DeviceRegistryStatus`. The filter must include both `.new` and `.unknown`, because both require review. Keep the existing attention, IoT, and infrastructure semantics unchanged.

Pass the matched record, derived status, key, and store into `DeviceRow` and `DeviceDetailView`. If no network context exists, use `nil` record and `.unknown`; do not invent a global network identifier.

- [ ] **Step 5: Add row badges and the editable detail section**

Update `DeviceRow` to accept:

```swift
let device: NetworkDevice
let record: KnownDeviceRecord?
let registryStatus: DeviceRegistryStatus
```

Display `device.displayName(using: record)` and add a compact badge whose labels are exactly “Nowe”, “Zaufane”, and “Nieznane”. Use neutral cyan for new, green for trusted, and orange for unknown; retain the existing exposure badge separately.

Update `DeviceDetailView` to accept `KnownDeviceStore` and an optional `KnownDeviceKey`. Add local draft state initialized from `record?.customName ?? ""`. The “Moje urządzenie” section must:

- show a `TextField("Własna nazwa", text: $customName)`;
- save the trimmed name through `store.rename` on submit;
- show `Toggle("Zaufane urządzenie", isOn:)` backed by `store.setTrust`;
- show first-seen and last-seen values when a record exists;
- show a destructive “Usuń z zapamiętanych” button with a confirmation dialog;
- explain that a forgotten device can be added again by the next completed scan.

Change the navigation title and identity section to use `device.displayName(using: record)`. Do not remove current scan telemetry, service, exposure, export, or iSH functionality.

- [ ] **Step 6: Run model tests and refresh diagnostics for both views**

Run `KnownDeviceModelTests`, then refresh Xcode issues for `ScannerView.swift` and `SupportingViews.swift`. Expected: tests pass and both files have no new diagnostics.

- [ ] **Step 7: Commit scanner UI**

```bash
git add NetScope/Models.swift NetScope/ScannerView.swift NetScope/SupportingViews.swift NetScopeTests/NetScopeTests.swift
git commit -m "feat: manage trusted devices in scanner"
```

---

### Task 5: Dashboard Metric, Storage Errors, Privacy Copy, and Verification

**Files:**
- Modify: `NetScope/DashboardView.swift`
- Modify: `NetScope/AppShellView.swift`
- Modify: `NetScope/SupportingViews.swift`
- Test: `NetScopeTests/NetScopeTests.swift`

**Interfaces:**
- Consumes: shared `KnownDeviceStore`, `NetworkScanner.networkID`, `NetworkScanner.newDeviceKeys`, and `DeviceRegistryStatus`.
- Produces: dashboard new/unknown count, recoverable storage alert, and DHCP identity limitation copy.

- [ ] **Step 1: Add a pure helper test for dashboard review count**

In `NetScopeTests.swift`, add the failing test first to `KnownDeviceModelTests`:

```swift
@Test("Review count includes new and unknown but excludes trusted")
func reviewCount() {
  let statuses: [DeviceRegistryStatus] = [.new, .unknown, .trusted, .trusted]

  #expect(DeviceRegistryStatus.reviewCount(in: statuses) == 2)
}
```

Run `KnownDeviceModelTests`. Expected: compilation fails because `reviewCount(in:)` does not exist. Then implement:

```swift
static func reviewCount(in statuses: [DeviceRegistryStatus]) -> Int {
  statuses.count { $0 == .new || $0 == .unknown }
}
```

Run the suite again. Expected: pass.

- [ ] **Step 2: Replace the dashboard attention tile with the registry review metric**

Make `DashboardView` accept `@ObservedObject var knownDeviceStore: KnownDeviceStore`. Derive statuses only for `scanner.devices` in the current `scanner.networkID`, using `scanner.newDeviceKeys` to distinguish `.new`. Replace the “Do sprawdzenia” tile’s current high-exposure count with the new/unknown count and keep the existing exposure information available in device rows and details.

Use copy that does not imply maliciousness:

```swift
MetricCard(
  title: "Nowe / nieznane",
  value: "\(reviewCount)",
  icon: "questionmark.circle",
  tint: reviewCount > 0 ? .orange : .green
)
```

- [ ] **Step 3: Surface recoverable store errors once**

In `AppShellView`, attach an alert driven by a binding derived from `knownDeviceStore.errorMessage`. The alert title is “Problem z zapamiętanymi urządzeniami”, its message is the store-provided text, and its dismissal calls `knownDeviceStore.clearError()`. Scanning and tab navigation remain usable while the alert is shown.

- [ ] **Step 4: Add the DHCP identity limitation to About**

In the existing “Ograniczenia iOS” section of `AboutView`, add:

```swift
Text(
  "Zapamiętane urządzenia są rozróżniane na podstawie sieci i adresu IP. Po zmianie adresu przez router to samo urządzenie może pojawić się jako nowe."
)
```

Keep the existing MAC/ARP, TCP Ping, and exposure disclaimers.

- [ ] **Step 5: Run live diagnostics on every changed production file**

Run `XcodeRefreshCodeIssuesInFile` for:

- `NetScope/NetScope/Models.swift`
- `NetScope/NetScope/KnownDeviceStore.swift`
- `NetScope/NetScope/NetworkScanner.swift`
- `NetScope/NetScope/AppShellView.swift`
- `NetScope/NetScope/ScannerView.swift`
- `NetScope/NetScope/SupportingViews.swift`
- `NetScope/NetScope/DashboardView.swift`

Expected: no errors and no new warnings caused by the feature.

- [ ] **Step 6: Run the complete test target**

Run the complete `NetScopeTests` target in Xcode. Expected: all legacy XCTest tests and new Swift Testing tests pass.

- [ ] **Step 7: Build the complete project**

Run `BuildProject` with test targets included. Expected: `NetScope.app` and `NetScopeTests.xctest` build successfully.

- [ ] **Step 8: Manually verify the user flow on an iOS simulator or device**

Verify these exact scenarios:

1. A completed scan marks first-time results “Nowe”.
2. Renaming a device changes its scanner row and detail title.
3. Marking it trusted changes the badge to “Zaufane”.
4. Relaunching the app preserves name and trust.
5. A second completed scan updates last-seen without resetting user fields.
6. Removing the record leaves the current scan result visible and allows a later scan to add it again.
7. Cancelling a scan leaves the saved registry unchanged.

- [ ] **Step 9: Commit the completed feature**

```bash
git add NetScope/DashboardView.swift NetScope/AppShellView.swift NetScope/SupportingViews.swift NetScope/Models.swift NetScopeTests/NetScopeTests.swift
git commit -m "feat: surface known device status"
```

- [ ] **Step 10: Confirm clean feature diff without touching unrelated changes**

Run `git status --short` and `git diff --stat HEAD~5..HEAD`. Confirm that commits contain only the known-device feature and its tests. Pre-existing edits in `NetScope/NetworkToolsModel.swift` and unrelated Xcode metadata must remain uncommitted and unmodified by this work.
