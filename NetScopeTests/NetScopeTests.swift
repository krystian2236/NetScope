import XCTest
import Testing

@testable import NetScope

@Suite("DEV UI references")
struct DevUIReferenceTests {
  @Test("VectorNet labels use stable English technical paths")
  func labelsUseStablePaths() {
    #expect(DevUIReference.start.displayLabel == "[DEV: VECTORNET / START]")
    #expect(DevUIReference.scanner.displayLabel == "[DEV: VECTORNET / START / SCANNER]")
    #expect(DevUIReference.toolboxNmap.displayLabel == "[DEV: VECTORNET / TOOLBOX / NMAP]")
    #expect(DevUIReference.deviceDetail.displayLabel == "[DEV: VECTORNET / DEVICE_DETAIL]")
  }

  @Test("Copy values identify app screen component and SwiftUI view")
  func copyValuesAreAgentReady() {
    #expect(
      DevUIReference.toolboxNmap.uiRef
        == "UIREF app=VectorNet screen=toolbox component=nmap view=ToolLearningView"
    )
    #expect(
      DevUIReference.diagnostics.uiRef
        == "UIREF app=VectorNet screen=services component=diagnostics view=DiagnosticsView"
    )
    #expect(Set(DevUIReference.allCases.map(\.uiRef)).count == DevUIReference.allCases.count)
  }

  @Test("DEV references are enabled only for debug/developer presentation")
  func visibilityIsDeveloperOnly() {
    #expect(DevUIReference.isVisible(isDebugBuild: true))
    #expect(!DevUIReference.isVisible(isDebugBuild: false))
  }
}

@Suite("Session restoration")
struct SessionRestorationTests {
  @Test("Unknown tab falls back to dashboard")
  func unknownTabFallsBackToDashboard() {
    #expect(AppTab.restored(from: 999) == .dashboard)
  }

  @Test("Primary navigation keeps Toolbox in the center")
  func primaryNavigationKeepsToolboxInTheCenter() {
    #expect(AppTab.navigationOrder == [.dashboard, .toolbox, .comingSoon])
    #expect(AppTab.restored(from: 1) == .dashboard)
    #expect(AppTab.restored(from: 2) == .dashboard)
    #expect(AppTab.restored(from: 4) == .dashboard)
  }

  @Test("Shortcut route restores the selected command")
  func shortcutRouteRestoresSelectedCommand() {
    #expect(ISHWorkspaceRoute(rawValue: SSHShortcutID.commonPorts.rawValue)?.shortcutID == .commonPorts)
    #expect(ISHWorkspaceRoute(rawValue: ISHWorkspaceRoute.library.rawValue) == .library)
  }
}

@Suite("Toolbox workflow")
struct ToolboxWorkflowTests {
  @Test("Toolbox exposes Nmap and Nuclei")
  func toolboxExposesBothLearningTools() {
    #expect(ToolboxEntry.allCases == [.reconnaissance, .nuclei])
  }
}

@Suite("Tool command catalog")
struct ToolCommandCatalogTests {
  private let tool = ToolDefinition(
    id: "demo",
    executable: "demo",
    title: "Demo",
    helpVersion: "1.0",
    reviewedAt: "2026-09-12",
    categories: [
      .init(id: "target", title: "Cel", subtitle: "Adres", icon: "scope"),
      .init(id: "output", title: "Wyjście", subtitle: "Format", icon: "text.alignleft"),
    ],
    options: [
      .init(
        id: "target",
        categoryID: "target",
        flags: ["-u", "-target"],
        title: "Cel",
        summary: "Wybiera cel.",
        valueKind: .text(example: "https://example.com"),
        risk: .standard,
        order: 10
      ),
      .init(
        id: "json",
        categoryID: "output",
        flags: ["-j", "-jsonl"],
        title: "JSONL",
        summary: "Włącza JSONL.",
        valueKind: .none,
        risk: .standard,
        order: 20
      ),
    ]
  )

  @Test("Builder orders and quotes selected fragments")
  func builderOrdersAndQuotesSelectedFragments() {
    let selection = ToolSelection(
      selectedOptionIDs: ["json", "target"],
      values: ["target": "https://example.com/a'b"]
    )
    let draft = ToolCommandBuilder.build(tool: tool, selection: selection)

    #expect(draft.command == "demo -u 'https://example.com/a'\"'\"'b' -j")
    #expect(draft.errors.isEmpty)
  }

  @Test("Missing value remains visible and is excluded")
  func missingValueRemainsVisibleAndIsExcluded() {
    let selection = ToolSelection(selectedOptionIDs: ["target", "json"], values: [:])
    let draft = ToolCommandBuilder.build(tool: tool, selection: selection)

    #expect(draft.command == "demo -j")
    #expect(draft.fragments.first { $0.optionID == "target" }?.role == .invalid)
    #expect(draft.errors == ["Uzupełnij wartość dla -u."])
  }

  @Test("Removing an option clears its transient value")
  func removingOptionClearsTransientValue() {
    var selection = ToolSelection(
      selectedOptionIDs: ["target"],
      values: ["target": "https://example.com"]
    )

    selection.toggle(optionID: "target")

    #expect(selection.selectedOptionIDs.isEmpty)
    #expect(selection.values["target"] == nil)
  }

  @Test("Builder supports attached and equals option values")
  func builderSupportsAttachedAndEqualsValues() {
    let tool = ToolDefinition(
      id: "syntax",
      executable: "tool",
      title: "Tool",
      helpVersion: "1",
      reviewedAt: "2026-09-12",
      categories: [.init(id: "options", title: "Opcje", subtitle: "", icon: "gear")],
      options: [
        .init(id: "timing", categoryID: "options", flags: ["-T"], title: "Tempo", summary: "Tempo.", valueKind: .integer(range: 0...5, example: "4"), valuePlacement: .attached, risk: .standard, order: 10),
        .init(id: "script", categoryID: "options", flags: ["--script"], title: "Skrypt", summary: "Skrypt.", valueKind: .text(example: "default"), valuePlacement: .equals, risk: .standard, order: 20),
      ]
    )
    let selection = ToolSelection(
      selectedOptionIDs: ["timing", "script"],
      values: ["timing": "4", "script": "default"]
    )

    #expect(ToolCommandBuilder.build(tool: tool, selection: selection).command == "tool -T4 --script='default'")
  }

  @Test("Conflicting options stay visible but are excluded")
  func conflictingOptionsStayVisibleButAreExcluded() {
    let selection = ToolSelection(
      selectedOptionIDs: ["follow-redirects", "disable-redirects", "target"],
      values: ["target": "https://example.com"]
    )
    let draft = ToolCommandBuilder.build(tool: NucleiCatalog.definition, selection: selection)

    #expect(draft.command == "nuclei -u 'https://example.com'")
    #expect(draft.fragments.filter { $0.role == .invalid }.count == 2)
  }

  @Test("Public target stays copyable and receives a warning")
  func publicTargetStaysCopyableWithWarning() {
    let selection = ToolSelection(
      selectedOptionIDs: ["tcp-connect", "target"],
      values: ["target": "scanme.nmap.org"]
    )
    let draft = ToolCommandBuilder.build(tool: NmapCatalog.definition, selection: selection)

    #expect(draft.command == "nmap -sT 'scanme.nmap.org'")
    #expect(draft.warnings.contains { $0.contains("zgodą właściciela") })
    #expect(draft.fragments.last?.role == .caution)
  }

  @Test("Dependent option is excluded until its base option is selected")
  func dependentOptionNeedsBaseOption() {
    let selection = ToolSelection(
      selectedOptionIDs: ["version-light", "target"],
      values: ["target": "192.168.1.20"]
    )
    let draft = ToolCommandBuilder.build(tool: NmapCatalog.definition, selection: selection)

    #expect(draft.command == "nmap '192.168.1.20'")
    #expect(draft.fragments.first { $0.optionID == "version-light" }?.role == .invalid)
  }

  @Test("Invalid Nmap ports stay visible but are excluded")
  func invalidNmapPortsStayVisibleButAreExcluded() {
    let selection = ToolSelection(
      selectedOptionIDs: ["tcp-connect", "ports", "target"],
      values: ["ports": "22,wrong", "target": "192.168.1.20"]
    )
    let draft = ToolCommandBuilder.build(tool: NmapCatalog.definition, selection: selection)

    #expect(draft.command == "nmap -sT '192.168.1.20'")
    #expect(draft.fragments.first { $0.optionID == "ports" }?.role == .invalid)
  }
}

@Suite("Nuclei catalog")
struct NucleiCatalogTests {
  @Test("Catalog follows Kali help categories")
  func categoriesFollowKaliHelp() {
    #expect(NucleiCatalog.definition.helpVersion == "3.11.1")
    #expect(
      NucleiCatalog.definition.categories.map(\.id)
        == [
          "common", "target", "target-format", "templates", "filtering", "output",
          "configurations", "interactsh", "fuzzing", "uncover", "rate-limit",
          "optimizations", "headless", "debug", "update", "honeypot", "statistics",
          "cloud", "authentication",
        ]
    )
  }

  @Test("Representative aliases and value kinds are preserved")
  func aliasesAndValuesArePreserved() {
    let options = Dictionary(
      uniqueKeysWithValues: NucleiCatalog.definition.options.map { ($0.id, $0) }
    )

    #expect(options["target"]?.flags == ["-u", "-target"])
    #expect(options["severity"]?.flags == ["-s", "-severity"])
    #expect(
      options["rate-limit"]?.valueKind
        == .integer(range: 1...10_000, example: "50")
    )
    #expect(options["interactsh-token"]?.isSecret == true)
  }

  @Test("Advanced network features explain their risk")
  func advancedNetworkFeaturesExplainTheirRisk() {
    for id in ["dast", "uncover", "dashboard", "prompt", "allow-local-file-access"] {
      guard let option = NucleiCatalog.definition.options.first(where: { $0.id == id }) else {
        Issue.record("Brak opcji \(id)")
        continue
      }
      if case .advanced(let reason) = option.risk {
        #expect(!reason.isEmpty)
      } else {
        Issue.record("Opcja \(id) nie ma poziomu zaawansowanego")
      }
    }
  }
}

@Suite("Nmap catalog")
struct NmapCatalogTests {
  @Test("Usage header maps each placeholder to the correct category")
  func usageHeaderMapsPlaceholdersToCategories() {
    #expect(
      NmapCatalog.definition.usageParts
        == [
          .literal("nmap"),
          .category(label: "[Scan Type(s)]", categoryID: "scan"),
          .category(label: "[Options]", categoryID: "discovery"),
          .category(label: "{target specification}", categoryID: "target"),
        ]
    )
  }

  @Test("Catalog emits current discovery flags")
  func currentDiscoveryFlags() {
    let options = Dictionary(
      uniqueKeysWithValues: NmapCatalog.definition.options.map { ($0.id, $0) }
    )

    #expect(options["ping-scan"]?.flags.first == "-sn")
    #expect(options["skip-discovery"]?.flags.first == "-Pn")
    #expect(NmapCatalog.definition.options.flatMap(\.flags).contains("-sP") == false)
    #expect(NmapCatalog.definition.options.flatMap(\.flags).contains("-P0") == false)
  }

  @Test("Existing common command remains unchanged")
  func commonCommandRemainsUnchanged() {
    let selection = ToolSelection(
      selectedOptionIDs: [
        "tcp-connect", "skip-discovery", "open-only", "service-detection", "ports",
        "target",
      ],
      values: ["ports": "22,80", "target": "192.168.1.20"]
    )

    #expect(
      ToolCommandBuilder.build(tool: NmapCatalog.definition, selection: selection).command
        == "nmap -sT -Pn --open -sV -p '22,80' '192.168.1.20'"
    )
  }
}

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

  func testISHTargetValidationRejectsCIDRPrefixesShorterThanPrivateBlock() {
    XCTAssertFalse(ISHTargetValidator.isPrivate("10.0.0.0/7"))
    XCTAssertTrue(ISHTargetValidator.isPrivate("10.0.0.0/8"))
    XCTAssertFalse(ISHTargetValidator.isPrivate("172.16.0.0/11"))
    XCTAssertTrue(ISHTargetValidator.isPrivate("172.16.0.0/12"))
    XCTAssertFalse(ISHTargetValidator.isPrivate("192.168.0.0/15"))
    XCTAssertTrue(ISHTargetValidator.isPrivate("192.168.0.0/16"))
    XCTAssertFalse(ISHTargetValidator.isPrivate("169.254.0.0/15"))
    XCTAssertTrue(ISHTargetValidator.isPrivate("169.254.0.0/16"))
  }

  func testISHTargetValidationRejectsMalformedCIDRSuffixes() {
    XCTAssertFalse(ISHTargetValidator.isPrivate("10.0.0.0/33"))
    XCTAssertFalse(ISHTargetValidator.isPrivate("10.0.0.0/999"))
    XCTAssertFalse(ISHTargetValidator.isPrivate("10.0.0.0/abc"))
    XCTAssertFalse(ISHTargetValidator.isPrivate("10.0.0.0/"))
    XCTAssertFalse(ISHTargetValidator.isPrivate("10.0.0.0/8/16"))
  }

  func testISHTargetValidationHostOnlyRejectsCIDR() {
    XCTAssertTrue(ISHTargetValidator.isPrivateHost("192.168.1.20"))
    XCTAssertFalse(ISHTargetValidator.isPrivateHost("192.168.1.20/24"))
    XCTAssertFalse(ISHTargetValidator.isPrivateHost("192.168.1.0/24"))
    XCTAssertFalse(ISHTargetValidator.isPrivateHost("8.8.8.8"))
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

  func testSSHConnectionBuildsStandardURLForExternalClient() {
    let result = SSHShortcutLibrary.connectionURL(
      context: SSHShortcutContext(username: "krystian", host: "MacBook.local", target: nil)
    )

    XCTAssertEqual(result, URL(string: "ssh://krystian@MacBook.local"))
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

  func testSSHShortcutSearchLimitsResultsToSelectedCategory() {
    let all = SSHShortcutLibrary.shortcuts

    XCTAssertEqual(
      SSHShortcutSearch.filter(all, category: .ports, query: "").map(\.id),
      [.commonPorts, .serviceVersions, .detailedHost]
    )
    XCTAssertEqual(
      SSHShortcutSearch.filter(all, category: .networkInfo, query: "DNS").map(\.id),
      [.dnsServers]
    )
  }

  func testNmapStepsMapToOrderedSSHShortcuts() {
    XCTAssertEqual(
      NmapGuideStep.allCases.map(\.shortcutID),
      [.discoverHosts, .reverseDNS, .commonPorts, .serviceVersions, .detailedHost]
    )
  }

  func testSSHReverseDNSRejectsSubnetTarget() {
    let result = SSHShortcutLibrary.resolve(
      .reverseDNS,
      context: SSHShortcutContext(
        username: "krystian",
        host: "mac.local",
        target: "192.168.1.0/24"
      )
    )

    XCTAssertEqual(result, .blocked("Wybierz pojedynczy prywatny adres (bez podsieci)."))
  }

  func testSSHReverseDNSAcceptsSingleHostTarget() {
    let result = SSHShortcutLibrary.resolve(
      .reverseDNS,
      context: SSHShortcutContext(
        username: "krystian",
        host: "mac.local",
        target: "192.168.1.20"
      )
    )

    XCTAssertEqual(result, .command("dscacheutil -q host -a ip_address '192.168.1.20'"))
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
