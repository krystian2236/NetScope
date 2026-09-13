import Foundation

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
       let separator = tokens[1].firstIndex(of: "@")
    {
      let user = String(tokens[1][..<separator])
      let host = String(tokens[1][tokens[1].index(after: separator)...])
      guard !user.isEmpty, !host.isEmpty else { return nil }
      return .connectSSH(user: user, host: host)
    }
    return parseInspection(tokens)
  }

  private static func parseInspection(_ tokens: [String]) -> LabCommandIntent? {
    guard tokens.count >= 3, tokens.first == "nmap", tokens.contains("-sT"),
          let host = tokens.last, !host.hasPrefix("-")
    else { return nil }

    let versions = tokens.contains("-sV")
    var ports: [UInt16] = []
    if let index = tokens.firstIndex(of: "-p") {
      guard tokens.indices.contains(index + 1) else { return nil }
      let values = tokens[index + 1].split(separator: ",", omittingEmptySubsequences: false)
      ports = values.compactMap { UInt16($0) }
      guard ports.count == values.count else { return nil }
    }
    return .inspect(host: host, ports: ports.sorted(), versions: versions)
  }
}

enum LabCommandSegmentCategory: String, Equatable, Sendable {
  case tool
  case scanType
  case option
  case target
  case user

  var title: String {
    switch self {
    case .tool: "Narzędzie"
    case .scanType: "Typ skanu"
    case .option: "Opcja"
    case .target: "Cel"
    case .user: "Użytkownik"
    }
  }

  var icon: String {
    switch self {
    case .tool: "terminal"
    case .scanType: "dot.radiowaves.left.and.right"
    case .option: "slider.horizontal.3"
    case .target: "scope"
    case .user: "person.fill"
    }
  }
}

struct LabCommandSegment: Equatable, Sendable {
  let category: LabCommandSegmentCategory
  let value: String
  let explanation: String
}

struct LabCommandPresentation: Equatable, Sendable {
  let command: String
  let segments: [LabCommandSegment]

  init(intent: LabCommandIntent) {
    switch intent {
    case .discover(let cidr):
      command = "nmap -sn \(cidr)"
      segments = [
        .init(category: .tool, value: "nmap", explanation: "Program do rozpoznawania sieci i usług."),
        .init(category: .scanType, value: "-sn", explanation: "Wykrywa aktywne hosty bez skanowania portów."),
        .init(category: .target, value: cidr, explanation: "Sieć demonstracyjna, w której wyszukiwane są hosty."),
      ]
    case .inspect(let host, let ports, let versions):
      var commandParts = ["nmap", "-sT"]
      var commandSegments: [LabCommandSegment] = [
        .init(category: .tool, value: "nmap", explanation: "Program do rozpoznawania sieci i usług."),
        .init(category: .scanType, value: "-sT", explanation: "Pełne połączenie TCP używane bez uprawnień administratora."),
      ]
      if versions {
        commandParts.append("-sV")
        commandSegments.append(
          .init(category: .option, value: "-sV", explanation: "Rozpoznaje usługę i jej wersję.")
        )
      }
      if !ports.isEmpty {
        let value = ports.map(String.init).joined(separator: ",")
        commandParts.append(contentsOf: ["-p", value])
        commandSegments.append(
          .init(category: .option, value: "-p \(value)", explanation: "Ogranicza sprawdzenie do portów \(value.replacingOccurrences(of: ",", with: " i ")).")
        )
      }
      commandParts.append(host)
      commandSegments.append(
        .init(category: .target, value: host, explanation: "Host analizowany w sieci demonstracyjnej.")
      )
      command = commandParts.joined(separator: " ")
      segments = commandSegments
    case .connectSSH(let user, let host):
      command = "ssh \(user)@\(host)"
      segments = [
        .init(category: .tool, value: "ssh", explanation: "Program do bezpiecznego zdalnego logowania."),
        .init(category: .user, value: user, explanation: "Nazwa konta używana podczas logowania."),
        .init(category: .target, value: host, explanation: "Host, z którym ma zostać nawiązane połączenie."),
      ]
    }
  }
}

struct LabMission: Identifiable, Equatable, Sendable {
  let id: String
  let title: String
  let summary: String
  let isPro: Bool
  let steps: [LabStep]

  static let demo: [LabMission] = [
    LabMission(
      id: "host-discovery",
      title: "Znajdź urządzenia",
      summary: "Poznaj aktywne hosty w bezpiecznej sieci demonstracyjnej.",
      isPro: false,
      steps: [
        LabStep(
          id: "discover",
          objective: "Wykryj hosty w sieci 192.168.50.0/24.",
          hints: ["Nmap może wykryć hosty bez skanowania portów.", "Użyj opcji -sn."],
          acceptedIntent: .discover(cidr: "192.168.50.0/24"),
          explanation: "-sn wykonuje wykrywanie hostów bez skanowania ich portów."
        )
      ]
    ),
    LabMission(
      id: "ports-services",
      title: "Rozpoznaj usługi",
      summary: "Sprawdź porty i nazwy usług serwera WWW.",
      isPro: false,
      steps: [
        LabStep(
          id: "inspect-web",
          objective: "Sprawdź porty 22 i 80 oraz wersje usług hosta 192.168.50.20.",
          hints: ["Pełne połączenie TCP wybiera -sT.", "Wersje pokazuje -sV, a porty wybiera -p."],
          acceptedIntent: .inspect(host: "192.168.50.20", ports: [22, 80], versions: true),
          explanation: "Połączenie -sT potwierdza porty, a -sV opisuje wykryte usługi."
        )
      ]
    ),
    LabMission(
      id: "ssh-basics",
      title: "Połącz się przez SSH",
      summary: "Przećwicz składnię zdalnego logowania bez wysyłania danych.",
      isPro: false,
      steps: [
        LabStep(
          id: "connect",
          objective: "Połącz użytkownika learner z hostem mac.lab.",
          hints: ["SSH używa zapisu użytkownik@host.", "W laboratorium użyj użytkownika learner."],
          acceptedIntent: .connectSSH(user: "learner", host: "mac.lab"),
          explanation: "SSH łączy nazwę użytkownika i hosta znakiem @; tutaj połączenie jest wyłącznie symulowane."
        )
      ]
    ),
  ]
}
