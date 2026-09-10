import Foundation
import Network

@MainActor
final class NetworkScanner: ObservableObject {
  @Published var profile: ScanProfile = .quick
  @Published private(set) var devices: [NetworkDevice] = []
  @Published private(set) var phase: ScanPhase = .idle
  @Published private(set) var context: NetworkContext?
  @Published private(set) var history: [ScanSummary] = []
  @Published private(set) var sessionDetails: ScanSessionDetails?
  @Published private(set) var newDeviceKeys: Set<KnownDeviceKey> = []
  let bonjourDiscovery = BonjourDiscovery()
  let knownDeviceStore: KnownDeviceStore

  private var cancellationRequested = false
  private let historyKey = "NetScope.scanHistory"

  init(knownDeviceStore: KnownDeviceStore) {
    self.knownDeviceStore = knownDeviceStore
    loadHistory()
  }

  var networkID: String? {
    context?.scanRangeDescription
  }

  func refreshContext() {
    context = LocalNetworkInfo.currentWiFiContext()
  }

  func scan() async {
    guard !phase.isScanning else { return }

    cancellationRequested = false
    newDeviceKeys = []
    devices = []
    phase = .preparing
    let startedAt = Date()

    guard let context = LocalNetworkInfo.currentWiFiContext() else {
      phase = .failed("Połącz iPhone’a z siecią Wi‑Fi i spróbuj ponownie.")
      return
    }
    guard context.isPrivateOrLinkLocal else {
      phase = .failed("Dla bezpieczeństwa NetScope skanuje tylko prywatne sieci lokalne.")
      return
    }

    self.context = context
    bonjourDiscovery.start()

    let hosts = context.hostsInLocal24
    let selectedProfile = profile
    let ports = selectedProfile.ports
    var completed = 0
    var timedOutProbes = 0
    var deniedProbes = 0
    sessionDetails = ScanSessionDetails(
      id: UUID(),
      startedAt: startedAt,
      finishedAt: nil,
      profile: selectedProfile,
      subnet: context.scanRangeDescription,
      totalHosts: hosts.count,
      portsPerHost: ports.count,
      completedHosts: 0,
      detectedDevices: 0,
      openPorts: 0,
      timedOutProbes: 0,
      deniedProbes: 0,
      resolvedHostnames: 0
    )
    phase = .scanning(completed: completed, total: hosts.count)

    for chunkStart in stride(from: 0, to: hosts.count, by: selectedProfile.hostBatchSize) {
      if cancellationRequested || Task.isCancelled {
        finishSession(at: Date())
        phase = .cancelled
        bonjourDiscovery.stop()
        return
      }

      let chunkEnd = min(chunkStart + selectedProfile.hostBatchSize, hosts.count)
      let chunk = Array(hosts[chunkStart..<chunkEnd])
      let outcomes = await NetworkProbe.scan(hosts: chunk, ports: ports)
      let found = outcomes.compactMap(\.device)

      devices.append(contentsOf: found)
      devices.sort { IPv4SortKey($0.address) < IPv4SortKey($1.address) }
      timedOutProbes += outcomes.reduce(0) { $0 + $1.timedOutCount }
      deniedProbes += outcomes.reduce(0) { $0 + $1.deniedCount }

      completed += chunk.count
      updateSession(
        completedHosts: completed,
        timedOutProbes: timedOutProbes,
        deniedProbes: deniedProbes
      )
      phase = .scanning(completed: completed, total: hosts.count)
    }

    bonjourDiscovery.stop()
    let finishedAt = Date()
    finishSession(at: finishedAt)
    completeRegistryMerge(
      devices: devices,
      networkID: context.scanRangeDescription,
      at: finishedAt
    )
    recordSummary(startedAt: startedAt, finishedAt: finishedAt)
    phase = .finished(finishedAt)
  }

  func cancel() {
    cancellationRequested = true
  }

  func completeRegistryMerge(
    devices: [NetworkDevice],
    networkID: String,
    at date: Date
  ) {
    newDeviceKeys = knownDeviceStore.merge(
      devices: devices,
      networkID: networkID,
      at: date
    )
  }

  private func updateSession(
    completedHosts: Int,
    timedOutProbes: Int,
    deniedProbes: Int
  ) {
    guard var details = sessionDetails else { return }
    details.completedHosts = completedHosts
    details.detectedDevices = devices.count
    details.openPorts = devices.reduce(0) { $0 + $1.openPorts.count }
    details.timedOutProbes = timedOutProbes
    details.deniedProbes = deniedProbes
    details.resolvedHostnames = devices.filter { $0.hostname != nil }.count
    sessionDetails = details
  }

  private func finishSession(at date: Date) {
    guard var details = sessionDetails else { return }
    details.finishedAt = date
    sessionDetails = details
  }

  private func recordSummary(startedAt: Date, finishedAt: Date) {
    let summary = ScanSummary(
      id: UUID(),
      startedAt: startedAt,
      finishedAt: finishedAt,
      profile: profile,
      deviceCount: devices.count,
      openPortCount: devices.reduce(0) { $0 + $1.openPorts.count },
      attentionCount: devices.filter { $0.exposure == .high }.count
    )
    history.insert(summary, at: 0)
    history = Array(history.prefix(8))
    persistHistory()
  }

  private func loadHistory() {
    guard let data = UserDefaults.standard.data(forKey: historyKey),
      let stored = try? JSONDecoder().decode([ScanSummary].self, from: data)
    else {
      return
    }
    history = stored
  }

  private func persistHistory() {
    guard let data = try? JSONEncoder().encode(history) else { return }
    UserDefaults.standard.set(data, forKey: historyKey)
  }
}

private enum NetworkProbe {
  static func scan(
    hosts: [String],
    ports: [UInt16]
  ) async -> [HostProbeOutcome] {
    await withTaskGroup(of: HostProbeOutcome.self) { group in
      for host in hosts {
        group.addTask {
          await scanHost(host, ports: ports)
        }
      }

      var outcomes: [HostProbeOutcome] = []
      for await outcome in group {
        outcomes.append(outcome)
      }
      return outcomes
    }
  }

  private static func scanHost(
    _ host: String,
    ports: [UInt16]
  ) async -> HostProbeOutcome {
    let startedAt = DispatchTime.now().uptimeNanoseconds
    let results = await withTaskGroup(of: TCPConnectionResult.self) { group in
      for port in ports {
        group.addTask {
          await TCPPortProbe.check(
            host: host,
            port: port,
            timeout: 0.65
          )
        }
      }

      var found: [TCPConnectionResult] = []
      for await result in group {
        found.append(result)
      }
      return found
    }

    let openResults =
      results
      .filter { $0.status.isOpen }
      .sorted { $0.port < $1.port }
    let timedOutCount = results.filter { $0.status == .timedOut }.count
    let deniedCount = results.filter { $0.status == .localNetworkDenied }.count

    guard !openResults.isEmpty else {
      return HostProbeOutcome(
        device: nil,
        timedOutCount: timedOutCount,
        deniedCount: deniedCount
      )
    }

    let hostname = await DNSResolver.reverseLookup(host)
    let elapsed = DispatchTime.now().uptimeNanoseconds - startedAt
    let device = NetworkDevice(
      address: host,
      hostname: hostname,
      openPorts: openResults.map(\.port),
      lastSeen: Date(),
      portObservations: openResults.map {
        PortObservation(port: $0.port, latencyMilliseconds: $0.latencyMilliseconds)
      },
      testedPortCount: ports.count,
      timedOutPortCount: timedOutCount,
      deniedPortCount: deniedCount,
      probeDurationMilliseconds: Double(elapsed) / 1_000_000
    )
    return HostProbeOutcome(
      device: device,
      timedOutCount: timedOutCount,
      deniedCount: deniedCount
    )
  }
}

private struct HostProbeOutcome: Sendable {
  let device: NetworkDevice?
  let timedOutCount: Int
  let deniedCount: Int
}

private struct IPv4SortKey: Comparable {
  private let value: UInt32

  init(_ address: String) {
    let octets = address.split(separator: ".").compactMap { UInt32($0) }
    if octets.count == 4 {
      value = (octets[0] << 24) | (octets[1] << 16) | (octets[2] << 8) | octets[3]
    } else {
      value = 0
    }
  }

  static func < (lhs: Self, rhs: Self) -> Bool {
    lhs.value < rhs.value
  }
}
