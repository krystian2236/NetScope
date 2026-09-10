import Darwin
import Foundation
import Network

enum TCPConnectionStatus: Equatable, Sendable {
  case open
  case closed
  case timedOut
  case localNetworkDenied

  var isOpen: Bool {
    self == .open
  }
}

struct TCPConnectionResult: Equatable, Sendable {
  let host: String
  let port: UInt16
  let status: TCPConnectionStatus
  let latencyMilliseconds: Double?
}

struct PortScanEntry: Identifiable, Equatable, Sendable {
  let port: UInt16
  let status: TCPConnectionStatus
  let latencyMilliseconds: Double?

  var id: UInt16 { port }
  var serviceName: String { PortCatalog.name(for: port) }
  var info: PortInfo { PortCatalog.info(for: port) }
}

struct HostDiagnosticResult: Equatable, Sendable {
  let host: String
  let resolvedAddresses: [String]
  let portResult: TCPConnectionResult
  let checkedAt: Date
}

enum PortScanPreset: String, CaseIterable, Identifiable {
  case common
  case web
  case smartHome
  case remoteAccess
  case databases
  case custom

  var id: Self { self }

  var title: String {
    switch self {
    case .common: "Popularne"
    case .web: "WWW"
    case .smartHome: "IoT"
    case .remoteAccess: "Zdalny dostęp"
    case .databases: "Serwery i bazy"
    case .custom: "Własny zakres"
    }
  }

  var ports: [UInt16] {
    switch self {
    case .common:
      [
        21, 22, 25, 53, 80, 110, 139, 143, 443, 445, 554, 631,
        993, 995, 1883, 3389, 5900, 8080, 8443, 8883, 9100,
      ]
    case .web:
      [80, 443, 8000, 8008, 8080, 8081, 8443, 8888]
    case .smartHome:
      [
        53, 80, 443, 554, 1883, 5683, 6668, 7000, 8008, 8009,
        8080, 8883, 9100,
      ]
    case .remoteAccess:
      [21, 22, 23, 139, 445, 2375, 3389, 5900]
    case .databases:
      [111, 135, 389, 1433, 2049, 2375, 3000, 3306, 5432, 6379, 9000, 9200]
    case .custom:
      []
    }
  }
}

enum TargetValidator {
  static func normalizedHost(_ input: String) -> String? {
    let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    if let url = URL(string: trimmed.contains("://") ? trimmed : "https://\(trimmed)"),
      let host = url.host,
      !host.isEmpty
    {
      return host
    }

    let withoutBrackets =
      trimmed
      .trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
    guard !withoutBrackets.contains(" "),
      !withoutBrackets.contains("/"),
      !withoutBrackets.contains("?")
    else {
      return nil
    }
    return withoutBrackets
  }

  static func port(_ input: String) -> UInt16? {
    guard let value = UInt16(input), value > 0 else { return nil }
    return value
  }

  static func customPorts(start: String, end: String) -> [UInt16]? {
    guard let first = port(start),
      let last = port(end),
      first <= last,
      Int(last) - Int(first) < 512
    else {
      return nil
    }
    return Array(first...last)
  }
}

enum TCPPortProbe {
  static func check(
    host: String,
    port: UInt16,
    timeout: TimeInterval = 1.5
  ) async -> TCPConnectionResult {
    await withCheckedContinuation { continuation in
      guard let nwPort = NWEndpoint.Port(rawValue: port) else {
        continuation.resume(
          returning: TCPConnectionResult(
            host: host,
            port: port,
            status: .closed,
            latencyMilliseconds: nil
          )
        )
        return
      }

      let startedAt = DispatchTime.now().uptimeNanoseconds
      let connection = NWConnection(
        host: NWEndpoint.Host(host),
        port: nwPort,
        using: .tcp
      )
      let queue = DispatchQueue(
        label: "pl.krystian.NetScope.tcp.\(port)",
        qos: .userInitiated
      )
      let completion = TCPProbeCompletion(
        continuation: continuation,
        connection: connection,
        host: host,
        port: port,
        startedAt: startedAt
      )

      connection.stateUpdateHandler = { state in
        switch state {
        case .ready:
          completion.finish(.open)
        case .waiting:
          if connection.currentPath?.unsatisfiedReason == .localNetworkDenied {
            completion.finish(.localNetworkDenied)
          }
        case .failed, .cancelled:
          completion.finish(.closed)
        default:
          break
        }
      }

      connection.start(queue: queue)
      queue.asyncAfter(deadline: .now() + timeout) {
        completion.finish(.timedOut)
      }
    }
  }

  static func scan(
    host: String,
    ports: [UInt16],
    timeout: TimeInterval = 0.9,
    batchSize: Int = 32,
    progress: @escaping @MainActor (Int, Int) -> Void
  ) async -> [PortScanEntry] {
    var allResults: [PortScanEntry] = []
    var completed = 0

    for start in stride(from: 0, to: ports.count, by: batchSize) {
      guard !Task.isCancelled else { break }
      let end = min(start + batchSize, ports.count)
      let batch = Array(ports[start..<end])

      let batchResults = await withTaskGroup(of: PortScanEntry.self) { group in
        for port in batch {
          group.addTask {
            let result = await check(
              host: host,
              port: port,
              timeout: timeout
            )
            return PortScanEntry(
              port: port,
              status: result.status,
              latencyMilliseconds: result.latencyMilliseconds
            )
          }
        }

        var entries: [PortScanEntry] = []
        for await entry in group {
          entries.append(entry)
        }
        return entries
      }

      allResults.append(contentsOf: batchResults)
      completed += batch.count
      await progress(completed, ports.count)
    }

    return allResults.sorted { $0.port < $1.port }
  }
}

enum DNSResolver {
  static func resolve(_ host: String) async -> [String] {
    await Task.detached(priority: .userInitiated) {
      resolveSynchronously(host)
    }.value
  }

  static func reverseLookup(_ address: String) async -> String? {
    await Task.detached(priority: .utility) {
      reverseLookupSynchronously(address)
    }.value
  }

  private static func resolveSynchronously(_ host: String) -> [String] {
    var hints = addrinfo()
    hints.ai_flags = AI_ADDRCONFIG
    hints.ai_family = AF_UNSPEC
    hints.ai_socktype = SOCK_STREAM
    hints.ai_protocol = IPPROTO_TCP

    var resultPointer: UnsafeMutablePointer<addrinfo>?
    guard getaddrinfo(host, nil, &hints, &resultPointer) == 0,
      let first = resultPointer
    else {
      return []
    }
    defer { freeaddrinfo(resultPointer) }

    var addresses = Set<String>()
    var pointer: UnsafeMutablePointer<addrinfo>? = first
    while let info = pointer?.pointee {
      var buffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
      if getnameinfo(
        info.ai_addr,
        info.ai_addrlen,
        &buffer,
        socklen_t(buffer.count),
        nil,
        0,
        NI_NUMERICHOST
      ) == 0 {
        addresses.insert(String(cString: buffer))
      }
      pointer = info.ai_next
    }

    return addresses.sorted()
  }

  private static func reverseLookupSynchronously(_ address: String) -> String? {
    var hints = addrinfo()
    hints.ai_flags = AI_NUMERICHOST
    hints.ai_family = AF_UNSPEC
    hints.ai_socktype = SOCK_STREAM
    hints.ai_protocol = IPPROTO_TCP

    var resultPointer: UnsafeMutablePointer<addrinfo>?
    guard getaddrinfo(address, nil, &hints, &resultPointer) == 0,
      let first = resultPointer
    else {
      return nil
    }
    defer { freeaddrinfo(resultPointer) }

    var buffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
    guard
      getnameinfo(
        first.pointee.ai_addr,
        first.pointee.ai_addrlen,
        &buffer,
        socklen_t(buffer.count),
        nil,
        0,
        NI_NAMEREQD
      ) == 0
    else {
      return nil
    }

    let hostname = String(cString: buffer)
    return hostname == address ? nil : hostname
  }
}

enum PublicIPClient {
  private struct Response: Decodable {
    let ip: String
  }

  static func fetch() async throws -> String {
    let url = URL(string: "https://api64.ipify.org?format=json")!
    var request = URLRequest(url: url)
    request.timeoutInterval = 8
    request.cachePolicy = .reloadIgnoringLocalCacheData

    let (data, response) = try await URLSession.shared.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse,
      (200...299).contains(httpResponse.statusCode)
    else {
      throw URLError(.badServerResponse)
    }
    return try JSONDecoder().decode(Response.self, from: data).ip
  }
}

private final class TCPProbeCompletion: @unchecked Sendable {
  private let lock = NSLock()
  private var completed = false
  private let continuation: CheckedContinuation<TCPConnectionResult, Never>
  private let connection: NWConnection
  private let host: String
  private let port: UInt16
  private let startedAt: UInt64

  init(
    continuation: CheckedContinuation<TCPConnectionResult, Never>,
    connection: NWConnection,
    host: String,
    port: UInt16,
    startedAt: UInt64
  ) {
    self.continuation = continuation
    self.connection = connection
    self.host = host
    self.port = port
    self.startedAt = startedAt
  }

  func finish(_ status: TCPConnectionStatus) {
    lock.lock()
    guard !completed else {
      lock.unlock()
      return
    }
    completed = true
    lock.unlock()

    let elapsed = DispatchTime.now().uptimeNanoseconds - startedAt
    let latency = status == .open ? Double(elapsed) / 1_000_000 : nil
    connection.cancel()
    continuation.resume(
      returning: TCPConnectionResult(
        host: host,
        port: port,
        status: status,
        latencyMilliseconds: latency
      )
    )
  }
}
