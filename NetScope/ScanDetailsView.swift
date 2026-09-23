import Foundation
import SwiftUI

struct ScanDetailsView: View {
  @ObservedObject var scanner: NetworkScanner

  var body: some View {
    ScrollView {
      if let details = scanner.sessionDetails {
        LazyVStack(spacing: 12) {
          #if NETSCOPE_DEV
          HStack { UIRefCopyButton(ref: .scannerDetails); Spacer() }
          #endif
          progressCard(details)
          metrics(details)
          probeBreakdown(details)
          configuration(details)
          exportCard(details)
          InfoBanner(
            icon: "info.circle",
            title: "Jak czytać wyniki",
            message:
              "Brak odpowiedzi może oznaczać filtr zapory, uśpione urządzenie albo przekroczenie czasu. Nie oznacza automatycznie zamkniętego portu."
          )
        }
        .padding(12)
      } else {
        ContentUnavailableView(
          "Brak przebiegu skanu",
          systemImage: "chart.bar.doc.horizontal",
          description: Text("Rozpocznij skan sieci, aby zebrać szczegółowe statystyki.")
        )
        .frame(minHeight: 320)
      }
    }
    .background(Color(.systemGroupedBackground))
    .navigationTitle("Szczegóły skanu")
    .navigationBarTitleDisplayMode(.inline)
  }

  private func exportCard(_ details: ScanSessionDetails) -> some View {
    ToolCard(
      icon: "square.and.arrow.up",
      title: "Eksport wyników",
      subtitle: "Lokalne podsumowanie bez wysyłania do chmury"
    ) {
      VStack(spacing: 8) {
        ShareLink(item: jsonExport(details), subject: Text("Northbyte Radar JSON")) {
          Label("Udostępnij JSON", systemImage: "curlybraces")
            .font(.caption.weight(.semibold))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)

        ShareLink(item: csvExport, subject: Text("Northbyte Radar CSV")) {
          Label("Udostępnij CSV", systemImage: "tablecells")
            .font(.caption.weight(.semibold))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)

        Text("Eksport może zawierać lokalne adresy IP i nazwy hostów. Udostępniaj go tylko zaufanym osobom.")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
    }
  }

  private func jsonExport(_ details: ScanSessionDetails) -> String {
    let document = ScanExportDocument(
      title: "Northbyte Radar Scan",
      createdAt: details.finishedAt ?? Date(),
      network: details.subnet,
      deviceAddresses: scanner.devices.map(\.address),
      openPortCount: details.openPorts
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    guard let data = try? encoder.encode(document),
      let value = String(data: data, encoding: .utf8)
    else {
      return "{}"
    }
    return value
  }

  private var csvExport: String {
    let header = "ip,hostname,open_ports,last_seen"
    let rows = scanner.devices.map { device in
      let hostname = (device.hostname ?? "").replacingOccurrences(of: "\"", with: "\"\"")
      let ports = device.openPorts.map(String.init).joined(separator: ";")
      return "\(device.address),\"\(hostname)\",\"\(ports)\",\"\(device.lastSeen.formatted(.iso8601))\""
    }
    return ([header] + rows).joined(separator: "\n")
  }

  private func progressCard(_ details: ScanSessionDetails) -> some View {
    ToolCard(
      icon: scanner.phase.isScanning ? "dot.radiowaves.left.and.right" : "checkmark.circle",
      title: scanner.phase.isScanning ? "Skanowanie w toku" : "Ostatni przebieg",
      subtitle: "\(details.profile.title) • \(details.subnet)"
    ) {
      VStack(spacing: 8) {
        ProgressView(value: details.progress)
          .tint(.cyan)
        HStack {
          Text("\(details.completedHosts) z \(details.totalHosts) hostów")
          Spacer()
          Text(formatDuration(details.duration))
        }
        .font(.caption2.monospacedDigit())
        .foregroundStyle(.secondary)
      }
    }
  }

  private func metrics(_ details: ScanSessionDetails) -> some View {
    LazyVGrid(
      columns: [GridItem(.flexible()), GridItem(.flexible())],
      spacing: 8
    ) {
      MetricCard(
        title: "Zaplanowane próby",
        value: details.plannedProbes.formatted(),
        icon: "number.square"
      )
      MetricCard(
        title: "Wykonane próby",
        value: details.completedProbes.formatted(),
        icon: "checkmark.square"
      )
      MetricCard(
        title: "Urządzenia",
        value: details.detectedDevices.formatted(),
        icon: "desktopcomputer"
      )
      MetricCard(
        title: "Nazwy DNS",
        value: details.resolvedHostnames.formatted(),
        icon: "textformat.abc"
      )
    }
  }

  private func probeBreakdown(_ details: ScanSessionDetails) -> some View {
    ToolCard(
      icon: "chart.bar.xaxis",
      title: "Odpowiedzi portów",
      subtitle: "Podział wykonanych prób TCP"
    ) {
      VStack(spacing: 8) {
        ProbeBreakdownRow(
          title: "Otwarte",
          value: details.openPorts,
          total: details.completedProbes,
          tint: .green
        )
        ProbeBreakdownRow(
          title: "Odrzucone / zamknięte",
          value: details.closedProbes,
          total: details.completedProbes,
          tint: .secondary
        )
        ProbeBreakdownRow(
          title: "Brak odpowiedzi",
          value: details.timedOutProbes,
          total: details.completedProbes,
          tint: .orange
        )
        if details.deniedProbes > 0 {
          ProbeBreakdownRow(
            title: "Brak dostępu lokalnego",
            value: details.deniedProbes,
            total: details.completedProbes,
            tint: .red
          )
        }
      }
    }
  }

  private func configuration(_ details: ScanSessionDetails) -> some View {
    ToolCard(
      icon: "slider.horizontal.3",
      title: "Parametry",
      subtitle: "Zakres i użyty profil"
    ) {
      VStack(spacing: 8) {
        AddressRow(label: "Podsieć", value: details.subnet)
        AddressRow(label: "Hostów", value: "\(details.totalHosts)")
        AddressRow(label: "Portów na host", value: "\(details.portsPerHost)")
        AddressRow(
          label: "Rozpoczęto",
          value: details.startedAt.formatted(date: .omitted, time: .standard)
        )
        if let finishedAt = details.finishedAt {
          AddressRow(
            label: "Zakończono",
            value: finishedAt.formatted(date: .omitted, time: .standard)
          )
        }
        Divider()
        Text(details.profile.ports.map(String.init).joined(separator: ", "))
          .font(.caption2.monospaced())
          .foregroundStyle(.secondary)
          .textSelection(.enabled)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
  }

  private func formatDuration(_ duration: TimeInterval) -> String {
    if duration < 60 {
      return String(format: "%.1f s", duration)
    }
    return String(format: "%.1f min", duration / 60)
  }
}

private struct ProbeBreakdownRow: View {
  let title: String
  let value: Int
  let total: Int
  let tint: Color

  private var fraction: Double {
    guard total > 0 else { return 0 }
    return Double(value) / Double(total)
  }

  var body: some View {
    VStack(spacing: 4) {
      HStack {
        Text(title)
        Spacer()
        Text(value.formatted())
          .monospacedDigit()
      }
      .font(.caption)

      ProgressView(value: fraction)
        .tint(tint)
    }
  }
}
