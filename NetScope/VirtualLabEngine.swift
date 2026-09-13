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
    let tokens = input.split(whereSeparator: \.isWhitespace).map(String.init)
    guard let executable = tokens.first else {
      return invalid("Wpisz polecenie.", hint: "Dostępne: nmap, ping, dig i ssh.")
    }

    let arguments = Array(tokens.dropFirst())
    return switch executable.lowercased() {
    case "nmap": resolveNmap(arguments)
    case "ping": resolvePing(arguments)
    case "dig": resolveDig(arguments)
    case "ssh": resolveSSH(arguments)
    default:
      VirtualCommandResult(
        status: .unsupported,
        output: "Laboratorium nie wykonuje tego polecenia.",
        hint: "Dostępne: nmap, ping, dig i ssh.",
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
    var requestedPorts: Set<UInt16>?
    var target: String?
    var index = 0

    while index < arguments.count {
      switch arguments[index] {
      case "-sT":
        break
      case "-sV":
        showVersions = true
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
      return "\(service.port)/\(service.transport) open \(service.name)\(version)"
    }
    let output = (["Nmap scan report for \(host.hostname) (\(host.address))", "PORT STATE SERVICE"] + rows)
      .joined(separator: "\n")
    return success(
      output,
      explanations: [
        .init(term: "-sT", meaning: "Symuluje pełne połączenie TCP z portami hosta."),
        .init(term: "-sV", meaning: "Pokazuje wersję usługi, jeśli laboratorium ją zna."),
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
    guard arguments.count == 2, arguments[0] == "-x",
          let host = network.host(at: arguments[1])
    else {
      return invalid("Nieprawidłowe zapytanie reverse DNS.", hint: "Użyj dig -x <adres hosta>.")
    }
    return success(
      "\(host.address).in-addr.arpa. 60 IN PTR \(host.hostname).",
      explanations: [.init(term: "-x", meaning: "Pyta o nazwę przypisaną do adresu IP.")]
    )
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

  private func parsePorts(_ value: String) -> Set<UInt16>? {
    let parts = value.split(separator: ",", omittingEmptySubsequences: false)
    guard !parts.isEmpty else { return nil }
    let ports = parts.compactMap { UInt16($0) }
    return ports.count == parts.count ? Set(ports) : nil
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
