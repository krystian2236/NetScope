import SwiftUI
import UIKit

enum DeveloperAreaTool: String, CaseIterable, Equatable, Sendable {
  case nmap = "NMAP"
  case nuclei = "NUCLEI"
  case dig = "DIG"
  case curl = "CURL"

  init?(toolID: String) {
    switch toolID {
    case "nmap": self = .nmap
    case "nuclei": self = .nuclei
    case "dig": self = .dig
    case "curl": self = .curl
    default: return nil
    }
  }

  init(_ tool: LabToolID) {
    switch tool {
    case .nmap: self = .nmap
    case .nuclei: self = .nuclei
    case .dig: self = .dig
    case .curl: self = .curl
    }
  }
}

enum DeveloperToolboxPart: String, CaseIterable, Equatable, Sendable {
  case entry = "ENTRY"
  case screen = "SCREEN"
  case command = "COMMAND"
  case fragments = "FRAGMENTS"
  case syntax = "SYNTAX"
  case sections = "SECTIONS"
  case options = "OPTIONS"
  case value = "VALUE"
  case messages = "MESSAGES"
}

enum DeveloperLaboratoryPart: String, CaseIterable, Equatable, Sendable {
  case program = "PROGRAM"
  case missionList = "MISSION-LIST"
  case briefing = "BRIEFING"
  case terminal = "TERMINAL"
  case answer = "ANSWER"
  case result = "RESULT"
}

struct DeveloperAreaID: RawRepresentable, Hashable, Sendable {
  let rawValue: String

  static let navStart = Self(rawValue: "NAV-START")
  static let navToolbox = Self(rawValue: "NAV-TOOLBOX")
  static let navLaboratory = Self(rawValue: "NAV-LABORATORY")
  static let navCipherPath = Self(rawValue: "NAV-CIPHERPATH")
  static let navLabSections = Self(rawValue: "NAV-LAB-SECTIONS")
  static let navLabLearning = Self(rawValue: "NAV-LAB-LEARNING")

  static let startScreen = Self(rawValue: "START-SCREEN")
  static let startNetworkContext = Self(rawValue: "START-NETWORK-CONTEXT")
  static let startDevices = Self(rawValue: "START-DEVICES")
  static let startServices = Self(rawValue: "START-SERVICES")
  static let startScanWorkflow = Self(rawValue: "START-SCAN-WORKFLOW")
  static let startScanAction = Self(rawValue: "START-SCAN-ACTION")
  static let startScanResults = Self(rawValue: "START-SCAN-RESULTS")

  static let toolboxScreen = Self(rawValue: "TB-SCREEN")
  static let laboratoryScreen = Self(rawValue: "LAB-SCREEN")

  static let cpScreen = Self(rawValue: "CP-SCREEN")
  static let cpFeatures = Self(rawValue: "CP-FEATURES")
  static let cpIntegration = Self(rawValue: "CP-INTEGRATION")

  static func toolbox(
    _ tool: DeveloperAreaTool,
    _ part: DeveloperToolboxPart
  ) -> Self {
    Self(rawValue: "TB-\(tool.rawValue)-\(part.rawValue)")
  }

  static func laboratory(
    _ tool: DeveloperAreaTool,
    _ part: DeveloperLaboratoryPart
  ) -> Self {
    Self(rawValue: "LAB-\(tool.rawValue)-\(part.rawValue)")
  }

  static func navLabTool(_ tool: DeveloperAreaTool) -> Self {
    Self(rawValue: "NAV-LAB-\(tool.rawValue)")
  }

  static func learning(_ part: DeveloperLaboratoryPart) -> Self {
    Self(rawValue: "LAB-LEARNING-\(part.rawValue)")
  }

  static var allKnown: [Self] {
    let fixed: [Self] = [
      .navStart, .navToolbox, .navLaboratory, .navCipherPath,
      .navLabSections, .navLabLearning,
      .startScreen, .startNetworkContext, .startDevices, .startServices,
      .startScanWorkflow, .startScanAction, .startScanResults,
      .toolboxScreen, .laboratoryScreen,
      .cpScreen, .cpFeatures, .cpIntegration,
    ]
    let toolbox = DeveloperAreaTool.allCases.flatMap { tool in
      DeveloperToolboxPart.allCases.map { DeveloperAreaID.toolbox(tool, $0) }
    }
    let laboratory = DeveloperAreaTool.allCases.flatMap { tool in
      DeveloperLaboratoryPart.allCases.map { DeveloperAreaID.laboratory(tool, $0) }
    }
    let learning = DeveloperLaboratoryPart.allCases.map(DeveloperAreaID.learning)
    let labNavigation = DeveloperAreaTool.allCases.map(DeveloperAreaID.navLabTool)
    return fixed + labNavigation + toolbox + laboratory + learning
  }
}

struct DeveloperAreaTag: View {
  let area: DeveloperAreaID
  @State private var copied = false

  init(_ area: DeveloperAreaID) {
    self.area = area
  }

  @ViewBuilder
  var body: some View {
    #if NETSCOPE_DEVELOPER_TOOLS
    Button {
      UIPasteboard.general.string = area.rawValue
      copied = true
      UIAccessibility.post(
        notification: .announcement,
        argument: "Skopiowano \(area.rawValue)"
      )
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
        copied = false
      }
    } label: {
      HStack(spacing: 4) {
        Text("[\(area.rawValue)]")
        if copied {
          Image(systemName: "checkmark")
        }
      }
      .font(.caption2.monospaced().weight(.bold))
      .foregroundStyle(.cyan)
      .padding(.horizontal, 6)
      .padding(.vertical, 3)
      .background(Color.cyan.opacity(0.1), in: Capsule())
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Obszar developerski \(area.rawValue)")
    .accessibilityHint("Kopiuje oznaczenie do schowka")
    #else
    EmptyView()
    #endif
  }
}
