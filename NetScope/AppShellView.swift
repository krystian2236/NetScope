import SwiftUI

enum AppTab: Int, Hashable {
  case dashboard = 0
  case network = 1
  case security = 2
  // Keep the existing raw values for restored SceneStorage selections.
  case toolbox = 3
  case laboratory = 4

  static let navigationOrder: [AppTab] = [
    .dashboard, .network, .security, .laboratory, .toolbox,
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
      DashboardView(
        scanner: scanner,
        tools: tools,
        knownDeviceStore: knownDeviceStore,
        selectedTab: selectedTab
      )
        .tabItem { Label("Start", systemImage: "dot.radiowaves.left.and.right") }.tag(AppTab.dashboard)
      ScannerView(scanner: scanner, knownDeviceStore: knownDeviceStore, tools: tools)
        .tabItem { Label("Network", systemImage: "network") }.tag(AppTab.network)
      SecurityView(scanner: scanner)
        .tabItem { Label("Security", systemImage: "lock.shield") }.tag(AppTab.security)
      LaboratoryView(onTryOwnNetwork: {})
        .tabItem { Label("Lab", systemImage: "graduationcap.fill") }.tag(AppTab.laboratory)
      ToolboxView(scanner: scanner, workspaceRouteRaw: $ishWorkspaceRouteRaw)
        .tabItem { Label("Tools", systemImage: "wrench.and.screwdriver") }.tag(AppTab.toolbox)
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
      #if NETSCOPE_DEV
      HStack {
        UIRefCopyButton(ref: .scannerDevices)
        Spacer()
      }
      .padding(.horizontal, 12)
      #endif
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

struct SecurityView: View {
  @ObservedObject var scanner: NetworkScanner

  private var findings: [SecurityFinding] {
    SecurityFinding.fromNetworkDevices(scanner.devices)
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 12) {
          #if NETSCOPE_DEV
          HStack {
            UIRefCopyButton(ref: .security)
            Spacer()
          }
          #endif
          SecuritySummaryCard(findingCount: findings.count)
          NavigationLink {
            HardeningCenterView()
          } label: {
            HardeningCenterCard()
          }
          .buttonStyle(.plain)
          NavigationLink {
            SecretsInspectorView()
          } label: {
            SecretsInspectorCard()
          }
          .buttonStyle(.plain)
          NavigationLink {
            SecurityPlaybooksView()
          } label: {
            SecurityPlaybooksCard()
          }
          .buttonStyle(.plain)
          NavigationLink {
            SecurityLabsView()
          } label: {
            SecurityLabsCard()
          }
          .buttonStyle(.plain)
          if findings.isEmpty {
            ContentUnavailableView {
              Label("Brak aktywnych wskazań", systemImage: "checkmark.shield")
            } description: {
              Text("Po wykonaniu skanu pojawią się tu urządzenia wymagające uwagi.")
            }
            .frame(maxWidth: .infinity, minHeight: 180)
          } else {
            Text("Wymaga uwagi")
              .font(.headline)
            ForEach(findings) { finding in
              SecurityFindingCard(finding: finding)
            }
          }
          InfoBanner(
            icon: "lock.shield",
            title: "Ocena lokalna",
            message: "Wskazania opisują wykryte usługi w prywatnej sieci. NetScope nie wysyła danych poza urządzenie."
          )
        }
        .padding(12)
      }
      .background(Color(.systemGroupedBackground))
      .navigationTitle("Security")
      .navigationBarTitleDisplayMode(.inline)
    }
  }

}

struct HardeningCenterView: View {
  private let categories = HardeningCategory.allCases

  var body: some View {
    List {
      Section {
        Text("Lokalny przewodnik kontroli konfiguracji. SEC niczego nie zmienia i nie wykonuje poleceń za użytkownika.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }

      ForEach(categories, id: \.self) { category in
        Section {
          ForEach(HardeningCheck.catalog.filter { $0.category == category }) { check in
            VStack(alignment: .leading, spacing: 6) {
              HStack {
                Label(check.title, systemImage: "checkmark.shield")
                  .font(.subheadline.weight(.semibold))
                Spacer()
                StatusPill(title: "Do sprawdzenia", tint: .orange)
              }
              Text(check.rationale)
                .font(.caption)
              Text(check.guidance)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
          }
        } header: {
          Label(category.title, systemImage: category.icon)
        }
      }
    }
    .listStyle(.insetGrouped)
    .navigationTitle("Hardening Center")
    .navigationBarTitleDisplayMode(.inline)
    #if NETSCOPE_DEV
    .safeAreaInset(edge: .top) {
      HStack {
        UIRefCopyButton(ref: .securityHardening)
        Spacer()
      }
      .padding(.horizontal, 12)
      .padding(.top, 4)
      .background(.bar)
    }
    #endif
  }
}

private struct HardeningCenterCard: View {
  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: "checkmark.shield")
        .font(.title3.weight(.semibold))
        .foregroundStyle(.cyan)
        .frame(width: 38, height: 38)
        .background(Color.cyan.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
      VStack(alignment: .leading, spacing: 3) {
        Text("Hardening Center")
          .font(.headline)
        Text("Lokalna lista kontroli i bezpiecznych zaleceń")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
      Image(systemName: "chevron.right")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
    }
    .padding(12)
    .background(.background, in: RoundedRectangle(cornerRadius: 14))
    .overlay {
      RoundedRectangle(cornerRadius: 14)
        .stroke(Color.cyan.opacity(0.14), lineWidth: 1)
    }
  }
}

struct SecretsInspectorView: View {
  @State private var input = ""

  private var findings: [SecretFinding] {
    SecretsInspector.scan(input)
  }

  var body: some View {
    List {
      Section {
        Text("Wklej konfigurację lub fragment logu. Analiza odbywa się lokalnie, a wartości są zawsze maskowane.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
        ZStack(alignment: .topLeading) {
          TextEditor(text: $input)
            .frame(minHeight: 180)
          if input.isEmpty {
            Text("np. API_KEY=…")
              .foregroundStyle(.tertiary)
              .padding(.top, 8)
              .padding(.leading, 5)
              .allowsHitTesting(false)
          }
        }
        .overlay {
          RoundedRectangle(cornerRadius: 10)
            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        }
        Button("Wyczyść") { input = "" }
          .disabled(input.isEmpty)
      }

      Section("Wynik") {
        if findings.isEmpty {
          Label(
            input.isEmpty ? "Brak danych do analizy" : "Nie znaleziono oczywistych wzorców",
            systemImage: input.isEmpty ? "doc.text" : "checkmark.shield"
          )
          .foregroundStyle(.secondary)
        } else {
          ForEach(findings) { finding in
            HStack {
              Label(finding.kind, systemImage: "exclamationmark.triangle")
              Spacer()
              Text("linia \(finding.lineNumber)")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
            }
            Text(finding.maskedValue)
              .font(.caption.monospaced())
              .foregroundStyle(.secondary)
          }
        }
      }

      Section {
        Label("Nie zapisujemy, nie wysyłamy i nie pokazujemy wartości sekretów.", systemImage: "lock.shield")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .listStyle(.insetGrouped)
    .navigationTitle("Secrets Inspector")
    .navigationBarTitleDisplayMode(.inline)
    #if NETSCOPE_DEV
    .safeAreaInset(edge: .top) {
      HStack {
        UIRefCopyButton(ref: .securitySecrets)
        Spacer()
      }
      .padding(.horizontal, 12)
      .padding(.top, 4)
      .background(.bar)
    }
    #endif
  }
}

private struct SecretsInspectorCard: View {
  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: "key.viewfinder")
        .font(.title3.weight(.semibold))
        .foregroundStyle(.cyan)
        .frame(width: 38, height: 38)
        .background(Color.cyan.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
      VStack(alignment: .leading, spacing: 3) {
        Text("Secrets Inspector")
          .font(.headline)
        Text("Lokalne wykrywanie i maskowanie potencjalnych sekretów")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
      Image(systemName: "chevron.right")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
    }
    .padding(12)
    .background(.background, in: RoundedRectangle(cornerRadius: 14))
    .overlay {
      RoundedRectangle(cornerRadius: 14)
        .stroke(Color.cyan.opacity(0.14), lineWidth: 1)
    }
  }
}

struct SecurityPlaybooksView: View {
  var body: some View {
    List(SecurityPlaybook.catalog) { playbook in
      NavigationLink {
        SecurityPlaybookDetailView(playbook: playbook)
      } label: {
        VStack(alignment: .leading, spacing: 5) {
          Text(playbook.title)
            .font(.headline)
          Text(playbook.summary)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
      }
    }
    .listStyle(.insetGrouped)
    .navigationTitle("Security Playbooks")
    .navigationBarTitleDisplayMode(.inline)
    #if NETSCOPE_DEV
    .safeAreaInset(edge: .top) {
      HStack {
        UIRefCopyButton(ref: .securityPlaybooks)
        Spacer()
      }
      .padding(.horizontal, 12)
      .padding(.top, 4)
      .background(.bar)
    }
    #endif
  }
}

private struct SecurityPlaybookDetailView: View {
  let playbook: SecurityPlaybook

  var body: some View {
    List {
      Section {
        Text(playbook.summary)
          .font(.subheadline)
        Label(playbook.caution, systemImage: "exclamationmark.shield")
          .font(.caption)
          .foregroundStyle(.orange)
      }

      Section("Procedura") {
        ForEach(playbook.steps) { step in
          VStack(alignment: .leading, spacing: 5) {
            Text("\(step.id)/6  \(step.title)")
              .font(.subheadline.weight(.semibold))
            Text(step.instruction)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          .padding(.vertical, 4)
        }
      }
    }
    .listStyle(.insetGrouped)
    .navigationTitle(playbook.title)
    .navigationBarTitleDisplayMode(.inline)
  }
}

private struct SecurityPlaybooksCard: View {
  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: "list.number")
        .font(.title3.weight(.semibold))
        .foregroundStyle(.cyan)
        .frame(width: 38, height: 38)
        .background(Color.cyan.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
      VStack(alignment: .leading, spacing: 3) {
        Text("Security Playbooks")
          .font(.headline)
        Text("Procedury reagowania krok po kroku")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
      Image(systemName: "chevron.right")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
    }
    .padding(12)
    .background(.background, in: RoundedRectangle(cornerRadius: 14))
    .overlay {
      RoundedRectangle(cornerRadius: 14)
        .stroke(Color.cyan.opacity(0.14), lineWidth: 1)
    }
  }
}

struct SecurityLabsView: View {
  var body: some View {
    List(SecurityLab.catalog) { lab in
      NavigationLink {
        SecurityLabDetailView(lab: lab)
      } label: {
        VStack(alignment: .leading, spacing: 5) {
          Text(lab.title)
            .font(.headline)
          Text(lab.objective)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
      }
    }
    .listStyle(.insetGrouped)
    .navigationTitle("Security Labs")
    .navigationBarTitleDisplayMode(.inline)
    #if NETSCOPE_DEV
    .safeAreaInset(edge: .top) {
      HStack {
        UIRefCopyButton(ref: .securityLabs)
        Spacer()
      }
      .padding(.horizontal, 12)
      .padding(.top, 4)
      .background(.bar)
    }
    #endif
  }
}

private struct SecurityLabDetailView: View {
  let lab: SecurityLab

  var body: some View {
    List {
      Section("Cel") {
        Text(lab.objective)
      }
      Section("Scenariusz") {
        Text(lab.scenario)
          .foregroundStyle(.secondary)
      }
      Section("Dane demonstracyjne") {
        ForEach(lab.evidence, id: \.self) { item in
          Label(item, systemImage: "doc.text.magnifyingglass")
            .font(.caption)
        }
      }
      Section("Oczekiwany rezultat") {
        Label(lab.expectedOutcome, systemImage: "checkmark.shield")
      }
      Section {
        Label("To laboratorium używa wyłącznie fikcyjnych danych lokalnych. Nie wykonuje poleceń ani połączeń sieciowych.", systemImage: "lock.shield")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .listStyle(.insetGrouped)
    .navigationTitle(lab.title)
    .navigationBarTitleDisplayMode(.inline)
  }
}

private struct SecurityLabsCard: View {
  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: "graduationcap")
        .font(.title3.weight(.semibold))
        .foregroundStyle(.cyan)
        .frame(width: 38, height: 38)
        .background(Color.cyan.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
      VStack(alignment: .leading, spacing: 3) {
        Text("Security Labs")
          .font(.headline)
        Text("Scenariusze edukacyjne bez skanowania sieci")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
      Image(systemName: "chevron.right")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
    }
    .padding(12)
    .background(.background, in: RoundedRectangle(cornerRadius: 14))
    .overlay {
      RoundedRectangle(cornerRadius: 14)
        .stroke(Color.cyan.opacity(0.14), lineWidth: 1)
    }
  }
}

private struct SecuritySummaryCard: View {
  let findingCount: Int

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: findingCount == 0 ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
        .font(.title2.weight(.semibold))
        .foregroundStyle(findingCount == 0 ? .green : .orange)
        .frame(width: 42, height: 42)
        .background((findingCount == 0 ? Color.green : Color.orange).opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
      VStack(alignment: .leading, spacing: 3) {
        Text(findingCount == 0 ? "Sieć wygląda spokojnie" : "Wykryto wskazania")
          .font(.headline)
        Text("\(findingCount) findings z ostatniego wyniku NET")
          .font(.caption.monospaced())
          .foregroundStyle(.secondary)
      }
      Spacer()
    }
    .padding(14)
    .background(.background, in: RoundedRectangle(cornerRadius: 16))
    .overlay {
      RoundedRectangle(cornerRadius: 16)
        .stroke(Color.cyan.opacity(0.14), lineWidth: 1)
    }
  }
}

private struct SecurityFindingCard: View {
  let finding: SecurityFinding

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Label(finding.severity.title, systemImage: finding.severity == .high ? "exclamationmark.triangle.fill" : "exclamationmark.shield.fill")
          .font(.subheadline.weight(.semibold))
        Spacer()
        Text(finding.severity.title)
          .font(.caption.weight(.semibold))
          .foregroundStyle(finding.severity == .high ? .red : .orange)
      }
      Text(finding.title)
        .font(.headline)
      Text(finding.summary)
        .font(.subheadline)
        .foregroundStyle(.secondary)
      Label(finding.whyItMatters, systemImage: "questionmark.circle")
        .font(.caption)
      Label(finding.remediation, systemImage: "checkmark.shield")
        .font(.caption)
      Text(finding.evidence)
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
    .padding(12)
    .background(.background, in: RoundedRectangle(cornerRadius: 14))
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
      #if NETSCOPE_DEV
      HStack {
        UIRefCopyButton(ref: .scannerServices)
        Spacer()
      }
      #endif
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
