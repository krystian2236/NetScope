enum ToolboxEntry: CaseIterable, Equatable, Sendable {
  case reconnaissance
  case nuclei
}

enum NetScopeFeature: String, CaseIterable, Sendable {
  case networkOverview
  case basicDiagnostics
  case quickScan
  case limitedHistory
  case laboratoryBasics
  case fullPortScanner
  case customPorts
  case fullHistory
  case compareScans
  case extendedHostInspector
  case advancedDiagnostics
  case export
}

enum NetScopeAccessLevel: String, Sendable {
  case free
  case pro
}

struct NetScopeAccessController: Sendable {
  let level: NetScopeAccessLevel

  func allows(_ feature: NetScopeFeature) -> Bool {
    switch (level, feature) {
    case (.pro, _): true
    case (.free, .networkOverview), (.free, .basicDiagnostics),
         (.free, .quickScan), (.free, .limitedHistory), (.free, .laboratoryBasics): true
    case (.free, _): false
    }
  }
}
