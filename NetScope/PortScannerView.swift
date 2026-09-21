import SwiftUI

struct PortScannerView: View {
  @ObservedObject var model: NetworkToolsModel
  @State private var host = ""
  @State private var preset: PortScanPreset = .common
  @State private var customStart = "1"
  @State private var customEnd = "512"
  @State private var showClosedPorts = false

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
          PortResultRow(entry: entry)
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
    model.scanPorts(
      host: host,
      preset: preset,
      customStart: customStart,
      customEnd: customEnd
    )
  }
}
