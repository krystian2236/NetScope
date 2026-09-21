import SwiftUI

struct ScannerView: View {
  @ObservedObject var scanner: NetworkScanner
  @ObservedObject var knownDeviceStore: KnownDeviceStore
  @ObservedObject var tools: NetworkToolsModel

  var body: some View {
    NavigationStack {
      ScrollView {
        LazyVStack(spacing: 12) {
          #if NETSCOPE_DEV
          HStack {
            UIRefCopyButton(ref: .scanner)
            Spacer()
          }
          #endif
          NetworkHeaderCard(context: scanner.context)
          StartDestinations(
            scanner: scanner,
            knownDeviceStore: knownDeviceStore,
            tools: tools
          )
          ScanWorkflowView(current: scanner.stage, phase: scanner.phase)
          ScanControlCard(
            profile: $scanner.profile,
            isScanning: scanner.phase.isScanning,
            onScan: startScan,
            onCancel: scanner.cancel
          )
          ScanStatusView(phase: scanner.phase, deviceCount: scanner.devices.count)
          if scanner.sessionDetails != nil {
            NavigationLink {
              ScanDetailsView(scanner: scanner)
            } label: {
              HStack {
                Label("Szczegóły przebiegu", systemImage: "chart.bar.doc.horizontal")
                  .font(.caption.weight(.semibold))
                Spacer()
                Image(systemName: "chevron.right")
                  .font(.caption2.weight(.bold))
              }
              .padding(10)
              .background(.background, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
          }
          if !scanner.devices.isEmpty {
            DeviceSummaryStrip(devices: scanner.devices)
          } else if !scanner.phase.isScanning {
            ContentUnavailableView(
              "Brak wyników",
              systemImage: "dot.radiowaves.left.and.right",
              description: Text("Wybierz profil i rozpocznij skan prywatnej sieci.")
            )
            .frame(minHeight: 150)
          }
        }
        .padding(12)
      }
      .background(Color(.systemGroupedBackground))
      .navigationTitle("Skan sieci")
      .navigationBarTitleDisplayMode(.inline)
    }
  }

  private func startScan() {
    Task { await scanner.scan() }
  }

}

private struct StartDestinations: View {
  @ObservedObject var scanner: NetworkScanner
  @ObservedObject var knownDeviceStore: KnownDeviceStore
  @ObservedObject var tools: NetworkToolsModel

  var body: some View {
    HStack(spacing: 10) {
      destination(
        title: "Urządzenia",
        subtitle: scanner.devices.isEmpty ? "Po wykonaniu skanu" : "Wykryto: \(scanner.devices.count)",
        icon: "desktopcomputer"
      ) {
        DevicesView(scanner: scanner, knownDeviceStore: knownDeviceStore)
      }

      destination(
        title: "Usługi",
        subtitle: "Porty, ping i Bonjour",
        icon: "wrench.and.screwdriver"
      ) {
        ServicesHubView(scanner: scanner, tools: tools)
      }
    }
  }

  private func destination<Destination: View>(
    title: String,
    subtitle: String,
    icon: String,
    @ViewBuilder destination: () -> Destination
  ) -> some View {
    NavigationLink(destination: destination()) {
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Image(systemName: icon)
            .font(.headline)
            .foregroundStyle(.cyan)
          Spacer()
          Image(systemName: "chevron.right")
            .font(.caption.weight(.bold))
            .foregroundStyle(.secondary)
        }
        Text(title)
          .font(.subheadline.weight(.semibold))
        Text(subtitle)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .minimumScaleFactor(0.8)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(12)
      .background(.background, in: RoundedRectangle(cornerRadius: 14))
    }
    .buttonStyle(.plain)
  }
}

private struct ScanWorkflowView: View {
  let current: ScanStage
  let phase: ScanPhase

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text("Przebieg skanu")
          .font(.caption.weight(.semibold))
        Spacer()
        Text(current.title)
          .font(.caption2.weight(.medium))
          .foregroundStyle(.secondary)
      }

      HStack(alignment: .top, spacing: 4) {
        ForEach(Array(ScanStage.allCases.enumerated()), id: \.element.id) { index, stage in
          VStack(spacing: 5) {
            Image(systemName: symbol(for: stage))
              .font(.caption2.weight(.bold))
              .foregroundStyle(color(for: stage))
              .frame(width: 26, height: 26)
              .background(color(for: stage).opacity(0.12), in: Circle())
            Text(stage.title)
              .font(.caption2)
              .multilineTextAlignment(.center)
              .foregroundStyle(stage.rawValue <= current.rawValue ? .primary : .secondary)
              .lineLimit(2)
              .minimumScaleFactor(0.8)
          }
          .frame(maxWidth: .infinity)

          if index < ScanStage.allCases.count - 1 {
            Capsule()
              .fill(stage.rawValue < current.rawValue ? Color.green : Color.secondary.opacity(0.2))
              .frame(height: 2)
              .padding(.top, 12)
          }
        }
      }

      ProgressView(value: displayedProgress)
        .tint(.cyan)
        .accessibilityLabel("Przebieg skanu")
        .accessibilityValue(current.title)
    }
    .padding(11)
    .background(.background, in: RoundedRectangle(cornerRadius: 14))
  }

  private var displayedProgress: Double {
    switch phase {
    case .idle: 0
    case .failed, .cancelled: current.progress
    default: current.progress
    }
  }

  private func symbol(for stage: ScanStage) -> String {
    if isComplete(stage) { return "checkmark" }
    return stage.icon
  }

  private func color(for stage: ScanStage) -> Color {
    if isComplete(stage) { return .green }
    if stage == current, phase != .idle { return .cyan }
    return .secondary
  }

  private func isComplete(_ stage: ScanStage) -> Bool {
    stage.rawValue < current.rawValue
      || (stage == .results && current == .results && scanFinished)
  }

  private var scanFinished: Bool {
    if case .finished = phase { return true }
    return false
  }
}

enum DeviceFilter: String, CaseIterable, Identifiable {
  case all
  case unknown
  case attention
  case smartHome
  case infrastructure

  var id: Self { self }

  var title: String {
    switch self {
    case .all: "Wszystkie"
    case .unknown: "Nowe / nieznane"
    case .attention: "Do sprawdzenia"
    case .smartHome: "IoT"
    case .infrastructure: "Infrastruktura"
    }
  }

  func matches(
    _ device: NetworkDevice,
    registryStatus: DeviceRegistryStatus
  ) -> Bool {
    switch self {
    case .all:
      true
    case .unknown:
      registryStatus == .new || registryStatus == .unknown
    case .attention:
      device.exposure == .high
    case .smartHome:
      [.smartHome, .camera, .media].contains(device.kind)
    case .infrastructure:
      [.router, .server, .computer].contains(device.kind)
    }
  }
}

private struct NetworkHeaderCard: View {
  let context: NetworkContext?

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: "network")
        .font(.headline)
        .foregroundStyle(.white)
        .frame(width: 36, height: 36)
        .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 10))
      VStack(alignment: .leading, spacing: 2) {
        Text("Prywatna sieć lokalna")
          .font(.subheadline.weight(.semibold))
        if let context {
          Text("\(context.address) • \(context.scanRangeDescription)")
            .font(.caption2.monospaced())
            .foregroundStyle(.white.opacity(0.82))
        } else {
          Text("Połącz iPhone’a z Wi‑Fi")
            .font(.caption)
            .foregroundStyle(.white.opacity(0.82))
        }
      }
      Spacer()
      Text("LOKALNIE")
        .font(.caption2.weight(.bold))
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(.white.opacity(0.14), in: Capsule())
    }
    .foregroundStyle(.white)
    .padding(12)
    .background(
      LinearGradient(
        colors: [.indigo, .cyan],
        startPoint: .leading,
        endPoint: .trailing
      ),
      in: RoundedRectangle(cornerRadius: 14)
    )
  }
}

private struct ScanControlCard: View {
  @Binding var profile: ScanProfile
  let isScanning: Bool
  let onScan: () -> Void
  let onCancel: () -> Void

  var body: some View {
    VStack(spacing: 9) {
      HStack {
        VStack(alignment: .leading, spacing: 1) {
          Text("Profil skanowania")
            .font(.caption.weight(.semibold))
          Text(profile.subtitle)
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        Spacer()
        Picker("Profil", selection: $profile) {
          ForEach(ScanProfile.allCases) { item in
            Text(item.title).tag(item)
          }
        }
        .pickerStyle(.menu)
        .disabled(isScanning)
      }

      HStack {
        Label("\(profile.ports.count) portów", systemImage: "number")
        Spacer()
        Label("do 254 adresów", systemImage: "rectangle.3.group")
      }
      .font(.caption2)
      .foregroundStyle(.secondary)

      if isScanning {
        Button(role: .destructive, action: onCancel) {
          Label("Zatrzymaj skanowanie", systemImage: "stop.fill")
            .font(.caption.weight(.semibold))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
      } else {
        Button(action: onScan) {
          Label("Skanuj moją sieć", systemImage: "dot.radiowaves.left.and.right")
            .font(.caption.weight(.semibold))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(.cyan)
      }
    }
    .padding(11)
    .background(.background, in: RoundedRectangle(cornerRadius: 14))
  }
}

private struct ScanStatusView: View {
  let phase: ScanPhase
  let deviceCount: Int

  @ViewBuilder
  var body: some View {
    switch phase {
    case .idle:
      InfoBanner(
        icon: "hand.tap",
        title: "Gotowe",
        message: "iOS może poprosić o dostęp do sieci lokalnej."
      )
    case .preparing:
      ProgressView("Sprawdzanie Wi‑Fi…")
        .font(.caption)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel("Sprawdzanie połączenia Wi‑Fi")
    case .scanning(let completed, let total):
      VStack(alignment: .leading, spacing: 7) {
        HStack {
          Text("Skanowanie \(completed) z \(total)")
          Spacer()
          Text("\(deviceCount) wykrytych")
            .foregroundStyle(.secondary)
        }
        .font(.caption.weight(.medium))
        ProgressView(value: Double(completed), total: Double(max(total, 1)))
          .tint(.cyan)
          .accessibilityLabel("Postęp skanowania")
          .accessibilityValue("\(completed) z \(total) adresów")
      }
    case .finished(let date):
      InfoBanner(
        icon: "checkmark.circle.fill",
        title: "Skan zakończony",
        message: "\(deviceCount) urządzeń • \(date.formatted(date: .omitted, time: .shortened))"
      )
    case .cancelled:
      InfoBanner(
        icon: "stop.circle",
        title: "Skan zatrzymany",
        message: "Zachowano dotychczasowe wyniki."
      )
    case .failed(let message):
      InfoBanner(
        icon: "exclamationmark.triangle.fill",
        title: "Nie można skanować",
        message: message,
        tint: .orange
      )
    }
  }
}

private struct DeviceSummaryStrip: View {
  let devices: [NetworkDevice]

  var body: some View {
    HStack(spacing: 8) {
      MetricCard(
        title: "Urządzenia",
        value: "\(devices.count)",
        icon: "desktopcomputer"
      )
      MetricCard(
        title: "Usługi",
        value: "\(devices.reduce(0) { $0 + $1.openPorts.count })",
        icon: "door.left.hand.open"
      )
      MetricCard(
        title: "Uwaga",
        value: "\(devices.filter { $0.exposure == .high }.count)",
        icon: "exclamationmark.shield",
        tint: .orange
      )
    }
  }
}

struct DeviceFilterBar: View {
  @Binding var selection: DeviceFilter

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 6) {
        ForEach(DeviceFilter.allCases) { filter in
          Button(filter.title) {
            selection = filter
          }
          .font(.caption2.weight(.medium))
          .buttonStyle(.bordered)
          .tint(selection == filter ? .cyan : .secondary)
        }
      }
    }
  }
}

private struct DeviceResultsSection: View {
  let devices: [NetworkDevice]
  let phase: ScanPhase
  let hasScanResults: Bool
  let networkID: String?
  let newDeviceKeys: Set<KnownDeviceKey>
  @ObservedObject var knownDeviceStore: KnownDeviceStore
  let onSelect: (NetworkDevice) -> Void

  @ViewBuilder
  var body: some View {
    if devices.isEmpty {
      ContentUnavailableView(
        emptyTitle,
        systemImage: emptyIcon,
        description: Text(description)
      )
      .frame(minHeight: 180)
    } else {
      VStack(alignment: .leading, spacing: 8) {
        Text("Urządzenia (\(devices.count))")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)

        ForEach(devices) { device in
          Button {
            onSelect(device)
          } label: {
            let record = savedRecord(for: device)
            DeviceRow(
              device: device,
              record: record,
              registryStatus: registryStatus(for: device, record: record)
            )
          }
          .buttonStyle(.plain)
        }
      }
    }
  }

  private var description: String {
    if phase.isScanning {
      return "Wyniki pojawią się tutaj w trakcie skanowania."
    }
    if hasScanResults {
      return "Żadne urządzenie nie pasuje do wybranego filtra."
    }
    switch phase {
    case .finished:
      return "Skan zakończony. Spróbuj profilu Standard albo sprawdź, czy urządzenia są w tej samej sieci Wi‑Fi."
    case .cancelled:
      return "Skan został zatrzymany przed wykryciem urządzeń."
    case .failed(let message):
      return message
    default:
      return "Uruchom skan, aby znaleźć urządzenia i dostępne usługi."
    }
  }

  private var emptyTitle: String {
    if phase.isScanning { return "Szukam urządzeń…" }
    if hasScanResults { return "Brak pasujących wyników" }
    switch phase {
    case .finished: return "Nie znaleziono urządzeń"
    case .cancelled: return "Skan zatrzymany"
    case .failed: return "Skan niedostępny"
    default: return "Brak wyników"
    }
  }

  private var emptyIcon: String {
    switch phase {
    case .scanning, .preparing: "dot.radiowaves.left.and.right"
    case .failed: "exclamationmark.triangle"
    default: "network.slash"
    }
  }

  private func key(for device: NetworkDevice) -> KnownDeviceKey? {
    guard let networkID else { return nil }
    return KnownDeviceKey(networkID: networkID, address: device.address)
  }

  private func savedRecord(for device: NetworkDevice) -> KnownDeviceRecord? {
    guard let key = key(for: device) else { return nil }
    return knownDeviceStore.record(for: key)
  }

  private func registryStatus(
    for device: NetworkDevice,
    record: KnownDeviceRecord?
  ) -> DeviceRegistryStatus {
    guard let key = key(for: device) else { return .unknown }
    return DeviceRegistryStatus(
      record: record,
      isNew: newDeviceKeys.contains(key)
    )
  }
}
