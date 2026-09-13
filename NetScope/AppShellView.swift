import SwiftUI

enum AppTab: Int, Hashable {
  case dashboard = 0
  case toolbox = 3
  case comingSoon = 5

  static let navigationOrder: [AppTab] = [
    .dashboard, .toolbox, .comingSoon,
  ]

  static func restored(from rawValue: Int) -> AppTab {
    AppTab(rawValue: rawValue) ?? .dashboard
  }
}

enum ISHWorkspaceRoute: RawRepresentable, Hashable {
  case library
  case shortcut(SSHShortcutID)

  static let libraryRawValue = "library"

  init?(rawValue: String) {
    if rawValue == Self.libraryRawValue {
      self = .library
    } else if let shortcutID = SSHShortcutID(rawValue: rawValue) {
      self = .shortcut(shortcutID)
    } else {
      return nil
    }
  }

  var rawValue: String {
    switch self {
    case .library: Self.libraryRawValue
    case .shortcut(let shortcutID): shortcutID.rawValue
    }
  }

  var shortcutID: SSHShortcutID? {
    guard case .shortcut(let shortcutID) = self else { return nil }
    return shortcutID
  }
}

struct AppShellView: View {
  @StateObject private var knownDeviceStore: KnownDeviceStore
  @StateObject private var scanner: NetworkScanner
  @StateObject private var tools = NetworkToolsModel()
  @SceneStorage("NetScope.selectedTab") private var selectedTabRaw = AppTab.dashboard.rawValue
  @SceneStorage("NetScope.ishWorkspaceRoute") private var ishWorkspaceRouteRaw = ""

  init() {
    let store = KnownDeviceStore()
    _knownDeviceStore = StateObject(wrappedValue: store)
    _scanner = StateObject(wrappedValue: NetworkScanner(knownDeviceStore: store))
  }

  var body: some View {
    TabView(selection: selectedTab) {
      ScannerView(scanner: scanner, knownDeviceStore: knownDeviceStore, tools: tools)
        .tabItem { Label("Start", systemImage: "dot.radiowaves.left.and.right") }.tag(AppTab.dashboard)
      ToolboxView(scanner: scanner, workspaceRouteRaw: $ishWorkspaceRouteRaw)
        .tabItem { Label("Toolbox", systemImage: "arrow.up.circle.fill") }.tag(AppTab.toolbox)
      ComingSoonView()
        .tabItem { Label("Wkrótce", systemImage: "sparkles") }.tag(AppTab.comingSoon)
    }
    .tint(.cyan)
    .alert("Problem z zapamiętanymi urządzeniami", isPresented: storeErrorIsPresented) {
      Button("OK") { knownDeviceStore.clearError() }
    } message: {
      Text(knownDeviceStore.errorMessage ?? "Nieznany błąd zapisu.")
    }
    .task { scanner.refreshContext(); tools.refreshLocalContext() }
  }

  private var selectedTab: Binding<AppTab> {
    Binding(
      get: { AppTab.restored(from: selectedTabRaw) },
      set: { selectedTabRaw = $0.rawValue }
    )
  }

  private var storeErrorIsPresented: Binding<Bool> {
    Binding(get: { knownDeviceStore.errorMessage != nil }, set: { if !$0 { knownDeviceStore.clearError() } })
  }
}

struct DevicesView: View {
  @ObservedObject var scanner: NetworkScanner
  @ObservedObject var knownDeviceStore: KnownDeviceStore

  var body: some View {
    Group {
      if scanner.devices.isEmpty {
        ContentUnavailableView {
          Label("Brak urządzeń", systemImage: "desktopcomputer")
        } description: {
          Text("Wróć do ekranu Start i wykonaj skan prywatnej sieci lokalnej.")
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

private struct ComingSoonView: View {
  var body: some View {
    NavigationStack {
      List {
        Section {
          Label("Konto i synchronizacja", systemImage: "person.crop.circle.badge.checkmark")
          Label("Zadania i przypomnienia", systemImage: "checklist")
          Label("Informacje o aktualizacjach", systemImage: "arrow.triangle.2.circlepath")
        } header: {
          Text("Planowane")
        } footer: {
          Text("Pojawią się tutaj dopiero po wdrożeniu konta lub zakupu. Ta wersja niczego nie wysyła ani nie wymaga logowania.")
        }
      }
      .navigationTitle("Wkrótce")
    }
  }
}

struct ServicesHubView: View {
  @ObservedObject var scanner: NetworkScanner
  @ObservedObject var tools: NetworkToolsModel

  var body: some View {
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
