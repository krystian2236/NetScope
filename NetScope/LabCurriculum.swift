import Foundation

enum LabToolID: String, CaseIterable, Identifiable, Equatable, Sendable {
  case nmap, nuclei, dig, curl

  var id: String { rawValue }

  static let firstMilestone: [Self] = [.nmap, .nuclei, .dig, .curl]
}

enum LabAccessTier: Equatable, Sendable {
  case demo
  case pro
}

enum LabAccessState: Equatable, Sendable {
  case demo
  case pro
}

struct LabLessonCoverage: Equatable, Sendable {
  enum Kind: Equatable, Sendable {
    case exercise
    case diagnostic
    case explanationOnly(String)
  }

  let optionID: String
  let kind: Kind
}

struct LabModule: Identifiable, Equatable, Sendable {
  let id: String
  let title: String
  let summary: String
  let access: LabAccessTier
  let lessons: [LabMission]
  let coverage: [LabLessonCoverage]
}

struct LabProgram: Identifiable, Equatable, Sendable {
  let id: LabToolID
  let title: String
  let summary: String
  let icon: String
  let modules: [LabModule]
}

enum LabCurriculum {
  static let firstMilestonePrograms: [LabProgram] = [
    NmapLabProgram.definition,
    NucleiLabProgram.definition,
    DigLabProgram.definition,
    CurlLabProgram.definition,
  ]
}

enum LabAccessPolicy {
  static func canOpen(
    _ tier: LabAccessTier,
    state: LabAccessState,
    variant: BuildVariant
  ) -> Bool {
    tier == .demo || state == .pro || variant.includesDeveloperTools
  }
}

enum LabCommandSanitizer {
  static func redact(_ command: String, tool: ToolDefinition) -> String {
    tool.options.filter(\.isSecret).reduce(command) { current, option in
      option.flags.reduce(current) { value, flag in
        let escaped = NSRegularExpression.escapedPattern(for: flag)
        let pattern = "(?<!\\S)\(escaped)(?:=|\\s+|(?=[^\\s-]))(?:'[^']*'|\"[^\"]*\"|\\S+)"
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return value }
        let range = NSRange(value.startIndex..., in: value)
        return expression.stringByReplacingMatches(
          in: value,
          range: range,
          withTemplate: "\(flag) [REDACTED]"
        )
      }
    }
  }

  static func redactForHistory(_ command: String) -> String {
    switch command.split(whereSeparator: \.isWhitespace).first?.lowercased() {
    case "nuclei": redact(command, tool: NucleiCatalog.definition)
    case "curl": redactCurl(redact(command, tool: CurlCatalog.definition))
    default: command
    }
  }

  private static func redactCurl(_ command: String) -> String {
    let pattern = "(?i)(Authorization:\\s*(?:Bearer\\s+)?)[^'\\\"\\s]+"
    guard let expression = try? NSRegularExpression(pattern: pattern) else { return command }
    return expression.stringByReplacingMatches(
      in: command,
      range: NSRange(command.startIndex..., in: command),
      withTemplate: "$1[REDACTED]"
    )
  }
}

enum LaboratorySectionID: Hashable {
  case learning
  case tool(LabToolID)

  static let navigationOrder: [Self] = [
    .learning, .tool(.nmap), .tool(.nuclei), .tool(.dig), .tool(.curl),
  ]

  var title: String {
    switch self {
    case .learning: "Nauka"
    case .tool(let tool): tool.rawValue.capitalized
    }
  }
}
