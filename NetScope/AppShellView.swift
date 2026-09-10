import SwiftUI

enum AppTab: Hashable {
  case dashboard
  case network
  case ports
  case diagnostics
  case services
}

struct AppShellView: View {
  @StateObject private var knownDeviceStore: KnownDeviceStore
  @StateObject private var scanner: NetworkScanner
  @StateObject private var tools = NetworkToolsModel()
  @State private var selectedTab: AppTab = .dashboard

  init() {
    let store = KnownDeviceStore()
    _knownDeviceStore = StateObject(wrappedValue: store)
    _scanner = StateObject(wrappedValue: NetworkScanner(knownDeviceStore: store))
  }

  var body: some View {
    TabView(selection: $selectedTab) {
      DashboardView(
        scanner: scanner,
        tools: tools,
        knownDeviceStore: knownDeviceStore,
        selectedTab: $selectedTab
      )
      .tabItem {
        Label("Start", systemImage: "square.grid.2x2")
      }
      .tag(AppTab.dashboard)

      ScannerView(scanner: scanner, knownDeviceStore: knownDeviceStore)
        .tabItem {
          Label("Sieć", systemImage: "network")
        }
        .tag(AppTab.network)

      PortScannerView(model: tools)
        .tabItem {
          Label("Porty", systemImage: "shield.lefthalf.filled")
        }
        .tag(AppTab.ports)

      DiagnosticsView(model: tools)
        .tabItem {
          Label("Ping", systemImage: "waveform.path.ecg")
        }
        .tag(AppTab.diagnostics)

      ServicesView(discovery: scanner.bonjourDiscovery)
        .tabItem {
          Label("Bonjour", systemImage: "bonjour")
        }
        .tag(AppTab.services)
    }
    .tint(.cyan)
    .alert(
      "Problem z zapamiętanymi urządzeniami",
      isPresented: storeErrorIsPresented
    ) {
      Button("OK") {
        knownDeviceStore.clearError()
      }
    } message: {
      Text(knownDeviceStore.errorMessage ?? "Nieznany błąd zapisu.")
    }
    .task {
      scanner.refreshContext()
      tools.refreshLocalContext()
    }
  }

  private var storeErrorIsPresented: Binding<Bool> {
    Binding(
      get: { knownDeviceStore.errorMessage != nil },
      set: { isPresented in
        if !isPresented {
          knownDeviceStore.clearError()
        }
      }
    )
  }
}
