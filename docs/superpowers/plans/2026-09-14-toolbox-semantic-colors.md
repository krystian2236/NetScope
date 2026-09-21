# Toolbox Semantic Colors Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dodać kolory stanów opcji, ocenę konfliktów oraz automatyczną kolejność fragmentów i celu, zachowując kopiowalność błędnych poleceń.

**Architecture:** Czysty model Swift opisze ton sekcji, fazę argumentu i stan opcji. Osobny evaluator będzie jedynym źródłem konfliktów, zależności i błędów wartości, a builder użyje tego samego wyniku. SwiftUI odwzoruje gotowe stany na kolory i ustawi nieruchome `TB-COMMAND` nad `TB-SYNTAX`.

**Tech Stack:** Swift 6, SwiftUI, Swift Testing, Xcode, iOS Simulator.

**Spec:** `docs/superpowers/specs/2026-09-14-toolbox-semantic-colors-design.md`

## Global Constraints

- Zakres obejmuje tylko NetScope w bieżącym worktree.
- Toolbox buduje i kopiuje tekst; nie wykonuje poleceń ani skanów.
- Błędna opcja pozostaje wybieralna i kopiowalna, lecz jest czerwona i ma konkretny opis.
- Ryzyko jest pomarańczową informacją i nie steruje kolorem poprawności.
- Oznaczenia `TB-*` pozostają tylko w wariancie Developer.
- Wariant App Store nie może zawierać oznaczeń developerskich.
- Nie zmieniać Laboratorium, CipherPath ani projektów Android.
- Nie wykonywać commita ani pushu bez osobnego polecenia użytkownika.
- Instalować wyłącznie `pl.krystian.NetScope.dev` na symulatorze `0058F185-AD3B-4AE6-83B9-337E482F17F2`.

---

### Task 1: Model stanu i evaluator zgodności

**Files:**
- Create: `NetScope/ToolCompatibilityEvaluator.swift`
- Modify: `NetScope/ToolboxCatalogModel.swift:31-77`
- Modify: `NetScope/ToolCommandBuilder.swift:23-148`
- Modify: `NetScope.xcodeproj/project.pbxproj`
- Test: `NetScopeTests/NetScopeTests.swift:147-325`

**Interfaces:**
- Consumes: `ToolDefinition`, `ToolOptionDefinition`, `ToolSelection`.
- Produces: `ToolOptionPresentationState`, `ToolSelectionIssue`, `ToolCompatibilityEvaluator.presentationState(for:in:selection:)` i `ToolCompatibilityEvaluator.issue(for:in:selection:validateValue:)`.

- [ ] **Step 1: Napisać testy stanów przed implementacją**

Dodać do `ToolCommandCatalogTests`:

```swift
@Test("Selected valid option has selected-valid state")
func selectedValidPresentationState() {
  let selection = ToolSelection(selectedOptionIDs: ["tcp-syn"], values: [:])
  let option = NmapCatalog.definition.options.first { $0.id == "tcp-syn" }!
  #expect(ToolCompatibilityEvaluator.presentationState(
    for: option, in: NmapCatalog.definition, selection: selection
  ) == .selectedValid)
}

@Test("SYN conflicts with another TCP technique and FTP bounce")
func nmapTechniqueConflicts() {
  let selection = ToolSelection(selectedOptionIDs: ["tcp-syn"], values: [:])
  func state(_ id: String) -> ToolOptionPresentationState {
    let option = NmapCatalog.definition.options.first { $0.id == id }!
    return ToolCompatibilityEvaluator.presentationState(
      for: option, in: NmapCatalog.definition, selection: selection
    )
  }
  #expect(state("tcp-window").isConflict)
  #expect(state("ftp-bounce").isConflict)
  #expect(state("udp-scan") == .compatible)
}

@Test("Missing dependency and selected missing value are incomplete")
func incompletePresentationStates() {
  let versionLight = NmapCatalog.definition.options.first { $0.id == "version-light" }!
  let ports = NmapCatalog.definition.options.first { $0.id == "ports" }!
  #expect(ToolCompatibilityEvaluator.presentationState(
    for: versionLight,
    in: NmapCatalog.definition,
    selection: ToolSelection(selectedOptionIDs: ["version-light"], values: [:])
  ).isIncomplete)
  #expect(ToolCompatibilityEvaluator.presentationState(
    for: ports,
    in: NmapCatalog.definition,
    selection: ToolSelection(selectedOptionIDs: ["ports"], values: [:])
  ).isIncomplete)
}
```

- [ ] **Step 2: Uruchomić testy i zobaczyć oczekiwany błąd kompilacji**

```bash
xcodebuild -project NetScope.xcodeproj -scheme "NetScope Developer" \
  -destination 'platform=iOS Simulator,id=0058F185-AD3B-4AE6-83B9-337E482F17F2' \
  -derivedDataPath /private/tmp/NetScope-566c-derived \
  -only-testing:NetScopeTests/ToolCommandCatalogTests test
```

Expected: FAIL, bo evaluator i nowe stany jeszcze nie istnieją.

- [ ] **Step 3: Dodać typy modelu**

W `ToolboxCatalogModel.swift` dodać:

```swift
enum ToolSyntaxTone: Equatable, Sendable {
  case scan, options, target, auxiliary
}

enum ToolArgumentPhase: Int, Equatable, Sendable {
  case beforeTarget, target, afterTarget
}

enum ToolOptionPresentationState: Equatable, Sendable {
  case compatible
  case selectedValid
  case conflicting(String)
  case incomplete(String)

  var isConflict: Bool {
    if case .conflicting = self { return true }
    return false
  }

  var isIncomplete: Bool {
    if case .incomplete = self { return true }
    return false
  }
}

enum ToolSelectionIssue: Equatable, Sendable {
  case conflict(String)
  case incomplete(String)

  var message: String {
    switch self {
    case .conflict(let text), .incomplete(let text): text
    }
  }
}
```

Dodać `var tone: ToolSyntaxTone = .options` do `ToolUsageSection` oraz `var argumentPhase: ToolArgumentPhase = .beforeTarget` do `ToolOptionDefinition`. Pozostałe pola i ich dotychczasowe wartości zachować.

- [ ] **Step 4: Zaimplementować evaluator**

W nowym pliku utworzyć:

```swift
enum ToolCompatibilityEvaluator {
  static func presentationState(
    for option: ToolOptionDefinition,
    in tool: ToolDefinition,
    selection: ToolSelection
  ) -> ToolOptionPresentationState

  static func issue(
    for option: ToolOptionDefinition,
    in tool: ToolDefinition,
    selection: ToolSelection,
    validateValue: Bool
  ) -> ToolSelectionIssue?
}
```

Algorytm ma sprawdzać w tej kolejności: jawne konflikty symetryczne, reguły rodzin Nmap, brak `requiresOptionIDs`, brak wartości, format wartości i zakres portów Nmap. Dla opcji niewybranej ma utworzyć wybór kandydujący z dodanym `option.id`, ale nie oznaczać samego pustego pola wartości jako błędu przed dotknięciem opcji.

Rodziny Nmap:

```swift
let tcpBase: Set<String> = [
  "tcp-syn", "tcp-connect", "tcp-ack", "tcp-window", "tcp-maimon",
  "tcp-null", "tcp-fin", "tcp-xmas"
]
let sctp: Set<String> = ["sctp-init", "sctp-cookie"]
let exclusive: Set<String> = ["idle-scan", "ip-protocol-scan", "ftp-bounce"]
```

Reguły: maksymalnie jeden `tcpBase`; maksymalnie jeden SCTP; `udp-scan` może współistnieć z jednym TCP i jednym SCTP; element `exclusive` koliduje z każdą inną opcją kategorii `scan`; `scan-flags` nie jest bazową techniką i może towarzyszyć jednej technice TCP.

- [ ] **Step 5: Podłączyć evaluator do buildera**

Przenieść istniejące `selectionError`, `validNmapPorts` i `validationError` z buildera do evaluatora. W builderze użyć:

```swift
let issue = ToolCompatibilityEvaluator.issue(
  for: option,
  in: tool,
  selection: selection,
  validateValue: true
)
let error = issue?.message
```

Nie filtrować błędnych fragmentów z `command`; nadal otrzymują rolę `.invalid`.

- [ ] **Step 6: Dodać plik do projektu i uruchomić testy**

Dodać `ToolCompatibilityEvaluator.swift` do grupy `NetScope` i fazy `Sources`, według istniejących wpisów `ToolCommandBuilder.swift`. Uruchomić komendę ze Step 2. Expected: cały `ToolCommandCatalogTests` PASS.

- [ ] **Step 7: Punkt kontroli bez commita**

```bash
git diff --check
git diff -- NetScope/ToolboxCatalogModel.swift NetScope/ToolCompatibilityEvaluator.swift NetScope/ToolCommandBuilder.swift NetScopeTests/NetScopeTests.swift NetScope.xcodeproj/project.pbxproj
```

Expected: brak błędów whitespace i brak plików spoza zadania.

---

### Task 2: Automatyczna kolejność fragmentów i celu

**Files:**
- Modify: `NetScope/ToolCommandBuilder.swift:4-65`
- Modify: `NetScope/NmapCatalog.swift:8-198`
- Modify: `NetScope/NucleiCatalog.swift:8-110`
- Modify: `NetScope/DigCatalog.swift:8-50`
- Modify: `NetScope/CurlCatalog.swift:14-65`
- Test: `NetScopeTests/NetScopeTests.swift:183-325`

**Interfaces:**
- Consumes: `ToolOptionDefinition.argumentPhase`.
- Produces: jedną kolejność `argumentPhase.rawValue`, `order`, `id`, wspólną dla `command` i `fragments`.

- [ ] **Step 1: Dodać testy kolejności**

```swift
@Test("Nmap options precede target")
func nmapTargetOrder() {
  let selection = ToolSelection(
    selectedOptionIDs: ["target", "ports", "tcp-connect"],
    values: ["target": "192.168.1.20", "ports": "22"]
  )
  let draft = ToolCommandBuilder.build(tool: NmapCatalog.definition, selection: selection)
  #expect(draft.command == "nmap -sT -p '22' '192.168.1.20'")
  #expect(draft.fragments.map(\.optionID) == [nil, "tcp-connect", "ports", "target"])
}

@Test("Dig server precedes name and type follows name")
func digTargetOrder() {
  let selection = ToolSelection(
    selectedOptionIDs: ["short", "record-type", "target", "server"],
    values: ["server": "router.lab", "target": "web.lab", "record-type": "A"]
  )
  #expect(ToolCommandBuilder.build(tool: DigCatalog.definition, selection: selection).command
    == "dig @router.lab web.lab A +short")
}

@Test("Curl URL follows options")
func curlTargetOrder() {
  let selection = ToolSelection(
    selectedOptionIDs: ["target", "head", "max-time"],
    values: ["target": "http://web.lab/start", "max-time": "5"]
  )
  #expect(ToolCommandBuilder.build(tool: CurlCatalog.definition, selection: selection).command
    == "curl -I --max-time '5' 'http://web.lab/start'")
}
```

- [ ] **Step 2: Uruchomić testy z Task 1 Step 2**

Expected: nowe testy FAIL przed przypisaniem faz.

- [ ] **Step 3: Przypisać fazy katalogów**

- Nmap: `target` = `.target`; pozostałe = `.beforeTarget`.
- Nuclei: wszystkie pozycje, także flagowe `-u/-target`, = `.beforeTarget`, aby zachować kolejność katalogu.
- Dig: `server` = `.beforeTarget`, `target` = `.target`, `record-type` i pozostałe = `.afterTarget`.
- Curl: `target` = `.target`, pozostałe = `.beforeTarget`.

Lokalne funkcje `f` i `v` rozszerzyć o parametr fazy tylko w katalogach, które go przekazują; wartość domyślna ma być `.beforeTarget`.

- [ ] **Step 4: Zmienić sortowanie buildera**

```swift
.sorted { lhs, rhs in
  if lhs.argumentPhase != rhs.argumentPhase {
    return lhs.argumentPhase.rawValue < rhs.argumentPhase.rawValue
  }
  return lhs.order == rhs.order ? lhs.id < rhs.id : lhs.order < rhs.order
}
```

Nie sortować ponownie fragmentów dla widoku; `command` i `[TB-FRAGMENTS]` mają używać tej samej tablicy.

- [ ] **Step 5: Uruchomić testy katalogów**

```bash
xcodebuild -project NetScope.xcodeproj -scheme "NetScope Developer" \
  -destination 'platform=iOS Simulator,id=0058F185-AD3B-4AE6-83B9-337E482F17F2' \
  -derivedDataPath /private/tmp/NetScope-566c-derived \
  -only-testing:NetScopeTests/ToolCommandCatalogTests \
  -only-testing:NetScopeTests/NmapCatalogTests \
  -only-testing:NetScopeTests/NucleiCatalogTests \
  -only-testing:NetScopeTests/DigCatalogTests \
  -only-testing:NetScopeTests/CurlCatalogTests test
```

Expected: wszystkie wskazane zestawy PASS.

- [ ] **Step 6: Punkt kontroli bez commita**

Uruchomić `git diff --check` i obejrzeć diff buildera, czterech katalogów oraz testów.

---

### Task 3: Kolory, pionowe opcje i nieruchomy nagłówek

**Files:**
- Modify: `NetScope/NmapCatalog.swift:8-30`
- Modify: `NetScope/NucleiCatalog.swift:8-25`
- Modify: `NetScope/DigCatalog.swift:8-20`
- Modify: `NetScope/CurlCatalog.swift:14-24`
- Modify: `NetScope/ToolLearningView.swift:29-394`
- Test: `NetScopeTests/NetScopeTests.swift:67-145`

**Interfaces:**
- Consumes: `ToolSyntaxTone`, `ToolOptionPresentationState`, evaluator.
- Produces: mapowania kolorów, `commandPanel`, `syntaxPanel`, przewijane opcje.

- [ ] **Step 1: Dodać testy tonów sekcji**

```swift
@Test("Tool usage sections expose stable tones")
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
```

- [ ] **Step 2: Uruchomić `ToolCatalogBrowserTests` i potwierdzić FAIL**

Użyć polecenia testowego z Task 1 z selektorem `-only-testing:NetScopeTests/ToolCatalogBrowserTests`.

- [ ] **Step 3: Przypisać tony sekcjom**

Ustawić: Nmap `.scan/.options/.target`; Nuclei `.options`; Dig `.auxiliary/.target/.options/.options`; Curl `.options/.target`, w kolejności sekcji istniejącej w każdym katalogu.

- [ ] **Step 4: Ustawić nieruchomy układ**

```swift
.safeAreaInset(edge: .top, spacing: 0) {
  VStack(spacing: 0) {
    commandPanel
    Divider()
    syntaxPanel
  }
  .background(.regularMaterial)
}
```

`commandPanel` zawiera kolejno: `DeveloperSectionTag(.command)`, komendę i kopiowanie, `DeveloperSectionTag(.fragments)`, fragmenty, „Co zrobi” i komunikaty. `syntaxPanel` zawiera `DeveloperSectionTag(.syntax)` oraz `usageHeader`. Usunąć obecną kolejność syntax → fragments → command.

- [ ] **Step 5: Zastosować mapowanie kolorów**

```swift
private func color(for tone: ToolSyntaxTone) -> Color {
  switch tone {
  case .scan: .blue
  case .options: .purple
  case .target: .teal
  case .auxiliary: .indigo
  }
}

private func color(
  for state: ToolOptionPresentationState,
  sectionTone: ToolSyntaxTone
) -> Color {
  switch state {
  case .compatible: color(for: sectionTone)
  case .selectedValid: .green
  case .conflicting, .incomplete: .red
  }
}
```

`usageHeader` używa `section.tone`. `optionRow` pobiera stan tylko z evaluatora. `ToolRiskLevel` nie steruje już kolorem flagi, tła ani ikony wyboru; nadal zasila pomarańczowy `riskLabel`.

- [ ] **Step 6: Ułożyć wiersz opcji pionowo**

```swift
VStack(alignment: .leading, spacing: 4) {
  Text(option.flags.joined(separator: " / "))
    .font(.body.monospaced().weight(.semibold))
  Text(option.title).font(.subheadline.weight(.semibold))
  Text(option.summary)
    .font(.caption)
    .foregroundStyle(.secondary)
}
```

Ikona plus/checkmark pozostaje po prawej. Tekst ze stanu `.conflicting` albo `.incomplete` pojawia się pod opisem na czerwono. Pole wartości pozostaje widoczne dla wybranej opcji również wtedy, gdy wartość jest błędna.

- [ ] **Step 7: Uruchomić pełne testy Developer**

```bash
xcodebuild -project NetScope.xcodeproj -scheme "NetScope Developer" \
  -destination 'platform=iOS Simulator,id=0058F185-AD3B-4AE6-83B9-337E482F17F2' \
  -derivedDataPath /private/tmp/NetScope-566c-derived test
```

Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 8: Punkt kontroli bez commita**

Uruchomić `git diff --check`. Sprawdzić, że panele nie są powielone, a wszystkie etykiety `TB-*` nadal przechodzą przez `DeveloperSectionTag` z warunkiem `NETSCOPE_DEVELOPER_TOOLS`.

---

### Task 4: Końcowa weryfikacja obu wariantów

**Files:**
- Verify: `NetScope/ToolLearningView.swift`
- Verify: `NetScope/ToolCompatibilityEvaluator.swift`
- Verify: `NetScope/ToolCommandBuilder.swift`
- Verify: `NetScope/NmapCatalog.swift`
- Verify: `NetScope/NucleiCatalog.swift`
- Verify: `NetScope/DigCatalog.swift`
- Verify: `NetScope/CurlCatalog.swift`
- Verify: `NetScopeTests/NetScopeTests.swift`

**Interfaces:**
- Consumes: Tasks 1–3.
- Produces: wyniki testów, obu buildów i uruchomioną aplikację Developer; bez commita i pushu.

- [ ] **Step 1: Uruchomić pełne testy na właściwym symulatorze**

```bash
xcrun simctl bootstatus 0058F185-AD3B-4AE6-83B9-337E482F17F2 -b
xcodebuild -project NetScope.xcodeproj -scheme "NetScope Developer" \
  -destination 'platform=iOS Simulator,id=0058F185-AD3B-4AE6-83B9-337E482F17F2' \
  -derivedDataPath /private/tmp/NetScope-566c-derived test
```

Expected: `** TEST SUCCEEDED **`; raport podaje faktyczną liczbę testów.

- [ ] **Step 2: Zbudować wariant App Store bez podpisu**

```bash
xcodebuild -project NetScope.xcodeproj -scheme "NetScope App Store" \
  -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath /private/tmp/NetScope-566c-appstore-derived \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
```

Expected: `** BUILD SUCCEEDED **`; konfiguracja App Store nie zawiera `NETSCOPE_DEVELOPER_TOOLS`.

- [ ] **Step 3: Uruchomić kontrolę przed push bez wykonywania pushu**

```bash
git diff --check
./scripts/pre-push-check.sh
git status --short --branch
```

Expected: `Kontrola przed push: OK`. Status może być brudny z powodu wcześniejszych zatwierdzonych zmian; wymienić ścieżki bez przypisywania ich automatycznie temu etapowi.

- [ ] **Step 4: Zainstalować wyłącznie NetScope Developer**

```bash
xcrun simctl install 0058F185-AD3B-4AE6-83B9-337E482F17F2 \
  /private/tmp/NetScope-566c-derived/Build/Products/Debug-Developer-iphonesimulator/NetScope.app
xcrun simctl launch 0058F185-AD3B-4AE6-83B9-337E482F17F2 pl.krystian.NetScope.dev
```

Expected: polecenie zwraca PID, bez usuwania ani resetowania innych aplikacji.

- [ ] **Step 5: Sprawdzić ręcznie Nmap w Toolbox**

1. `TB-COMMAND` jest nad `TB-SYNTAX`; oba pozostają widoczne podczas przewijania.
2. Scan Type jest niebieski, Options fioletowe, target turkusowy.
3. Po wyborze `-sS`: `-sS` jest zielone, `-sW` i `-b` czerwone, `-sU` ma kolor sekcji.
4. Czerwona opcja nadal daje się dodać, skopiować i pokazuje konkretny konflikt.
5. Ponowne dotknięcie usuwa opcję i jej wartość.
6. Cel trafia automatycznie we właściwe miejsce w komendzie i `TB-FRAGMENTS`.
7. Flaga, nazwa i opis są czytelne przy zwykłym oraz powiększonym tekście.
8. Pomarańczowe ryzyko nie zmienia zielonego lub czerwonego stanu poprawności.

- [ ] **Step 6: Przekazać wynik i zatrzymać się przed Git**

Raport zawiera: zmienione pliki, faktyczną liczbę testów, wyniki obu buildów, wynik `pre-push-check`, PID aplikacji i elementy wymagające oceny wzrokowej. Commit i push dopiero po osobnym poleceniu użytkownika.
