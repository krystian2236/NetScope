import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct ISHTarget: Identifiable, Hashable, Sendable {
  let address: String
  let title: String
  let subtitle: String

  var id: String { address }
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
  static func isPrivate(_ target: String) -> Bool {
    let address = target.split(separator: "/", maxSplits: 1).first.map(String.init) ?? target
    let octets = address.split(separator: ".").compactMap { Int($0) }
    guard octets.count == 4,
      octets.allSatisfy({ (0...255).contains($0) })
    else {
      return false
    }

    return octets[0] == 10
      || (octets[0] == 172 && (16...31).contains(octets[1]))
      || (octets[0] == 192 && octets[1] == 168)
      || (octets[0] == 169 && octets[1] == 254)
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
