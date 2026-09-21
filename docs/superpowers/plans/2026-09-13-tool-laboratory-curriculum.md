# Tool Laboratory Curriculum Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Zbudować wspólny program laboratoriów z osobnymi pakietami Nmap, Nuclei, Dig i Curl, zachowując trzy darmowe misje oraz odrębny wariant Developer.

**Architecture:** Czysty model `LabProgram` opisuje narzędzie, moduły, lekcje i dostęp, a osobne katalogi dostarczają treść każdego narzędzia. `VirtualLabEngine` obsługuje wyłącznie jawne, deterministyczne scenariusze; SwiftUI tylko renderuje model.

**Tech Stack:** Swift 5, SwiftUI, Combine, Swift Testing, UserDefaults, Xcode iOS 17+

**Spec:** `docs/superpowers/specs/2026-09-13-tool-laboratory-curriculum-design.md`

## Global Constraints

- Pierwszy etap obejmuje dokładnie Nmap, Nuclei, Dig i Curl.
- Demo zachowuje trzy obecne darmowe misje.
- Pro jest przyszłym zakupem niekonsumowalnym; Developer lokalnie odblokowuje wszystko.
- App Store nie pokazuje kopiowania ani wstawiania gotowego rozwiązania.
- Laboratorium nie uruchamia procesu, shella ani prawdziwego połączenia sieciowego.
- Nie zapisujemy haseł, tokenów, kluczy ani wartości sekretnych.
- Każdy commit wymaga osobnej zgody użytkownika.
- Nie instalujemy aplikacji na fizycznym iPhonie.
- Po czterech pakietach uruchamiamy symulator Developer i wykonujemy screenshot.

---

### Task 0: Zamknięcie obecnego Demo

**Files:**
- Review: `NetScope/AppShellView.swift`
- Review: `NetScope/LaboratoryView.swift`
- Review: `NetScope/TerminalLessonView.swift`
- Review: `NetScope/LabMission.swift`
- Review: `NetScope/LabProgressStore.swift`
- Review: `NetScopeTests/LabMissionTests.swift`
- Review: `NetScopeTests/VirtualLabEngineTests.swift`

**Interfaces:**
- Consumes: bieżący niezatwierdzony diff Demo.
- Produces: czysty punkt bazowy z trzema misjami, resetem i prezentacją poleceń.

- [ ] **Step 1: Zinwentaryzuj cały diff, także pliki nieśledzone**

```zsh
git status --short --branch
git diff --stat
git diff -- NetScope NetScopeTests docs/superpowers
```

Expected: tylko znane zmiany Demo; brak sekretów i zmian CipherPath.

- [ ] **Step 2: Uruchom regresję Demo**

```zsh
xcodebuild test -project NetScope.xcodeproj -scheme 'NetScope App Store' \
  -destination 'platform=iOS Simulator,id=0058F185-AD3B-4AE6-83B9-337E482F17F2' \
  -only-testing:NetScopeTests/LabMissionTests \
  -only-testing:NetScopeTests/LabCommandPresentationTests \
  -only-testing:NetScopeTests/VirtualLabEngineTests
git diff --check
```

Expected: 17 testów PASS i brak błędów whitespace.

- [ ] **Step 3: Zatrzymaj się po zgodę na commit**

Proposed commit: `feat: add interactive virtual labs`

---

### Task 1: Wspólny model programu i dostępu

**Files:**
- Create: `NetScope/LabCurriculum.swift`
- Create: `NetScopeTests/LabCurriculumTests.swift`
- Modify: `NetScope.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: `BuildVariant.current`, `LabMission`, `ToolDefinition`.
- Produces: `LabToolID`, `LabAccessTier`, `LabAccessState`, `LabProgram`, `LabModule`, `LabLessonCoverage`, `LabAccessPolicy.canOpen`.

- [ ] **Step 1: Dodaj failing test kolejności i dostępu**

```swift
import Testing
@testable import NetScope

@Suite("Lab curriculum")
struct LabCurriculumTests {
  @Test("First milestone contains four ordered tools")
  func orderedTools() {
    #expect(LabToolID.firstMilestone == [.nmap, .nuclei, .dig, .curl])
  }

  @Test("Developer opens Pro while Demo does not")
  func accessPolicy() {
    #expect(LabAccessPolicy.canOpen(.pro, state: .demo, variant: .developer))
    #expect(!LabAccessPolicy.canOpen(.pro, state: .demo, variant: .appStore))
    #expect(LabAccessPolicy.canOpen(.pro, state: .pro, variant: .appStore))
  }
}
```

- [ ] **Step 2: Uruchom RED**

```zsh
xcodebuild test -project NetScope.xcodeproj -scheme 'NetScope App Store' \
  -destination 'platform=iOS Simulator,id=0058F185-AD3B-4AE6-83B9-337E482F17F2' \
  -only-testing:NetScopeTests/LabCurriculumTests
```

Expected: FAIL, ponieważ typy jeszcze nie istnieją.

- [ ] **Step 3: Dodaj minimalne typy domenowe**

```swift
enum LabToolID: String, CaseIterable, Identifiable, Sendable {
  case nmap, nuclei, dig, curl
  var id: String { rawValue }
  static let firstMilestone: [Self] = [.nmap, .nuclei, .dig, .curl]
}
enum LabAccessTier: Sendable { case demo, pro }
enum LabAccessState: Sendable { case demo, pro }

struct LabLessonCoverage: Equatable, Sendable {
  enum Kind: Equatable, Sendable { case exercise, diagnostic, explanationOnly(String) }
  let optionID: String
  let kind: Kind
}

struct LabModule: Identifiable, Equatable, Sendable {
  let id: String
  let title: String
  let summary: String
  let access: LabAccessTier
  let lessons: [LabMission]
  let coverage: [LabLessonCoverage]
}

struct LabProgram: Identifiable, Equatable, Sendable {
  let id: LabToolID
  let title: String
  let summary: String
  let icon: String
  let modules: [LabModule]
}

enum LabAccessPolicy {
  static func canOpen(_ tier: LabAccessTier, state: LabAccessState, variant: BuildVariant) -> Bool {
    tier == .demo || state == .pro || variant.includesDeveloperTools
  }
}
```

- [ ] **Step 4: Dodaj pliki do targetów i uruchom GREEN w obu schematach**

Expected: `LabCurriculumTests` PASS dla App Store i Developer.

- [ ] **Step 5: Zatrzymaj się po zgodę na commit**

Proposed commit: `feat: add laboratory curriculum model`

---

### Task 2: Menu Nauka i programy narzędziowe

**Files:**
- Modify: `NetScope/LaboratoryView.swift`
- Create: `NetScope/LabProgramView.swift`
- Modify: `NetScopeTests/LabCurriculumTests.swift`
- Modify: `NetScope.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: `[LabProgram]`, `LabProgressStore`, `LabAccessPolicy`.
- Produces: `LaboratorySectionID`, selektor Nauka/Nmap/Nuclei/Dig/Curl i `LabProgramView`.

- [ ] **Step 1: Dodaj failing test nawigacji**

```swift
@Test("Laboratory starts with learning then tool programs")
func navigationOrder() {
  #expect(LaboratorySectionID.navigationOrder == [
    .learning, .tool(.nmap), .tool(.nuclei), .tool(.dig), .tool(.curl),
  ])
}
```

- [ ] **Step 2: Uruchom RED**

Expected: FAIL z brakiem `LaboratorySectionID`.

- [ ] **Step 3: Dodaj selektor i widok programu**

```swift
enum LaboratorySectionID: Hashable {
  case learning
  case tool(LabToolID)
  static let navigationOrder: [Self] = [
    .learning, .tool(.nmap), .tool(.nuclei), .tool(.dig), .tool(.curl),
  ]
}
```

Selektor to poziomy `ScrollView` z kapsułami. „Nauka” pokazuje obecne trzy
misje. Narzędzie pokazuje kartę programu, postęp i moduły. Nie dodawaj
zagnieżdżonego `TabView` ani drugiego wejścia do Toolbox.

- [ ] **Step 4: Dodaj czytelną blokadę Pro**

Zablokowana karta pokazuje `PRO`, zakres i `Dowiedz się o Pro`. Przycisk otwiera
lokalny arkusz opisowy; nie rozpoczyna zakupu ani nie udaje StoreKit.

- [ ] **Step 5: Uruchom testy oraz build obu wariantów**

```zsh
xcodebuild build -project NetScope.xcodeproj -scheme 'NetScope App Store' \
  -destination 'generic/platform=iOS Simulator'
xcodebuild build -project NetScope.xcodeproj -scheme 'NetScope Developer' \
  -destination 'generic/platform=iOS Simulator'
git diff --check
```

- [ ] **Step 6: Zatrzymaj się po zgodę na commit**

Proposed commit: `feat: add tool laboratory navigation`

---

### Task 3: Kompletny program Nmap

**Files:**
- Create: `NetScope/NmapLabProgram.swift`
- Modify: `NetScope/LabMission.swift`
- Modify: `NetScope/VirtualLabEngine.swift`
- Create: `NetScopeTests/NmapLabProgramTests.swift`
- Modify: `NetScope.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: `NmapCatalog.definition`, `LabProgram`, `VirtualLabEngine`.
- Produces: `NmapLabProgram.definition` i pokrycie wszystkich `option.id` Nmap.

- [ ] **Step 1: Dodaj failing test pokrycia i kolejności**

```swift
@Test("Every Nmap option has educational coverage")
func completeCoverage() {
  let covered = Set(NmapLabProgram.definition.modules.flatMap(\.coverage).map(\.optionID))
  let catalog = Set(NmapCatalog.definition.options.map(\.id))
  #expect(covered == catalog)
  #expect(NmapLabProgram.definition.modules.map(\.id) == NmapCatalog.definition.categories.map(\.id))
}
```

- [ ] **Step 2: Uruchom RED**

Expected: FAIL z brakiem `NmapLabProgram`.

- [ ] **Step 3: Zbuduj moduły z kategorii katalogu**

Każdy `ToolCategoryDefinition.id` tworzy `LabModule`. Bezpieczne opcje dostają
`.exercise`, konflikty `.diagnostic`, a opcje zależne od surowych pakietów,
plików, systemu lub uprawnień `.explanationOnly(reason)`. Nie pomijaj żadnego ID.

- [ ] **Step 4: Dodaj praktyczne misje kombinowane**

```text
nmap -sn 192.168.50.0/24
nmap -sT -p 22,80 192.168.50.20
nmap -sT -sV -p 22,80 192.168.50.20
nmap -sT -Pn --open --reason 192.168.50.10
```

Parser ocenia znaczenie, nie identyczny tekst.

- [ ] **Step 5: Uruchom testy Nmap, katalogu i silnika**

Expected: pełne pokrycie oraz istniejące testy PASS.

- [ ] **Step 6: Zatrzymaj się po zgodę na commit**

Proposed commit: `feat: add complete Nmap lab program`

---

### Task 4: Kompletny program Nuclei

**Files:**
- Create: `NetScope/NucleiLabProgram.swift`
- Modify: `NetScope/VirtualLabEngine.swift`
- Create: `NetScopeTests/NucleiLabProgramTests.swift`
- Modify: `NetScope.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: `NucleiCatalog.definition`, wirtualne hosty HTTP.
- Produces: `NucleiLabProgram.definition` i lokalne wyniki kontroli szablonowych.

- [ ] **Step 1: Dodaj failing test pokrycia**

```swift
@Test("Every Nuclei option has educational coverage")
func completeCoverage() {
  let covered = Set(NucleiLabProgram.definition.modules.flatMap(\.coverage).map(\.optionID))
  let catalog = Set(NucleiCatalog.definition.options.map(\.id))
  #expect(covered == catalog)
}
```

- [ ] **Step 2: Dodaj failing test scenariusza**

```swift
@Test("Nuclei scan stays inside the demo network")
func simulatedTemplateScan() {
  let result = VirtualLabEngine(network: .demo).execute(
    "nuclei -u http://web.lab -tags misconfiguration"
  )
  #expect(result.status == .success)
  #expect(result.output.contains("web.lab"))
  #expect(result.output.contains("symulacja"))
}
```

- [ ] **Step 3: Uruchom RED**

Expected: program missing and `nuclei` unsupported.

- [ ] **Step 4: Dodaj moduły i scenariusze**

Zachowaj kolejność kategorii katalogu. Opcje chmury, sekretów, aktualizacji,
plików i zewnętrznych endpointów otrzymują zadania diagnostyczne lub opisowe.
Sekrety nigdy nie trafiają do historii ani `UserDefaults`.

- [ ] **Step 5: Uruchom testy Nuclei, katalogu i silnika**

- [ ] **Step 6: Zatrzymaj się po zgodę na commit**

Proposed commit: `feat: add complete Nuclei lab program`

---

### Task 5: Program Dig

**Files:**
- Create: `NetScope/DigLabProgram.swift`
- Modify: `NetScope/VirtualNetwork.swift`
- Modify: `NetScope/VirtualLabEngine.swift`
- Create: `NetScopeTests/DigLabProgramTests.swift`
- Modify: `NetScope.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: rekordy DNS `VirtualNetwork.demo`.
- Produces: `DigLabProgram.definition` i obsługę A, AAAA, PTR, MX, TXT, NS.

- [ ] **Step 1: Dodaj failing test rekordów**

```swift
@Test(arguments: ["A", "AAAA", "MX", "TXT", "NS"])
func supportedRecordTypes(type: String) {
  let result = VirtualLabEngine(network: .demo).execute("dig web.lab \(type)")
  #expect(result.status == .success)
  #expect(result.output.contains(type))
}
```

- [ ] **Step 2: Dodaj failing test modułów**

```swift
#expect(DigLabProgram.definition.modules.map(\.id) == [
  "records", "server", "output", "troubleshooting",
])
```

- [ ] **Step 3: Dodaj rekordy i parser Dig**

Wynik buduj wyłącznie z danych demo. Zachowaj zgodność `dig -x`.

- [ ] **Step 4: Dodaj program i lekcje**

Każdy typ rekordu ma zadanie; wybór serwera, `+short` i NXDOMAIN mają osobne ćwiczenia.

- [ ] **Step 5: Uruchom testy Dig i silnika**

- [ ] **Step 6: Zatrzymaj się po zgodę na commit**

Proposed commit: `feat: add Dig laboratory program`

---

### Task 6: Program Curl

**Files:**
- Create: `NetScope/CurlLabProgram.swift`
- Modify: `NetScope/VirtualNetwork.swift`
- Modify: `NetScope/VirtualLabEngine.swift`
- Create: `NetScopeTests/CurlLabProgramTests.swift`
- Modify: `NetScope.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: wirtualne endpointy HTTP.
- Produces: `CurlLabProgram.definition`, `VirtualHTTPRequest` i lokalne odpowiedzi.

- [ ] **Step 1: Dodaj failing test żądania**

```swift
@Test("Curl explains method and target")
func categorizedRequest() {
  let result = VirtualLabEngine(network: .demo).execute(
    "curl -X POST -H 'Content-Type: application/json' -d '{\"name\":\"lab\"}' http://api.lab/devices"
  )
  #expect(result.status == .success)
  #expect(result.explanations.map(\.term).contains("POST"))
  #expect(result.explanations.map(\.term).contains("Cel"))
}
```

- [ ] **Step 2: Dodaj failing test redakcji sekretów**

```swift
@Test("Authorization values are never echoed")
func redactsAuthorization() {
  let result = VirtualLabEngine(network: .demo).execute(
    "curl -H 'Authorization: Bearer demo-secret' http://api.lab/profile"
  )
  #expect(!result.output.contains("demo-secret"))
}
```

- [ ] **Step 3: Dodaj endpointy i parser**

Obsłuż `-X`, `-H`, `-d`, `-I`, `-L`, `--max-time`. Authorization, cookies i
dane formularzy oznaczone jako sekretne muszą zostać zredagowane przed
utworzeniem `TerminalEntry`.

- [ ] **Step 4: Dodaj moduły Curl**

Moduły: cel, metoda, nagłówki, ciało, przekierowania, TLS, czas i odpowiedź.

- [ ] **Step 5: Uruchom testy Curl i pełną regresję silnika**

- [ ] **Step 6: Zatrzymaj się po zgodę na commit**

Proposed commit: `feat: add Curl laboratory program`

---

### Task 7: Integracja i screenshot

**Files:**
- Modify: `NetScope/LaboratoryView.swift`
- Modify: `NetScope/LabProgramView.swift`
- Modify: `NetScope/TerminalLessonView.swift`
- Modify: `NetScopeTests/LabCurriculumTests.swift`

**Interfaces:**
- Consumes: cztery kompletne `LabProgram` i `LabProgressStore`.
- Produces: finalne menu etapu i dwa zrzuty z symulatora.

- [ ] **Step 1: Dodaj failing test kompletnego milestone**

```swift
@Test("First milestone registers four complete programs")
func milestonePrograms() {
  let programs = LabProgramCatalog.firstMilestone
  #expect(programs.map(\.id) == [.nmap, .nuclei, .dig, .curl])
  #expect(programs.allSatisfy { !$0.modules.isEmpty })
  #expect(programs.flatMap(\.modules).allSatisfy { !$0.lessons.isEmpty || !$0.coverage.isEmpty })
}
```

- [ ] **Step 2: Uruchom RED**

Expected: FAIL z brakiem `LabProgramCatalog`.

- [ ] **Step 3: Zarejestruj cztery programy**

```swift
enum LabProgramCatalog {
  static let firstMilestone: [LabProgram] = [
    NmapLabProgram.definition,
    NucleiLabProgram.definition,
    DigLabProgram.definition,
    CurlLabProgram.definition,
  ]
}
```

`LaboratoryView` otrzymuje ten katalog przez parametr inicjalizatora, aby testy
mogły wstrzyknąć mniejszy zestaw bez globalnego stanu.

- [ ] **Step 4: Uruchom testy obu wariantów**

Potwierdź, że Developer otwiera cztery programy, a App Store zostawia otwarte
Demo i nie pokazuje działań Developer.

- [ ] **Step 5: Uruchom kontrolę projektu**

```zsh
./scripts/pre-push-check.sh
git diff --check
git status --short --branch
```

- [ ] **Step 6: Uruchom świeży symulator Developer**

Zamknij i uruchom symulator `0058F185-AD3B-4AE6-83B9-337E482F17F2`, zbuduj
schemat `NetScope Developer`, zainstaluj wynik przez `simctl` i uruchom bundle
`pl.krystian.NetScope.dev`. Nie używaj `devicectl device install app`.

- [ ] **Step 7: Wykonaj dwa screenshoty**

```zsh
xcrun simctl io 0058F185-AD3B-4AE6-83B9-337E482F17F2 screenshot \
  /private/tmp/netscope-lab-menu.png
xcrun simctl io 0058F185-AD3B-4AE6-83B9-337E482F17F2 screenshot \
  /private/tmp/netscope-command-anatomy.png
```

Pierwszy pokazuje Nauka/Nmap/Nuclei/Dig/Curl. Drugi pokazuje narzędzie, typ lub
operację, opcje, cel i dane dodatkowe.

- [ ] **Step 8: Pokaż wynik i zatrzymaj się**

Nie commituj integracji, nie pushuj i nie instaluj na iPhonie bez kolejnego polecenia.
