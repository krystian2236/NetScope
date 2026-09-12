import SwiftUI

enum AppTab: Hashable {
  case dashboard, network, devices, nmap, services
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
      DashboardView(scanner: scanner, tools: tools, knownDeviceStore: knownDeviceStore, selectedTab: $selectedTab)
        .tabItem { Label("Start", systemImage: "square.grid.2x2") }.tag(AppTab.dashboard)
      ScannerView(scanner: scanner, knownDeviceStore: knownDeviceStore)
        .tabItem { Label("Skan", systemImage: "dot.radiowaves.left.and.right") }.tag(AppTab.network)
      DevicesView(scanner: scanner, knownDeviceStore: knownDeviceStore, selectedTab: $selectedTab)
        .tabItem { Label("Urządzenia", systemImage: "desktopcomputer") }.tag(AppTab.devices)
      NmapGuideView(scanner: scanner)
        .tabItem { Label("Nmap", systemImage: "terminal") }.tag(AppTab.nmap)
      ServicesHubView(scanner: scanner, tools: tools)
        .tabItem { Label("Usługi", systemImage: "wrench.and.screwdriver") }.tag(AppTab.services)
    }
    .tint(.cyan)
    .alert("Problem z zapamiętanymi urządzeniami", isPresented: storeErrorIsPresented) {
      Button("OK") { knownDeviceStore.clearError() }
    } message: {
      Text(knownDeviceStore.errorMessage ?? "Nieznany błąd zapisu.")
    }
    .task { scanner.refreshContext(); tools.refreshLocalContext() }
  }

  private var storeErrorIsPresented: Binding<Bool> {
    Binding(get: { knownDeviceStore.errorMessage != nil }, set: { if !$0 { knownDeviceStore.clearError() } })
  }
}

private struct DevicesView: View {
  @ObservedObject var scanner: NetworkScanner
  @ObservedObject var knownDeviceStore: KnownDeviceStore
  @Binding var selectedTab: AppTab

  var body: some View {
    NavigationStack {
      Group {
        if scanner.devices.isEmpty {
          ContentUnavailableView {
            Label("Brak urządzeń", systemImage: "desktopcomputer")
          } description: {
            Text("Najpierw wykonaj skan prywatnej sieci lokalnej.")
          } actions: {
            Button("Przejdź do skanu") { selectedTab = .network }
              .buttonStyle(.borderedProminent).tint(.cyan)
          }
        } else {
          List(scanner.devices) { device in
            NavigationLink {
              DeviceDetailView(device: device, key: key(for: device), knownDeviceStore: knownDeviceStore)
            } label: {
              DeviceRow(device: device, record: record(for: device), registryStatus: status(for: device))
            }
            .listRowInsets(EdgeInsets(top: 5, leading: 12, bottom: 5, trailing: 12))
            .listRowSeparator(.hidden)
          }
          .listStyle(.plain)
        }
      }
      .navigationTitle("Urządzenia")
      .navigationBarTitleDisplayMode(.inline)
    }
  }

  private func key(for device: NetworkDevice) -> KnownDeviceKey? {
    scanner.networkID.map { KnownDeviceKey(networkID: $0, address: device.address) }
  }

  private func record(for device: NetworkDevice) -> KnownDeviceRecord? {
    key(for: device).flatMap(knownDeviceStore.record)
  }

  private func status(for device: NetworkDevice) -> DeviceRegistryStatus {
    guard let key = key(for: device) else { return .unknown }
    return DeviceRegistryStatus(record: knownDeviceStore.record(for: key), isNew: scanner.newDeviceKeys.contains(key))
  }
}

private struct ServicesHubView: View {
  @ObservedObject var scanner: NetworkScanner
  @ObservedObject var tools: NetworkToolsModel

  var body: some View {
    NavigationStack {
      List {
        Section {
          InfoBanner(icon: "wrench.and.screwdriver.fill", title: "Narzędzia sieciowe", message: "Wszystkie dotychczasowe funkcje są tutaj, w jednym uporządkowanym miejscu.")
            .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
        }
        Section("Sprawdzanie") {
          serviceLink(title: "Porty", subtitle: "Sprawdź dostępność wybranych usług TCP", icon: "shield.lefthalf.filled") {
            PortScannerView(model: tools)
          }
          serviceLink(title: "Ping i adresy", subtitle: "DNS, lokalny i publiczny IP oraz TCP Ping", icon: "waveform.path.ecg") {
            DiagnosticsView(model: tools)
          }
        }
        Section("Wykrywanie automatyczne") {
          serviceLink(title: "Bonjour", subtitle: "Usługi ogłaszane przez urządzenia w sieci", icon: "bonjour") {
            ServicesView(discovery: scanner.bonjourDiscovery)
          }
        }
      }
      .navigationTitle("Usługi")
      .navigationBarTitleDisplayMode(.inline)
    }
  }

  private func serviceLink<Destination: View>(title: String, subtitle: String, icon: String, @ViewBuilder destination: () -> Destination) -> some View {
    NavigationLink(destination: destination()) {
      HStack(spacing: 11) {
        Image(systemName: icon).foregroundStyle(.cyan).frame(width: 34, height: 34)
          .background(.cyan.opacity(0.1), in: RoundedRectangle(cornerRadius: 9))
        VStack(alignment: .leading, spacing: 2) {
          Text(title).font(.subheadline.weight(.semibold))
          Text(subtitle).font(.caption2).foregroundStyle(.secondary)
        }
      }.padding(.vertical, 3)
    }
  }
}
