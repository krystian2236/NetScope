import SwiftUI

struct DashboardView: View {
  @ObservedObject var scanner: NetworkScanner
  @ObservedObject var tools: NetworkToolsModel
  @ObservedObject var knownDeviceStore: KnownDeviceStore
  @Binding var selectedTab: AppTab
  @Binding var workspaceRouteRaw: String

  private var openPortCount: Int {
    scanner.devices.reduce(0) { $0 + $1.openPorts.count }
  }

  private var reviewCount: Int {
    guard let networkID = scanner.networkID else { return 0 }
    let statuses = scanner.devices.map { device in
      let key = KnownDeviceKey(networkID: networkID, address: device.address)
      return DeviceRegistryStatus(
        record: knownDeviceStore.record(for: key),
        isNew: scanner.newDeviceKeys.contains(key)
      )
    }
    return DeviceRegistryStatus.reviewCount(in: statuses)
  }

  private var hasChanges: Bool {
    !scanner.newDeviceKeys.isEmpty
      || !scanner.newServiceKeys.isEmpty
      || !scanner.closedServiceKeys.isEmpty
      || !scanner.hostnameChangedKeys.isEmpty
      || !scanner.disappearedDeviceKeys.isEmpty
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        LazyVStack(spacing: 12) {
          #if NETSCOPE_DEV
          HStack {
            UIRefCopyButton(ref: .dashboard)
            Spacer()
          }
          #endif
          networkHeader
          AppReleaseIdentityCard()
          primaryScanAction
          primaryActions
          metrics
          networkHealth
          changes
          scanStatus
          history
          InfoBanner(
            icon: "lock.shield",
            title: "Skanowanie lokalne",
            message: "Northbyte Radar sprawdza dostępność usług, bez logowania i wysyłania poleceń."
          )
        }
        .padding(12)
      }
      .background(Color(.systemGroupedBackground))
      .navigationTitle("Northbyte Radar")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          NavigationLink {
            AboutView()
          } label: {
            Label("Informacje", systemImage: "info.circle")
          }
        }
      }
    }
  }

  private var primaryScanAction: some View {
    NavigationLink {
      ScannerView(scanner: scanner, knownDeviceStore: knownDeviceStore, tools: tools)
    } label: {
      HStack(spacing: 11) {
        Image(systemName: primaryActionIcon)
          .font(.headline.weight(.semibold))
        VStack(alignment: .leading, spacing: 2) {
          Text(primaryActionTitle)
            .font(.subheadline.weight(.semibold))
          Text(primaryActionSubtitle)
            .font(.caption)
            .foregroundStyle(.white.opacity(0.8))
        }
        Spacer()
        Image(systemName: "chevron.right")
          .font(.caption.weight(.bold))
      }
      .foregroundStyle(.white)
      .padding(14)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Color.cyan.gradient, in: RoundedRectangle(cornerRadius: 16))
    }
    .buttonStyle(.plain)
    #if NETSCOPE_DEV
    .accessibilityIdentifier(UIRef.dashboardPrimaryAction.rawValue)
    #endif
  }

  private var primaryActionTitle: String {
    if reviewCount > 0 { return "Przejrzyj zmiany" }
    if scanner.phase.isScanning { return "Pokaż skan" }
    if !scanner.history.isEmpty { return "Skanuj ponownie" }
    return "Rozpocznij pierwszy skan"
  }

  private var primaryActionSubtitle: String {
    if reviewCount > 0 { return "Nowe lub nieznane urządzenia" }
    if scanner.phase.isScanning { return "Przejdź do postępu skanu" }
    if !scanner.history.isEmpty { return "Uruchom skan z ekranu Scan" }
    return "Tylko prywatny zakres sieci"
  }

  private var primaryActionIcon: String {
    if reviewCount > 0 { return "exclamationmark.bubble" }
    if scanner.phase.isScanning { return "hourglass" }
    if !scanner.history.isEmpty { return "arrow.clockwise" }
    return "dot.radiowaves.left.and.right"
  }

  private var primaryActions: some View {
    VStack(alignment: .leading, spacing: 9) {
      HStack {
        Text("Szybki dostęp")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
        Spacer()
        #if NETSCOPE_DEV
        UIRefCopyButton(ref: .dashboardActions)
        #endif
      }

      LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
        actionButton("Network", icon: "network", tab: .network)
        scanActionButton
        actionButton("Diagnose", icon: "waveform.path.ecg", tab: .diagnose)
        actionButton("Lab", icon: "graduationcap.fill", tab: .laboratory)
      }

      NavigationLink {
        ToolboxView(scanner: scanner, workspaceRouteRaw: $workspaceRouteRaw)
      } label: {
        Label("Otwórz Toolbox", systemImage: "wrench.and.screwdriver")
          .font(.caption.weight(.semibold))
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.bordered)
      .tint(.cyan)
    }
  }

  private var scanActionButton: some View {
    NavigationLink {
      ScannerView(scanner: scanner, knownDeviceStore: knownDeviceStore, tools: tools)
    } label: {
      Label("Scan", systemImage: "dot.radiowaves.left.and.right")
        .font(.caption.weight(.semibold))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(.background, in: RoundedRectangle(cornerRadius: 13))
    }
    .buttonStyle(.plain)
    .foregroundStyle(.primary)
  }

  private func actionButton(_ title: String, icon: String, tab: AppTab) -> some View {
    Button { selectedTab = tab } label: {
      Label(title, systemImage: icon)
        .font(.caption.weight(.semibold))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(.background, in: RoundedRectangle(cornerRadius: 13))
    }
    .buttonStyle(.plain)
    .foregroundStyle(.primary)
  }

  private var networkHealth: some View {
    VStack(alignment: .leading, spacing: 9) {
      HStack {
        Text("Network Health")
          .font(.caption.weight(.semibold))
        Spacer()
        #if NETSCOPE_DEV
        UIRefCopyButton(ref: .dashboardHealth)
        #endif
      }

      HStack(spacing: 8) {
        healthPill(title: "\(scanner.devices.count) urządzeń", color: .cyan)
        healthPill(title: "\(openPortCount) usług", color: .indigo)
      }
    }
    .padding(12)
    .background(.background, in: RoundedRectangle(cornerRadius: 14))
  }

  private func healthPill(title: String, color: Color) -> some View {
    Text(title)
      .font(.caption2.weight(.semibold))
      .foregroundStyle(color)
      .padding(.horizontal, 8)
      .padding(.vertical, 5)
      .background(color.opacity(0.11), in: Capsule())
  }

  private var networkHeader: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 11) {
        Image(systemName: "network")
          .font(.title3.weight(.semibold))
          .foregroundStyle(.cyan)
          .frame(width: 42, height: 42)
          .background(.cyan.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        VStack(alignment: .leading, spacing: 2) {
          Text("Monitor sieci lokalnej")
            .font(.subheadline.weight(.bold))
          Text(scanner.context?.address ?? "Połącz iPhone’a z Wi‑Fi")
            .font(.caption.monospaced())
            .foregroundStyle(.secondary)
        }
        Spacer(minLength: 6)
        StatusPill(title: scanner.context == nil ? "Offline" : "Local")
        #if NETSCOPE_DEV
        UIRefCopyButton(ref: .dashboardNetworkHeader)
        #endif
      }

      if let context = scanner.context {
        HStack {
          Text("Zakres lokalny")
            .font(.caption2)
            .foregroundStyle(.secondary)
          Spacer()
          Text(context.scanRangeDescription)
            .font(.caption2.monospaced())
            .foregroundStyle(.cyan)
            .textSelection(.enabled)
        }
      }
    }
    .padding(13)
    .background(.background, in: RoundedRectangle(cornerRadius: 16))
    .overlay {
      RoundedRectangle(cornerRadius: 16)
        .stroke(Color.cyan.opacity(0.2), lineWidth: 1)
    }
  }

  private var metrics: some View {
    VStack(alignment: .trailing, spacing: 2) {
      #if NETSCOPE_DEV
      UIRefCopyButton(ref: .dashboardMetrics)
      #endif
      LazyVGrid(
        columns: [GridItem(.flexible()), GridItem(.flexible())],
        spacing: 8
      ) {
        MetricCard(
          title: "Urządzenia",
          value: "\(scanner.devices.count)",
          icon: "desktopcomputer"
        )
        MetricCard(
          title: "Otwarte usługi",
          value: "\(openPortCount)",
          icon: "door.left.hand.open"
        )
        MetricCard(
          title: "Bonjour",
          value: "\(scanner.bonjourDiscovery.services.count)",
          icon: "bonjour",
          tint: .indigo
        )
        MetricCard(
          title: "Nowe / nieznane",
          value: "\(reviewCount)",
          icon: "questionmark.circle",
          tint: reviewCount > 0 ? .orange : .green
        )
      }
    }
  }

  @ViewBuilder
  private var changes: some View {
    if hasChanges {
      VStack(alignment: .leading, spacing: 9) {
        HStack {
          Label("Od ostatniego skanu", systemImage: "arrow.triangle.2.circlepath")
            .font(.caption.weight(.semibold))
          Spacer()
          #if NETSCOPE_DEV
          UIRefCopyButton(ref: .dashboardChanges)
          #endif
        }

        if !scanner.newDeviceKeys.isEmpty {
          ChangeRow(
            icon: "plus.circle.fill",
            tint: .green,
            title: "Nowe urządzenia",
            detail: names(for: scanner.newDeviceKeys)
          )
        }
        if !scanner.newServiceKeys.isEmpty {
          ChangeRow(
            icon: "sparkles",
            tint: .cyan,
            title: "Nowe lub zmienione usługi",
            detail: names(for: scanner.newServiceKeys)
          )
        }
        if !scanner.closedServiceKeys.isEmpty {
          ChangeRow(
            icon: "minus.circle.fill",
            tint: .green,
            title: "Zamknięte porty",
            detail: names(for: scanner.closedServiceKeys)
          )
        }
        if !scanner.hostnameChangedKeys.isEmpty {
          ChangeRow(
            icon: "character.cursor.ibeam",
            tint: .purple,
            title: "Zmienione hostname",
            detail: names(for: scanner.hostnameChangedKeys)
          )
        }
        if !scanner.disappearedDeviceKeys.isEmpty {
          ChangeRow(
            icon: "minus.circle.fill",
            tint: .orange,
            title: "Niewidoczne urządzenia",
            detail: names(for: scanner.disappearedDeviceKeys)
          )
        }
      }
      .padding(12)
      .background(.background, in: RoundedRectangle(cornerRadius: 14))
      .overlay {
        RoundedRectangle(cornerRadius: 14)
          .stroke(Color.cyan.opacity(0.12), lineWidth: 1)
      }
    }
  }

  private func names(for keys: Set<KnownDeviceKey>) -> String {
    keys
      .sorted { $0.address.localizedStandardCompare($1.address) == .orderedAscending }
      .prefix(2)
      .map { key in
        if let device = scanner.devices.first(where: { $0.address == key.address }) {
          return device.primaryName
        }
        if let record = knownDeviceStore.record(for: key) {
          return record.normalizedCustomName ?? record.hostname ?? record.kind.title
        }
        return key.address
      }
      .joined(separator: " • ")
      + (keys.count > 2 ? " • +\(keys.count - 2)" : "")
  }

  @ViewBuilder
  private var scanStatus: some View {
    switch scanner.phase {
    case .scanning(let completed, let total):
      VStack(alignment: .leading, spacing: 7) {
        HStack {
          Text("Skanowanie sieci")
          Spacer()
          Text("\(completed)/\(total)")
            .monospacedDigit()
            .foregroundStyle(.secondary)
        }
        .font(.caption.weight(.medium))
        ProgressView(value: Double(completed), total: Double(max(total, 1)))
          .tint(.cyan)
          .accessibilityLabel("Postęp skanowania sieci")
          .accessibilityValue("\(completed) z \(total) adresów")
      }
      .padding(11)
      .background(.background, in: RoundedRectangle(cornerRadius: 13))
      .overlay {
        RoundedRectangle(cornerRadius: 13)
          .stroke(Color.cyan.opacity(0.12), lineWidth: 1)
      }
    default:
      EmptyView()
    }
  }

  @ViewBuilder
  private var history: some View {
    if !scanner.history.isEmpty {
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Text("Ostatnie skany").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
          Spacer()
          #if NETSCOPE_DEV
          UIRefCopyButton(ref: .history)
          #endif
        }

        if let change = historyChange {
          Text(change)
            .font(.caption2.weight(.medium))
            .foregroundStyle(.cyan)
        }

        ForEach(scanner.history.prefix(4)) { summary in
          HStack(spacing: 9) {
            Image(systemName: "clock.arrow.circlepath")
              .font(.caption)
              .foregroundStyle(.cyan)
            VStack(alignment: .leading, spacing: 1) {
              Text(summary.profile.title)
                .font(.caption.weight(.semibold))
              Text(summary.finishedAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(summary.deviceCount) urz. • \(summary.openPortCount) usług")
              .font(.caption2.monospacedDigit())
              .foregroundStyle(.secondary)
          }
          if summary.id != scanner.history.prefix(4).last?.id {
            Divider()
          }
        }
      }
      .padding(11)
      .background(.background, in: RoundedRectangle(cornerRadius: 14))
      .overlay {
        RoundedRectangle(cornerRadius: 14)
          .stroke(Color.cyan.opacity(0.12), lineWidth: 1)
      }
    }
  }

  private var historyChange: String? {
    guard scanner.history.count > 1 else { return nil }
    let latest = scanner.history[0]
    let previous = scanner.history[1]
    guard latest.isComparable, previous.isComparable else { return nil }

    let current = Set(latest.deviceAddresses)
    let old = Set(previous.deviceAddresses)
    let appeared = current.subtracting(old).count
    let disappeared = old.subtracting(current).count
    guard appeared > 0 || disappeared > 0 else { return "Bez zmian względem poprzedniego skanu" }

    var parts: [String] = []
    if appeared > 0 { parts.append("+\(appeared) nowych") }
    if disappeared > 0 { parts.append("-\(disappeared) zniknęło") }
    return parts.joined(separator: " • ") + " względem poprzedniego skanu"
  }
}

struct NetworkOverviewView: View {
  @ObservedObject var scanner: NetworkScanner
  @ObservedObject var tools: NetworkToolsModel
  @ObservedObject var knownDeviceStore: KnownDeviceStore

  var body: some View {
    NavigationStack {
      ScrollView {
        LazyVStack(spacing: 12) {
          #if NETSCOPE_DEV
          HStack { UIRefCopyButton(ref: .networkOverview); Spacer() }
          #endif

          if let context = scanner.context ?? tools.localContext {
            overviewCard(context)
          } else {
            VStack(spacing: 12) {
              networkScanButton
              ContentUnavailableView(
                "Brak aktywnego interfejsu",
                systemImage: "wifi.slash",
                description: Text("Połącz urządzenie z siecią Wi‑Fi i odśwież ekran.")
              )
              .frame(minHeight: 150)
            }
          }

          if let details = scanner.sessionDetails {
            scanAnalysisCard(details)
          } else if let summary = scanner.history.first {
            scanHistoryCard(summary)
          } else {
            ContentUnavailableView(
              "Brak skanu sieci",
              systemImage: "dot.radiowaves.left.and.right",
              description: Text("Po wykonaniu skanu jego wynik i ograniczenia pojawią się tutaj.")
            )
            .frame(minHeight: 150)
          }
        }
        .padding(12)
      }
      .background(Color(.systemGroupedBackground))
      .navigationTitle("Network")
      .navigationBarTitleDisplayMode(.inline)
      .task {
        scanner.refreshContext()
        tools.refreshLocalContext()
      }
    }
  }

  private func overviewCard(_ context: NetworkContext) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Label("Monitor sieci lokalnej", systemImage: "network")
          .font(.headline)
        Spacer()
        networkScanButton
      }

      AddressRow(label: "Lokalny IPv4", value: context.address)
      AddressRow(label: "IPv6", value: context.ipv6Address ?? "Niedostępny")
      AddressRow(label: "Interfejs", value: context.interfaceName)
      AddressRow(label: "Zakres sieci", value: context.scanRangeDescription)
      AddressRow(label: "Maska", value: context.netmask)

      Text("Dane pochodzą z aktywnego interfejsu urządzenia. Brakujące informacje nie są uzupełniane sztucznie.")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .padding(14)
    .background(.background, in: RoundedRectangle(cornerRadius: 16))
    .overlay {
      RoundedRectangle(cornerRadius: 16)
      .stroke(Color.cyan.opacity(0.2), lineWidth: 1)
    }
  }

  private var networkScanButton: some View {
    Button(action: startNetworkScan) {
      Label("Skanuj sieć", systemImage: "dot.radiowaves.left.and.right")
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .foregroundStyle(.white)
        .background(Color.green.opacity(canStartNetworkScan ? 1 : 0.45), in: Capsule())
    }
    .buttonStyle(.plain)
    .disabled(!canStartNetworkScan)
    .accessibilityHint(
      scanner.phase.isScanning
        ? "Skan sieci już trwa."
        : "Dostępny tylko w prywatnej lub lokalnej sieci."
    )
  }

  private var canStartNetworkScan: Bool {
    guard !scanner.phase.isScanning,
      let context = scanner.context ?? tools.localContext
    else {
      return false
    }
    return context.isPrivateOrLinkLocal
  }

  private func startNetworkScan() {
    guard canStartNetworkScan else { return }
    Task { await scanner.scan() }
  }

  private func scanHistoryCard(_ summary: ScanSummary) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Label("Ostatni skan", systemImage: "clock.arrow.circlepath")
          .font(.headline)
        Spacer()
        Text(summary.startedAt.formatted(date: .abbreviated, time: .shortened))
          .font(.caption2)
          .foregroundStyle(.secondary)
      }

      HStack(alignment: .top, spacing: 8) {
        scanMetric(summary.deviceCount.formatted(), label: "Urządzenia")
        scanMetric(summary.openPortCount.formatted(), label: "Otwarte porty")
        scanMetric(summary.attentionCount.formatted(), label: "Wymagają uwagi")
      }

      AddressRow(label: "Profil", value: summary.profile.title)
      AddressRow(label: "Sprawdzany zakres", value: summary.subnet ?? "Nie zapisano")
      AddressRow(label: "Czas trwania", value: "\(Int(summary.duration.rounded())) s")

      Divider()

      Text("Wynik obejmuje hosty i porty sprawdzone przez wybrany profil w pokazanym zakresie. Zapora, brak uprawnień lub brak odpowiedzi mogą ukryć aktywne urządzenia i usługi. Brak wykryć nie potwierdza ich nieobecności ani bezpieczeństwa sieci.")
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(14)
    .background(.background, in: RoundedRectangle(cornerRadius: 16))
    .overlay {
      RoundedRectangle(cornerRadius: 16)
        .stroke(Color.cyan.opacity(0.2), lineWidth: 1)
    }
  }

  private func scanAnalysisCard(_ details: ScanSessionDetails) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Label("Analiza skanu", systemImage: "checkmark.circle.fill")
          .font(.headline)
        Spacer()
        Text(scanStatusTitle)
          .font(.caption.weight(.semibold))
          .foregroundStyle(scanner.phase.isScanning ? .cyan : .secondary)
      }

      HStack(alignment: .top, spacing: 8) {
        scanMetric(details.detectedDevices.formatted(), label: "Urządzenia")
        scanMetric(details.completedProbes.formatted(), label: "Próby")
        scanMetric(details.openPorts.formatted(), label: "Otwarte porty")
      }

      AddressRow(label: "Profil", value: details.profile.title)
      AddressRow(label: "Sprawdzany zakres", value: details.subnet)
      AddressRow(label: "Rozpoczęto", value: details.startedAt.formatted(date: .abbreviated, time: .shortened))

      Divider()

      VStack(alignment: .leading, spacing: 5) {
        Text("Jak czytać wynik")
          .font(.subheadline.weight(.semibold))
        Text(scanInterpretation(for: details))
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding(14)
    .background(.background, in: RoundedRectangle(cornerRadius: 16))
    .overlay {
      RoundedRectangle(cornerRadius: 16)
        .stroke(Color.cyan.opacity(0.2), lineWidth: 1)
    }
  }

  private var scanStatusTitle: String {
    switch scanner.phase {
    case .idle, .finished: "Zakończony"
    case .preparing: "Przygotowanie"
    case .scanning: "W toku"
    case .cancelled: "Przerwany"
    case .failed: "Nieukończony"
    }
  }

  private func scanMetric(_ value: String, label: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(value)
        .font(.title3.weight(.semibold).monospacedDigit())
      Text(label)
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func scanInterpretation(for details: ScanSessionDetails) -> String {
    switch scanner.phase {
    case .preparing:
      "Skan jest przygotowywany. Wyniki nie są jeszcze kompletne."
    case .scanning(let completed, let total):
      "Skan trwa: sprawdzono \(completed) z \(total) hostów. Wyniki są częściowe i mogą się zmienić."
    case .cancelled:
      "Skan został przerwany. Dane obejmują tylko zakończone próby; brak odpowiedzi nie potwierdza, że host lub usługa nie istnieje."
    case .failed(let message):
      "Skan nie zakończył się poprawnie: \(message) Zebrane dane mogą być niepełne."
    case .idle, .finished:
      if details.openPorts == 0 {
        "Nie wykryto otwartych portów. Skan sprawdza adresy w zakresie /24 i porty wybranego profilu; zapory, uprawnienia lub brak odpowiedzi mogą ukryć aktywne hosty i usługi. Brak wykryć nie dowodzi ich nieobecności ani bezpieczeństwa sieci."
      } else {
        "Wykryte porty odpowiedziały podczas skanu. Sprawdzono adresy w zakresie /24 i porty wybranego profilu; zapory lub brak odpowiedzi mogą ukryć inne hosty i usługi. Wynik sam w sobie nie potwierdza podatności ani pełnego bezpieczeństwa urządzeń."
      }
    }
  }
}

private struct ChangeRow: View {
  let icon: String
  let tint: Color
  let title: String
  let detail: String

  var body: some View {
    HStack(spacing: 9) {
      Image(systemName: icon)
        .foregroundStyle(tint)
        .frame(width: 24)
      VStack(alignment: .leading, spacing: 1) {
        Text(title)
          .font(.caption.weight(.semibold))
        Text(detail)
          .font(.caption2.monospaced())
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
      Spacer(minLength: 0)
    }
  }
}
