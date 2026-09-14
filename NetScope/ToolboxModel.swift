enum ToolboxEntry: String, CaseIterable, Equatable, Sendable {
  case nmap, nuclei, dig, curl

  var title: String {
    switch self {
    case .nmap: "Nmap"
    case .nuclei: "Nuclei"
    case .dig: "Dig"
    case .curl: "Curl"
    }
  }

  var subtitle: String {
    switch self {
    case .nmap: "Wybieraj opcje według kategorii"
    case .nuclei: "Buduj kontrole oparte na szablonach"
    case .dig: "Poznawaj zapytania i odpowiedzi DNS"
    case .curl: "Buduj żądania i analizuj odpowiedzi"
    }
  }

  var icon: String {
    switch self {
    case .nmap: "scope"
    case .nuclei: "checkmark.shield"
    case .dig: "globe"
    case .curl: "arrow.left.arrow.right"
    }
  }

  var tileTone: ToolboxTileTone {
    switch self {
    case .nmap: .cyan
    case .nuclei: .indigo
    case .dig: .teal
    case .curl: .orange
    }
  }
}

enum ToolboxTileTone: String, Equatable, Sendable {
  case cyan, indigo, teal, orange
}

enum ToolboxInitialTarget {
  static func resolve(storedFavourite: String, detectedTarget: String) -> String {
    let favourite = storedFavourite.trimmingCharacters(in: .whitespacesAndNewlines)
    return favourite.isEmpty ? detectedTarget : favourite
  }
}

enum ToolboxPresetValues {
  static func targetOptions(in tool: ToolDefinition) -> [ToolOptionDefinition] {
    let targetCategoryIDs: Set<String>
    switch tool.id {
    case "nmap", "nuclei": targetCategoryIDs = ["target"]
    case "dig": targetCategoryIDs = ["name"]
    case "curl": targetCategoryIDs = ["url"]
    default:
      targetCategoryIDs = Set(
        tool.usageParts.compactMap { part -> [String]? in
          guard case .section(let section) = part, section.tone == .target else { return nil }
          return section.categoryIDs
        }.flatMap { $0 }
      )
    }

    return tool.options.filter { targetCategoryIDs.contains($0.categoryID) }
  }

  static func presetOptions(in tool: ToolDefinition) -> [ToolOptionDefinition] {
    if tool.id == "nuclei" {
      return tool.options.filter(\.valueKind.requiresValue)
    }
    return targetOptions(in: tool)
  }

  static func values(
    for tool: ToolDefinition,
    primaryTarget: String,
    overrides: [String: String] = [:]
  ) -> [String: String] {
    var values = presetOptions(in: tool).reduce(into: [String: String]()) { result, option in
      guard option.valueKind.requiresValue, let example = option.valueKind.example else { return }
      result[option.id] = example
    }

    switch tool.id {
    case "nmap":
      values["target"] = "192.168.05.10"
      values["input-list"] = "gurk-agi-7777.txt"
      values["random-targets"] = "08"
      values["exclude"] = "192.168.22.36"
      values["exclude-file"] = "maet-ysazcurk-7777.txt"
    case "nuclei":
      values["target"] = "https://gurk-naitsyrk-7777.example.test"
      values["list"] = "gurk-agi-7777.txt"
      values["targets-inline"] = "192.168.05.10,192.168.22.36"
      values["exclude-hosts"] = "192.168.22.36"
      values["resume"] = "7777-0510-2236.cfg"
      values["ip-version"] = "4"
      values["prompt"] = "check the security headers"
      values["exclude-id"] = "gurk-template-7777"
      values["header"] = "X-Lab: 7777"
      values["source-ip"] = "192.168.05.10"
      values["interactsh-token"] = "fake-token-7777"
      values["dast-server-token"] = "fake-token-7777"
      values["team-id"] = "maet-ysazcurk"
      values["scan-id"] = "7777-2236"
      values["scan-name"] = "maet-ysazcurk-7777"
      values["secret-file"] = "fictional-secrets.yaml"
    case "dig":
      values["target"] = "maet-ysazcurk-7777.example.test"
    case "curl":
      values["target"] = "https://gurk-agi-7777.example.test/0510/2236/7777"
    default:
      break
    }
    if (values["target"] ?? "").isEmpty,
       !primaryTarget.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      values["target"] = primaryTarget.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    for (optionID, value) in overrides {
      let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
      if !trimmed.isEmpty { values[optionID] = trimmed }
    }
    return values
  }

  static func targetValues(
    for tool: ToolDefinition,
    primaryTarget: String,
    overrides: [String: String] = [:]
  ) -> [String: String] {
    values(for: tool, primaryTarget: primaryTarget, overrides: overrides)
  }

  static func initialSelection(
    for tool: ToolDefinition,
    presetValues: [String: String]
  ) -> ToolSelection {
    let validOptionIDs = Set(tool.options.map(\.id))
    return ToolSelection(
      selectedOptionIDs: [],
      values: presetValues.filter { validOptionIDs.contains($0.key) }
    )
  }
}

enum ToolTerminalGuidance {
  static func exampleCommand(
    for option: ToolOptionDefinition,
    executable: String
  ) -> String {
    let example = option.valueKind.example ?? "wartość"
    let argument: String
    if option.flags.isEmpty || option.canonicalFlag.isEmpty {
      argument = example
    } else if option.valuePlacement == .attached || option.valuePlacement == .equals {
      let separator = option.valuePlacement == .equals ? "=" : ""
      argument = "\(option.canonicalFlag)\(separator)\(example)"
    } else {
      argument = "\(option.canonicalFlag) \(example)"
    }
    return "\(executable) \(argument)"
  }
}
