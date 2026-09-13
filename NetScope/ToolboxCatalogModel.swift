import Foundation

enum ToolValueKind: Equatable, Sendable {
  case none
  case text(example: String)
  case integer(range: ClosedRange<Int>, example: String)
  case duration(example: String)
  case path(example: String)
  case list(example: String)
  case choice(values: [String], example: String)
  case secret(example: String)

  var example: String? {
    switch self {
    case .none: nil
    case .text(let example), .duration(let example), .path(let example),
         .list(let example), .secret(let example): example
    case .integer(_, let example), .choice(_, let example): example
    }
  }

  var requiresValue: Bool { self != .none }
}

enum ToolRiskLevel: Equatable, Sendable {
  case standard
  case caution(reason: String)
  case advanced(reason: String)
}

enum ToolValuePlacement: Equatable, Sendable {
  case separated
  case attached
  case equals
}

struct ToolCategoryDefinition: Identifiable, Equatable, Sendable {
  let id: String
  let title: String
  let subtitle: String
  let icon: String
}

enum ToolUsagePart: Equatable, Sendable {
  case literal(String)
  case category(label: String, categoryID: String)
}

struct ToolOptionDefinition: Identifiable, Equatable, Sendable {
  let id: String
  let categoryID: String
  let flags: [String]
  let title: String
  let summary: String
  let valueKind: ToolValueKind
  var valuePlacement: ToolValuePlacement = .separated
  let risk: ToolRiskLevel
  var requirements: String? = nil
  var requiresOptionIDs: Set<String> = []
  var conflictsWithOptionIDs: Set<String> = []
  let order: Int

  var canonicalFlag: String { flags.first ?? "" }

  var isSecret: Bool {
    if case .secret = valueKind { return true }
    return false
  }
}

struct ToolDefinition: Identifiable, Equatable, Sendable {
  let id: String
  let executable: String
  let title: String
  let helpVersion: String
  let reviewedAt: String
  var usageParts: [ToolUsagePart] = []
  let categories: [ToolCategoryDefinition]
  let options: [ToolOptionDefinition]
}

struct ToolSelection: Equatable, Sendable {
  var selectedOptionIDs: Set<String> = []
  var values: [String: String] = [:]

  mutating func toggle(optionID: String) {
    if selectedOptionIDs.contains(optionID) {
      selectedOptionIDs.remove(optionID)
      values.removeValue(forKey: optionID)
    } else {
      selectedOptionIDs.insert(optionID)
    }
  }
}

enum ToolCommandFragmentRole: Equatable, Sendable {
  case required
  case additional
  case target
  case caution
  case invalid
}

struct ToolCommandFragment: Identifiable, Equatable, Sendable {
  let position: Int
  let optionID: String?
  let value: String
  let role: ToolCommandFragmentRole
  let explanation: String

  var id: Int { position }
}

struct ToolCommandDraft: Equatable, Sendable {
  let command: String
  let fragments: [ToolCommandFragment]
  let explanation: String
  let warnings: [String]
  let errors: [String]
}
