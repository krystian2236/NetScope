# Toolbox Learning Catalog Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Zbudować wspólny edukacyjny kreator poleceń z kompletnymi katalogami bieżącej pomocy Nmap i Nuclei.

**Architecture:** Każde narzędzie dostarcza statyczny, wersjonowany katalog ToolDefinition. Wspólny ToolCommandBuilder waliduje wybory, porządkuje fragmenty, bezpiecznie cytuje wartości i generuje polskie objaśnienia. Jeden widok SwiftUI renderuje oba katalogi.

**Tech Stack:** Swift 5, SwiftUI, Swift Testing, XCTest, Xcode 27, iOS 17+

**Spec:** docs/superpowers/specs/2026-09-12-toolbox-learning-catalog-design.md

## Global Constraints

- NetScope nie uruchamia Nmap ani Nuclei; wyłącznie buduje i kopiuje polecenia.
- Poprawne opcje ostrzegawcze są kopiowalne; błędne fragmenty są widoczne, ale pomijane w poleceniu.
- Pola sekretów nie używają AppStorage, SceneStorage ani UserDefaults.
- Każda wartość użytkownika jest cytowana pojedynczym cudzysłowem, a apostrof zostaje bezpiecznie zastąpiony.
- Cel publiczny nie jest blokowany, lecz otrzymuje ostrzeżenie o wymaganej zgodzie.
- Minimalny system pozostaje iOS 17.0; bez nowych zależności.
- Każdy etap zaczyna test RED i kończy test GREEN oraz git diff --check.
- Commit, push i instalacja fizyczna wymagają osobnego polecenia użytkownika.

---

### Task 1: Wspólny model katalogu i generator

**Files:**
- Create: NetScope/ToolboxCatalogModel.swift
- Create: NetScope/ToolCommandBuilder.swift
- Modify: NetScope.xcodeproj/project.pbxproj
- Test: NetScopeTests/NetScopeTests.swift

**Interfaces:**
- Produces: ToolRiskLevel, ToolValueKind, ToolOptionDefinition, ToolCategoryDefinition, ToolDefinition, ToolSelection, ToolCommandFragment, ToolCommandDraft.
- Produces: ToolCommandBuilder.build(tool:selection:) -> ToolCommandDraft.
- Consumes: ISHTargetValidator.isPrivate(_:) do oznaczania celu.

- [ ] **Step 1: Write the failing tests**

~~~swift
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
      .init(id: "target", categoryID: "target", flags: ["-u", "-target"], title: "Cel", summary: "Wybiera cel.", valueKind: .text(example: "https://example.com"), risk: .standard, order: 10),
      .init(id: "json", categoryID: "output", flags: ["-j", "-jsonl"], title: "JSONL", summary: "Włącza JSONL.", valueKind: .none, risk: .standard, order: 20),
    ]
  )

  @Test("Builder orders and quotes selected fragments")
  func builderOrdersAndQuotesSelectedFragments() {
    let selection = ToolSelection(selectedOptionIDs: ["json", "target"], values: ["target": "https://example.com/a'b"])
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
  }
}
~~~

- [ ] **Step 2: Run RED**

~~~bash
xcodebuild test -quiet -project NetScope.xcodeproj -scheme NetScope -destination 'platform=iOS Simulator,id=0058F185-AD3B-4AE6-83B9-337E482F17F2' -derivedDataPath /tmp/NetScopeDerivedData CODE_SIGNING_ALLOWED=NO -only-testing:NetScopeTests/ToolCommandCatalogTests
~~~

Expected: FAIL because ToolDefinition and ToolCommandBuilder do not exist.

- [ ] **Step 3: Implement minimal shared types**

ToolValueKind contains none, text, integer(range), duration, path, list, choice(values), secret. ToolRiskLevel contains standard, caution(reason), advanced(reason). ToolOptionDefinition stores id, categoryID, aliases, Polish title/summary, value kind, risk, requirements, dependencies, conflicts and order. ToolSelection stores selected IDs and transient values.

ToolCommandBuilder sorts by order, selects the first alias as canonical, validates required values, integer bounds, durations and choices, detects dependencies/conflicts, and returns ordered fragments, command, explanations, warnings and errors.

- [ ] **Step 4: Add both sources to Xcode**

Add PBXFileReference, PBXBuildFile, NetScope group membership and Sources build-phase entries for both files. Preserve existing entry order.

- [ ] **Step 5: Run GREEN**

Run the Step 2 command, then:

~~~bash
xcrun swiftc -frontend -parse NetScope/ToolboxCatalogModel.swift NetScope/ToolCommandBuilder.swift
git diff --check
~~~

Expected: catalog tests PASS and both checks exit 0.

- [ ] **Step 6: Pause for review**

Show the scoped diff. Commit only after explicit approval, using: feat: add shared toolbox command catalog

---

### Task 2: Kompletny katalog Nuclei 3.11.1

**Files:**
- Create: NetScope/NucleiCatalog.swift
- Modify: NetScope.xcodeproj/project.pbxproj
- Test: NetScopeTests/NetScopeTests.swift

**Interfaces:**
- Consumes shared types from Task 1.
- Produces NucleiCatalog.definition: ToolDefinition.
- Category IDs: common, target, target-format, templates, filtering, output, configurations, interactsh, fuzzing, uncover, rate-limit, optimizations, headless, debug, update, honeypot, statistics, cloud, authentication.

- [ ] **Step 1: Write failing catalog tests**

~~~swift
@Suite("Nuclei catalog")
struct NucleiCatalogTests {
  @Test("Catalog follows Kali help categories")
  func categoriesFollowKaliHelp() {
    #expect(NucleiCatalog.definition.helpVersion == "3.11.1")
    #expect(NucleiCatalog.definition.categories.map(\.id) == [
      "common", "target", "target-format", "templates", "filtering", "output",
      "configurations", "interactsh", "fuzzing", "uncover", "rate-limit",
      "optimizations", "headless", "debug", "update", "honeypot", "statistics",
      "cloud", "authentication",
    ])
  }

  @Test("Representative aliases and value kinds are preserved")
  func aliasesAndValuesArePreserved() {
    let options = Dictionary(uniqueKeysWithValues: NucleiCatalog.definition.options.map { ($0.id, $0) })
    #expect(options["target"]?.flags == ["-u", "-target"])
    #expect(options["severity"]?.flags == ["-s", "-severity"])
    #expect(options["interactsh-token"]?.isSecret == true)
  }
}
~~~

- [ ] **Step 2: Run RED**

Run the Task 1 test command with only-testing:NetScopeTests/NucleiCatalogTests.

Expected: FAIL because NucleiCatalog is missing.

- [ ] **Step 3: Add every option from the Kali nuclei -h block**

Set executable nuclei, helpVersion 3.11.1 and reviewedAt 2026-09-12. Preserve every displayed short and long alias and original category order. Every row receives a Polish title, Polish explanation, exact value kind, example without credentials, risk, requirements and stable order.

Required classifications:
- secret: interactsh-token, client-key, secret-file;
- advanced: prompt, code, allow-local-file-access, attack-type, DAST, DAST server, Uncover, TLS impersonation, HTTP API, Cloud and Authentication;
- caution: reset/update, request-response storage, headers, environment variables, proxy, headless, debug traffic and high concurrency;
- standard: filtering, bounded rate limits, ordinary output, statistics, diagnostics and template listing/validation.

- [ ] **Step 4: Add source to Xcode and run GREEN**

~~~bash
xcodebuild test -quiet -project NetScope.xcodeproj -scheme NetScope -destination 'platform=iOS Simulator,id=0058F185-AD3B-4AE6-83B9-337E482F17F2' -derivedDataPath /tmp/NetScopeDerivedData CODE_SIGNING_ALLOWED=NO -only-testing:NetScopeTests/NucleiCatalogTests
xcrun swiftc -frontend -parse NetScope/NucleiCatalog.swift
git diff --check
~~~

Expected: tests PASS and checks exit 0.

- [ ] **Step 5: Pause for review**

Show the complete catalog diff and confirm no literal secret exists. Commit only after explicit approval, using: feat: add complete Nuclei learning catalog

---

### Task 3: Wspólny widok edukacyjny i wejście Nuclei

**Files:**
- Create: NetScope/ToolLearningView.swift
- Modify: NetScope/ToolboxModel.swift
- Modify: NetScope/ToolboxView.swift
- Modify: NetScope.xcodeproj/project.pbxproj
- Test: NetScopeTests/NetScopeTests.swift

**Interfaces:**
- Consumes ToolDefinition, ToolSelection and ToolCommandBuilder.
- Produces ToolLearningView(tool:initialTarget:).
- Extends ToolboxEntry with nuclei while keeping reconnaissance for Nmap.

- [ ] **Step 1: Write failing behavior tests**

~~~swift
@Test("Toolbox exposes Nmap and Nuclei")
func toolboxExposesBothLearningTools() {
  #expect(ToolboxEntry.allCases == [.reconnaissance, .nuclei])
}

@Test("Removing an option clears its transient value")
func removingOptionClearsTransientValue() {
  var selection = ToolSelection(selectedOptionIDs: ["target"], values: ["target": "https://example.com"])
  selection.toggle(optionID: "target")
  #expect(selection.selectedOptionIDs.isEmpty)
  #expect(selection.values["target"] == nil)
}
~~~

- [ ] **Step 2: Run RED**

Run ToolboxWorkflowTests and ToolCommandCatalogTests.

Expected: FAIL because nuclei and toggle(optionID:) are missing.

- [ ] **Step 3: Implement ToolLearningView**

Use safeAreaInset at the top for the permanently visible syntax, ordered fragment chips, command, copy button and explanation. Render one DisclosureGroup per category. Render choice as Picker, integer with numeric keyboard, other values with TextField, and secret with SecureField plus: NetScope nie zapisuje tej wartości.

Hold all selection state only in @State. Never use a persistence property wrapper in this view.

- [ ] **Step 4: Add Nuclei tile and route**

Tile: Nuclei, icon checkmark.shield, subtitle Buduj kontrole oparte na szablonach.

Route:

~~~swift
ToolLearningView(
  tool: NucleiCatalog.definition,
  initialTarget: scanner.context?.address ?? ""
)
~~~

Keep the current Nmap route until Task 4.

- [ ] **Step 5: Run GREEN and build**

~~~bash
xcodebuild test -quiet -project NetScope.xcodeproj -scheme NetScope -destination 'platform=iOS Simulator,id=0058F185-AD3B-4AE6-83B9-337E482F17F2' -derivedDataPath /tmp/NetScopeDerivedData CODE_SIGNING_ALLOWED=NO -only-testing:NetScopeTests/ToolboxWorkflowTests -only-testing:NetScopeTests/ToolCommandCatalogTests
xcodebuild build -quiet -project NetScope.xcodeproj -scheme NetScope -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/NetScopeDerivedData CODE_SIGNING_ALLOWED=NO
git diff --check
~~~

Expected: tests and build PASS.

- [ ] **Step 6: Pause for review**

Commit only after explicit approval, using: feat: add interactive Nuclei command builder

---

### Task 4: Pełny katalog Nmap i migracja widoku

**Files:**
- Create: NetScope/NmapCatalog.swift
- Modify: NetScope/ToolboxModel.swift
- Modify: NetScope/ToolboxView.swift
- Modify: NetScope.xcodeproj/project.pbxproj
- Test: NetScopeTests/NetScopeTests.swift

**Interfaces:**
- Produces NmapCatalog.definition: ToolDefinition.
- Removes after parity: NmapOptionCategory, NmapOption, NmapOptionSelection, NmapCommandDraft and NmapCommandBuilderView.

- [ ] **Step 1: Write failing parity tests**

~~~swift
@Suite("Nmap catalog")
struct NmapCatalogTests {
  @Test("Catalog emits current discovery flags")
  func currentDiscoveryFlags() {
    let options = Dictionary(uniqueKeysWithValues: NmapCatalog.definition.options.map { ($0.id, $0) })
    #expect(options["ping-scan"]?.flags.first == "-sn")
    #expect(options["skip-discovery"]?.flags.first == "-Pn")
    #expect(NmapCatalog.definition.options.flatMap(\.flags).contains("-sP") == false)
    #expect(NmapCatalog.definition.options.flatMap(\.flags).contains("-P0") == false)
  }

  @Test("Existing common command remains unchanged")
  func commonCommandRemainsUnchanged() {
    let selection = ToolSelection(
      selectedOptionIDs: ["tcp-connect", "skip-discovery", "open-only", "service-detection", "ports", "target"],
      values: ["ports": "22,80", "target": "192.168.1.20"]
    )
    #expect(ToolCommandBuilder.build(tool: NmapCatalog.definition, selection: selection).command == "nmap -sT -Pn --open -sV -p '22,80' '192.168.1.20'")
  }
}
~~~

- [ ] **Step 2: Run RED**

Run only-testing:NetScopeTests/NmapCatalogTests.

Expected: FAIL because NmapCatalog is missing.

- [ ] **Step 3: Implement current Nmap help catalog**

Categories in order: target, host-discovery, scan-techniques, ports, service-version, os-detection, timing, firewall-ids, output, miscellaneous. Add every option from current nmap --help with current canonical spelling and aliases. Historical -sP and -P0 appear only in educational notes for -sn and -Pn and are never generated.

Mark raw packet modes, OS detection, spoofing, decoys, source selection, firewall/IDS and privileged features as caution or advanced with concrete requirements.

- [ ] **Step 4: Switch Nmap to shared view**

~~~swift
ToolLearningView(
  tool: NmapCatalog.definition,
  initialTarget: scanner.context?.scanRangeDescription ?? ""
)
~~~

Remove legacy Nmap model/view only after parity tests pass.

- [ ] **Step 5: Run GREEN**

Run NmapCatalogTests and ToolboxWorkflowTests, followed by git diff --check.

Expected: both suites PASS and the existing common command remains byte-for-byte identical.

- [ ] **Step 6: Pause for review**

Commit only after explicit approval, using: feat: complete Nmap learning catalog

---

### Task 5: Konflikty, ostrzeżenia i sekrety

**Files:**
- Modify: NetScope/ToolCommandBuilder.swift
- Modify: NetScope/ToolLearningView.swift
- Modify: NetScope/NmapCatalog.swift
- Modify: NetScope/NucleiCatalog.swift
- Test: NetScopeTests/NetScopeTests.swift

**Interfaces:**
- Strengthens deterministic errors, warnings, fragments and explanation.

- [ ] **Step 1: Write failing safety tests**

~~~swift
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

@Test("Secret fields are identifiable and transient")
func secretFieldsAreIdentifiableAndTransient() {
  #expect(NucleiCatalog.definition.options.first { $0.id == "interactsh-token" }?.isSecret == true)
}
~~~

- [ ] **Step 2: Run RED**

Run ToolCommandCatalogTests.

Expected: conflicting flags remain in the command or secret identification is absent.

- [ ] **Step 3: Implement deterministic validation**

Mark both sides of a selected conflict invalid. Mark dependent options invalid when requirements are missing. Deduplicate messages while preserving option order. Add one warning per selected caution/advanced option and one warning for a public target.

- [ ] **Step 4: Run GREEN and persistence inspection**

~~~bash
xcodebuild test -quiet -project NetScope.xcodeproj -scheme NetScope -destination 'platform=iOS Simulator,id=0058F185-AD3B-4AE6-83B9-337E482F17F2' -derivedDataPath /tmp/NetScopeDerivedData CODE_SIGNING_ALLOWED=NO -only-testing:NetScopeTests/ToolCommandCatalogTests
rg -n 'AppStorage|SceneStorage|UserDefaults' NetScope/ToolLearningView.swift NetScope/ToolCommandBuilder.swift NetScope/NucleiCatalog.swift
git diff --check
~~~

Expected: tests PASS; rg returns no persistence API; diff check exits 0.

- [ ] **Step 5: Pause for review**

Commit only after explicit approval, using: fix: validate toolbox options and secrets

---

### Task 6: Pełna weryfikacja i simulator

**Files:**
- Verify only. Modify a production file only for a defect proven by a failing test.

- [ ] **Step 1: Parse changed Swift sources**

~~~bash
xcrun swiftc -frontend -parse NetScope/ToolboxCatalogModel.swift NetScope/ToolCommandBuilder.swift NetScope/NucleiCatalog.swift NetScope/NmapCatalog.swift NetScope/ToolLearningView.swift NetScope/ToolboxModel.swift NetScope/ToolboxView.swift NetScopeTests/NetScopeTests.swift
~~~

Expected: exit 0 with no output.

- [ ] **Step 2: Run all tests**

~~~bash
xcodebuild test -quiet -project NetScope.xcodeproj -scheme NetScope -destination 'platform=iOS Simulator,id=0058F185-AD3B-4AE6-83B9-337E482F17F2' -derivedDataPath /tmp/NetScopeDerivedData CODE_SIGNING_ALLOWED=NO
~~~

Expected: TEST SUCCEEDED. Report the actual count from the result bundle.

- [ ] **Step 3: Run repository checks**

~~~bash
git diff --check
./scripts/pre-push-check.sh
git status --short
~~~

Expected: diff and pre-push checks exit 0. Inspect every untracked file separately before a commit.

- [ ] **Step 4: Restart and launch iPhone 17 Simulator**

~~~bash
xcrun simctl shutdown 0058F185-AD3B-4AE6-83B9-337E482F17F2
xcrun simctl boot 0058F185-AD3B-4AE6-83B9-337E482F17F2
xcrun simctl bootstatus 0058F185-AD3B-4AE6-83B9-337E482F17F2 -b
xcrun simctl install 0058F185-AD3B-4AE6-83B9-337E482F17F2 /tmp/NetScopeDerivedData/Build/Products/Debug-iphonesimulator/NetScope.app
xcrun simctl launch 0058F185-AD3B-4AE6-83B9-337E482F17F2 pl.krystian.NetScope
~~~

Expected: installation succeeds and launch returns a process identifier.

- [ ] **Step 5: Manual learning-flow checklist**

1. Toolbox shows exactly Nmap and Nuclei.
2. Both tools show all expected categories in order.
3. Selection and deselection update chips and command.
4. Editors match their value kinds.
5. Errors are red and excluded; warnings are orange and copyable.
6. Every fragment has a Polish explanation.
7. Secret fields use secure entry and disappear after leaving the screen.

- [ ] **Step 6: Stop before consequential actions**

Report changed files, exact test results, pre-push result and simulator evidence. Wait for explicit approval before physical installation, commit or push.
