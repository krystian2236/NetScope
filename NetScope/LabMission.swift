import Foundation

struct LabStep: Identifiable, Equatable, Sendable {
  let id: String
  let objective: String
  let hints: [String]
  let acceptedIntent: LabCommandIntent
  let explanation: String
  var expectsFailure = false

  func accepts(command: String, result: VirtualCommandResult) -> Bool {
    let expectedStatus: VirtualCommandResult.Status = expectsFailure ? .invalid : .success
    return result.status == expectedStatus && LabCommandIntent.parse(command) == acceptedIntent
  }
}

enum LabCommandIntent: Equatable, Sendable {
  case discover(cidr: String)
  case inspect(host: String, ports: [UInt16], versions: Bool)
  case nmapDiagnostic(host: String)
  case nuclei(target: String, tags: [String])
  case dig(name: String, type: String, server: String?, short: Bool)
  case curl(method: String, url: String, headers: [String], body: String?, head: Bool, follow: Bool, timeout: Int?)
  case connectSSH(user: String, host: String)

  static func parse(_ command: String) -> LabCommandIntent? {
    let tokens = LabCommandTokenizer.tokenize(command)
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
    if let nuclei = parseNuclei(tokens) { return nuclei }
    if let dig = parseDig(tokens) { return dig }
    if let curl = parseCurl(tokens) { return curl }
    if tokens.first == "nmap",
       tokens.contains("-sT"), tokens.contains("-Pn"),
       tokens.contains("--open"), tokens.contains("--reason"),
       let host = tokens.last, !host.hasPrefix("-")
    {
      return .nmapDiagnostic(host: host)
    }
    return parseInspection(tokens)
  }

  private static func parseNuclei(_ tokens: [String]) -> LabCommandIntent? {
    guard tokens.first == "nuclei" else { return nil }
    var target: String?
    var tags: [String] = []
    var index = 1
    while index < tokens.count {
      switch tokens[index] {
      case "-u", "-url":
        index += 1
        guard index < tokens.count else { return nil }
        target = tokens[index]
      case "-tags":
        index += 1
        guard index < tokens.count else { return nil }
        tags = tokens[index].split(separator: ",").map(String.init).sorted()
      default: return nil
      }
      index += 1
    }
    guard let target else { return nil }
    return .nuclei(target: target, tags: tags)
  }

  private static func parseDig(_ tokens: [String]) -> LabCommandIntent? {
    guard tokens.first == "dig" else { return nil }
    if tokens.count == 3, tokens[1] == "-x" {
      return .dig(name: tokens[2], type: "PTR", server: nil, short: false)
    }
    var server: String?
    var short = false
    var values: [String] = []
    for token in tokens.dropFirst() {
      if token.hasPrefix("@") {
        guard server == nil, token.count > 1 else { return nil }
        server = String(token.dropFirst())
      } else if token == "+short" {
        short = true
      } else {
        values.append(token)
      }
    }
    guard values.count == 2 else { return nil }
    return .dig(name: values[0], type: values[1].uppercased(), server: server, short: short)
  }

  private static func parseCurl(_ tokens: [String]) -> LabCommandIntent? {
    guard tokens.first == "curl" else { return nil }
    var method = "GET"
    var headers: [String] = []
    var body: String?
    var head = false
    var follow = false
    var timeout: Int?
    var url: String?
    var index = 1
    while index < tokens.count {
      switch tokens[index] {
      case "-X", "--request":
        index += 1; guard index < tokens.count else { return nil }
        method = tokens[index].uppercased()
      case "-H", "--header":
        index += 1; guard index < tokens.count else { return nil }
        headers.append(tokens[index])
      case "-d", "--data":
        index += 1; guard index < tokens.count else { return nil }
        body = tokens[index]
        if method == "GET" { method = "POST" }
      case "-I", "--head":
        head = true; method = "HEAD"
      case "-L", "--location":
        follow = true
      case "--max-time":
        index += 1; guard index < tokens.count, let value = Int(tokens[index]) else { return nil }
        timeout = value
      default:
        guard !tokens[index].hasPrefix("-"), url == nil else { return nil }
        url = tokens[index]
      }
      index += 1
    }
    guard let url else { return nil }
    return .curl(method: method, url: url, headers: headers, body: body, head: head, follow: follow, timeout: timeout)
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
    case .nmapDiagnostic(let host):
      command = "nmap -sT -Pn --open --reason \(host)"
      segments = [
        .init(category: .tool, value: "nmap", explanation: "Program do rozpoznawania sieci i usług."),
        .init(category: .scanType, value: "-sT", explanation: "Pełne połączenie TCP bez surowych pakietów."),
        .init(category: .option, value: "-Pn", explanation: "Pomija wcześniejsze wykrywanie dostępności hosta."),
        .init(category: .option, value: "--open", explanation: "Ogranicza wynik do otwartych portów."),
        .init(category: .option, value: "--reason", explanation: "Wyjaśnia przyczynę rozpoznanego stanu."),
        .init(category: .target, value: host, explanation: "Host w bezpiecznej sieci demonstracyjnej."),
      ]
    case .nuclei(let target, let tags):
      command = "nuclei -u \(target) -tags \(tags.joined(separator: ","))"
      segments = [
        .init(category: .tool, value: "nuclei", explanation: "Silnik kontroli opartych na szablonach."),
        .init(category: .target, value: target, explanation: "Wirtualny serwer HTTP w laboratorium."),
        .init(category: .option, value: "-tags \(tags.joined(separator: ","))", explanation: "Ogranicza szablony do wybranej kategorii."),
      ]
    case .dig(let name, let type, let server, let short):
      var parts = ["dig"]
      var commandSegments = [
        LabCommandSegment(category: .tool, value: "dig", explanation: "Program do wykonywania zapytań DNS."),
      ]
      if let server {
        parts.append("@\(server)")
        commandSegments.append(.init(category: .option, value: "@\(server)", explanation: "Wybiera serwer DNS w sieci demonstracyjnej."))
      }
      if type.uppercased() == "PTR" {
        parts.append(contentsOf: ["-x", name])
        commandSegments.append(.init(category: .option, value: "-x", explanation: "Wykonuje odwrotne wyszukiwanie DNS dla adresu IP."))
        commandSegments.append(.init(category: .target, value: name, explanation: "Adres IP sprawdzany w lokalnej strefie demonstracyjnej."))
      } else {
        parts.append(contentsOf: [name, type])
        commandSegments.append(.init(category: .target, value: name, explanation: "Nazwa sprawdzana w lokalnej strefie demonstracyjnej."))
        commandSegments.append(.init(category: .option, value: type, explanation: "Typ rekordu DNS."))
      }
      if short {
        parts.append("+short")
        commandSegments.append(.init(category: .option, value: "+short", explanation: "Pokazuje wyłącznie wartości odpowiedzi."))
      }
      command = parts.joined(separator: " ")
      segments = commandSegments
    case .curl(let method, let url, let headers, let body, let head, let follow, let timeout):
      var parts = ["curl"]
      var commandSegments = [LabCommandSegment(category: .tool, value: "curl", explanation: "Klient żądań HTTP w laboratorium.")]
      if method != "GET" && !head {
        parts.append(contentsOf: ["-X", method])
        commandSegments.append(.init(category: .scanType, value: method, explanation: "Metoda żądania HTTP."))
      }
      for header in headers {
        parts.append(contentsOf: ["-H", "'\(header)'"])
        commandSegments.append(.init(category: .option, value: "-H", explanation: "Dodaje nagłówek bez zapisywania sekretów."))
      }
      if let body {
        parts.append(contentsOf: ["-d", "'\(body)'"])
        commandSegments.append(.init(category: .option, value: "-d", explanation: "Dodaje ciało żądania."))
      }
      if head { parts.append("-I") }
      if follow { parts.append("-L") }
      if let timeout { parts.append(contentsOf: ["--max-time", String(timeout)]) }
      parts.append(url)
      commandSegments.append(.init(category: .target, value: url, explanation: "Lokalny endpoint wirtualnej sieci."))
      command = parts.joined(separator: " ")
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

enum LabCommandTokenizer {
  static func tokenize(_ command: String) -> [String] {
    var tokens: [String] = []
    var current = ""
    var quote: Character?
    for character in command {
      if let activeQuote = quote {
        if character == activeQuote { quote = nil } else { current.append(character) }
      } else if character == "'" || character == "\"" {
        quote = character
      } else if character.isWhitespace {
        if !current.isEmpty { tokens.append(current); current = "" }
      } else {
        current.append(character)
      }
    }
    guard quote == nil else { return [] }
    if !current.isEmpty { tokens.append(current) }
    return tokens
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

struct LabBriefing: Equatable, Sendable {
  let target: String
  let objectives: [String]

  var stepCountLabel: String {
    objectives.count == 1 ? "1 krok" : "\(objectives.count) kroki"
  }

  init(mission: LabMission) {
    objectives = mission.steps.map(\.objective)
    target = mission.steps.first.map { step in
      switch step.acceptedIntent {
      case .discover(let cidr): cidr
      case .inspect(let host, _, _): host
      case .nmapDiagnostic(let host): host
      case .nuclei(let target, _): target
      case .dig(let name, _, _, _): name
      case .curl(_, let url, _, _, _, _, _): url
      case .connectSSH(_, let host): host
      }
    } ?? VirtualNetwork.demo.cidr
  }
}

struct TerminalLessonPresentation: Equatable, Sendable {
  let lessonDescription: String
  let taskDescription: String
  let terminalPrompt: String

  init(mission: LabMission, activeStep: LabStep?) {
    lessonDescription = mission.summary
    taskDescription = activeStep?.objective ?? "Wszystkie zadania tej lekcji są ukończone."
    terminalPrompt = "Terminal czeka. Wybierz gotowe polecenie albo wpisz własne."
  }
}
