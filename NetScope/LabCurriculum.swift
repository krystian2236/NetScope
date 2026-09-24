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
        let pattern = "(?<!\\S)\(escaped)(?:=|\\s+)(?:'[^']*'|\"[^\"]*\"|\\S+)"
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
    case "curl": redactCurl(command)
    default: command
    }
  }

  private static func redactCurl(_ command: String) -> String {
    let marker = "Authorization:"
    var result = String()
    result.reserveCapacity(command.count)

    var index = command.startIndex
    var quote: Character?
    while index < command.endIndex {
      let markerEnd = command.index(index, offsetBy: marker.count, limitedBy: command.endIndex)
      let previous = index > command.startIndex ? command[command.index(before: index)] : nil
      let isHeader = markerEnd.map {
        command[index..<$0].caseInsensitiveCompare(marker) == .orderedSame
          && (previous == nil || previous!.isWhitespace || previous == "'" || previous == "\"")
      } ?? false

      if isHeader, let markerEnd {
        var valueStart = markerEnd
        while valueStart < command.endIndex, command[valueStart].isWhitespace {
          valueStart = command.index(after: valueStart)
        }

        var valueEnd = valueStart
        var escaped = false
        while valueEnd < command.endIndex {
          let character = command[valueEnd]
          if let quote {
            if escaped {
              escaped = false
            } else if character == "\\" {
              escaped = true
            } else if character == quote {
              break
            }
          } else if character.isWhitespace {
            break
          }
          valueEnd = command.index(after: valueEnd)
        }

        result.append(contentsOf: command[index..<valueStart])
        result.append("[REDACTED]")
        index = valueEnd
        continue
      }

      let character = command[index]
      result.append(character)
      if character == "'" || character == "\"" {
        quote = quote == character ? nil : (quote ?? character)
      }
      index = command.index(after: index)
    }

    return result
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
