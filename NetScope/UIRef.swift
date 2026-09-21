import Foundation

#if NETSCOPE_DEV
enum UIRef: String, CaseIterable, Sendable {
  case dashboard = "NETSCOPE.DASHBOARD"
  case dashboardNetworkHeader = "NETSCOPE.DASHBOARD.NETWORK_HEADER"
  case dashboardMetrics = "NETSCOPE.DASHBOARD.METRICS"
  case scanner = "NETSCOPE.SCANNER"
  case scannerDevices = "NETSCOPE.SCANNER.DEVICES"
  case scannerServices = "NETSCOPE.SCANNER.SERVICES"
  case history = "NETSCOPE.HISTORY"
  case toolbox = "NETSCOPE.TOOLBOX"
  case toolboxNmap = "NETSCOPE.TOOLBOX.NMAP"
  case toolboxNuclei = "NETSCOPE.TOOLBOX.NUCLEI"
  case scannerDetails = "NETSCOPE.SCANNER.DETAILS"
  case scannerDeviceDetails = "NETSCOPE.SCANNER.DEVICE_DETAILS"
  case scannerPortScanner = "NETSCOPE.SCANNER.PORTS"
  case scannerDiagnostics = "NETSCOPE.SCANNER.DIAGNOSTICS"
  case scannerBonjour = "NETSCOPE.SCANNER.BONJOUR"
  case labs = "NETSCOPE.LABS"
  case labsMission = "NETSCOPE.LABS.MISSION"
  case ssh = "NETSCOPE.SSH"
  case sshGuide = "NETSCOPE.SSH.GUIDE"
  case about = "NETSCOPE.ABOUT"

  var label: String {
    switch self {
    case .dashboard: "Start"
    case .dashboardNetworkHeader: "Nagłówek sieci"
    case .dashboardMetrics: "Metryki"
    case .scanner: "Skaner"
    case .scannerDevices: "Urządzenia"
    case .scannerServices: "Usługi"
    case .history: "Historia skanów"
    case .toolbox: "Toolbox"
    case .toolboxNmap: "Toolbox Nmap"
    case .toolboxNuclei: "Toolbox Nuclei"
    case .scannerDetails: "Szczegóły skanu"
    case .scannerDeviceDetails: "Szczegóły urządzenia"
    case .scannerPortScanner: "Skaner portów"
    case .scannerDiagnostics: "Diagnostyka"
    case .scannerBonjour: "Bonjour"
    case .labs: "Laboratoria"
    case .labsMission: "Misja laboratorium"
    case .ssh: "Skróty SSH"
    case .sshGuide: "Przewodnik SSH"
    case .about: "Informacje"
    }
  }

  var source: String {
    switch self {
    case .dashboard, .dashboardNetworkHeader, .dashboardMetrics, .history: "NetScope/DashboardView.swift"
    case .scanner: "NetScope/ScannerView.swift"
    case .scannerDevices, .scannerServices: "NetScope/AppShellView.swift"
    case .toolbox, .toolboxNmap, .toolboxNuclei: "NetScope/ToolboxView.swift"
    case .scannerDetails: "NetScope/ScanDetailsView.swift"
    case .scannerDeviceDetails: "NetScope/SupportingViews.swift"
    case .scannerPortScanner, .scannerDiagnostics, .scannerBonjour: "NetScope/AppShellView.swift"
    case .labs, .labsMission: "NetScope/LaboratoryView.swift"
    case .ssh, .sshGuide: "NetScope/SSHShortcutLibraryView.swift"
    case .about: "NetScope/SupportingViews.swift"
    }
  }

  var symbol: String {
    switch self {
    case .dashboard: "DashboardView"
    case .dashboardNetworkHeader: "networkHeader"
    case .dashboardMetrics: "metrics"
    case .scanner: "ScannerView"
    case .scannerDevices: "DevicesView"
    case .scannerServices: "ServicesHubView"
    case .history: "history"
    case .toolbox: "ToolboxView"
    case .toolboxNmap, .toolboxNuclei: "ToolLearningView"
    case .scannerDetails: "ScanDetailsView"
    case .scannerDeviceDetails: "DeviceDetailView"
    case .scannerPortScanner: "PortScannerView"
    case .scannerDiagnostics: "DiagnosticsView"
    case .scannerBonjour: "ServicesView"
    case .labs: "LaboratoryView"
    case .labsMission: "TerminalLessonView"
    case .ssh: "SSHShortcutLibraryView"
    case .sshGuide: "NmapGuideView"
    case .about: "AboutView"
    }
  }

  var clipboardText: String {
    "UIREF: \(rawValue)\nLabel: \(label)\nSource: \(source)\nSymbol: \(symbol)"
  }
}
#endif
