import SwiftUI

struct DiagnosticsView: View {
  @ObservedObject var model: NetworkToolsModel
  @State private var diagnosticHost = ""
  @State private var diagnosticPort = "443"

  var body: some View {
    NavigationStack {
      ScrollView {
        LazyVStack(spacing: 12) {
          #if NETSCOPE_DEV
          HStack { UIRefCopyButton(ref: .scannerDiagnostics); Spacer() }
          #endif
          myIPCard
          diagnosticsCard
          InfoBanner(
            icon: "info.circle",
            title: "TCP Ping",
            message: "Mierzy czas połączenia z portem. iOS nie udostępnia zwykłego ping ICMP."
          )
        }
        .padding(12)
      }
      .background(Color(.systemGroupedBackground))
      .navigationTitle("Network Diagnostics")
      .navigationBarTitleDisplayMode(.inline)
      .task {
        model.refreshLocalContext()
      }
    }
  }

  private var myIPCard: some View {
    ToolCard(
      icon: "number.circle.fill",
      title: "My IP",
      subtitle: "Adres lokalny i publiczny"
    ) {
      VStack(spacing: 9) {
        AddressRow(
          label: "Lokalny IPv4",
          value: model.localContext?.address ?? "Brak Wi‑Fi"
        )

        switch model.publicIPState {
        case .idle:
          Button {
            Task { await model.fetchPublicIP() }
          } label: {
            Label("Pobierz publiczny IP", systemImage: "globe")
              .font(.caption.weight(.semibold))
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.bordered)
        case .loading:
          ProgressView("Sprawdzanie…")
            .font(.caption)
            .frame(maxWidth: .infinity, alignment: .leading)
        case .loaded(let address):
          AddressRow(label: "Publiczny IP", value: address)
          Button("Odśwież") {
            Task { await model.fetchPublicIP() }
          }
          .font(.caption)
        case .failed(let message):
          Text(message)
            .font(.caption)
            .foregroundStyle(.red)
          Button("Spróbuj ponownie") {
            Task { await model.fetchPublicIP() }
          }
          .font(.caption)
        }
      }
    }
  }

  private var diagnosticsCard: some View {
    ToolCard(
      icon: "waveform.path.ecg",
      title: "DNS + TCP Ping",
      subtitle: "Domena, rozpoznane adresy i dostępność portu"
    ) {
      VStack(spacing: 9) {
        TextField("Domena lub IP, np. example.com", text: $diagnosticHost)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
          .keyboardType(.URL)
          .textFieldStyle(.roundedBorder)
          .font(.subheadline)

        HStack {
          TextField("Port", text: $diagnosticPort)
            .keyboardType(.numberPad)
            .textFieldStyle(.roundedBorder)
            .font(.subheadline)

          Button {
            runDiagnostic()
          } label: {
            if model.isDiagnosing {
              ProgressView()
                .frame(minWidth: 66)
            } else {
              Text("Sprawdź")
                .font(.caption.weight(.semibold))
                .frame(minWidth: 66)
            }
          }
          .buttonStyle(.borderedProminent)
          .tint(.cyan)
          .disabled(model.isDiagnosing)
        }

        if let error = model.diagnosticError {
          Text(error)
            .font(.caption)
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        if let result = model.diagnosticResult {
          DiagnosticResultView(result: result)
        }
      }
    }
  }

  private func runDiagnostic() {
    Task {
      await model.diagnose(
        host: diagnosticHost,
        port: diagnosticPort
      )
    }
  }
}
