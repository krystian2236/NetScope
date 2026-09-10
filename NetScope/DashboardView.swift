import SwiftUI

struct DashboardView: View {
  @ObservedObject var scanner: NetworkScanner
  @ObservedObject var tools: NetworkToolsModel
  @ObservedObject var knownDeviceStore: KnownDeviceStore
  @Binding var selectedTab: AppTab

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

  var body: some View {
    NavigationStack {
      ScrollView {
        LazyVStack(spacing: 12) {
          networkHeader
          metrics
          quickActions
          scanStatus
          history
          InfoBanner(
            icon: "lock.shield",
            title: "Skanowanie lokalne",
            message: "NetScope sprawdza dostępność usług, bez logowania i wysyłania poleceń."
          )
        }
        .padding(12)
      }
      .background(Color(.systemGroupedBackground))
      .navigationTitle("NetScope")
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

  private var networkHeader: some View {
    HStack(spacing: 11) {
      Image(systemName: "network")
        .font(.title3.weight(.semibold))
        .foregroundStyle(.white)
        .frame(width: 42, height: 42)
        .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 12))
      VStack(alignment: .leading, spacing: 2) {
        Text("Monitor sieci lokalnej")
          .font(.subheadline.weight(.bold))
        Text(scanner.context?.address ?? "Połącz iPhone’a z Wi‑Fi")
          .font(.caption.monospaced())
          .foregroundStyle(.white.opacity(0.8))
      }
      Spacer()
      if let context = scanner.context {
        Text(context.scanRangeDescription)
          .font(.caption2.monospaced())
          .padding(.horizontal, 7)
          .padding(.vertical, 4)
          .background(.white.opacity(0.14), in: Capsule())
      }
    }
    .foregroundStyle(.white)
    .padding(13)
    .background(
      LinearGradient(
        colors: [.indigo, .cyan],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      ),
      in: RoundedRectangle(cornerRadius: 15)
    )
  }

  private var metrics: some View {
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

  private var quickActions: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Szybkie działania")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)

      HStack(spacing: 7) {
        QuickActionButton(title: "Sieć", icon: "dot.radiowaves.left.and.right") {
          selectedTab = .network
        }
        QuickActionButton(title: "Porty", icon: "shield.lefthalf.filled") {
          selectedTab = .ports
        }
        QuickActionButton(title: "Ping", icon: "waveform.path.ecg") {
          selectedTab = .diagnostics
        }
        QuickActionButton(title: "Bonjour", icon: "bonjour") {
          selectedTab = .services
        }
      }

      NavigationLink {
        ISHToolkitView(
          context: scanner.context,
          devices: scanner.devices
        )
      } label: {
        HStack(spacing: 9) {
          Image(systemName: "terminal.fill")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.cyan)
          VStack(alignment: .leading, spacing: 1) {
            Text("Narzędzia dla iSH")
              .font(.caption.weight(.semibold))
            Text("Polecenia Nmap i eksport gotowego skryptu")
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
          Spacer()
          Image(systemName: "chevron.right")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.tertiary)
        }
        .padding(9)
        .background(.cyan.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
      }
      .buttonStyle(.plain)
    }
    .padding(11)
    .background(.background, in: RoundedRectangle(cornerRadius: 14))
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
      }
      .padding(11)
      .background(.background, in: RoundedRectangle(cornerRadius: 13))
    default:
      EmptyView()
    }
  }

  @ViewBuilder
  private var history: some View {
    if !scanner.history.isEmpty {
      VStack(alignment: .leading, spacing: 8) {
        Text("Ostatnie skany")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)

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
    }
  }
}

private struct QuickActionButton: View {
  let title: String
  let icon: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(spacing: 5) {
        Image(systemName: icon)
          .font(.subheadline.weight(.semibold))
        Text(title)
          .font(.caption2)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 8)
    }
    .buttonStyle(.bordered)
    .tint(.cyan)
  }
}
