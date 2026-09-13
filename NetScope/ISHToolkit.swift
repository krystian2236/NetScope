import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct ISHTarget: Identifiable, Hashable, Sendable {
  let address: String
  let title: String
  let subtitle: String

  var id: String { address }
}

enum NmapGuideStep: Int, CaseIterable, Identifiable, Sendable {
  case discovery
  case names
  case commonPorts
  case services
  case detailed

  var id: Self { self }

  var title: String {
    switch self {
    case .discovery: "Wykrywanie urządzeń"
    case .names: "Nazwy urządzeń"
    case .commonPorts: "Najważniejsze porty"
    case .services: "Rozpoznawanie usług"
    case .detailed: "Dokładna analiza urządzenia"
    }
  }

  var subtitle: String {
    switch self {
    case .discovery: "Sprawdza, które urządzenia odpowiadają w prywatnej sieci."
    case .names: "Próbuje ustalić nazwy DNS i rodzaj wykrytych urządzeń."
    case .commonPorts: "Sprawdza WWW, SSH, drukarki, multimedia i udostępnianie plików."
    case .services: "Rozpoznaje usługi oraz ich podstawowe informacje."
    case .detailed: "Rozszerza analizę jednego wybranego urządzenia."
    }
  }

  var icon: String {
    switch self {
    case .discovery: "dot.radiowaves.left.and.right"
    case .names: "textformat.abc"
    case .commonPorts: "door.left.hand.open"
    case .services: "server.rack"
    case .detailed: "magnifyingglass.circle"
    }
  }

  var mode: ISHScanMode {
    switch self {
    case .discovery, .names, .commonPorts: .inventory
    case .services: .serviceDetails
    case .detailed: .extended
    }
  }

  var shortcutID: SSHShortcutID {
    switch self {
    case .discovery: .discoverHosts
    case .names: .reverseDNS
    case .commonPorts: .commonPorts
    case .services: .serviceVersions
    case .detailed: .detailedHost
    }
  }

  func isAvailable(hasDevices: Bool, completedSteps: Int) -> Bool {
    hasDevices && rawValue <= completedSteps
  }
}

enum ISHScanMode: String, CaseIterable, Identifiable, Sendable {
  case inventory
  case extended
  case serviceDetails

  var id: Self { self }

  var title: String {
    switch self {
    case .inventory: "Inwentaryzacja"
    case .extended: "Rozszerzony TCP"
    case .serviceDetails: "Szczegóły usług"
    }
  }

  var subtitle: String {
    switch self {
    case .inventory: "Popularne usługi i otwarte porty"
    case .extended: "Pełny profil NetScope i przyczyna wyniku"
    case .serviceDetails: "Lekka identyfikacja wersji usług"
    }
  }
}

enum ISHCommandBuilder {
  static let installCommand = "apk update && apk add nmap"

  static func command(
    target: String,
    mode: ISHScanMode,
    knownPorts: [UInt16] = []
  ) -> String {
    guard ISHTargetValidator.isPrivate(target) else {
      return "# NetScope: wybierz prywatny adres IPv4 lub lokalną podsieć."
    }

    let ports = ports(for: mode, knownPorts: knownPorts)
      .map(String.init)
      .joined(separator: ",")
    let versionOptions = mode == .serviceDetails ? " -sV --version-light" : ""

    return
      "nmap --unprivileged -sT -Pn\(versionOptions) --open --reason -p '\(ports)' \(shellQuoted(target))"
  }

  static func script(
    target: String,
    mode: ISHScanMode,
    knownPorts: [UInt16] = []
  ) -> String {
    guard ISHTargetValidator.isPrivate(target) else {
      return "#!/bin/sh\n\necho 'NetScope: nieprawidłowy prywatny cel IPv4.'\nexit 2\n"
    }

    let ports = ports(for: mode, knownPorts: knownPorts)
      .map(String.init)
      .joined(separator: ",")
    let versionOptions = mode == .serviceDetails ? "-sV --version-light" : ""

    return """
      #!/bin/sh
      set -eu

      # NetScope iSH Toolkit
      # Używaj wyłącznie w swojej sieci lub za zgodą jej właściciela.
      TARGET=\(shellQuoted(target))
      PORTS=\(shellQuoted(ports))
      OUTPUT_DIR="$HOME/netscope-$(date +%Y%m%d-%H%M%S)"

      if ! command -v nmap >/dev/null 2>&1; then
        echo "Brak Nmap. Zainstaluj go poleceniem:"
        echo "\(installCommand)"
        exit 1
      fi

      mkdir -p "$OUTPUT_DIR"
      echo "Cel: $TARGET"
      echo "Wyniki: $OUTPUT_DIR"

      nmap --unprivileged -sT -Pn \(versionOptions) --open --reason \
        -p "$PORTS" "$TARGET" -oA "$OUTPUT_DIR/scan"

      echo
      echo "Gotowe. Raport tekstowy: $OUTPUT_DIR/scan.nmap"
      """
  }

  private static func ports(
    for mode: ISHScanMode,
    knownPorts: [UInt16]
  ) -> [UInt16] {
    switch mode {
    case .inventory:
      ScanProfile.standard.ports
    case .extended:
      ScanProfile.extended.ports
    case .serviceDetails:
      knownPorts.isEmpty ? ScanProfile.standard.ports : knownPorts
    }
  }

  private static func shellQuoted(_ value: String) -> String {
    "'\(value.replacingOccurrences(of: "'", with: "'\"'\"'"))'"
  }
}

enum ISHTargetValidator {
  /// Minimalny wymagany prefiks CIDR dla danego bloku prywatnego, tak aby
  /// cała podsieć mieściła się w jego granicach (np. `10.0.0.0/7` wykracza
  /// poza blok `10.0.0.0/8`, więc jest odrzucane).
  private static func minimumPrefixLength(forFirstOctet first: Int, secondOctet second: Int) -> Int? {
    if first == 10 {
      return 8
    }
    if first == 172, (16...31).contains(second) {
      return 12
    }
    if first == 192, second == 168 {
      return 16
    }
    if first == 169, second == 254 {
      return 16
    }
    return nil
  }

  /// Sprawdza, czy `octets` reprezentują adres należący do jednego z prywatnych
  /// bloków (10/8, 172.16/12, 192.168/16, 169.254/16), zwracając minimalny
  /// prefiks wymagany dla tego bloku, jeśli tak.
  private static func privateBlockMinimumPrefix(for octets: [Int]) -> Int? {
    guard octets.count == 4, octets.allSatisfy({ (0...255).contains($0) }) else {
      return nil
    }
    return minimumPrefixLength(forFirstOctet: octets[0], secondOctet: octets[1])
  }

  /// Akceptuje pojedynczy adres IPv4 z opcjonalnym prefiksem CIDR, o ile cała
  /// podsieć mieści się w jednym z prywatnych bloków. Odrzuca brakujący/
  /// niepoprawny/wielokrotny separator `/`, prefiksy spoza 0–32 oraz prefiksy
  /// zbyt krótkie dla danego bloku (np. `10.0.0.0/7`).
  static func isPrivate(_ target: String) -> Bool {
    let parts = target.split(separator: "/", omittingEmptySubsequences: false)
    guard parts.count == 1 || parts.count == 2 else {
      return false
    }

    let octets = parts[0].split(separator: ".").compactMap { Int($0) }
    guard let minimumPrefix = privateBlockMinimumPrefix(for: octets) else {
      return false
    }

    guard parts.count == 2 else {
      return true
    }

    let prefixText = parts[1]
    guard !prefixText.isEmpty,
      prefixText.allSatisfy({ $0.isNumber }),
      let prefixLength = Int(prefixText),
      (0...32).contains(prefixLength)
    else {
      return false
    }

    return prefixLength >= minimumPrefix
  }

  /// Akceptuje wyłącznie pojedynczy prywatny adres IPv4 bez zapisu CIDR.
  /// Przeznaczone dla poleceń (np. odwrotny DNS), które operują na
  /// pojedynczym hoście, a nie na całej podsieci.
  static func isPrivateHost(_ target: String) -> Bool {
    guard !target.contains("/") else {
      return false
    }
    let octets = target.split(separator: ".").compactMap { Int($0) }
    return privateBlockMinimumPrefix(for: octets) != nil
  }
}

struct ISHScriptDocument: FileDocument {
  static var readableContentTypes: [UTType] { [.shellScript] }

  let contents: String

  init(contents: String) {
    self.contents = contents
  }

  init(configuration: ReadConfiguration) throws {
    contents = ""
  }

  func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
    FileWrapper(regularFileWithContents: Data(contents.utf8))
  }
}
