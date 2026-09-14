import SwiftUI

enum AppTab: Int, Hashable {
  case dashboard = 0
  case toolbox = 3
  case comingSoon = 5
  case cipherPath = 6
  case scanner = 7

  static let navigationOrder: [AppTab] = [
    .dashboard, .toolbox, .comingSoon, .cipherPath, .scanner
  ]

  static func restored(from rawValue: Int) -> AppTab {
    AppTab(rawValue: rawValue) ?? .dashboard
  }

  var developerAreaID: DeveloperAreaID {
    switch self {
    case .dashboard: .navStart
    case .toolbox: .navToolbox
    case .comingSoon: .navLaboratory
    case .cipherPath: .navCipherPath
    case .scanner: .navStart
    }
  }
}

enum AppRouteRequest: Equatable {
  case tryOwnNetwork

  var recommendedProfile: ScanProfile { .quick }
  var startsAutomatically: Bool { false }
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
  @State private var routeNotice: String?

  init() {
    let store = KnownDeviceStore()
    _knownDeviceStore = StateObject(wrappedValue: store)
    _scanner = StateObject(wrappedValue: NetworkScanner(knownDeviceStore: store))
  }

  var body: some View {
    TabView(selection: selectedTab) {
      NetScopeStartView(
        selectedTab: selectedTab,
        discoveredTargets: discoveredTargetsFromScanner,
        scanner: scanner,
        knownDeviceStore: knownDeviceStore,
        tools: tools
      )
        .tabItem { Label("Start", systemImage: "dot.radiowaves.left.and.right") }.tag(AppTab.dashboard)
      ScannerView(
        scanner: scanner,
        knownDeviceStore: knownDeviceStore,
        tools: tools,
        routeNotice: routeNotice
      )
        .tabItem { Label("Scanner", systemImage: "wave.3.right") }.tag(AppTab.scanner)
      ToolboxView(scanner: scanner, workspaceRouteRaw: $ishWorkspaceRouteRaw)
        .tabItem { Label("Toolbox", systemImage: "arrow.up.circle.fill") }.tag(AppTab.toolbox)
      LaboratoryView(
        onTryOwnNetwork: tryOwnNetwork,
        discoveredTargets: discoveredTargetsFromScanner
      )
        .tabItem { Label("Laboratorium", systemImage: "terminal") }.tag(AppTab.comingSoon)
      CipherPathInfoView()
        .tabItem { Label("CipherPath", systemImage: "point.topleft.down.to.point.bottomright.curvepath") }
        .tag(AppTab.cipherPath)
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

  private var discoveredTargetsFromScanner: [String] {
    let addresses = scanner.devices.map(\.address)
    var seen: Set<String> = []
    return addresses
      .filter { seen.insert($0).inserted }
  }

  private func tryOwnNetwork() {
    let request = AppRouteRequest.tryOwnNetwork
    scanner.profile = request.recommendedProfile
    routeNotice = "Profil Szybki jest gotowy. Skan rozpocznie się dopiero po dotknięciu przycisku Rozpocznij skan."
    selectedTabRaw = AppTab.scanner.rawValue
  }
}

private struct NetScopeStartView: View {
  @Binding var selectedTab: AppTab
  let discoveredTargets: [String]
  @ObservedObject var scanner: NetworkScanner
  @ObservedObject var knownDeviceStore: KnownDeviceStore
  @ObservedObject var tools: NetworkToolsModel

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 14) {
          Text("NetScope")
            .font(.largeTitle.bold())
            .frame(maxWidth: .infinity, alignment: .leading)

          Text("NetScope uczy bezpiecznego badania sieci lokalnej i pracy z narzędziami. Start to szybki punkt wejścia do skanera, urządzeń i usług.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)

          VStack(spacing: 10) {
            sectionHeader("Moja sieć", "W jednym miejscu do skanera i wyników")
            StartActionButton(title: "Otwórz skaner", icon: "wave.3.right") {
              selectedTab = .scanner
            }
            if let context = scanner.context?.scanRangeDescription {
              Text("Zakres: \(context)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
          }
          .padding(.vertical, 10)
          .padding(.horizontal, 12)
          .background(.background, in: RoundedRectangle(cornerRadius: 14))

          VStack(spacing: 10) {
            sectionHeader("Zakładka urządzeń", "Szczegółowa lista urządzeń z ostatniego skanu")
            StartEntryButton(
              title: "Urządzenia",
              subtitle: discoveredTargets.isEmpty ? "Brak danych – uruchom skan" : "\(discoveredTargets.count) wyniki",
              icon: "desktopcomputer"
            ) {
              DevicesView(scanner: scanner, knownDeviceStore: knownDeviceStore)
            }
          }
          .padding(.vertical, 10)
          .padding(.horizontal, 12)
          .background(.background, in: RoundedRectangle(cornerRadius: 14))

          VStack(spacing: 10) {
            sectionHeader("Zakładka usług", "Porty, diagnostyka i usługi ogłoszone przez sieć")
            StartEntryButton(
              title: "Usługi",
              subtitle: "\(scanner.bonjourDiscovery.services.count) usług Bonjour",
              icon: "wrench.and.screwdriver"
            ) {
              ServicesHubView(scanner: scanner, tools: tools)
            }
          }
          .padding(.vertical, 10)
          .padding(.horizontal, 12)
          .background(.background, in: RoundedRectangle(cornerRadius: 14))

          if !scanner.devices.isEmpty || !scanner.bonjourDiscovery.services.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
              sectionHeader("Stan ostatniego skanu", "Najnowsze wyniki pozostają zachowane przy zmianie zakładki")
              HStack {
                Text("Urządzenia: \(scanner.devices.count)")
                Spacer()
                Text("Usługi: \(scanner.bonjourDiscovery.services.count)")
              }
              .font(.caption)
              .foregroundStyle(.secondary)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(.background, in: RoundedRectangle(cornerRadius: 14))
          }
        }
        .padding(12)
      }
      .background(Color(.systemGroupedBackground))
      .navigationTitle("Start")
      .navigationBarTitleDisplayMode(.inline)
      .scrollIndicators(.never)
    }
  }

  @ViewBuilder
  private func sectionHeader(_ title: String, _ subtitle: String) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(title).font(.headline)
      Text(subtitle).font(.caption2).foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func StartActionButton(
    title: String,
    icon: String,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack {
        Image(systemName: icon)
          .foregroundStyle(.white)
          .frame(width: 30, height: 30)
          .background(Color.cyan, in: RoundedRectangle(cornerRadius: 8))
        VStack(alignment: .leading) {
          Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
          Text("Przejdź do skanera")
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        Spacer()
        Image(systemName: "arrow.right")
          .font(.caption.weight(.bold))
          .foregroundStyle(.secondary)
      }
      .padding(10)
      .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }
    .buttonStyle(.plain)
  }
}

private struct StartEntryButton<Destination: View>: View {
  let title: String
  let subtitle: String
  let icon: String
  @ViewBuilder var destination: () -> Destination

  var body: some View {
    NavigationLink(destination: destination()) {
      HStack(spacing: 10) {
        Image(systemName: icon).foregroundStyle(.cyan)
          .frame(width: 28, height: 28)
          .background(Color.cyan.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        VStack(alignment: .leading, spacing: 2) {
          Text(title).font(.subheadline.weight(.semibold))
          Text(subtitle).font(.caption2).foregroundStyle(.secondary)
        }
        Spacer()
        Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.secondary)
      }
      .padding(10)
      .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }
    .buttonStyle(.plain)
  }
}

private struct CipherPathInfoView: View {
  var body: some View {
    NavigationStack {
      List {
        DeveloperAreaTag(AppTab.cipherPath.developerAreaID)
        DeveloperAreaTag(.cpScreen)

        Section {
          DeveloperAreaTag(.cpFeatures)
          Label("Nauka krok po kroku", systemImage: "map.fill")
          Label("Misje i bezpieczne scenariusze", systemImage: "target")
          Label("Postęp, punkty i osiągnięcia", systemImage: "medal.fill")
        } header: {
          Text("CipherPath")
        } footer: {
          Text("CipherPath uczy podstaw i prowadzi przez misje. NetScope pozostaje miejscem do praktyki z siecią, narzędziami i lokalnym laboratorium.")
        }

        Section("Integracja") {
          DeveloperAreaTag(.cpIntegration)
          Label("Połączenie aplikacji pojawi się później", systemImage: "link.badge.plus")
            .foregroundStyle(.secondary)
        }
      }
      .navigationTitle("CipherPath")
    }
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
