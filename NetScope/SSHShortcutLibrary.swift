import Foundation

enum SSHShortcutCategory: Int, CaseIterable, Identifiable, Sendable {
  case connection, networkInfo, discovery, dns, ports, reports

  var id: Self { self }

  var title: String {
    [
      "Połączenie z Maciem",
      "Informacje o sieci",
      "Wykrywanie urządzeń",
      "DNS i nazwy",
      "Porty i usługi",
      "Raporty",
    ][rawValue]
  }
}

enum SSHExecutionPlace: String, Sendable {
  case beforeSSH = "Wklej w iSH przed SSH"
  case onMac = "Wklej po zalogowaniu na Maca"
}

enum SSHShortcutID: String, CaseIterable, Identifiable, Sendable {
  case connect, disconnect, macIPv4, gateway, dnsServers, neighbors
  case discoverHosts, reverseDNS, commonPorts, serviceVersions, detailedHost
  case createReportDirectory, listReports

  var id: Self { self }
}

struct SSHShortcut: Identifiable, Equatable, Sendable {
  let id: SSHShortcutID
  let category: SSHShortcutCategory
  let title: String
  let summary: String
  let place: SSHExecutionPlace
}

struct SSHShortcutContext: Equatable, Sendable {
  let username: String
  let host: String
  let target: String?
}

enum SSHShortcutResolution: Equatable, Sendable {
  case command(String)
  case blocked(String)
}

enum SSHShortcutLibrary {
  static let shortcuts: [SSHShortcut] = [
    SSHShortcut(id: .connect, category: .connection, title: "Połącz z Maciem", summary: "Rozpoczyna sesję SSH z iSH na wskazanym Macu.", place: .beforeSSH),
    SSHShortcut(id: .disconnect, category: .connection, title: "Zakończ połączenie", summary: "Kończy bieżącą sesję SSH i wraca do iSH.", place: .onMac),
    SSHShortcut(id: .macIPv4, category: .networkInfo, title: "Adres IPv4 Maca", summary: "Wyświetla adres IPv4 głównego interfejsu Wi-Fi.", place: .onMac),
    SSHShortcut(id: .gateway, category: .networkInfo, title: "Brama domyślna", summary: "Wyświetla trasę i bramę domyślną Maca.", place: .onMac),
    SSHShortcut(id: .dnsServers, category: .networkInfo, title: "Serwery DNS", summary: "Wyświetla konfigurację serwerów DNS na Macu.", place: .onMac),
    SSHShortcut(id: .neighbors, category: .networkInfo, title: "Tablica sąsiadów", summary: "Wyświetla znane urządzenia z lokalnej tablicy ARP.", place: .onMac),
    SSHShortcut(id: .discoverHosts, category: .discovery, title: "Wykryj urządzenia", summary: "Wykrywa odpowiadające hosty w wybranej prywatnej sieci.", place: .onMac),
    SSHShortcut(id: .reverseDNS, category: .dns, title: "Odwrotny DNS", summary: "Sprawdza nazwę DNS wybranego prywatnego adresu.", place: .onMac),
    SSHShortcut(id: .commonPorts, category: .ports, title: "Najważniejsze porty", summary: "Sprawdza typowe porty TCP bez uprawnień administratora.", place: .onMac),
    SSHShortcut(id: .serviceVersions, category: .ports, title: "Wersje usług", summary: "Lekko rozpoznaje usługi na typowych portach TCP.", place: .onMac),
    SSHShortcut(id: .detailedHost, category: .ports, title: "Dokładna analiza hosta", summary: "Rozszerza bezpieczną analizę jednego prywatnego hosta.", place: .onMac),
    SSHShortcut(id: .createReportDirectory, category: .reports, title: "Utwórz katalog raportów", summary: "Uruchomienie tworzy folder NetScope w Dokumentach.", place: .onMac),
    SSHShortcut(id: .listReports, category: .reports, title: "Pokaż raporty", summary: "Wyświetla zapisane pliki raportów NetScope.", place: .onMac),
  ]

  private static let safeToken = /^[A-Za-z0-9._-]+$/
  private static let commonPortList = "22,53,80,443,445,548,631,9100"

  static func resolve(
    _ id: SSHShortcutID,
    context: SSHShortcutContext
  ) -> SSHShortcutResolution {
    switch id {
    case .connect:
      return connection(context)
    case .disconnect:
      return .command("exit")
    case .macIPv4:
      return .command("ipconfig getifaddr en0")
    case .gateway:
      return .command("route -n get default")
    case .dnsServers:
      return .command("scutil --dns")
    case .neighbors:
      return .command("arp -a")
    case .discoverHosts:
      return targetCommand(context) { "nmap -sn \($0)" }
    case .reverseDNS:
      return targetCommand(context) { "dscacheutil -q host -a ip_address \($0)" }
    case .commonPorts:
      return targetCommand(context) {
        "nmap --unprivileged -sT -Pn --open -p '\(commonPortList)' \($0)"
      }
    case .serviceVersions:
      return targetCommand(context) {
        "nmap --unprivileged -sT -Pn -sV --version-light --open -p '\(commonPortList)' \($0)"
      }
    case .detailedHost:
      return targetCommand(context) {
        "nmap --unprivileged -sT -Pn -sV --version-light --open --reason -p '\(commonPortList)' \($0)"
      }
    case .createReportDirectory:
      return .command("mkdir -p \"$HOME/Documents/NetScope\"")
    case .listReports:
      return .command("find \"$HOME/Documents/NetScope\" -maxdepth 1 -type f -print")
    }
  }

  private static func connection(_ context: SSHShortcutContext) -> SSHShortcutResolution {
    guard !context.username.isEmpty, !context.host.isEmpty else {
      return .blocked("Uzupełnij użytkownika i host Maca.")
    }
    guard context.username.wholeMatch(of: safeToken) != nil,
      context.host.wholeMatch(of: safeToken) != nil
    else {
      return .blocked("Użytkownik lub host zawiera niedozwolone znaki.")
    }
    return .command("ssh \(context.username)@\(context.host)")
  }

  private static func targetCommand(
    _ context: SSHShortcutContext,
    build: (String) -> String
  ) -> SSHShortcutResolution {
    guard let target = context.target, ISHTargetValidator.isPrivate(target) else {
      return .blocked("Wybierz prywatny adres lub podsieć.")
    }
    return .command(build(shellQuoted(target)))
  }

  private static func shellQuoted(_ value: String) -> String {
    "'\(value.replacingOccurrences(of: "'", with: "'\"'\"'"))'"
  }
}
