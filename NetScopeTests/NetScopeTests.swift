import XCTest
import Testing

@testable import NetScope

@Suite("Session restoration")
struct SessionRestorationTests {
  @Test("Unknown tab falls back to dashboard")
  func unknownTabFallsBackToDashboard() {
    #expect(AppTab.restored(from: 999) == .dashboard)
  }

  @Test("Primary navigation keeps Toolbox in the center")
  func primaryNavigationKeepsToolboxInTheCenter() {
    #expect(AppTab.navigationOrder == [.dashboard, .toolbox, .comingSoon, .cipherPath])
    #expect(AppTab.restored(from: 1) == .dashboard)
    #expect(AppTab.restored(from: 2) == .dashboard)
    #expect(AppTab.restored(from: 4) == .dashboard)
  }

  @Test("Primary tabs map to their Developer identifiers")
  func primaryTabsMapToDeveloperIdentifiers() {
    #expect(AppTab.dashboard.developerAreaID == .navStart)
    #expect(AppTab.toolbox.developerAreaID == .navToolbox)
    #expect(AppTab.comingSoon.developerAreaID == .navLaboratory)
    #expect(AppTab.cipherPath.developerAreaID == .navCipherPath)
  }

  @Test("Shortcut route restores the selected command")
  func shortcutRouteRestoresSelectedCommand() {
    #expect(ISHWorkspaceRoute(rawValue: SSHShortcutID.commonPorts.rawValue)?.shortcutID == .commonPorts)
    #expect(ISHWorkspaceRoute(rawValue: ISHWorkspaceRoute.library.rawValue) == .library)
  }

  @Test("Build variant has one compile-time identity")
  func buildVariantIdentity() {
    #if NETSCOPE_DEVELOPER_TOOLS
    #expect(BuildVariant.current == .developer)
    #expect(BuildVariant.current.includesDeveloperTools)
    #else
    #expect(BuildVariant.current == .appStore)
    #expect(!BuildVariant.current.includesDeveloperTools)
    #endif
  }

  @Test("Try-own-network always starts with quick profile")
  func laboratoryUsesSafeScanProfile() {
    #expect(AppRouteRequest.tryOwnNetwork.recommendedProfile == .quick)
    #expect(AppRouteRequest.tryOwnNetwork.startsAutomatically == false)
  }
}

@Suite("Toolbox workflow")
struct ToolboxWorkflowTests {
  @Test("Toolbox identifiers include their tool name")
  func toolboxIdentifiersIncludeToolName() {
    #expect(DeveloperAreaTool(toolID: "nmap") == .nmap)
    #expect(DeveloperAreaTool(toolID: "unknown") == nil)
    #expect(DeveloperAreaID.toolbox(.nmap, .command).rawValue == "TB-NMAP-COMMAND")
    #expect(DeveloperAreaID.toolbox(.nuclei, .options).rawValue == "TB-NUCLEI-OPTIONS")
    #expect(DeveloperAreaID.toolbox(.dig, .syntax).rawValue == "TB-DIG-SYNTAX")
    #expect(DeveloperAreaID.toolbox(.curl, .messages).rawValue == "TB-CURL-MESSAGES")
    #expect(!DeveloperAreaID.allKnown.map(\.rawValue).contains("TB-COMMAND"))
  }

  @Test("Toolbox follows the laboratory tool order")
  func toolboxFollowsLaboratoryOrder() {
    #expect(ToolboxEntry.allCases == [.nmap, .nuclei, .dig, .curl])
    #expect(ToolboxEntry.allCases.map(\.rawValue) == LabToolID.firstMilestone.map(\.rawValue))
  }

  @Test("Toolbox tiles keep an individual ordered colour identity")
  func toolboxTileColours() {
    #expect(ToolboxEntry.allCases.map(\.tileTone) == [.cyan, .indigo, .teal, .orange])
  }

  @Test("Option details expand independently from command selection")
  func optionDetailsAreIndependent() {
    var disclosure = ToolOptionDisclosureState()
    var selection = ToolSelection()

    disclosure.toggle(optionID: "user")
    #expect(disclosure.isExpanded(optionID: "user"))
    #expect(selection.selectedOptionIDs.isEmpty)

    selection.toggle(optionID: "user")
    #expect(selection.selectedOptionIDs == ["user"])
    #expect(disclosure.isExpanded(optionID: "user"))
  }

  @Test("Category tiles open one command group and toggle it closed")
  func categoryTilesToggleOneGroup() {
    var disclosure = ToolCategoryDisclosureState()

    disclosure.toggle(categoryID: "discovery")
    #expect(disclosure.selectedCategoryID == "discovery")

    disclosure.toggle(categoryID: "ports")
    #expect(disclosure.selectedCategoryID == "ports")

    disclosure.toggle(categoryID: "ports")
    #expect(disclosure.selectedCategoryID == nil)
  }

  @Test("Two-column category rows keep the expanded commands beside their tiles")
  func categoryRowsKeepExpansionLocal() {
    let categories = Array(NucleiCatalog.definition.categories.prefix(5))
    let rows = ToolCategoryLayout.rows(categories, columns: 2)

    #expect(rows.map { $0.categories.map(\.id) } == [
      ["common", "target"],
      ["target-format", "templates"],
      ["filtering"],
    ])
    #expect(rows.first { $0.contains(categoryID: "templates") }?.id == "target-format|templates")
  }

  @Test("Developer favourite target takes priority over detected context")
  func developerFavouriteTargetPriority() {
    #expect(
      ToolboxInitialTarget.resolve(
        storedFavourite: " 192.168.22.36 ",
        detectedTarget: "192.168.1.0/24"
      ) == "192.168.22.36"
    )
    #expect(
      ToolboxInitialTarget.resolve(
        storedFavourite: "   ",
        detectedTarget: "192.168.1.0/24"
      ) == "192.168.1.0/24"
    )
  }

  @Test("Target presets stay ready without entering the command")
  func targetPresetsStartUnselected() {
    let presets = ToolboxPresetValues.targetValues(
      for: NmapCatalog.definition,
      primaryTarget: "192.168.22.36"
    )
    let selection = ToolboxPresetValues.initialSelection(
      for: NmapCatalog.definition,
      presetValues: presets
    )
    let draft = ToolCommandBuilder.build(tool: NmapCatalog.definition, selection: selection)

    #expect(
      presets == [
        "input-list": "gurk-agi-7777.txt",
        "random-targets": "08",
        "exclude": "192.168.22.36",
        "exclude-file": "maet-ysazcurk-7777.txt",
        "target": "192.168.05.10",
      ]
    )
    #expect(selection.selectedOptionIDs.isEmpty)
    #expect(draft.command == "nmap")
    #expect(draft.errors.isEmpty)
  }

  @Test("App defaults contain the approved Easter eggs for every tool")
  func approvedEasterEggDefaults() {
    let nuclei = ToolboxPresetValues.values(for: NucleiCatalog.definition, primaryTarget: "")
    #expect(nuclei["target"] == "https://gurk-naitsyrk-7777.example.test")
    #expect(nuclei["list"] == "gurk-agi-7777.txt")
    #expect(nuclei["targets-inline"] == "192.168.05.10,192.168.22.36")
    #expect(nuclei["exclude-hosts"] == "192.168.22.36")
    #expect(nuclei["resume"] == "7777-0510-2236.cfg")
    #expect(nuclei["ip-version"] == "4")
    #expect(
      ToolboxPresetValues.targetValues(for: DigCatalog.definition, primaryTarget: "")["target"]
        == "maet-ysazcurk-7777.example.test"
    )
    #expect(
      ToolboxPresetValues.targetValues(for: CurlCatalog.definition, primaryTarget: "")["target"]
        == "https://gurk-agi-7777.example.test/0510/2236/7777"
    )
  }

  @Test("Nuclei provides a permanent preset for every value option")
  func nucleiProvidesAllPermanentPresets() {
    let valueOptions = NucleiCatalog.definition.options.filter(\.valueKind.requiresValue)
    let presets = ToolboxPresetValues.values(
      for: NucleiCatalog.definition,
      primaryTarget: ""
    )

    #expect(valueOptions.count == 110)
    #expect(Set(presets.keys) == Set(valueOptions.map(\.id)))
    #expect(presets["prompt"] == "check the security headers")
    #expect(presets["exclude-id"] == "gurk-template-7777")
    #expect(presets["source-ip"] == "192.168.05.10")
    #expect(presets["interactsh-token"] == "fake-token-7777")
    #expect(presets["dast-server-token"] == "fake-token-7777")
    #expect(presets["team-id"] == "maet-ysazcurk")
    #expect(presets["scan-id"] == "7777-2236")
    #expect(presets["scan-name"] == "maet-ysazcurk-7777")
    #expect(presets["secret-file"] == "fictional-secrets.yaml")
  }

  @Test("Nuclei catalog includes the engine update aliases from local help")
  func nucleiIncludesEngineUpdateAliases() {
    let update = NucleiCatalog.definition.options.first { $0.id == "update-engine" }

    #expect(update?.flags == ["-up", "-update"])
    #expect(update?.valueKind == ToolValueKind.none)
  }

  @Test("Every tool provides values for all value-based target options")
  func everyToolProvidesCompleteTargetPresets() {
    for tool in [
      NmapCatalog.definition,
      NucleiCatalog.definition,
      DigCatalog.definition,
      CurlCatalog.definition,
    ] {
      let presets = ToolboxPresetValues.targetValues(for: tool, primaryTarget: "lab.test")
      let targetOptions = ToolboxPresetValues.targetOptions(in: tool)

      #expect(!targetOptions.isEmpty)
      #expect(targetOptions.filter(\.valueKind.requiresValue).allSatisfy {
        !(presets[$0.id] ?? "").isEmpty
      })
    }
  }

  @Test("Removing a preset option keeps its ready value")
  func removingPresetKeepsItsValue() {
    var selection = ToolSelection(values: ["random-targets": "08"])

    selection.toggle(optionID: "random-targets", preservingValue: "08")
    #expect(selection.selectedOptionIDs == ["random-targets"])
    #expect(selection.values["random-targets"] == "08")

    selection.toggle(optionID: "random-targets", preservingValue: "08")
    #expect(selection.selectedOptionIDs.isEmpty)
    #expect(selection.values["random-targets"] == "08")
  }

  @Test("Target guidance explains real terminal placement")
  func targetGuidanceExplainsTerminalPlacement() {
    let inputList = NmapCatalog.definition.options.first { $0.id == "input-list" }!
    let randomTargets = NmapCatalog.definition.options.first { $0.id == "random-targets" }!

    #expect(ToolTerminalGuidance.exampleCommand(for: inputList, executable: "nmap") == "nmap -iL hosts.txt")
    #expect(ToolTerminalGuidance.exampleCommand(for: randomTargets, executable: "nmap") == "nmap -iR 10")
  }
}

@Suite("Developer area identifiers")
struct DeveloperAreaIdentifierTests {
  @Test("Known identifiers are unique and follow the grammar")
  func uniqueAndWellFormed() {
    let values = DeveloperAreaID.allKnown.map(\.rawValue)
    #expect(Set(values).count == values.count)
    #expect(values.allSatisfy {
      $0.range(
        of: #"^[A-Z0-9]+(?:-[A-Z0-9]+)+$"#,
        options: .regularExpression
      ) != nil
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

  @Test("Laboratory navigation identifies its picker and active section")
  func laboratoryNavigationIsSpecific() {
    #expect(DeveloperAreaID.navLabSections.rawValue == "NAV-LAB-SECTIONS")
    #expect(DeveloperAreaID.navLabLearning.rawValue == "NAV-LAB-LEARNING")
    #expect(DeveloperAreaID.navLabTool(.nmap).rawValue == "NAV-LAB-NMAP")
    #expect(DeveloperAreaID.navLabTool(.nuclei).rawValue == "NAV-LAB-NUCLEI")
    #expect(DeveloperAreaID.navLabTool(.dig).rawValue == "NAV-LAB-DIG")
    #expect(DeveloperAreaID.navLabTool(.curl).rawValue == "NAV-LAB-CURL")
  }
}

@Suite("Tool catalog browser")
struct ToolCatalogBrowserTests {
  @Test("Tool usage sections expose stable semantic tones")
  func toolUsageSectionTones() {
    func tones(_ tool: ToolDefinition) -> [ToolSyntaxTone] {
      tool.usageParts.compactMap { part in
        if case .section(let section) = part { return section.tone }
        return nil
      }
    }

    #expect(tones(NmapCatalog.definition) == [.scan, .options, .target])
    #expect(tones(NucleiCatalog.definition) == [.options])
    #expect(tones(DigCatalog.definition) == [.auxiliary, .target, .options, .options])
    #expect(tones(CurlCatalog.definition) == [.options, .target])
  }

  private let tool = ToolDefinition(
    id: "sample",
    executable: "sample",
    title: "Sample",
    helpVersion: "1",
    reviewedAt: "2026-09-13",
    usageParts: [
      .literal("sample"),
      .section(.init(id: "options", label: "[Options]", categoryIDs: ["network", "output"])),
    ],
    categories: [
      .init(id: "network", title: "Sieć", subtitle: "Opcje sieciowe", icon: "network"),
      .init(id: "output", title: "Wynik", subtitle: "Format wyniku", icon: "doc"),
    ],
    options: [
      .init(
        id: "timeout",
        categoryID: "network",
        flags: ["--timeout"],
        title: "Limit czasu",
        summary: "Kończy oczekiwanie po czasie.",
        valueKind: .duration(example: "5s"),
        risk: .standard,
        order: 10,
        isFeatured: true
      ),
      .init(
        id: "verbose",
        categoryID: "output",
        flags: ["-v"],
        title: "Szczegóły",
        summary: "Pokazuje więcej informacji.",
        valueKind: .none,
        risk: .standard,
        order: 20
      ),
    ]
  )

  @Test("Syntax section exposes its categories in catalog order")
  func syntaxSectionExposesItsCategories() {
    #expect(
      ToolCatalogBrowser.categories(in: tool, sectionID: "options").map(\.id)
        == ["network", "output"]
    )
  }

  @Test("Search and featured mode filter real option fields")
  func searchAndFeaturedFilterOptions() {
    #expect(
      ToolCatalogBrowser.options(
        in: tool,
        categoryID: "network",
        query: "TIME",
        featuredOnly: true
      ).map(\.id) == ["timeout"]
    )
    #expect(
      ToolCatalogBrowser.options(
        in: tool,
        categoryID: "output",
        query: "",
        featuredOnly: true
      ).isEmpty
    )
  }

  @Test("Syntax navigation exposes the full selected category by default")
  func syntaxNavigationExposesFullCategoryByDefault() {
    #expect(
      ToolCatalogBrowser.options(
        in: tool,
        categoryID: "output",
        query: ""
      ).map(\.id) == ["verbose"]
    )
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

  @Test("Missing value remains visible and copyable")
  func missingValueRemainsVisibleAndCopyable() {
    let selection = ToolSelection(selectedOptionIDs: ["target", "json"], values: [:])
    let draft = ToolCommandBuilder.build(tool: tool, selection: selection)

    #expect(draft.command == "demo -u '' -j")
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

  @Test("Builder supports positional values without a flag")
  func builderSupportsPositionalValues() {
    let positionalTool = ToolDefinition(
      id: "positional",
      executable: "dig",
      title: "Dig",
      helpVersion: "1",
      reviewedAt: "2026-09-13",
      categories: [.init(id: "name", title: "Nazwa", subtitle: "Cel", icon: "scope")],
      options: [
        .init(
          id: "target",
          categoryID: "name",
          flags: [],
          title: "Nazwa",
          summary: "Wybiera nazwę.",
          valueKind: .text(example: "web.lab"),
          valuePlacement: .positional,
          risk: .standard,
          order: 10
        ),
      ]
    )
    let selection = ToolSelection(
      selectedOptionIDs: ["target"],
      values: ["target": "web.lab"]
    )

    #expect(
      ToolCommandBuilder.build(tool: positionalTool, selection: selection).command
        == "dig web.lab"
    )
  }

  @Test("Conflicting options stay visible and copyable")
  func conflictingOptionsStayVisibleAndCopyable() {
    let selection = ToolSelection(
      selectedOptionIDs: ["follow-redirects", "disable-redirects", "target"],
      values: ["target": "https://example.com"]
    )
    let draft = ToolCommandBuilder.build(tool: NucleiCatalog.definition, selection: selection)

    #expect(draft.command == "nuclei -u 'https://example.com' -fr -dr")
    #expect(draft.fragments.filter { $0.role == .invalid }.count == 2)
    #expect(draft.errors.count == 2)
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

  @Test("Dependent option remains copyable until its base option is selected")
  func dependentOptionNeedsBaseOption() {
    let selection = ToolSelection(
      selectedOptionIDs: ["version-light", "target"],
      values: ["target": "192.168.1.20"]
    )
    let draft = ToolCommandBuilder.build(tool: NmapCatalog.definition, selection: selection)

    #expect(draft.command == "nmap --version-light '192.168.1.20'")
    #expect(draft.fragments.first { $0.optionID == "version-light" }?.role == .invalid)
    #expect(draft.errors == ["Opcja --version-light wymaga: -sV."])
  }

  @Test("Invalid Nmap ports stay visible and copyable")
  func invalidNmapPortsStayVisibleAndCopyable() {
    let selection = ToolSelection(
      selectedOptionIDs: ["tcp-connect", "ports", "target"],
      values: ["ports": "22,wrong", "target": "192.168.1.20"]
    )
    let draft = ToolCommandBuilder.build(tool: NmapCatalog.definition, selection: selection)

    #expect(draft.command == "nmap -sT -p '22,wrong' '192.168.1.20'")
    #expect(draft.fragments.first { $0.optionID == "ports" }?.role == .invalid)
    #expect(draft.errors == ["Nieprawidłowy zakres portów. Użyj np. 22, 22,80,443 albo 1-1024."])
  }

  @Test("Selected valid option has selected-valid state")
  func selectedValidPresentationState() {
    let selection = ToolSelection(selectedOptionIDs: ["tcp-syn"], values: [:])
    let option = NmapCatalog.definition.options.first { $0.id == "tcp-syn" }!

    #expect(
      ToolCompatibilityEvaluator.presentationState(
        for: option,
        in: NmapCatalog.definition,
        selection: selection
      ) == .selectedValid
    )
  }

  @Test("Another TCP technique conflicts with selected SYN")
  func tcpTechniqueConflictsWithSyn() {
    let selection = ToolSelection(selectedOptionIDs: ["tcp-syn"], values: [:])
    let option = NmapCatalog.definition.options.first { $0.id == "tcp-window" }!

    #expect(
      ToolCompatibilityEvaluator.presentationState(
        for: option,
        in: NmapCatalog.definition,
        selection: selection
      ).isConflict
    )
  }

  @Test("FTP bounce conflicts with selected SYN")
  func ftpBounceConflictsWithSyn() {
    let selection = ToolSelection(selectedOptionIDs: ["tcp-syn"], values: [:])
    let option = NmapCatalog.definition.options.first { $0.id == "ftp-bounce" }!

    #expect(
      ToolCompatibilityEvaluator.presentationState(
        for: option,
        in: NmapCatalog.definition,
        selection: selection
      ).isConflict
    )
  }

  @Test("UDP remains compatible with selected SYN")
  func udpRemainsCompatibleWithSyn() {
    let selection = ToolSelection(selectedOptionIDs: ["tcp-syn"], values: [:])
    let option = NmapCatalog.definition.options.first { $0.id == "udp-scan" }!

    #expect(
      ToolCompatibilityEvaluator.presentationState(
        for: option,
        in: NmapCatalog.definition,
        selection: selection
      ) == .compatible
    )
  }

  @Test("Selected dependent option without its base is incomplete")
  func missingDependencyIsIncomplete() {
    let selection = ToolSelection(selectedOptionIDs: ["version-light"], values: [:])
    let option = NmapCatalog.definition.options.first { $0.id == "version-light" }!

    #expect(
      ToolCompatibilityEvaluator.presentationState(
        for: option,
        in: NmapCatalog.definition,
        selection: selection
      ).isIncomplete
    )
  }

  @Test("Selected value option without a value is incomplete")
  func missingValueIsIncomplete() {
    let selection = ToolSelection(selectedOptionIDs: ["ports"], values: [:])
    let option = NmapCatalog.definition.options.first { $0.id == "ports" }!

    #expect(
      ToolCompatibilityEvaluator.presentationState(
        for: option,
        in: NmapCatalog.definition,
        selection: selection
      ).isIncomplete
    )
  }

  @Test("Argument phase takes priority over numeric order")
  func argumentPhasePrecedesNumericOrder() {
    let phasedTool = ToolDefinition(
      id: "phased",
      executable: "tool",
      title: "Tool",
      helpVersion: "1",
      reviewedAt: "2026-09-14",
      categories: [
        .init(id: "options", title: "Opcje", subtitle: "", icon: "gear"),
        .init(id: "target", title: "Cel", subtitle: "", icon: "scope"),
      ],
      options: [
        .init(
          id: "target",
          categoryID: "target",
          flags: [],
          title: "Cel",
          summary: "Wybiera cel.",
          valueKind: .text(example: "host.lab"),
          valuePlacement: .positional,
          risk: .standard,
          order: 1,
          argumentPhase: .target
        ),
        .init(
          id: "verbose",
          categoryID: "options",
          flags: ["-v"],
          title: "Szczegóły",
          summary: "Włącza szczegóły.",
          valueKind: .none,
          risk: .standard,
          order: 999,
          argumentPhase: .beforeTarget
        ),
      ]
    )
    let selection = ToolSelection(
      selectedOptionIDs: ["target", "verbose"],
      values: ["target": "host.lab"]
    )
    let draft = ToolCommandBuilder.build(tool: phasedTool, selection: selection)

    #expect(draft.command == "tool -v host.lab")
    #expect(draft.fragments.map(\.optionID) == [nil, "verbose", "target"])
  }
}

@Suite("Nuclei catalog")
struct NucleiCatalogTests {
  @Test("Usage header exposes every flag category")
  func usageHeaderExposesEveryFlagCategory() {
    #expect(
      NucleiCatalog.definition.usageParts
        == [
          .literal("nuclei"),
          .section(
            .init(
              id: "flags",
              label: "[flags]",
              categoryIDs: [
                "common", "target", "target-format", "templates", "filtering", "output",
                "configurations", "interactsh", "fuzzing", "uncover", "rate-limit",
                "optimizations", "headless", "debug", "update", "honeypot", "statistics",
                "cloud", "authentication",
              ]
            )
          ),
        ]
    )
  }

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
          .section(.init(id: "scan-types", label: "[Scan Type(s)]", categoryIDs: ["scan"], tone: .scan)),
          .section(
            .init(
              id: "options",
              label: "[Options]",
              categoryIDs: [
                "discovery", "ports", "service", "scripts", "os", "timing", "evasion",
                "output", "misc",
              ],
              tone: .options
            )
          ),
          .section(
            .init(
              id: "target-specification",
              label: "{target specification}",
              categoryIDs: ["target"],
              tone: .target
            )
          ),
        ]
    )
    #expect(
      NmapCatalog.definition.options.first { $0.id == "input-list" }?.categoryID == "target"
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

@Suite("Dig catalog")
struct DigCatalogTests {
  @Test("Syntax and common record types follow Dig help")
  func syntaxAndRecordTypes() {
    #expect(
      DigCatalog.definition.usageParts
        == [
          .literal("dig"),
          .section(.init(id: "server", label: "[@server]", categoryIDs: ["server"], tone: .auxiliary)),
          .section(.init(id: "name", label: "{name}", categoryIDs: ["name"], tone: .target)),
          .section(.init(id: "type", label: "[type]", categoryIDs: ["type"], tone: .options)),
          .section(
            .init(
              id: "options",
              label: "[options]",
              categoryIDs: ["query", "output", "behavior"],
              tone: .options
            )
          ),
        ]
    )
    guard case .choice(let values, _) = DigCatalog.definition.options
      .first(where: { $0.id == "record-type" })?.valueKind else {
      Issue.record("Brak wyboru typu rekordu")
      return
    }
    #expect(["A", "AAAA", "PTR", "MX", "TXT", "NS", "SOA", "SRV", "CAA", "ANY"].allSatisfy(values.contains))
  }

  @Test("Builder emits a representative Dig command")
  func representativeCommand() {
    let selection = ToolSelection(
      selectedOptionIDs: ["server", "target", "record-type", "short"],
      values: ["server": "router.lab", "target": "web.lab", "record-type": "A"]
    )
    #expect(
      ToolCommandBuilder.build(tool: DigCatalog.definition, selection: selection).command
        == "dig @router.lab web.lab A +short"
    )
  }
}

@Suite("Curl catalog")
struct CurlCatalogTests {
  @Test("Syntax and help categories follow Curl")
  func syntaxAndCategories() {
    #expect(
      CurlCatalog.definition.usageParts
        == [
          .literal("curl"),
          .section(
            .init(
              id: "options",
              label: "[options]",
              categoryIDs: [
                "auth", "connection", "curl", "dns", "file", "ftp", "http", "imap",
                "misc", "output", "pop3", "post", "proxy", "scp", "sftp", "smtp",
                "ssh", "telnet", "tftp", "tls", "upload", "verbose",
              ],
              tone: .options
            )
          ),
          .section(.init(id: "url", label: "{URL}", categoryIDs: ["url"], tone: .target)),
        ]
    )
  }

  @Test("Builder emits representative HTTP commands")
  func representativeCommands() {
    let post = ToolSelection(
      selectedOptionIDs: ["request", "header", "data", "target"],
      values: [
        "request": "POST", "header": "Content-Type: application/json",
        "data": #"{"name":"lab"}"#, "target": "http://api.lab/devices",
      ]
    )
    #expect(
      ToolCommandBuilder.build(tool: CurlCatalog.definition, selection: post).command
        == #"curl -X 'POST' -H 'Content-Type: application/json' -d '{"name":"lab"}' 'http://api.lab/devices'"#
    )

    let head = ToolSelection(
      selectedOptionIDs: ["head", "location", "max-time", "target"],
      values: ["max-time": "5", "target": "http://web.lab/start"]
    )
    #expect(
      ToolCommandBuilder.build(tool: CurlCatalog.definition, selection: head).command
        == "curl -I -L --max-time '5' 'http://web.lab/start'"
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
