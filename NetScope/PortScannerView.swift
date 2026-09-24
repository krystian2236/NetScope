import SwiftUI

struct PortScannerView: View {
  @ObservedObject var model: NetworkToolsModel
  @State private var host = ""
  @State private var preset: PortScanPreset = .common
  @State private var customStart = "1"
  @State private var customEnd = "512"
  @State private var showClosedPorts = false
  @State private var selectedOpenPort: PortScanEntry?
  @State private var scannedHost = ""

  private var visibleResults: [PortScanEntry] {
    showClosedPorts
      ? model.portScanResults
      : model.portScanResults.filter { $0.status.isOpen }
  }

  private var openCount: Int {
    model.portScanResults.filter { $0.status.isOpen }.count
  }

  private var timedOutCount: Int {
    model.portScanResults.filter { $0.status == .timedOut }.count
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        LazyVStack(spacing: 12) {
          #if NETSCOPE_DEV
          HStack { UIRefCopyButton(ref: .scannerPortScanner); Spacer() }
          #endif
          configurationCard
          scanStatus
          resultsSummary
          results
          InfoBanner(
            icon: "hand.raised",
            title: "Tylko za zgodą",
            message: "Skanuj własne urządzenia i systemy, do których masz uprawnienia."
          )
        }
        .padding(12)
      }
      .background(Color(.systemGroupedBackground))
      .navigationTitle("Skaner portów")
      .navigationBarTitleDisplayMode(.inline)
    }
  }

  private var configurationCard: some View {
    ToolCard(
      icon: "shield.lefthalf.filled",
      title: "TCP Port Scan",
      subtitle: "Lekki skaner inspirowany Nmap, zgodny z iOS"
    ) {
      VStack(spacing: 9) {
        TextField("Domena lub adres IP", text: $host)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
          .keyboardType(.URL)
          .textFieldStyle(.roundedBorder)
          .font(.subheadline)

        HStack {
          Text("Profil")
            .font(.caption)
            .foregroundStyle(.secondary)
          Spacer()
          Picker("Profil portów", selection: $preset) {
            ForEach(PortScanPreset.allCases) { item in
              Text(item.title).tag(item)
            }
          }
          .pickerStyle(.menu)
          .font(.caption)
        }

        if preset == .custom {
          HStack {
            TextField("Od", text: $customStart)
              .keyboardType(.numberPad)
              .textFieldStyle(.roundedBorder)
            Text("—")
              .foregroundStyle(.secondary)
            TextField("Do", text: $customEnd)
              .keyboardType(.numberPad)
              .textFieldStyle(.roundedBorder)
          }
          .font(.subheadline)
        } else {
          HStack {
            Text("\(preset.ports.count) portów")
            Spacer()
            Text(preset.ports.map(String.init).prefix(5).joined(separator: ", ") + "…")
              .monospaced()
          }
          .font(.caption2)
          .foregroundStyle(.secondary)
        }

        if model.isScanningPorts {
          Button(role: .destructive) {
            model.cancelPortScan()
          } label: {
            Label("Zatrzymaj", systemImage: "stop.fill")
              .font(.caption.weight(.semibold))
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.bordered)
        } else {
          Button {
            startScan()
          } label: {
            Label("Skanuj porty", systemImage: "dot.radiowaves.left.and.right")
              .font(.caption.weight(.semibold))
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.borderedProminent)
          .tint(.cyan)
        }

        if let error = model.portScanError {
          Text(error)
            .font(.caption)
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
    }
  }

  @ViewBuilder
  private var scanStatus: some View {
    if let progress = model.portScanProgress {
      VStack(alignment: .leading, spacing: 7) {
        HStack {
          Text(model.isScanningPorts ? "Skanowanie…" : "Skan zakończony")
          Spacer()
          Text("\(progress.completed)/\(progress.total)")
            .monospacedDigit()
            .foregroundStyle(.secondary)
        }
        .font(.caption.weight(.medium))
        ProgressView(
          value: Double(progress.completed),
          total: Double(max(progress.total, 1))
        )
        .tint(.cyan)
      }
      .padding(.horizontal, 2)
    }
  }

  @ViewBuilder
  private var resultsSummary: some View {
    if !model.portScanResults.isEmpty {
      HStack(spacing: 8) {
        MetricCard(
          title: "Otwarte",
          value: "\(openCount)",
          icon: "lock.open.fill",
          tint: openCount > 0 ? .orange : .green
        )
        MetricCard(
          title: "Brak odpowiedzi",
          value: "\(timedOutCount)",
          icon: "clock.badge.questionmark",
          tint: .secondary
        )
      }
    }
  }

  @ViewBuilder
  private var results: some View {
    if !model.portScanResults.isEmpty {
      VStack(alignment: .leading, spacing: 8) {
        Toggle("Pokaż zamknięte i bez odpowiedzi", isOn: $showClosedPorts)
          .font(.caption)

        ForEach(visibleResults) { entry in
          if entry.status.isOpen {
            Button {
              selectedOpenPort = selectedOpenPort?.id == entry.id ? nil : entry
            } label: {
              PortResultRow(entry: entry)
            }
            .buttonStyle(.plain)

            if selectedOpenPort?.id == entry.id {
              OpenPortDetailsCard(entry: entry, host: scannedHost)
            }
          } else {
            PortResultRow(entry: entry)
          }
        }

        if visibleResults.isEmpty {
          InfoBanner(
            icon: "lock.fill",
            title: "Brak otwartych portów",
            message: "W wybranym profilu nie znaleziono dostępnej usługi TCP.",
            tint: .green
          )
        }
      }
    }
  }

  private func startScan() {
    selectedOpenPort = nil
    scannedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
    model.scanPorts(
      host: host,
      preset: preset,
      customStart: customStart,
      customEnd: customEnd
    )
  }
}

private struct OpenPortDetailsCard: View {
  let entry: PortScanEntry
  let host: String

  private var details: (name: String, service: String, description: String, risk: String, recommendation: String, more: String) {
    switch entry.port {
    case 22:
      ("SSH", "zdalne zarządzanie", "Szyfrowana usługa administracyjna.", "Średnie", "Tylko zaufana sieć", "SSH służy do administracji serwerem, Makiem lub routerem.")
    case 53:
      ("DNS", "rozwiązywanie nazw", "Lokalna usługa DNS.", "Niskie", "Tylko sieć lokalna", "DNS tłumaczy nazwy urządzeń i usług na adresy sieciowe.")
    case 80:
      ("HTTP", "usługa WWW", "WWW bez gwarancji szyfrowania.", "Średnie", "Sprawdź właściciela", "Port może udostępniać stronę lub panel administracyjny urządzenia.")
    case 443:
      ("HTTPS", "szyfrowana usługa WWW", "WWW chronione podczas transmisji.", "Niskie", "Sprawdź dostęp", "Port może udostępniać stronę lub panel administracyjny urządzenia.")
    case 7000:
      ("AirPlay", "multimedia Apple", "Usługa odtwarzania multimediów.", "Niskie", "Tylko sieć lokalna", "AirPlay służy do odtwarzania i sterowania multimediami w sieci lokalnej.")
    default:
      ("Nieznana usługa", "niezidentyfikowana usługa TCP", "Port przyjmuje połączenia TCP.", "Nieokreślone", "Sprawdź usługę", "Otwarty port nie jest błędem; ryzyko zależy od usługi i zakresu dostępu.")
    }
  }

  private var command: String {
    "nc -vz -G 3 \(host) \(entry.port)"
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      Label("\(entry.port) \(details.name)", systemImage: "info.circle")
        .font(.subheadline.weight(.semibold))

      PortDetailsRow(label: "Usługa", value: details.service)
      Text(details.description)
        .font(.caption)
        .foregroundStyle(.secondary)
      PortDetailsRow(label: "Poziom ryzyka", value: details.risk)
      PortDetailsRow(label: "Zalecenie", value: details.recommendation)

      DisclosureGroup("Więcej") {
        Text(details.more)
          .font(.caption)
          .foregroundStyle(.secondary)
          .padding(.top, 3)
      }
      .font(.caption.weight(.semibold))

      VStack(alignment: .leading, spacing: 4) {
        Text("Komenda diagnostyczna")
          .font(.caption.weight(.semibold))
        Text(command)
          .font(.caption.monospaced())
          .textSelection(.enabled)
      }
      .padding(8)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(.background.opacity(0.7), in: RoundedRectangle(cornerRadius: 10))
    }
    .padding(10)
    .background(.cyan.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    .overlay {
      RoundedRectangle(cornerRadius: 14)
        .stroke(Color.cyan.opacity(0.22), lineWidth: 1)
    }
  }
}

private struct PortDetailsRow: View {
  let label: String
  let value: String

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 8) {
      Text(label)
        .font(.caption)
        .foregroundStyle(.secondary)
        .frame(width: 82, alignment: .leading)

      Text(value)
        .font(.caption.monospaced())
        .multilineTextAlignment(.trailing)
        .lineLimit(3)
        .fixedSize(horizontal: false, vertical: true)
        .layoutPriority(1)
        .textSelection(.enabled)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}
