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
  case positional
}

enum ToolSyntaxTone: Equatable, Sendable {
  case scan
  case options
  case target
  case auxiliary
}

enum ToolArgumentPhase: Int, Equatable, Sendable {
  case beforeTarget
  case target
  case afterTarget
}

enum ToolOptionPresentationState: Equatable, Sendable {
  case compatible
  case selectedValid
  case conflicting(String)
  case incomplete(String)

  var isConflict: Bool {
    if case .conflicting = self { return true }
    return false
  }

  var isIncomplete: Bool {
    if case .incomplete = self { return true }
    return false
  }
}

enum ToolSelectionIssue: Equatable, Sendable {
  case conflict(String)
  case incomplete(String)

  var message: String {
    switch self {
    case .conflict(let text), .incomplete(let text): text
    }
  }
}

struct ToolCategoryDefinition: Identifiable, Equatable, Sendable {
  let id: String
  let title: String
  let subtitle: String
  let icon: String
}

enum ToolUsagePart: Equatable, Sendable {
  case literal(String)
  case section(ToolUsageSection)
}

struct ToolUsageSection: Identifiable, Equatable, Sendable {
  let id: String
  let label: String
  let categoryIDs: [String]
  var tone: ToolSyntaxTone = .options
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
  var isFeatured = false
  var argumentPhase: ToolArgumentPhase = .beforeTarget

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

  mutating func toggle(optionID: String, preservingValue presetValue: String? = nil) {
    if selectedOptionIDs.contains(optionID) {
      selectedOptionIDs.remove(optionID)
      if let presetValue, !presetValue.isEmpty {
        values[optionID] = presetValue
      } else {
        values.removeValue(forKey: optionID)
      }
    } else {
      selectedOptionIDs.insert(optionID)
      if let presetValue, !presetValue.isEmpty,
         (values[optionID] ?? "").isEmpty {
        values[optionID] = presetValue
      }
    }
  }
}

struct ToolOptionDisclosureState: Equatable, Sendable {
  private(set) var expandedOptionIDs: Set<String> = []

  func isExpanded(optionID: String) -> Bool {
    expandedOptionIDs.contains(optionID)
  }

  mutating func toggle(optionID: String) {
    if expandedOptionIDs.contains(optionID) {
      expandedOptionIDs.remove(optionID)
    } else {
      expandedOptionIDs.insert(optionID)
    }
  }
}

struct ToolCategoryDisclosureState: Equatable, Sendable {
  private(set) var selectedCategoryID: String?

  mutating func toggle(categoryID: String) {
    selectedCategoryID = selectedCategoryID == categoryID ? nil : categoryID
  }

  mutating func reset() {
    selectedCategoryID = nil
  }
}

struct ToolCategoryRow: Identifiable, Equatable, Sendable {
  let categories: [ToolCategoryDefinition]

  var id: String { categories.map(\.id).joined(separator: "|") }

  func contains(categoryID: String) -> Bool {
    categories.contains { $0.id == categoryID }
  }
}

enum ToolCategoryLayout {
  static func rows(
    _ categories: [ToolCategoryDefinition],
    columns: Int
  ) -> [ToolCategoryRow] {
    let width = max(1, columns)
    return stride(from: 0, to: categories.count, by: width).map { start in
      ToolCategoryRow(categories: Array(categories[start..<min(start + width, categories.count)]))
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

enum ToolCatalogBrowser {
  static func categories(
    in tool: ToolDefinition,
    sectionID: String
  ) -> [ToolCategoryDefinition] {
    guard let section = tool.usageParts.compactMap({ part -> ToolUsageSection? in
      if case .section(let section) = part { return section }
      return nil
    }).first(where: { $0.id == sectionID }) else {
      return []
    }

    return section.categoryIDs.compactMap { categoryID in
      tool.categories.first(where: { $0.id == categoryID })
    }
  }

  static func options(
    in tool: ToolDefinition,
    categoryID: String,
    query: String,
    featuredOnly: Bool = false
  ) -> [ToolOptionDefinition] {
    let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
    return tool.options.filter { option in
      guard option.categoryID == categoryID else { return false }
      guard !featuredOnly || option.isFeatured else { return false }
      guard !trimmedQuery.isEmpty else { return true }

      return option.flags.contains {
        $0.localizedCaseInsensitiveContains(trimmedQuery)
      } || option.title.localizedCaseInsensitiveContains(trimmedQuery)
        || option.summary.localizedCaseInsensitiveContains(trimmedQuery)
    }
  }
}
