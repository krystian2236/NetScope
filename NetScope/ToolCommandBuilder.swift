import Foundation

enum ToolCommandBuilder {
  static func build(tool: ToolDefinition, selection: ToolSelection) -> ToolCommandDraft {
    let selectedOptions = tool.options
      .filter { selection.selectedOptionIDs.contains($0.id) }
      .sorted { lhs, rhs in
        if tool.id == "curl" {
          let lhsDisable = lhs.id == "disable"
          let rhsDisable = rhs.id == "disable"
          if lhsDisable != rhsDisable { return lhsDisable }
        }
        if lhs.argumentPhase != rhs.argumentPhase {
          return lhs.argumentPhase.rawValue < rhs.argumentPhase.rawValue
        }
        return lhs.order == rhs.order ? lhs.id < rhs.id : lhs.order < rhs.order
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
      let issue = ToolCompatibilityEvaluator.issue(
        for: option,
        in: tool,
        selection: selection,
        validateValue: true
      )
      let error = issue?.message
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
      command: fragments.map(\.value).joined(separator: " "),
      fragments: fragments,
      explanation: validFragments.map(\.explanation).joined(separator: " "),
      warnings: unique(warnings),
      errors: unique(errors)
    )
  }

  private static func renderedFragment(
    for option: ToolOptionDefinition,
    rawValue: String?
  ) -> String {
    guard option.valueKind.requiresValue else { return option.canonicalFlag }
    let value = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if option.id == "target", option.canonicalFlag.isEmpty,
       option.valuePlacement != .positional { return quoted(value) }
    switch option.valuePlacement {
    case .separated:
      return "\(option.canonicalFlag) \(quoted(value))"
    case .attached:
      return shellWord("\(option.canonicalFlag)\(value)")
    case .equals:
      return "\(option.canonicalFlag)=\(quoted(value))"
    case .positional:
      return shellWord(value)
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

  private static func shellWord(_ value: String) -> String {
    let safe = value.range(of: #"^[A-Za-z0-9._:/+@-]+$"#, options: .regularExpression) != nil
    return safe ? value : quoted(value)
  }

  private static func unique(_ values: [String]) -> [String] {
    var seen: Set<String> = []
    return values.filter { seen.insert($0).inserted }
  }
}
