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

  private var hasChanges: Bool {
    !scanner.newDeviceKeys.isEmpty
      || !scanner.newServiceKeys.isEmpty
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
          metrics
          changes
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
      Spacer()
      #if NETSCOPE_DEV
      UIRefCopyButton(ref: .dashboardNetworkHeader)
      #endif
      if let context = scanner.context {
        Text(context.scanRangeDescription)
          .font(.caption2.monospaced())
          .padding(.horizontal, 7)
          .padding(.vertical, 4)
          .foregroundStyle(.cyan)
          .background(.cyan.opacity(0.1), in: Capsule())
      }
    }
    .overlay(alignment: .topTrailing) {
      StatusPill(title: scanner.context == nil ? "Offline" : "Local")
        .padding(10)
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
          .accessibilityValue("(completed) z (total) adresów")
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
