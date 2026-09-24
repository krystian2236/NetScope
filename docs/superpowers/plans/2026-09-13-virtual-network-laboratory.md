# Virtual Network Laboratory Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dodać do Northbyte Radar całkowicie lokalne laboratorium terminalowe z trzema darmowymi lekcjami, bezpiecznym przejściem do skanera własnej sieci i jednorazowym odblokowaniem Northbyte Radar Pro.

**Architecture:** Deterministyczny `VirtualNetwork` i interpreter `VirtualLabEngine` generują wyniki bez uruchamiania shella. Misje, postęp i interfejs terminala są oddzielnymi modułami; istniejący `NetworkScanner` jest używany dopiero po świadomym przejściu użytkownika. StoreKit 2 jest ukryty za `EntitlementStore`, dzięki czemu demo działa także bez sklepu i Internetu.

**Tech Stack:** Swift 5, SwiftUI, Observation/Combine, Swift Testing, XCTest, StoreKit 2, UserDefaults, Xcode iOS 17+

**Spec:** `docs/superpowers/specs/2026-09-13-virtual-network-laboratory-design.md`

## Global Constraints

- Laboratorium nie uruchamia `Process`, shella, pobranego kodu ani prawdziwych połączeń sieciowych.
- Interpreter obsługuje wyłącznie jawnie zdefiniowane polecenia i argumenty.
- Wszystkie dane laboratorium pozostają lokalnie i działają bez Internetu.
- Prawdziwy skan jest osobną czynnością i zachowuje ograniczenie do prywatnych adresów.
- Demo działa bez zakupu, konta oraz usługi chmurowej.
- Pierwsza monetyzacja to jeden niekonsumowalny zakup `Northbyte Radar Pro`, nie subskrypcja.
- Nie zapisujemy haseł, tokenów ani kluczy prywatnych.
- Zachowujemy iOS 17.0 jako minimalną wersję systemu.
- Każdy commit wymaga osobnego, jednoznacznego zatwierdzenia użytkownika.
- Przed każdym zatwierdzonym commitem uruchamiamy właściwe testy i `git diff --check`.

## Struktura plików

- Create: `NetScope/VirtualNetwork.swift` — model i deterministyczna sieć demo.
- Create: `NetScope/VirtualLabEngine.swift` — tokenizacja, walidacja i symulacja poleceń.
- Create: `NetScope/LabMission.swift` — trzy misje oraz ich warunki ukończenia.
- Create: `NetScope/LabProgressStore.swift` — lokalny postęp i przywracanie sesji.
- Create: `NetScope/TerminalLessonView.swift` — terminal, historia, podpowiedzi i objaśnienia.
- Create: `NetScope/LaboratoryView.swift` — lista lekcji, blokady Pro i wejście do terminala.
- Create: `NetScope/EntitlementStore.swift` — stan demo/Pro i StoreKit 2.
- Create: `NetScope/NetScope.storekit` — lokalna konfiguracja produktu testowego.
- Modify: `NetScope/AppShellView.swift` — wejście do laboratorium i przekazanie żądania skanu.
- Modify: `NetScope/ScannerView.swift` — bezpieczny profil przekazany z lekcji.
- Modify: `NetScope.xcodeproj/project.pbxproj` — źródła, testy i StoreKit configuration.
- Modify: `NetScopeTests/NetScopeTests.swift` — testy nawigacji i integracji.
- Create: `NetScopeTests/VirtualNetworkTests.swift` — testy danych sieci.
- Create: `NetScopeTests/VirtualLabEngineTests.swift` — testy interpretera.
- Create: `NetScopeTests/LabMissionTests.swift` — testy misji i postępu.
- Create: `NetScopeTests/EntitlementStoreTests.swift` — testy dostępu demo/Pro.
- Modify: `scripts/test-project-integrity.sh` — kontrola obecności nowych źródeł i produktu.

---

### Task 1: Deterministyczna sieć wirtualna

**Files:**
- Create: `NetScope/VirtualNetwork.swift`
- Create: `NetScopeTests/VirtualNetworkTests.swift`
- Modify: `NetScope.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: wyłącznie typy standardowej biblioteki Swift.
- Produces: `VirtualHost`, `VirtualService`, `VirtualNetwork.demo` oraz metody `host(at:)` i `activeHosts(in:)`.

- [ ] **Step 1: Dodaj test danych sieci**

```swift
import Testing
@testable import NetScope

@Suite("Virtual network")
struct VirtualNetworkTests {
  @Test("Demo network has stable private hosts")
  func stableHosts() {
    let network = VirtualNetwork.demo
    #expect(network.cidr == "192.168.50.0/24")
    #expect(network.activeHosts(in: network.cidr).map(\.address) == [
      "192.168.50.1", "192.168.50.10", "192.168.50.20", "192.168.50.30",
    ])
    #expect(network.host(at: "192.168.50.20")?.services.map(\.port) == [22, 80])
  }
}
```

- [ ] **Step 2: Uruchom test i potwierdź oczekiwaną porażkę**

Run:

```zsh
xcodebuild test -project NetScope.xcodeproj -scheme NetScope \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:NetScopeTests/VirtualNetworkTests CODE_SIGNING_ALLOWED=NO
```

Expected: FAIL, ponieważ `VirtualNetwork` nie istnieje.

- [ ] **Step 3: Dodaj minimalny model i dane demo**

```swift
import Foundation

struct VirtualService: Equatable, Sendable {
  let port: UInt16
  let transport: String
  let name: String
  let version: String?
}

struct VirtualHost: Identifiable, Equatable, Sendable {
  var id: String { address }
  let address: String
  let hostname: String
  let role: String
  let services: [VirtualService]
}

struct VirtualNetwork: Equatable, Sendable {
  let cidr: String
  let hosts: [VirtualHost]

  func host(at address: String) -> VirtualHost? {
    hosts.first { $0.address == address }
  }

  func activeHosts(in cidr: String) -> [VirtualHost] {
    cidr == self.cidr ? hosts : []
  }

  static let demo = VirtualNetwork(cidr: "192.168.50.0/24", hosts: [
    .init(address: "192.168.50.1", hostname: "router.lab", role: "Router", services: [
      .init(port: 53, transport: "tcp", name: "domain", version: nil),
      .init(port: 443, transport: "tcp", name: "https", version: nil),
    ]),
    .init(address: "192.168.50.10", hostname: "mac.lab", role: "Mac", services: [
      .init(port: 22, transport: "tcp", name: "ssh", version: "OpenSSH"),
    ]),
    .init(address: "192.168.50.20", hostname: "web.lab", role: "Serwer", services: [
      .init(port: 22, transport: "tcp", name: "ssh", version: "OpenSSH"),
      .init(port: 80, transport: "tcp", name: "http", version: "nginx"),
    ]),
    .init(address: "192.168.50.30", hostname: "printer.lab", role: "Drukarka", services: [
      .init(port: 631, transport: "tcp", name: "ipp", version: nil),
    ]),
  ])
}
```

- [ ] **Step 4: Dodaj oba pliki do targetów i uruchom test ponownie**

Expected: `VirtualNetworkTests` PASS.

- [ ] **Step 5: Zatrzymaj się przed commitem**

Po zgodzie użytkownika:

```zsh
git add NetScope/VirtualNetwork.swift NetScopeTests/VirtualNetworkTests.swift NetScope.xcodeproj/project.pbxproj
git commit -m "feat: add virtual demo network"
```

### Task 2: Bezpieczny interpreter poleceń

**Files:**
- Create: `NetScope/VirtualLabEngine.swift`
- Create: `NetScopeTests/VirtualLabEngineTests.swift`
- Modify: `NetScope.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: `VirtualNetwork`.
- Produces: `VirtualLabEngine.execute(_:) -> VirtualCommandResult`, `VirtualCommandResult`, `VirtualExplanation`.

- [ ] **Step 1: Dodaj testy obsługiwanych i zabronionych operacji**

```swift
import Testing
@testable import NetScope

@Suite("Virtual lab engine")
struct VirtualLabEngineTests {
  let engine = VirtualLabEngine(network: .demo)

  @Test("Discovery returns only simulated hosts")
  func discovery() {
    let result = engine.execute("nmap -sn 192.168.50.0/24")
    #expect(result.status == .success)
    #expect(result.output.contains("192.168.50.20"))
    #expect(result.output.contains("web.lab"))
  }

  @Test("Unknown commands never execute")
  func unknownCommand() {
    let result = engine.execute("rm -rf /")
    #expect(result.status == .unsupported)
    #expect(result.output.contains("Laboratorium nie wykonuje tego polecenia"))
  }

  @Test("Invalid flag receives a correction")
  func invalidFlag() {
    let result = engine.execute("nmap -zz 192.168.50.20")
    #expect(result.status == .invalid)
    #expect(result.hint?.contains("-sV") == true)
  }
}
```

- [ ] **Step 2: Uruchom test i potwierdź porażkę z brakiem typu**

Run: poprzednie polecenie z `-only-testing:NetScopeTests/VirtualLabEngineTests`.

- [ ] **Step 3: Zaimplementuj zamknięty zestaw poleceń**

```swift
struct VirtualExplanation: Equatable, Sendable {
  let term: String
  let meaning: String
}

struct VirtualCommandResult: Equatable, Sendable {
  enum Status: Equatable, Sendable { case success, invalid, unsupported }
  let status: Status
  let output: String
  let hint: String?
  let explanations: [VirtualExplanation]
}

struct VirtualLabEngine: Sendable {
  let network: VirtualNetwork

  func execute(_ input: String) -> VirtualCommandResult {
    let tokens = input.split(whereSeparator: \.isWhitespace).map(String.init)
    guard let executable = tokens.first,
          ["nmap", "ping", "dig", "ssh"].contains(executable)
    else {
      return .init(status: .unsupported,
        output: "Laboratorium nie wykonuje tego polecenia.",
        hint: "Dostępne: nmap, ping, dig i ssh.", explanations: [])
    }
    return resolve(executable: executable, arguments: Array(tokens.dropFirst()))
  }
}
```

Dodaj prywatne metody `resolveNmap(_:)`, `resolvePing(_:)`, `resolveDig(_:)` i
`resolveSSH(_:)`. `resolve(executable:arguments:)` deleguje wyłącznie do jednej z
nich. Obsługiwane układy to: `nmap -sn <cidr>`, `nmap -sT [-sV] [-p ports]
<host>`, `ping <host>`, `dig -x <host>` i `ssh <user>@<host>`. Każdy inny układ
zwraca `.invalid`; żadna metoda nie importuje `Network` ani nie wywołuje API
sieciowego.

- [ ] **Step 4: Dodaj test każdej jawnej gałęzi i uruchom cały suite interpretera**

Expected: wszystkie testy PASS; wynik dla tego samego wejścia jest identyczny.

- [ ] **Step 5: Zatrzymaj się przed commitem**

Po zgodzie użytkownika commit: `feat: add safe virtual command engine`.

### Task 3: Misje i lokalny postęp

**Files:**
- Create: `NetScope/LabMission.swift`
- Create: `NetScope/LabProgressStore.swift`
- Create: `NetScopeTests/LabMissionTests.swift`
- Modify: `NetScope.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: `VirtualCommandResult`.
- Produces: `LabMission.demo`, `LabStep.accepts(command:result:)`, `LabProgressStore.complete(missionID:stepID:)`.

- [ ] **Step 1: Dodaj test semantycznego zaliczenia i przywrócenia postępu**

```swift
@Suite("Lab missions")
struct LabMissionTests {
  @Test("Equivalent discovery command completes first step")
  func semanticCompletion() {
    let step = LabMission.demo[0].steps[0]
    let result = VirtualLabEngine(network: .demo).execute("nmap  -sn  192.168.50.0/24")
    #expect(step.accepts(command: "nmap  -sn  192.168.50.0/24", result: result))
  }

  @Test("Progress round trips through isolated defaults")
  func progressRoundTrip() {
    let suite = "LabProgressTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = LabProgressStore(defaults: defaults)
    store.complete(missionID: "host-discovery", stepID: "discover")
    #expect(LabProgressStore(defaults: defaults).isComplete(
      missionID: "host-discovery", stepID: "discover"))
  }
}
```

- [ ] **Step 2: Uruchom test i potwierdź porażkę**

Run: test `LabMissionTests` na iPhonie 17.

- [ ] **Step 3: Dodaj trzy misje demo**

```swift
struct LabStep: Identifiable, Equatable, Sendable {
  let id: String
  let objective: String
  let hints: [String]
  let acceptedIntent: LabCommandIntent
  let explanation: String

  func accepts(command: String, result: VirtualCommandResult) -> Bool {
    result.status == .success && LabCommandIntent.parse(command) == acceptedIntent
  }
}

enum LabCommandIntent: Equatable, Sendable {
  case discover(cidr: String)
  case inspect(host: String, ports: [UInt16], versions: Bool)
  case connectSSH(user: String, host: String)

  static func parse(_ command: String) -> LabCommandIntent? {
    let tokens = command.split(whereSeparator: \.isWhitespace).map(String.init)
    if tokens.count == 3, tokens[0] == "nmap", tokens[1] == "-sn" {
      return .discover(cidr: tokens[2])
    }
    if tokens.count == 2, tokens[0] == "ssh",
       let separator = tokens[1].firstIndex(of: "@") {
      return .connectSSH(
        user: String(tokens[1][..<separator]),
        host: String(tokens[1][tokens[1].index(after: separator)...])
      )
    }
    return parseInspection(tokens)
  }

  private static func parseInspection(_ tokens: [String]) -> LabCommandIntent? {
    guard tokens.first == "nmap", let host = tokens.last else { return nil }
    let versions = tokens.contains("-sV")
    let ports: [UInt16]
    if let index = tokens.firstIndex(of: "-p"), tokens.indices.contains(index + 1) {
      ports = tokens[index + 1].split(separator: ",").compactMap { UInt16($0) }
    } else {
      ports = []
    }
    return .inspect(host: host, ports: ports, versions: versions)
  }
}

struct LabMission: Identifiable, Equatable, Sendable {
  let id: String
  let title: String
  let summary: String
  let isPro: Bool
  let steps: [LabStep]
}
```

`LabMission.demo` zawiera identyfikatory `host-discovery`, `ports-services` i `ssh-basics`; wszystkie mają `isPro == false`. Intencje opisują odkrycie podsieci, skan TCP z wersjami oraz połączenie SSH do `mac.lab`.

- [ ] **Step 4: Dodaj trwałość postępu**

```swift
struct CompletedLabStep: Codable, Hashable {
  let missionID: String
  let stepID: String
}

@MainActor
final class LabProgressStore: ObservableObject {
  @Published private(set) var completed: Set<CompletedLabStep>
  private let defaults: UserDefaults
  private let key = "NetScope.labProgress.v1"

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    completed = (defaults.data(forKey: key))
      .flatMap { try? JSONDecoder().decode(Set<CompletedLabStep>.self, from: $0) }
      ?? []
  }

  func complete(missionID: String, stepID: String) {
    completed.insert(.init(missionID: missionID, stepID: stepID))
    if let data = try? JSONEncoder().encode(completed) {
      defaults.set(data, forKey: key)
    }
  }

  func isComplete(missionID: String, stepID: String) -> Bool {
    completed.contains(.init(missionID: missionID, stepID: stepID))
  }
}
```

Historia tekstu terminala pozostaje osobnym stanem sceny i nie trafia do analityki.

- [ ] **Step 5: Uruchom testy misji, następnie `git diff --check`**

Expected: PASS i brak błędów whitespace.

- [ ] **Step 6: Zatrzymaj się przed commitem**

Po zgodzie użytkownika commit: `feat: add demo missions and progress`.

### Task 4: Interfejs terminala edukacyjnego

**Files:**
- Create: `NetScope/TerminalLessonView.swift`
- Create: `NetScope/LaboratoryView.swift`
- Modify: `NetScope.xcodeproj/project.pbxproj`
- Modify: `NetScopeTests/NetScopeTests.swift`

**Interfaces:**
- Consumes: `VirtualLabEngine`, `LabMission`, `LabProgressStore`, `EntitlementAccess`.
- Produces: `LaboratoryView(onTryOwnNetwork:)` i `TerminalLessonView(mission:onTryOwnNetwork:)`.

- [ ] **Step 1: Dodaj test stabilnego katalogu demo**

```swift
@Test("Demo exposes three free missions in learning order")
func demoMissionOrder() {
  #expect(LabMission.demo.map(\.id) == ["host-discovery", "ports-services", "ssh-basics"])
  #expect(LabMission.demo.allSatisfy { !$0.isPro })
}
```

- [ ] **Step 2: Uruchom test i potwierdź jego wynik przed zmianą UI**

Expected: PASS po Task 3; jest to test kontraktu wejściowego widoku.

- [ ] **Step 3: Zbuduj listę lekcji**

```swift
struct LaboratoryView: View {
  let missions: [LabMission]
  let onTryOwnNetwork: () -> Void

  var body: some View {
    NavigationStack {
      List(missions) { mission in
        NavigationLink(mission.title) {
          TerminalLessonView(mission: mission, onTryOwnNetwork: onTryOwnNetwork)
        }
      }
      .navigationTitle("Laboratorium")
    }
  }
}
```

- [ ] **Step 4: Zbuduj terminal bez automatycznego wykonywania**

Dodaj model wpisu:

```swift
struct TerminalEntry: Identifiable, Equatable {
  let id = UUID()
  let command: String
  let result: VirtualCommandResult
}
```

Widok przechowuje `input`, `[TerminalEntry]`, bieżący krok i numer podpowiedzi.
Przycisk „Uruchom w laboratorium” wywołuje wyłącznie
`VirtualLabEngine.execute(input)`. Każda odpowiedź pokazuje status, tekst oraz
rozwijane `VirtualExplanation`. Pole tekstowe ma etykietę VoiceOver „Polecenie
laboratorium”; komunikaty sukcesu są ogłaszane przez accessibility announcement.

- [ ] **Step 5: Dodaj zachowanie błędów i podpowiedzi**

Nieznane polecenie pozostaje w historii. Błąd nie zeruje wpisu ani postępu. Podpowiedzi odsłaniają się kolejno, a pełne rozwiązanie pojawia się dopiero po ostatniej podpowiedzi.

- [ ] **Step 6: Uruchom aplikację i ręcznie przejdź pierwszą lekcję**

Sprawdź: błędne polecenie, podpowiedź, poprawne polecenie, rozwinięte wyjaśnienie, powrót do listy i przywrócenie kroku.

- [ ] **Step 7: Zatrzymaj się przed commitem**

Po zgodzie użytkownika commit: `feat: add educational terminal interface`.

### Task 5: Przejście do skanera własnej sieci

**Files:**
- Modify: `NetScope/AppShellView.swift`
- Modify: `NetScope/ScannerView.swift`
- Modify: `NetScopeTests/NetScopeTests.swift`

**Interfaces:**
- Consumes: `LaboratoryView(onTryOwnNetwork:)`, `NetworkScanner.profile`.
- Produces: `AppRouteRequest.tryOwnNetwork` i kontrolowane przełączenie do `.dashboard`.

- [ ] **Step 1: Dodaj test mapowania lekcji na bezpieczny profil**

```swift
@Test("Try-own-network always starts with quick profile")
func laboratoryUsesSafeScanProfile() {
  #expect(AppRouteRequest.tryOwnNetwork.recommendedProfile == .quick)
  #expect(AppRouteRequest.tryOwnNetwork.startsAutomatically == false)
}
```

- [ ] **Step 2: Uruchom test i potwierdź oczekiwaną porażkę**

Expected: FAIL, ponieważ `AppRouteRequest` nie istnieje.

- [ ] **Step 3: Dodaj żądanie nawigacyjne**

```swift
enum AppRouteRequest: Equatable {
  case tryOwnNetwork

  var recommendedProfile: ScanProfile { .quick }
  var startsAutomatically: Bool { false }
}
```

- [ ] **Step 4: Podłącz laboratorium do głównej nawigacji**

Laboratorium zostaje pierwszą zawartością karty „Wkrótce” albo zastępuje tę kartę nazwą „Laboratorium”. Callback ustawia `scanner.profile = .quick`, przełącza `selectedTabRaw` na `.dashboard` i pokazuje informacyjny banner. Nie wywołuje `scanner.scan()`.

- [ ] **Step 5: Ręcznie zweryfikuj granicę zgody**

W trybie samolotowym laboratorium ma działać. „Wypróbuj we własnej sieci” ma tylko otworzyć Start. Dopiero dotknięcie istniejącego przycisku skanu może uruchomić systemową zgodę i skan.

- [ ] **Step 6: Uruchom testy nawigacji i skanera**

Run:

```zsh
xcodebuild test -project NetScope.xcodeproj -scheme NetScope \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:NetScopeTests/SessionRestorationTests \
  -only-testing:NetScopeTests/ScannerRegistryIntegrationTests \
  CODE_SIGNING_ALLOWED=NO
```

- [ ] **Step 7: Zatrzymaj się przed commitem**

Po zgodzie użytkownika commit: `feat: connect labs to local scanner`.

### Task 6: Jednorazowe odblokowanie Northbyte Radar Pro

**Files:**
- Create: `NetScope/EntitlementStore.swift`
- Create: `NetScope/NetScope.storekit`
- Create: `NetScopeTests/EntitlementStoreTests.swift`
- Modify: `NetScope/LaboratoryView.swift`
- Modify: `NetScope.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: StoreKit `Product`, `Transaction.currentEntitlements`.
- Produces: `EntitlementAccess`, `EntitlementStore.hasPro`, `purchasePro()` i `restorePurchases()`.

- [ ] **Step 1: Dodaj test polityki dostępu niezależnej od StoreKit**

```swift
@Suite("Entitlements")
struct EntitlementStoreTests {
  @Test("Free missions stay available without Pro")
  func freeAccess() {
    #expect(EntitlementAccess(hasPro: false).canOpen(isPro: false))
    #expect(!EntitlementAccess(hasPro: false).canOpen(isPro: true))
    #expect(EntitlementAccess(hasPro: true).canOpen(isPro: true))
  }
}
```

- [ ] **Step 2: Uruchom test i potwierdź porażkę z brakiem typu**

- [ ] **Step 3: Dodaj czystą politykę i StoreKit adapter**

```swift
import StoreKit

struct EntitlementAccess: Equatable, Sendable {
  let hasPro: Bool
  func canOpen(isPro: Bool) -> Bool { !isPro || hasPro }
}

@MainActor
final class EntitlementStore: ObservableObject {
  static let proProductID = "pl.krystian.NetScope.pro"
  @Published private(set) var hasPro = false
  @Published private(set) var product: Product?
  @Published private(set) var errorMessage: String?

  func refresh() async {
    do {
      product = try await Product.products(for: [Self.proProductID]).first
      hasPro = false
      for await entitlement in Transaction.currentEntitlements {
        let transaction = try verified(entitlement)
        if transaction.productID == Self.proProductID,
           transaction.revocationDate == nil {
          hasPro = true
        }
      }
      errorMessage = nil
    } catch {
      errorMessage = "Nie udało się odświeżyć dostępu do Northbyte Radar Pro."
    }
  }

  func purchasePro() async {
    guard let product else {
      errorMessage = "Zakup jest teraz niedostępny."
      return
    }
    do {
      switch try await product.purchase() {
      case .success(let verification):
        let transaction = try verified(verification)
        await transaction.finish()
        await refresh()
      case .userCancelled, .pending:
        break
      @unknown default:
        errorMessage = "Sklep zwrócił nieznany stan zakupu."
      }
    } catch {
      errorMessage = "Nie udało się dokończyć zakupu."
    }
  }

  func restorePurchases() async {
    do {
      try await AppStore.sync()
      await refresh()
    } catch {
      errorMessage = "Nie udało się przywrócić zakupu."
    }
  }

  private func verified<T>(_ result: VerificationResult<T>) throws -> T {
    switch result {
    case .verified(let value): return value
    case .unverified: throw EntitlementError.failedVerification
    }
  }
}

enum EntitlementError: Error { case failedVerification }
```

Implementacja akceptuje wyłącznie zweryfikowaną transakcję z identyfikatorem `proProductID`. Anulowanie zakupu nie pokazuje błędu. Błąd sklepu nie blokuje demo.

- [ ] **Step 4: Dodaj lokalny produkt StoreKit**

`NetScope.storekit` zawiera jeden non-consumable product: product ID `pl.krystian.NetScope.pro`, reference name `NetScope Pro`, polską nazwę `NetScope Pro` i opis pełnego odblokowania. Nie dodawaj produktu subskrypcyjnego.

- [ ] **Step 5: Dodaj ekran Pro bez agresywnego paywalla**

Widok pokazuje darmowe lekcje normalnie. Element Pro opisuje zawartość, aktualną cenę zwróconą przez StoreKit, przycisk zakupu i „Przywróć zakup”. Nie pokazuje fałszywego rabatu, licznika czasu ani automatycznego okna przy starcie.

- [ ] **Step 6: Uruchom testy StoreKit Configuration**

Sprawdź zakup, anulowanie, ponowne uruchomienie, przywrócenie i niedostępny sklep. Darmowe trzy lekcje muszą działać w każdym przypadku.

- [ ] **Step 7: Zatrzymaj się przed commitem**

Po zgodzie użytkownika commit: `feat: add NetScope Pro unlock`.

### Task 7: Integracja, dostępność i gotowość demo

**Files:**
- Modify: `scripts/test-project-integrity.sh`
- Modify: `NetScope/PrivacyInfo.xcprivacy` tylko jeśli rzeczywiste API wymagają zmiany deklaracji.
- Modify: `NetScopeTests/NetScopeTests.swift`
- Review: `NetScope/Info.plist`

**Interfaces:**
- Consumes: wszystkie moduły z Task 1–6.
- Produces: zweryfikowany build demonstracyjny bez nowych uprawnień laboratorium.

- [ ] **Step 1: Rozszerz kontrolę integralności**

Skrypt sprawdza obecność `VirtualNetwork.swift`, `VirtualLabEngine.swift`, `LabMission.swift`, `TerminalLessonView.swift`, `LaboratoryView.swift` i `EntitlementStore.swift` w projekcie oraz potwierdza, że bundle zawiera `PrivacyInfo.xcprivacy`. Nie opieraj kontroli na tekstach przycisków SwiftUI.

- [ ] **Step 2: Dodaj regresyjny test braku automatycznego skanu**

```swift
@Test("Laboratory handoff never starts a scan")
func noAutomaticRealScan() {
  #expect(AppRouteRequest.tryOwnNetwork.startsAutomatically == false)
}
```

- [ ] **Step 3: Uruchom wszystkie testy**

```zsh
xcodebuild test -project NetScope.xcodeproj -scheme NetScope \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO
```

Expected: `** TEST SUCCEEDED **`, zero testów pominiętych i zero błędów.

- [ ] **Step 4: Uruchom kontrolę przed push**

```zsh
zsh scripts/pre-push-check.sh
```

Expected: `Diff: OK`, `Integralność bundle: OK`, `Kontrola przed push: OK`.

- [ ] **Step 5: Wykonaj ręczne przejście demo na iPhonie 17**

Sprawdź kolejno: trzy misje, błędne polecenia, wszystkie podpowiedzi, przywrócenie sesji, tryb offline, Dynamic Type, VoiceOver, przejście do skanera bez automatycznego startu oraz StoreKit Test.

- [ ] **Step 6: Sprawdź zakres danych i uprawnień**

Potwierdź, że laboratorium nie dodało nowych kluczy uprawnień w `Info.plist`, nie wykonuje żądań sieciowych i nie zapisuje danych poza `UserDefaults`. Jeżeli manifest prywatności pozostaje prawidłowy, nie zmieniaj go.

- [ ] **Step 7: Przejrzyj końcowy stan Git**

```zsh
git status --short
git diff --check
git diff --stat
```

Oddziel zmiany laboratorium od wcześniejszego niezatwierdzonego Toolboxa. Nie commituj plików spoza zatwierdzonego zakresu.

- [ ] **Step 8: Zatrzymaj się przed końcowym commitem**

Po zgodzie użytkownika commit: `feat: add virtual network laboratory` — tylko jeśli wcześniejsze zadania nie zostały zatwierdzone jako osobne commity. Preferowane są małe commity z Task 1–6.

## Kryterium zakończenia

Plan jest wykonany dopiero wtedy, gdy trzy darmowe laboratoria działają offline, interpreter nie uruchamia prawdziwego kodu, przejście do skanera nie startuje automatycznie, demo działa bez StoreKit, zakup Pro można kupić i przywrócić w środowisku testowym, wszystkie testy przechodzą, Release build jest poprawny, a ręczna ścieżka na iPhonie 17 została udokumentowana rzeczywistym wynikiem.
