import Foundation

struct VirtualExplanation: Equatable, Sendable {
  let term: String
  let meaning: String
}

struct VirtualCommandResult: Equatable, Sendable {
  enum Status: Equatable, Sendable {
    case success
    case invalid
    case unsupported
  }

  let status: Status
  let output: String
  let hint: String?
  let explanations: [VirtualExplanation]
}

struct VirtualLabEngine: Sendable {
  let network: VirtualNetwork

  func execute(_ input: String) -> VirtualCommandResult {
    let tokens = LabCommandTokenizer.tokenize(input)
    guard let executable = tokens.first else {
      return invalid("Wpisz polecenie.", hint: supportedCommandsHint)
    }

    let arguments = Array(tokens.dropFirst())
    return switch executable.lowercased() {
    case "nmap": resolveNmap(arguments)
    case "nuclei": resolveNuclei(arguments)
    case "ping": resolvePing(arguments)
    case "dig": resolveDig(arguments)
    case "curl": resolveCurl(arguments)
    case "ssh": resolveSSH(arguments)
    default:
      VirtualCommandResult(
        status: .unsupported,
        output: "Laboratorium nie wykonuje tego polecenia.",
        hint: supportedCommandsHint,
        explanations: []
      )
    }
  }

  private func resolveNmap(_ arguments: [String]) -> VirtualCommandResult {
    if arguments.count == 2, arguments[0] == "-sn" {
      let hosts = network.activeHosts(in: arguments[1])
      guard !hosts.isEmpty else {
        return invalid(
          "Poza wirtualną siecią nie znaleziono hostów.",
          hint: "Użyj zakresu \(network.cidr)."
        )
      }

      let output = hosts
        .map { "Nmap scan report for \($0.hostname) (\($0.address))\nHost is up." }
        .joined(separator: "\n")
      return success(
        output,
        explanations: [
          .init(term: "-sn", meaning: "Wykrywa aktywne hosty bez skanowania portów."),
          .init(term: network.cidr, meaning: "Prywatna sieć demonstracyjna /24."),
        ]
      )
    }

    guard arguments.contains("-sT") else {
      return invalid(
        "Nieobsługiwany typ skanu Nmap.",
        hint: "Użyj -sn do wykrywania albo -sT [-sV] [-p porty] <host>."
      )
    }

    var showVersions = false
    var showReason = false
    var requestedPorts: Set<UInt16>?
    var target: String?
    var index = 0

    while index < arguments.count {
      switch arguments[index] {
      case "-sT":
        break
      case "-sV":
        showVersions = true
      case "-Pn", "--open":
        break
      case "--reason":
        showReason = true
      case "-p":
        index += 1
        guard index < arguments.count,
              let ports = parsePorts(arguments[index])
        else {
          return invalid("Nieprawidłowa lista portów.", hint: "Przykład: -p 22,80,443.")
        }
        requestedPorts = ports
      default:
        guard !arguments[index].hasPrefix("-"), target == nil else {
          return invalid(
            "Nieobsługiwana opcja Nmap: \(arguments[index]).",
            hint: "Do wykrywania usług dodaj -sV."
          )
        }
        target = arguments[index]
      }
      index += 1
    }

    guard let target, let host = network.host(at: target) else {
      return invalid("Host nie istnieje w laboratorium.", hint: "Wybierz host znaleziony przez nmap -sn.")
    }

    let services = host.services.filter { requestedPorts?.contains($0.port) ?? true }
    let rows = services.map { service in
      let version = showVersions ? service.version.map { " \($0)" } ?? "" : ""
      let reason = showReason ? " syn-ack" : ""
      return "\(service.port)/\(service.transport) open \(service.name)\(version)\(reason)"
    }
    let output = (["Nmap scan report for \(host.hostname) (\(host.address))", "PORT STATE SERVICE"] + rows)
      .joined(separator: "\n")
    return success(
      output,
      explanations: [
        .init(term: "-sT", meaning: "Symuluje pełne połączenie TCP z portami hosta."),
        .init(term: "-sV", meaning: "Pokazuje wersję usługi, jeśli laboratorium ją zna."),
      ] + (showReason ? [.init(term: "--reason", meaning: "Wyjaśnia, z czego wynika stan portu.")] : [])
    )
  }

  private func resolveNuclei(_ arguments: [String]) -> VirtualCommandResult {
    guard case .nuclei(let target, let tags)? = LabCommandIntent.parse(
      (["nuclei"] + arguments).joined(separator: " ")
    ), let components = URLComponents(string: target),
       let hostName = components.host, network.host(at: hostName) != nil
    else {
      return invalid(
        "Cel Nuclei nie należy do sieci demonstracyjnej.",
        hint: "Użyj nuclei -u http://web.lab -tags misconfiguration."
      )
    }

    let tagList = tags.isEmpty ? "domyślne" : tags.joined(separator: ",")
    return success(
      "[symulacja] \(target) [\(tagList)] konfiguracja wymaga uwagi",
      explanations: [
        .init(term: "-u", meaning: "Wskazuje pojedynczy cel w sieci demo."),
        .init(term: "-tags", meaning: "Wybiera kategorie szablonów bez kontaktu z Internetem."),
      ]
    )
  }

  private func resolvePing(_ arguments: [String]) -> VirtualCommandResult {
    guard arguments.count == 1, let host = network.host(at: arguments[0]) else {
      return invalid("Nie można odnaleźć hosta w laboratorium.", hint: "Podaj jeden adres wykryty przez nmap -sn.")
    }
    return success(
      "64 bytes from \(host.address): icmp_seq=1 ttl=64 time=1.0 ms",
      explanations: [.init(term: "ping", meaning: "Sprawdza w symulacji, czy host odpowiada.")]
    )
  }

  private func resolveDig(_ arguments: [String]) -> VirtualCommandResult {
    if arguments.count == 2, arguments[0] == "-x" {
      guard let host = network.host(at: arguments[1]) else {
        return invalid("NXDOMAIN: adres nie istnieje w sieci demonstracyjnej.", hint: "Użyj adresu hosta znalezionego w laboratorium.")
      }
      return success(
        "\(host.address).in-addr.arpa. 60 IN PTR \(host.hostname).",
        explanations: [.init(term: "-x", meaning: "Pyta o nazwę przypisaną do adresu IP.")]
      )
    }

    guard case .dig(let name, let type, let server, let short)? = LabCommandIntent.parse(
      (["dig"] + arguments).joined(separator: " ")
    ) else {
      return invalid("Nieprawidłowe zapytanie Dig.", hint: "Użyj dig [@serwer] <nazwa> <typ> [+short].")
    }
    if let server, network.host(at: server) == nil {
      return invalid("Serwer DNS nie istnieje w laboratorium.", hint: "Użyj @router.lab.")
    }
    let records = network.records(named: name, type: type)
    guard !records.isEmpty else {
      return invalid("NXDOMAIN: \(name) nie istnieje w strefie demonstracyjnej.", hint: "Sprawdź pisownię nazwy i typ rekordu.")
    }
    let output = short
      ? records.map(\.value).joined(separator: "\n")
      : records.map { "\($0.name). 60 IN \($0.type) \($0.value)" }.joined(separator: "\n")
    return success(output, explanations: [
      .init(term: type, meaning: "Wybiera typ rekordu DNS."),
      .init(term: name, meaning: "Nazwa w lokalnej strefie demonstracyjnej."),
    ])
  }

  private func resolveSSH(_ arguments: [String]) -> VirtualCommandResult {
    guard arguments.count == 1 else {
      return invalid("Nieprawidłowe polecenie SSH.", hint: "Użyj ssh <użytkownik>@<host>.")
    }
    let parts = arguments[0].split(separator: "@", omittingEmptySubsequences: false)
    guard parts.count == 2, !parts[0].isEmpty,
          let host = network.host(at: String(parts[1])),
          host.services.contains(where: { $0.port == 22 && $0.name == "ssh" })
    else {
      return invalid("Host nie udostępnia SSH w laboratorium.", hint: "Najpierw znajdź host z otwartym portem 22.")
    }
    return success(
      "Połączenie demonstracyjne z \(parts[0])@\(host.hostname). Żadne dane logowania nie zostały wysłane.",
      explanations: [.init(term: "ssh", meaning: "Symuluje bezpieczne zdalne logowanie do hosta.")]
    )
  }

  private func resolveCurl(_ arguments: [String]) -> VirtualCommandResult {
    guard case .curl(let method, let url, _, _, let head, let follow, let timeout)? = LabCommandIntent.parse(
      (["curl"] + arguments.map(shellQuote)).joined(separator: " ")
    ), let components = URLComponents(string: url),
       let host = components.host,
       components.scheme == "http" || components.scheme == "https"
    else {
      return invalid("Nieprawidłowe żądanie Curl.", hint: "Podaj lokalny adres http://web.lab lub http://api.lab.")
    }
    guard timeout == nil || timeout! > 0 else {
      return invalid("Limit czasu musi być dodatni.", hint: "Przykład: --max-time 5.")
    }
    let path = components.path.isEmpty ? "/" : components.path
    guard var endpoint = network.endpoint(host: host, path: path, method: method) else {
      return invalid("Cel nie istnieje w wirtualnej sieci HTTP.", hint: "Użyj hosta web.lab albo api.lab.")
    }
    if follow, let redirectPath = endpoint.redirectPath,
       let redirected = network.endpoint(host: host, path: redirectPath, method: "GET") {
      endpoint = redirected
    }
    let reason = switch endpoint.status {
    case 200: "OK"
    case 201: "Created"
    case 302: "Found"
    default: "Demo"
    }
    var rows = ["HTTP/1.1 \(endpoint.status) \(reason)", "Content-Type: application/json"]
    if !head && !endpoint.body.isEmpty { rows.append("\n\(endpoint.body)") }
    return success(rows.joined(separator: "\n"), explanations: [
      .init(term: method, meaning: "Metoda żądania wykonywana wyłącznie w lokalnej symulacji."),
      .init(term: "Cel", meaning: "\(host)\(endpoint.path) należy do wirtualnej sieci Northbyte Radar."),
    ])
  }

  private func shellQuote(_ token: String) -> String {
    token.contains(where: \.isWhitespace) ? "'\(token)'" : token
  }

  private func parsePorts(_ value: String) -> Set<UInt16>? {
    let parts = value.split(separator: ",", omittingEmptySubsequences: false)
    guard !parts.isEmpty else { return nil }
    let ports = parts.compactMap { part -> UInt16? in
      guard let port = UInt16(part), port > 0 else { return nil }
      return port
    }
    return ports.count == parts.count ? Set(ports) : nil
  }

  private var supportedCommandsHint: String {
    "Dostępne: nmap, nuclei, ping, dig, curl i ssh."
  }

  private func success(
    _ output: String,
    explanations: [VirtualExplanation]
  ) -> VirtualCommandResult {
    .init(status: .success, output: output, hint: nil, explanations: explanations)
  }

  private func invalid(_ output: String, hint: String) -> VirtualCommandResult {
    .init(status: .invalid, output: output, hint: hint, explanations: [])
  }
}
