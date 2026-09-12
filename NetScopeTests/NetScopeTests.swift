import XCTest
import Testing

@testable import NetScope

final class NetScopeTests: XCTestCase {
  func testPrivateNetworkRecognition() {
    XCTAssertTrue(
      NetworkContext(
        address: "192.168.1.20",
        netmask: "255.255.255.0",
        interfaceName: "en0"
      ).isPrivateOrLinkLocal
    )
    XCTAssertFalse(
      NetworkContext(
        address: "8.8.8.8",
        netmask: "255.255.255.0",
        interfaceName: "en0"
      ).isPrivateOrLinkLocal
    )
  }

  func testLocal24ExcludesCurrentDevice() {
    let context = NetworkContext(
      address: "192.168.4.12",
      netmask: "255.255.255.0",
      interfaceName: "en0"
    )

    XCTAssertEqual(context.hostsInLocal24.count, 253)
    XCTAssertFalse(context.hostsInLocal24.contains("192.168.4.12"))
    XCTAssertTrue(context.hostsInLocal24.contains("192.168.4.1"))
    XCTAssertEqual(context.scanRangeDescription, "192.168.4.0/24")
  }

  func testKnownPortNames() {
    XCTAssertEqual(PortCatalog.name(for: 80), "HTTP")
    XCTAssertEqual(PortCatalog.name(for: 1883), "MQTT")
    XCTAssertEqual(PortCatalog.name(for: 9100), "Drukarka")
  }

  func testTargetNormalization() {
    XCTAssertEqual(
      TargetValidator.normalizedHost("https://example.com/path?q=1"),
      "example.com"
    )
    XCTAssertEqual(
      TargetValidator.normalizedHost("  192.168.1.1  "),
      "192.168.1.1"
    )
    XCTAssertNil(TargetValidator.normalizedHost("not a host"))
  }

  func testPortValidation() {
    XCTAssertEqual(TargetValidator.port("443"), 443)
    XCTAssertNil(TargetValidator.port("0"))
    XCTAssertNil(TargetValidator.port("70000"))
    XCTAssertEqual(
      TargetValidator.customPorts(start: "100", end: "110")?.count,
      11
    )
    XCTAssertEqual(
      TargetValidator.customPorts(start: "1", end: "512")?.count,
      512
    )
    XCTAssertNil(TargetValidator.customPorts(start: "1", end: "513"))
  }

  func testScanProfilesIncreaseCoverage() {
    XCTAssertLessThan(ScanProfile.quick.ports.count, ScanProfile.standard.ports.count)
    XCTAssertLessThan(ScanProfile.standard.ports.count, ScanProfile.extended.ports.count)
  }

  func testDeviceClassificationAndExposure() {
    let printer = NetworkDevice(
      address: "192.168.1.44",
      hostname: "drukarka.local",
      openPorts: [80, 631, 9100],
      lastSeen: Date()
    )
    let remoteDesktop = NetworkDevice(
      address: "192.168.1.55",
      hostname: nil,
      openPorts: [3389],
      lastSeen: Date()
    )

    XCTAssertEqual(printer.kind, .printer)
    XCTAssertEqual(printer.primaryName, "drukarka.local")
    XCTAssertEqual(printer.exposure, .medium)
    XCTAssertEqual(remoteDesktop.kind, .computer)
    XCTAssertEqual(remoteDesktop.exposure, .high)
  }

  func testPortMetadata() {
    XCTAssertTrue(PortCatalog.info(for: 443).isEncrypted)
    XCTAssertFalse(PortCatalog.info(for: 23).isEncrypted)
    XCTAssertEqual(PortCatalog.info(for: 5432).category, "Baza danych")
  }

  func testDeviceProbeTelemetry() {
    let device = NetworkDevice(
      address: "192.168.1.80",
      hostname: nil,
      openPorts: [22, 443],
      lastSeen: Date(),
      portObservations: [
        PortObservation(port: 22, latencyMilliseconds: 12.5),
        PortObservation(port: 443, latencyMilliseconds: 8.2),
      ],
      testedPortCount: 10,
      timedOutPortCount: 3,
      deniedPortCount: 1,
      probeDurationMilliseconds: 640
    )

    XCTAssertEqual(device.closedPortCount, 4)
    XCTAssertEqual(device.latency(for: 443), 8.2)
    XCTAssertEqual(device.testedPortCount, 10)
  }

  func testScanSessionCalculations() {
    let startedAt = Date()
    let details = ScanSessionDetails(
      id: UUID(),
      startedAt: startedAt,
      finishedAt: startedAt.addingTimeInterval(5),
      profile: .quick,
      subnet: "192.168.1.0/24",
      totalHosts: 20,
      portsPerHost: 10,
      completedHosts: 10,
      detectedDevices: 2,
      openPorts: 4,
      timedOutProbes: 10,
      deniedProbes: 2,
      resolvedHostnames: 1
    )

    XCTAssertEqual(details.plannedProbes, 200)
    XCTAssertEqual(details.completedProbes, 100)
    XCTAssertEqual(details.closedProbes, 84)
    XCTAssertEqual(details.progress, 0.5)
    XCTAssertEqual(details.duration, 5, accuracy: 0.01)
  }

  func testScanCompletionReportsLocalNetworkDenial() {
    let phase = ScanCompletion.phase(
      deviceCount: 0,
      completedProbes: 120,
      deniedProbes: 120,
      finishedAt: Date(timeIntervalSince1970: 10)
    )

    XCTAssertEqual(
      phase,
      .failed(
        "Brak dostępu do sieci lokalnej. Włącz go w Ustawieniach iPhone’a: Prywatność i ochrona > Sieć lokalna."
      )
    )
  }

  func testScanCompletionKeepsValidEmptyResult() {
    let finishedAt = Date(timeIntervalSince1970: 20)

    XCTAssertEqual(
      ScanCompletion.phase(
        deviceCount: 0,
        completedProbes: 120,
        deniedProbes: 0,
        finishedAt: finishedAt
      ),
      .finished(finishedAt)
    )
  }

  func testScanStagesHaveStableUserFacingOrder() {
    XCTAssertEqual(
      ScanStage.allCases.map(\.title),
      ["Sieć", "IP i porty", "DNS i usługi", "Wyniki"]
    )
    XCTAssertEqual(ScanStage.network.progress, 0.1)
    XCTAssertEqual(ScanStage.results.progress, 1)
  }

  func testISHTargetValidation() {
    XCTAssertTrue(ISHTargetValidator.isPrivate("192.168.1.0/24"))
    XCTAssertTrue(ISHTargetValidator.isPrivate("172.20.4.5"))
    XCTAssertFalse(ISHTargetValidator.isPrivate("8.8.8.8"))
    XCTAssertFalse(ISHTargetValidator.isPrivate("example.com"))
  }

  func testISHCommandUsesUnprivilegedConnectScan() {
    let command = ISHCommandBuilder.command(
      target: "192.168.1.40",
      mode: .serviceDetails,
      knownPorts: [22, 443]
    )

    XCTAssertTrue(command.contains("--unprivileged"))
    XCTAssertTrue(command.contains("-sT"))
    XCTAssertTrue(command.contains("-Pn"))
    XCTAssertTrue(command.contains("-sV --version-light"))
    XCTAssertTrue(command.contains("'22,443'"))
    XCTAssertFalse(command.contains(" -A "))
  }

  func testNmapGuideUsesFiveOrderedAnalyses() {
    XCTAssertEqual(
      NmapGuideStep.allCases.map(\.title),
      [
        "Wykrywanie urządzeń",
        "Nazwy urządzeń",
        "Najważniejsze porty",
        "Rozpoznawanie usług",
        "Dokładna analiza urządzenia",
      ]
    )
    XCTAssertTrue(NmapGuideStep.discovery.isAvailable(hasDevices: true, completedSteps: 0))
    XCTAssertFalse(NmapGuideStep.names.isAvailable(hasDevices: true, completedSteps: 0))
    XCTAssertTrue(NmapGuideStep.names.isAvailable(hasDevices: true, completedSteps: 1))
    XCTAssertFalse(NmapGuideStep.discovery.isAvailable(hasDevices: false, completedSteps: 5))
  }

  func testSSHShortcutCategoriesFollowWorkflowOrder() {
    XCTAssertEqual(
      SSHShortcutCategory.allCases.map(\.title),
      [
        "Połączenie z Maciem",
        "Informacje o sieci",
        "Wykrywanie urządzeń",
        "DNS i nazwy",
        "Porty i usługi",
        "Raporty",
      ]
    )
  }

  func testSSHLoginRequiresUsernameAndHost() {
    let result = SSHShortcutLibrary.resolve(
      .connect,
      context: SSHShortcutContext(username: "", host: "", target: nil)
    )

    XCTAssertEqual(result, .blocked("Uzupełnij użytkownika i host Maca."))
  }

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
      context: SSHShortcutContext(
        username: "krystian",
        host: "mac.local",
        target: "8.8.8.8"
      )
    )

    XCTAssertEqual(result, .blocked("Wybierz prywatny adres lub podsieć."))
  }

  func testSSHShortcutSearchMatchesTitleSummaryAndCategory() {
    let all = SSHShortcutLibrary.shortcuts

    XCTAssertEqual(
      SSHShortcutSearch.filter(all, query: "DNS").map(\.id),
      [.dnsServers, .reverseDNS]
    )
    XCTAssertEqual(
      SSHShortcutSearch.filter(all, query: "raport").map(\.category),
      [.reports, .reports]
    )
    XCTAssertEqual(SSHShortcutSearch.filter(all, query: "").count, all.count)
  }

  func testNmapStepsMapToOrderedSSHShortcuts() {
    XCTAssertEqual(
      NmapGuideStep.allCases.map(\.shortcutID),
      [.discoverHosts, .reverseDNS, .commonPorts, .serviceVersions, .detailedHost]
    )
  }
}

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

  @Test("Review count includes new and unknown but excludes trusted")
  func reviewCount() {
    let statuses: [DeviceRegistryStatus] = [.new, .unknown, .trusted, .trusted]

    #expect(DeviceRegistryStatus.reviewCount(in: statuses) == 2)
  }
}

@MainActor
@Suite("Known device store")
struct KnownDeviceStoreTests {
  private func temporaryURL() -> URL {
    FileManager.default.temporaryDirectory
      .appending(path: UUID().uuidString)
      .appendingPathExtension("json")
  }

  @Test("Merge inserts unknown device and returns its key as new")
  func mergeInsertsUnknownDevice() {
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
    #expect(inserted == Set([key]))
    #expect(store.records.first?.trustStatus == .unknown)
    #expect(store.records.first?.firstSeen == Date(timeIntervalSince1970: 10))
  }

  @Test("Merge preserves user fields and first seen")
  func mergePreservesUserFields() {
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
  func sameAddressOnAnotherNetwork() {
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

  @Test("Records survive a JSON round trip")
  func persistenceRoundTrip() {
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
      for sibling in siblings ?? []
      where sibling.lastPathComponent.hasPrefix(url.lastPathComponent + ".corrupt-") {
        try? FileManager.default.removeItem(at: sibling)
      }
    }

    let store = KnownDeviceStore(fileURL: url)

    #expect(store.records.isEmpty)
    #expect(store.errorMessage != nil)
  }
}

@MainActor
@Suite("Scanner registry integration")
struct ScannerRegistryIntegrationTests {
  @Test("Completed results merge and expose transient new keys")
  func completedResultsMerge() {
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
    #expect(scanner.newDeviceKeys == Set([key]))
  }

  @Test("Creating a scanner does not mutate the registry")
  func scannerCreationDoesNotMerge() {
    let url = FileManager.default.temporaryDirectory
      .appending(path: UUID().uuidString)
      .appendingPathExtension("json")
    defer { try? FileManager.default.removeItem(at: url) }
    let store = KnownDeviceStore(fileURL: url)

    _ = NetworkScanner(knownDeviceStore: store)

    #expect(store.records.isEmpty)
  }
}
