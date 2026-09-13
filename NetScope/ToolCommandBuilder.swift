import Foundation

enum ToolCommandBuilder {
  static func build(tool: ToolDefinition, selection: ToolSelection) -> ToolCommandDraft {
    let selectedOptions = tool.options
      .filter { selection.selectedOptionIDs.contains($0.id) }
      .sorted { lhs, rhs in
        lhs.order == rhs.order ? lhs.id < rhs.id : lhs.order < rhs.order
      }

    var fragments = [
      ToolCommandFragment(
        position: 1,
        optionID: nil,
        value: tool.executable,
        role: .required,
        explanation: "Uruchamia program \(tool.title)."
      )
    ]
    var warnings: [String] = []
    var errors: [String] = []

    for option in selectedOptions {
      let rawValue = selection.values[option.id]
      let error = selectionError(
        for: option,
        rawValue: rawValue,
        selectedOptionIDs: selection.selectedOptionIDs,
        tool: tool
      )
      let fragmentValue = renderedFragment(for: option, rawValue: rawValue)

      if let error { errors.append(error) }
      switch option.risk {
      case .standard:
        break
      case .caution(let reason), .advanced(let reason):
        warnings.append(reason)
      }
      if option.id == "target",
         let target = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines),
         !target.isEmpty,
         !ISHTargetValidator.isPrivate(target) {
        warnings.append("Cel nie został rozpoznany jako prywatny. Uruchamiaj polecenie tylko za zgodą właściciela.")
      }

      fragments.append(
        ToolCommandFragment(
          position: fragments.count + 1,
          optionID: option.id,
          value: fragmentValue,
          role: error == nil ? role(for: option, rawValue: rawValue) : .invalid,
          explanation: error ?? explanation(for: option)
        )
      )
    }

    let validFragments = fragments.filter { $0.role != .invalid }
    return ToolCommandDraft(
      command: validFragments.map(\.value).joined(separator: " "),
      fragments: fragments,
      explanation: validFragments.map(\.explanation).joined(separator: " "),
      warnings: unique(warnings),
      errors: unique(errors)
    )
  }

  private static func selectionError(
    for option: ToolOptionDefinition,
    rawValue: String?,
    selectedOptionIDs: Set<String>,
    tool: ToolDefinition
  ) -> String? {
    let conflicts = option.conflictsWithOptionIDs.intersection(selectedOptionIDs)
    if !conflicts.isEmpty {
      let names = tool.options
        .filter { conflicts.contains($0.id) }
        .map(\.canonicalFlag)
        .filter { !$0.isEmpty }
        .joined(separator: ", ")
      return "Opcja \(option.canonicalFlag) jest sprzeczna z: \(names)."
    }

    let missing = option.requiresOptionIDs.subtracting(selectedOptionIDs)
    if !missing.isEmpty {
      let names = tool.options
        .filter { missing.contains($0.id) }
        .map(\.canonicalFlag)
        .filter { !$0.isEmpty }
        .joined(separator: ", ")
      return "Opcja \(option.canonicalFlag) wymaga: \(names)."
    }
    if tool.id == "nmap", option.id == "ports",
       let value = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines),
       !value.isEmpty, !validNmapPorts(value) {
      return "Nieprawidłowy zakres portów. Użyj np. 22, 22,80,443 albo 1-1024."
    }
    return validationError(for: option, rawValue: rawValue)
  }

  private static func validNmapPorts(_ value: String) -> Bool {
    value.split(separator: ",", omittingEmptySubsequences: false).allSatisfy { item in
      let cleanItem = item.trimmingCharacters(in: .whitespaces)
      let protocolPrefix = cleanItem.range(of: #"^[TUSP]:"#, options: .regularExpression)
      let ports = protocolPrefix.map { String(cleanItem[$0.upperBound...]) } ?? cleanItem
      let bounds = ports.split(separator: "-", omittingEmptySubsequences: false)
      guard (1...2).contains(bounds.count) else { return false }
      return bounds.allSatisfy { part in
        guard let port = Int(part), (1...65_535).contains(port) else { return false }
        return String(port) == part
      }
    }
  }

  private static func validationError(
    for option: ToolOptionDefinition,
    rawValue: String?
  ) -> String? {
    guard !option.canonicalFlag.isEmpty || option.id == "target" else {
      return "Opcja \(option.title) nie ma zdefiniowanej flagi."
    }
    guard option.valueKind.requiresValue else { return nil }

    let value = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    guard !value.isEmpty else {
      return "Uzupełnij wartość dla \(option.canonicalFlag)."
    }

    switch option.valueKind {
    case .none, .text, .path, .list, .secret:
      return nil
    case .integer(let range, _):
      guard let number = Int(value), range.contains(number) else {
        return "Wartość dla \(option.canonicalFlag) musi być liczbą od \(range.lowerBound) do \(range.upperBound)."
      }
    case .duration:
      let pattern = #"^[1-9][0-9]*(ms|s|m|h)$"#
      guard value.range(of: pattern, options: .regularExpression) != nil else {
        return "Wartość dla \(option.canonicalFlag) podaj jako czas, np. 30s lub 2m."
      }
    case .choice(let values, _):
      guard values.contains(value) else {
        return "Wybierz dla \(option.canonicalFlag): \(values.joined(separator: ", "))."
      }
    }
    return nil
  }

  private static func renderedFragment(
    for option: ToolOptionDefinition,
    rawValue: String?
  ) -> String {
    guard option.valueKind.requiresValue else { return option.canonicalFlag }
    let value = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if option.id == "target", option.canonicalFlag.isEmpty { return quoted(value) }
    switch option.valuePlacement {
    case .separated:
      return "\(option.canonicalFlag) \(quoted(value))"
    case .attached:
      return "\(option.canonicalFlag)\(value)"
    case .equals:
      return "\(option.canonicalFlag)=\(quoted(value))"
    }
  }

  private static func role(
    for option: ToolOptionDefinition,
    rawValue: String?
  ) -> ToolCommandFragmentRole {
    if option.id == "target" {
      let target = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      return ISHTargetValidator.isPrivate(target) ? .target : .caution
    }
    switch option.risk {
    case .standard: return .additional
    case .caution, .advanced: return .caution
    }
  }

  private static func explanation(for option: ToolOptionDefinition) -> String {
    if let requirements = option.requirements {
      return "\(option.title): \(option.summary) Wymagania: \(requirements)"
    }
    return "\(option.title): \(option.summary)"
  }

  private static func quoted(_ value: String) -> String {
    "'\(value.replacingOccurrences(of: "'", with: "'\"'\"'"))'"
  }

  private static func unique(_ values: [String]) -> [String] {
    var seen: Set<String> = []
    return values.filter { seen.insert($0).inserted }
  }
}
