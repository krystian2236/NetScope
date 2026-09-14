import Foundation

enum ToolCompatibilityEvaluator {
  private static let nmapTCPBaseIDs: Set<String> = [
    "tcp-syn", "tcp-connect", "tcp-ack", "tcp-window", "tcp-maimon",
    "tcp-null", "tcp-fin", "tcp-xmas",
  ]
  private static let nmapSCTPIDs: Set<String> = ["sctp-init", "sctp-cookie"]
  private static let nmapExclusiveIDs: Set<String> = [
    "idle-scan", "ip-protocol-scan", "ftp-bounce",
  ]

  static func presentationState(
    for option: ToolOptionDefinition,
    in tool: ToolDefinition,
    selection: ToolSelection
  ) -> ToolOptionPresentationState {
    let selected = selection.selectedOptionIDs.contains(option.id)
    guard let issue = issue(
      for: option,
      in: tool,
      selection: selection,
      validateValue: selected
    ) else {
      return selected ? .selectedValid : .compatible
    }

    switch issue {
    case .conflict(let message): return .conflicting(message)
    case .incomplete(let message): return .incomplete(message)
    }
  }

  static func issue(
    for option: ToolOptionDefinition,
    in tool: ToolDefinition,
    selection: ToolSelection,
    validateValue: Bool
  ) -> ToolSelectionIssue? {
    var candidateIDs = selection.selectedOptionIDs
    candidateIDs.insert(option.id)

    if let message = explicitConflictMessage(
      for: option,
      selectedOptionIDs: candidateIDs,
      tool: tool
    ) {
      return .conflict(message)
    }

    if let message = nmapConflictMessage(
      for: option,
      selectedOptionIDs: candidateIDs,
      tool: tool
    ) {
      return .conflict(message)
    }

    let missing = option.requiresOptionIDs.subtracting(candidateIDs)
    if !missing.isEmpty {
      let names = optionNames(for: missing, in: tool)
      return .incomplete("Opcja \(displayName(for: option)) wymaga: \(names).")
    }

    guard validateValue else { return nil }
    return validationIssue(
      for: option,
      rawValue: selection.values[option.id],
      tool: tool
    )
  }

  private static func explicitConflictMessage(
    for option: ToolOptionDefinition,
    selectedOptionIDs: Set<String>,
    tool: ToolDefinition
  ) -> String? {
    var conflicts = option.conflictsWithOptionIDs.intersection(selectedOptionIDs)
    for selected in tool.options where selectedOptionIDs.contains(selected.id) {
      if selected.conflictsWithOptionIDs.contains(option.id) {
        conflicts.insert(selected.id)
      }
    }
    conflicts.remove(option.id)
    guard !conflicts.isEmpty else { return nil }
    return "Opcja \(displayName(for: option)) jest sprzeczna z: \(optionNames(for: conflicts, in: tool))."
  }

  private static func nmapConflictMessage(
    for option: ToolOptionDefinition,
    selectedOptionIDs: Set<String>,
    tool: ToolDefinition
  ) -> String? {
    guard tool.id == "nmap" else { return nil }
    let scanIDs = Set(tool.options.filter { $0.categoryID == "scan" }.map(\.id))
    let selectedScanIDs = selectedOptionIDs.intersection(scanIDs)

    var conflicts: Set<String> = []
    if nmapTCPBaseIDs.contains(option.id) {
      conflicts.formUnion(selectedScanIDs.intersection(nmapTCPBaseIDs))
    }
    if nmapSCTPIDs.contains(option.id) {
      conflicts.formUnion(selectedScanIDs.intersection(nmapSCTPIDs))
    }
    if nmapExclusiveIDs.contains(option.id) {
      conflicts.formUnion(selectedScanIDs)
    } else if !selectedScanIDs.intersection(nmapExclusiveIDs).isEmpty {
      conflicts.formUnion(selectedScanIDs.intersection(nmapExclusiveIDs))
    }
    conflicts.remove(option.id)

    guard !conflicts.isEmpty else { return nil }
    return "Opcja \(displayName(for: option)) jest sprzeczna z: \(optionNames(for: conflicts, in: tool))."
  }

  private static func validationIssue(
    for option: ToolOptionDefinition,
    rawValue: String?,
    tool: ToolDefinition
  ) -> ToolSelectionIssue? {
    guard !option.canonicalFlag.isEmpty || option.id == "target"
      || option.valuePlacement == .positional else {
      return .incomplete("Opcja \(option.title) nie ma zdefiniowanej flagi.")
    }
    guard option.valueKind.requiresValue else { return nil }

    let value = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    guard !value.isEmpty else {
      return .incomplete("Uzupełnij wartość dla \(displayName(for: option)).")
    }

    if tool.id == "nmap", option.id == "ports", !validNmapPorts(value) {
      return .incomplete("Nieprawidłowy zakres portów. Użyj np. 22, 22,80,443 albo 1-1024.")
    }

    switch option.valueKind {
    case .none, .text, .path, .list, .secret:
      return nil
    case .integer(let range, _):
      guard let number = Int(value), range.contains(number) else {
        return .incomplete(
          "Wartość dla \(displayName(for: option)) musi być liczbą od \(range.lowerBound) do \(range.upperBound)."
        )
      }
    case .duration:
      let pattern = #"^[1-9][0-9]*(ms|s|m|h)$"#
      guard value.range(of: pattern, options: .regularExpression) != nil else {
        return .incomplete(
          "Wartość dla \(displayName(for: option)) podaj jako czas, np. 30s lub 2m."
        )
      }
    case .choice(let values, _):
      guard values.contains(value) else {
        return .incomplete(
          "Wybierz dla \(displayName(for: option)): \(values.joined(separator: ", "))."
        )
      }
    }
    return nil
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

  private static func optionNames(
    for optionIDs: Set<String>,
    in tool: ToolDefinition
  ) -> String {
    tool.options
      .filter { optionIDs.contains($0.id) }
      .map(displayName)
      .joined(separator: ", ")
  }

  private static func displayName(for option: ToolOptionDefinition) -> String {
    option.canonicalFlag.isEmpty ? option.title : option.canonicalFlag
  }
}
