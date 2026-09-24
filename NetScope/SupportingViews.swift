import SwiftUI
import UniformTypeIdentifiers

struct DeviceRow: View {
  let device: NetworkDevice
  let record: KnownDeviceRecord?
  let registryStatus: DeviceRegistryStatus

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: device.kind.icon)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.cyan)
        .frame(width: 34, height: 34)
        .background(.cyan.opacity(0.11), in: RoundedRectangle(cornerRadius: 9))

      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 6) {
          Text(device.displayName(using: record))
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
            .lineLimit(1)
          DeviceRegistryStatusBadge(status: registryStatus)
          ExposureBadge(level: device.exposure)
        }
        Text("IP: \(device.address)")
          .font(.caption2.monospaced())
          .foregroundStyle(.secondary)
        if let hostname = device.hostname, hostname != device.address {
          Text("DNS: \(hostname)")
            .font(.caption2.monospaced())
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        Text(device.serviceSummary)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }

      Spacer(minLength: 4)
      Image(systemName: "chevron.right")
        .font(.caption2.weight(.bold))
        .foregroundStyle(.tertiary)
        .accessibilityHidden(true)
    }
    .padding(10)
    .background(.background, in: RoundedRectangle(cornerRadius: 12))
    .contentShape(Rectangle())
    .accessibilityElement(children: .combine)
    .accessibilityLabel(
      "\(device.displayName(using: record)), IP \(device.address), \(device.openPorts.count) usług"
    )
    .accessibilityHint("Otwiera szczegóły urządzenia")
  }
}

struct DeviceDetailView: View {
  let device: NetworkDevice
  let key: KnownDeviceKey?
  @ObservedObject var scanner: NetworkScanner
  @ObservedObject var knownDeviceStore: KnownDeviceStore
  @State private var customName: String
  @State private var isConfirmingRemoval = false

  init(
    device: NetworkDevice,
    key: KnownDeviceKey?,
    scanner: NetworkScanner,
    knownDeviceStore: KnownDeviceStore
  ) {
    self.device = device
    self.key = key
    self.scanner = scanner
    self.knownDeviceStore = knownDeviceStore
    _customName = State(
      initialValue: key.flatMap { knownDeviceStore.record(for: $0)?.customName } ?? ""
    )
  }

  private var record: KnownDeviceRecord? {
    guard let key else { return nil }
    return knownDeviceStore.record(for: key)
  }

  var body: some View {
    List {
      #if NETSCOPE_DEV
      HStack { UIRefCopyButton(ref: .scannerDeviceDetails); Spacer() }
      #endif
      if device.kind == .router {
        routerSummarySection
      } else {
        identitySection
        savedDeviceSection
        exposureSection
        scanTelemetrySection
        servicesSection
        ishSection
        explanationSection
      }
    }
    .font(.subheadline)
    .navigationTitle(device.displayName(using: record))
    .navigationBarTitleDisplayMode(.inline)
    .onDisappear(perform: saveName)
    .confirmationDialog(
      "Usunąć zapamiętane urządzenie?",
      isPresented: $isConfirmingRemoval,
      titleVisibility: .visible
    ) {
      Button("Usuń z zapamiętanych", role: .destructive, action: removeSavedDevice)
      Button("Anuluj", role: .cancel) {}
    } message: {
      Text("Urządzenie pozostanie w bieżących wynikach i może zostać dodane ponownie po następnym pełnym skanie.")
    }
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        ShareLink(item: device.address) {
          Label("Udostępnij IP", systemImage: "square.and.arrow.up")
        }
      }
    }
  }

  @ViewBuilder
  private var savedDeviceSection: some View {
    Section("Moje urządzenie") {
      if let key, let record {
        TextField("Własna nazwa", text: $customName)
          .submitLabel(.done)
          .onSubmit(saveName)

        Toggle(
          "Zaufane urządzenie",
          isOn: Binding(
            get: { record.trustStatus == .trusted },
            set: { isTrusted in
              knownDeviceStore.setTrust(
                key,
                status: isTrusted ? .trusted : .unknown
              )
            }
          )
        )

        LabeledContent(
          "Pierwsze wykrycie",
          value: record.firstSeen.formatted(date: .abbreviated, time: .shortened)
        )
        LabeledContent(
          "Ostatnie wykrycie",
          value: record.lastSeen.formatted(date: .abbreviated, time: .shortened)
        )

        Button("Usuń z zapamiętanych", role: .destructive) {
          isConfirmingRemoval = true
        }
      } else {
        Text("Urządzenie zostanie zapamiętane po ukończeniu pełnego skanu.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }

  private var identitySection: some View {
    Section("Urządzenie") {
      if let hostname = device.hostname {
        NavigationLink {
          HostAddressDetailView(
            title: "Nazwa DNS",
            host: hostname,
            openPorts: device.openPorts
          )
        } label: {
          LabeledContent("Nazwa DNS", value: hostname)
        }
      }
      NavigationLink {
        HostAddressDetailView(
          title: "Adres IP",
          host: device.address,
          openPorts: device.openPorts
        )
      } label: {
        LabeledContent("Adres IP", value: device.address)
      }
      LabeledContent("Rozpoznany typ", value: device.kind.title)
      LabeledContent(
        "Ostatnio widziane",
        value: device.lastSeen.formatted(date: .abbreviated, time: .standard)
      )
    }
  }

  private var exposureSection: some View {
    Section("Ocena ekspozycji") {
      HStack {
        Text("Poziom")
        Spacer()
        ExposureBadge(level: device.exposure)
      }
      LabeledContent("Otwarte usługi", value: "\(device.openPorts.count)")
      LabeledContent("Szyfrowane", value: "\(device.encryptedServiceCount)")
      LabeledContent("Bez gwarancji szyfrowania", value: "\(device.unencryptedServiceCount)")
      Text(device.exposure.recommendation)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }

  private var servicesSection: some View {
    Section("Wykryte usługi") {
      ForEach(device.openPorts, id: \.self) { port in
        let info = PortCatalog.info(for: port)
        HStack(alignment: .top, spacing: 9) {
          Image(systemName: info.isEncrypted ? "lock.shield.fill" : "door.left.hand.open")
            .foregroundStyle(info.isEncrypted ? .green : .orange)
            .frame(width: 18)
          VStack(alignment: .leading, spacing: 2) {
            HStack {
              Text(info.name)
                .font(.subheadline.weight(.semibold))
              Text(info.category)
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            Text(info.description)
              .font(.caption)
              .foregroundStyle(.secondary)
            if let latency = device.latency(for: port) {
              Text(String(format: "Połączenie TCP: %.1f ms", latency))
                .font(.caption2.monospaced())
                .foregroundStyle(.tertiary)
            }
          }
          Spacer()
          Text("\(port)")
            .font(.caption.monospaced())
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
      }
    }
  }

  private var routerSummarySection: some View {
    Group {
      Section("Podsumowanie") {
        HStack {
          VStack(alignment: .leading, spacing: 3) {
            Text("Router / Brama").font(.headline)
            Text(device.address).font(.caption.monospaced()).foregroundStyle(.secondary)
            if let customName = record?.customName, !customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
              Text(customName).font(.caption).foregroundStyle(.secondary)
            }
            if let hostname = device.hostname, hostname != device.address {
              Text(hostname).font(.caption).foregroundStyle(.secondary)
            }
          }
          Spacer()
          Text("Online").font(.caption.weight(.semibold)).foregroundStyle(.green)
        }
        Text(routerSummaryText)
          .font(.caption)
          .foregroundStyle(.secondary)
        LabeledContent("Otwarte usługi", value: "\(device.openPorts.count)")
        LabeledContent("Szyfrowane / pozostałe", value: "\(device.encryptedServiceCount) / \(device.unencryptedServiceCount)")
        LabeledContent("Poziom ekspozycji", value: device.exposure.title)
        NavigationLink("Co to oznacza?") { exposureDetail }
      }

      Section("Wykryte usługi") {
        ForEach(device.openPorts.prefix(2), id: \.self) { port in
          NavigationLink {
            ServiceDetailView(device: device, port: port)
          } label: {
            LabeledContent(
              "\(PortCatalog.info(for: port).name) \(port)/\(PortCatalog.transport(for: port))",
              value: PortCatalog.info(for: port).category
            )
          }
        }
        NavigationLink("Wszystkie usługi") { OpenServicesView(device: device) }
      }

      Section("Ostatni skan") {
        if let details = scanner.sessionDetails {
          LabeledContent("Zakończono", value: (details.finishedAt ?? details.startedAt).formatted(date: .abbreviated, time: .shortened))
          LabeledContent("Sprawdzone / wykryte", value: "\(device.testedPortCount) / \(device.openPorts.count)")
          LabeledContent("Status", value: scanner.phase.isScanning ? "W toku" : "Zakończony")
          NavigationLink("Szczegóły skanu") { ScanDetailsView(scanner: scanner) }
        } else {
          Text("Brak danych ostatniego przebiegu skanu.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }

      Section {
        NavigationLink("Narzędzia dla tego urządzenia") {
          DeviceToolsView(device: device)
        }
        NavigationLink("Informacje o urządzeniu") { deviceInfoDetail }
      }
    }
  }

  private var routerSummaryText: String {
    let count = device.openPorts.count
    guard count > 0 else { return "Nie wykryto otwartych usług podczas ostatniego sprawdzania." }
    if device.openPorts.contains(80) && device.openPorts.contains(443) {
      return "Wykryto \(count) usług. HTTPS jest szyfrowane, a HTTP nie — do logowania wybieraj HTTPS."
    }
    return "Wykryto \(count) usług. Nie oznacza to podatności, ale pokazuje funkcje dostępne dla urządzeń w tej sieci."
  }

  private var exposureDetail: some View {
    List {
      Section("Bezpieczeństwo") {
        LabeledContent("Poziom ekspozycji", value: device.exposure.title)
        Text("Poziom ekspozycji jest szacunkiem opartym na usługach widocznych podczas lokalnego skanu. Nie jest testem podatności.")
          .font(.caption)
          .foregroundStyle(.secondary)
        Text(device.exposure.recommendation)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Section("Metryki") {
        LabeledContent("Otwarte usługi", value: "\(device.openPorts.count)")
        LabeledContent("Szyfrowane", value: "\(device.encryptedServiceCount)")
        LabeledContent("Bez gwarancji szyfrowania", value: "\(device.unencryptedServiceCount)")
      }
    }
    .navigationTitle("Bezpieczeństwo")
    .navigationBarTitleDisplayMode(.inline)
  }

  private var deviceInfoDetail: some View {
    List {
      identitySection
      savedDeviceSection
    }
    .navigationTitle("Informacje o urządzeniu")
    .navigationBarTitleDisplayMode(.inline)
  }

  private var scanTelemetrySection: some View {
    Section("Przebieg wykrywania") {
      LabeledContent("Sprawdzone porty", value: "\(device.testedPortCount)")
      LabeledContent("Otwarte", value: "\(device.openPorts.count)")
      LabeledContent("Odrzucone / zamknięte", value: "\(device.closedPortCount)")
      LabeledContent("Brak odpowiedzi", value: "\(device.timedOutPortCount)")
      if device.deniedPortCount > 0 {
        LabeledContent("Brak dostępu lokalnego", value: "\(device.deniedPortCount)")
      }
      if let duration = device.probeDurationMilliseconds {
        LabeledContent(
          "Czas wykrywania",
          value: String(format: "%.0f ms", duration)
        )
      }
    }
  }

  private var ishSection: some View {
    Section("iSH") {
      NavigationLink {
        ISHToolkitView(
          context: nil,
          devices: [device],
          preferredAddress: device.address
        )
      } label: {
        Label("Przygotuj polecenie dla tego urządzenia", systemImage: "terminal")
      }
    }
  }

  private var explanationSection: some View {
    Section {
      Text(
        "Typ urządzenia i poziom ekspozycji są szacowane na podstawie widocznych portów. Nie jest to test podatności ani potwierdzenie zagrożenia."
      )
      .font(.caption)
      .foregroundStyle(.secondary)
    }
  }

  private func saveName() {
    guard let key, record != nil else { return }
    knownDeviceStore.rename(key, customName: customName)
  }

  private func removeSavedDevice() {
    guard let key else { return }
    knownDeviceStore.remove(key)
    customName = ""
  }
}

private struct DeviceToolsView: View {
  let device: NetworkDevice

  private var commands: [RouterReadyCommand] {
    RouterReadyCommandBuilder.commands(for: device)
  }

  var body: some View {
    List {
      Section("Podstawowe") {
        commandRows(prefixes: ["Sprawdź dostępność", "Sprawdź port"])
      }
      Section("Sieć") {
        commandRows(prefixes: ["Sprawdź trasę", "Sprawdź DNS"])
      }
      Section("Usługi") {
        commandRows(prefixes: ["Otwórz panel WWW", "Połącz przez SSH", "Rozpoznaj usługi"])
      }
      Section("Terminal") {
        NavigationLink("Przygotuj polecenie w iSH") {
          ISHToolkitView(context: nil, devices: [device], preferredAddress: device.address)
        }
        Text("Northbyte Radar niczego nie uruchamia automatycznie; polecenie wymaga świadomego skopiowania i uruchomienia.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .navigationTitle("Narzędzia")
    .navigationBarTitleDisplayMode(.inline)
  }

  @ViewBuilder
  private func commandRows(prefixes: [String]) -> some View {
    ForEach(commands.filter { item in prefixes.contains { item.title.hasPrefix($0) } }, id: \.command) { item in
      VStack(alignment: .leading, spacing: 3) {
        Text(item.title).font(.subheadline.weight(.semibold))
        Text(description(for: item.title)).font(.caption).foregroundStyle(.secondary)
        Text(item.command).font(.caption2.monospaced()).textSelection(.enabled)
      }
      .padding(.vertical, 3)
    }
  }

  private func description(for title: String) -> String {
    switch title {
    case "Sprawdź dostępność": "Sprawdza, czy urządzenie odpowiada w sieci lokalnej."
    case "Sprawdź trasę": "Pokazuje drogę pakietów do urządzenia."
    case "Sprawdź DNS": "Sprawdza rozwiązywanie nazwy przez wykryty resolver DNS."
    case "Połącz przez SSH": "Przygotowuje zdalne połączenie administracyjne."
    case "Rozpoznaj usługi": "Próbuje rozpoznać wersje wykrytych usług."
    default: "Sprawdza dostępność konkretnej usługi."
    }
  }
}

private struct OpenServicesView: View {
  let device: NetworkDevice

  var body: some View {
    List {
      Section("Wykryte podczas ostatniego skanu") {
        ForEach(device.openPorts, id: \.self) { port in
          NavigationLink {
            ServiceDetailView(device: device, port: port)
          } label: {
            LabeledContent(
              "\(PortCatalog.info(for: port).name) \(port)/\(PortCatalog.transport(for: port))",
              value: PortCatalog.info(for: port).category
            )
          }
        }
      }
    }
    .navigationTitle("Wykryte usługi")
    .navigationBarTitleDisplayMode(.inline)
  }
}

private struct ServiceDetailView: View {
  let device: NetworkDevice
  let port: UInt16

  private var info: PortInfo { PortCatalog.info(for: port) }
  private var commands: [RouterReadyCommand] {
    RouterReadyCommandBuilder.commands(for: device).filter { command in
      command.command.contains(" \(port)")
        || (port == 22 && command.command.hasPrefix("ssh "))
        || (port == 53 && command.command.hasPrefix("dig @"))
        || ([80, 443, 8000, 8080, 8081, 8443, 8888].contains(port) && command.command.contains("://"))
    }
  }

  var body: some View {
    List {
      Section {
        LabeledContent("Usługa", value: info.name)
        LabeledContent("Port / protokół", value: "\(port)/\(PortCatalog.transport(for: port))")
        LabeledContent("Szyfrowanie", value: info.isEncrypted ? "Tak" : "Brak gwarancji")
      }
      Section("Wyjaśnienie") {
        LabeledContent("Co to jest", value: info.description)
        LabeledContent("Co daje wykrycie", value: PortCatalog.userValue(for: port))
        if let use = PortCatalog.routerUse(for: port) {
          LabeledContent("Typowe zastosowanie", value: use)
        }
        Text(nextStep)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Section("Gotowe akcje") {
        ForEach(commands, id: \.command) { item in
          VStack(alignment: .leading, spacing: 3) {
            Text(item.title).font(.caption.weight(.semibold))
            Text(item.command).font(.caption2.monospaced()).textSelection(.enabled)
          }
        }
      }
    }
    .navigationTitle(info.name)
    .navigationBarTitleDisplayMode(.inline)
  }

  private var nextStep: String {
    switch port {
    case 80 where device.openPorts.contains(443):
      "Co warto zrobić dalej: jeśli panel jest dostępny, preferuj HTTPS zamiast HTTP."
    case 443, 8443:
      "Co warto zrobić dalej: korzystaj z panelu tylko w zaufanej sieci lokalnej."
    case 22:
      "Co warto zrobić dalej: sprawdź, czy SSH jest potrzebne i ograniczone do zaufanych urządzeń."
    case 53:
      "Co warto zrobić dalej: użyj DNS tylko jako lokalnego resolvera, jeśli tego potrzebujesz."
    default:
      "Co warto zrobić dalej: potwierdź, czy ta usługa jest potrzebna na urządzeniu."
    }
  }
}

private struct HostAddressDetailView: View {
  let title: String
  let host: String
  let openPorts: [UInt16]

  var body: some View {
    List {
      Section(title) {
        Text(host)
          .font(.body.monospaced())
          .textSelection(.enabled)
        ShareLink(item: host) {
          Label("Udostępnij lub kopiuj", systemImage: "square.and.arrow.up")
        }
      }

      if !webLinks.isEmpty {
        Section("Dostępne strony") {
          ForEach(webLinks, id: \.absoluteString) { url in
            Link(destination: url) {
              Label {
                HStack {
                  Text("Otwórz \(url.scheme?.uppercased() ?? "stronę")")
                  Spacer()
                  Image(systemName: "arrow.up.right")
                    .foregroundStyle(.secondary)
                }
              } icon: {
                Image(systemName: url.scheme == "https" ? "lock.fill" : "globe")
              }
            }
          }
        }
      } else {
        Section("Dostępne strony") {
          Text("Nie wykryto portu HTTP ani HTTPS dla tego urządzenia.")
            .foregroundStyle(.secondary)
        }
      }
    }
    .navigationTitle(title)
    .navigationBarTitleDisplayMode(.inline)
  }

  private var webLinks: [URL] {
    var links: [URL] = []
    if openPorts.contains(443), let url = URL(string: "https://\(host)") {
      links.append(url)
    }
    if openPorts.contains(80), let url = URL(string: "http://\(host)") {
      links.append(url)
    }
    return links
  }
}

private struct DeviceRegistryStatusBadge: View {
  let status: DeviceRegistryStatus

  private var tint: Color {
    switch status {
    case .new: .cyan
    case .trusted: .green
    case .unknown: .orange
    }
  }

  var body: some View {
    Text(status.title)
      .font(.caption2.weight(.semibold))
      .foregroundStyle(tint)
      .padding(.horizontal, 6)
      .padding(.vertical, 2)
      .background(tint.opacity(0.12), in: Capsule())
  }
}

struct InfoBanner: View {
  let icon: String
  let title: String
  let message: String
  var tint: Color = .cyan

  var body: some View {
    HStack(alignment: .top, spacing: 9) {
      Image(systemName: icon)
        .foregroundStyle(tint)
        .font(.subheadline)
        .frame(width: 20)
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.caption.weight(.semibold))
        Text(message)
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
      Spacer()
    }
    .padding(10)
    .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
  }
}

struct ServicesView: View {
  @ObservedObject var discovery: BonjourDiscovery

  var body: some View {
    NavigationStack {
      Group {
        if discovery.services.isEmpty {
          ContentUnavailableView(
            discovery.isRunning ? "Szukam usług…" : "Brak usług Bonjour",
            systemImage: "bonjour",
            description: Text(discovery.statusMessage)
          )
        } else {
          List {
            Section {
              HStack {
                Label("\(discovery.services.count) usług", systemImage: "bonjour")
                Spacer()
                if discovery.isRunning {
                  ProgressView()
                    .controlSize(.small)
                }
              }
              .font(.caption.weight(.semibold))
            }

            Section("Wykryte w sieci") {
              ForEach(discovery.services) { service in
                VStack(alignment: .leading, spacing: 3) {
                  HStack {
                    Text(service.name)
                      .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(service.friendlyType)
                      .font(.caption2)
                      .foregroundStyle(.cyan)
                  }
                  Text("\(service.type) • \(service.domain)")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                  if let interfaceName = service.interfaceName {
                    Text("Interfejs: \(interfaceName)")
                      .font(.caption2)
                      .foregroundStyle(.tertiary)
                  }
                }
                .padding(.vertical, 2)
              }
            }
          }
        }
      }
    .overlay(alignment: .topTrailing) {
      #if NETSCOPE_DEV
      UIRefCopyButton(ref: .scannerBonjour)
        .padding(.top, 8)
        .padding(.trailing, 12)
      #endif
    }
    .navigationTitle("Usługi Bonjour")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button(action: toggleDiscovery) {
            Label(
              discovery.isRunning ? "Zatrzymaj" : "Szukaj",
              systemImage: discovery.isRunning ? "stop.fill" : "arrow.clockwise"
            )
          }
        }
      }
      .task {
        if discovery.services.isEmpty && !discovery.isRunning {
          discovery.start()
        }
      }
    }
  }

  private func toggleDiscovery() {
    if discovery.isRunning {
      discovery.stop()
    } else {
      discovery.start()
    }
  }
}

struct AboutView: View {
  private let identity = AppReleaseIdentity.current

  var body: some View {
    List {
      #if NETSCOPE_DEV
      HStack { UIRefCopyButton(ref: .about); Spacer() }
      #endif
      Section("Wersja") {
        LabeledContent("Nazwa", value: identity.displayName)
        LabeledContent("Wersja", value: identity.version)
        LabeledContent("Build", value: identity.build)
        LabeledContent("Bundle ID", value: identity.bundleIdentifier)
        LabeledContent("Tryb", value: identity.distribution)
        Text("Natywny zestaw narzędzi do obserwacji własnej sieci na iOS.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Section("Bezpieczeństwo") {
        Label("Tylko prywatne adresy IPv4", systemImage: "lock.shield")
        Label("Wyniki i historia zostają lokalnie", systemImage: "iphone")
        Label("Bez logowania i wysyłania poleceń", systemImage: "hand.raised")
      }

      Section("My IP") {
        Text(
          "Publiczny adres IP jest pobierany z api64.ipify.org dopiero po naciśnięciu przycisku."
        )
      }

      Section("Ograniczenia iOS") {
        Text(
          "iOS nie udostępnia pełnych danych ARP, dlatego aplikacja nie pokazuje adresów MAC ani producenta urządzenia."
        )
        Text(
          "Zapamiętane urządzenia są rozróżniane na podstawie sieci i adresu IP. Po zmianie adresu przez router to samo urządzenie może pojawić się jako nowe."
        )
        Text(
          "TCP Ping mierzy czas nawiązania połączenia z portem, a nie klasyczny ping ICMP."
        )
        Text(
          "Typ urządzenia oraz ekspozycja są wskazówkami obliczonymi na podstawie portów, nie wynikiem audytu bezpieczeństwa."
        )
      }

      Section("iSH") {
        Text(
          "Northbyte Radar generuje polecenia i skrypty dla Nmap w trybie TCP connect. Skrypt trzeba świadomie zapisać i uruchomić w iSH."
        )
      }

      Section("Dostęp") {
        Link(
          "Otwórz ustawienia Northbyte Radar",
          destination: URL(string: UIApplication.openSettingsURLString)!
        )
      }
    }
    .navigationTitle("O aplikacji")
    .navigationBarTitleDisplayMode(.inline)
  }

}

struct ScanCSVDocument: FileDocument {
  static var readableContentTypes: [UTType] { [.commaSeparatedText] }

  let devices: [NetworkDevice]

  init(devices: [NetworkDevice]) {
    self.devices = devices
  }

  init(configuration: ReadConfiguration) throws {
    devices = []
  }

  func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
    let header = "IP,Nazwa DNS,Typ,Ekspozycja,Otwarte porty,Usługi,Ostatnio widziane\n"
    let rows = devices.map { device in
      let ports = device.openPorts.map(String.init).joined(separator: " ")
      let services = device.openPorts.map { PortCatalog.name(for: $0) }.joined(separator: " ")
      return [
        device.address,
        csv(device.hostname ?? ""),
        csv(device.kind.title),
        device.exposure.title,
        csv(ports),
        csv(services),
        ISO8601DateFormatter().string(from: device.lastSeen),
      ].joined(separator: ",")
    }
    return FileWrapper(
      regularFileWithContents: Data((header + rows.joined(separator: "\n")).utf8)
    )
  }

  private func csv(_ value: String) -> String {
    "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
  }
}
