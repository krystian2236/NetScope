import SwiftUI

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
    .background(NetScopeDesign.cardBackground, in: RoundedRectangle(cornerRadius: 12))
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
  @ObservedObject var knownDeviceStore: KnownDeviceStore
  @State private var customName: String
  @State private var isConfirmingRemoval = false

  init(
    device: NetworkDevice,
    key: KnownDeviceKey?,
    knownDeviceStore: KnownDeviceStore
  ) {
    self.device = device
    self.key = key
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
      identitySection
      savedDeviceSection
      exposureSection
      scanTelemetrySection
      servicesSection
      ishSection
      explanationSection
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
    Section("Dostępne usługi TCP") {
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
  var body: some View {
    List {
      Section("Wersja") {
        LabeledContent("NetScope", value: "1.3")
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
          "NetScope generuje polecenia i skrypty dla Nmap w trybie TCP connect. Skrypt trzeba świadomie zapisać i uruchomić w iSH."
        )
      }

      Section("Dostęp") {
        Link(
          "Otwórz ustawienia NetScope",
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

