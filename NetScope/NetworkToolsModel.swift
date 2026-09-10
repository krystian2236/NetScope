import Foundation

@MainActor
final class NetworkToolsModel: ObservableObject {
  enum PublicIPState: Equatable {
    case idle
    case loading
    case loaded(String)
    case failed(String)
  }

  @Published private(set) var localContext: NetworkContext?
  @Published private(set) var publicIPState: PublicIPState = .idle
  @Published private(set) var diagnosticResult: HostDiagnosticResult?
  @Published private(set) var diagnosticError: String?
  @Published private(set) var isDiagnosing = false
  @Published private(set) var portScanResults: [PortScanEntry] = []
  @Published private(set) var portScanProgress: (completed: Int, total: Int)?
  @Published private(set) var portScanError: String?
  @Published private(set) var isScanningPorts = false

  private var portScanTask: Task<Void, Never>?

  func refreshLocalContext() {
    localContext = LocalNetworkInfo.currentWiFiContext()
  }

  func fetchPublicIP() async {
    publicIPState = .loading
    do {
      publicIPState = .loaded(try await PublicIPClient.fetch())
    } catch is CancellationError {
      publicIPState = .idle
    } catch {
      publicIPState = .failed("Nie udało się pobrać publicznego adresu IP.")
    }
  }

  func diagnose(host input: String, port inputPort: String) async {
    guard let host = TargetValidator.normalizedHost(input) else {
      diagnosticError = "Wpisz poprawny adres IP lub domenę."
      diagnosticResult = nil
      return
    }
    guard let port = TargetValidator.port(inputPort) else {
      diagnosticError = "Port musi mieć wartość od 1 do 65535."
      diagnosticResult = nil
      return
    }

    diagnosticError = nil
    diagnosticResult = nil
    isDiagnosing = true
    defer { isDiagnosing = false }

    async let addresses = DNSResolver.resolve(host)
    async let portResult = TCPPortProbe.check(
      host: host,
      port: port,
      timeout: 3
    )

    diagnosticResult = await HostDiagnosticResult(
      host: host,
      resolvedAddresses: addresses,
      portResult: portResult,
      checkedAt: Date()
    )
  }

  func scanPorts(
    host input: String,
    preset: PortScanPreset,
    customStart: String,
    customEnd: String
  ) {
    guard let host = TargetValidator.normalizedHost(input) else {
      portScanError = "Wpisz poprawny adres IP lub domenę."
      return
    }

    let ports: [UInt16]
    if preset == .custom {
      guard
        let customPorts = TargetValidator.customPorts(
          start: customStart,
          end: customEnd
        )
      else {
        portScanError = "Zakres musi zawierać maksymalnie 512 portów od 1 do 65535."
        return
      }
      ports = customPorts
    } else {
      ports = preset.ports
    }

    portScanTask?.cancel()
    portScanResults = []
    portScanError = nil
    portScanProgress = (0, ports.count)
    isScanningPorts = true

    portScanTask = Task { [weak self] in
      let results = await TCPPortProbe.scan(
        host: host,
        ports: ports
      ) { completed, total in
        self?.portScanProgress = (completed, total)
      }

      guard let self else { return }
      if Task.isCancelled {
        self.isScanningPorts = false
        return
      }
      self.portScanResults = results
      self.isScanningPorts = false
    }
  }

  func cancelPortScan() {
    portScanTask?.cancel()
    portScanTask = nil
    isScanningPorts = false
  }
}
