import Foundation

struct NetworkContext: Equatable, Sendable {
  let address: String
  let netmask: String
  let interfaceName: String

  var scanRangeDescription: String {
    let parts = address.split(separator: ".")
    guard parts.count == 4 else { return address }
    return "\(parts[0]).\(parts[1]).\(parts[2]).0/24"
  }

  var hostsInLocal24: [String] {
    let parts = address.split(separator: ".")
    guard parts.count == 4 else { return [] }
    let prefix = "\(parts[0]).\(parts[1]).\(parts[2])"
    return (1...254)
      .map { "\(prefix).\($0)" }
      .filter { $0 != address }
  }

  var isPrivateOrLinkLocal: Bool {
    let octets = address.split(separator: ".").compactMap { Int($0) }
    guard octets.count == 4 else { return false }
    return octets[0] == 10
      || (octets[0] == 172 && (16...31).contains(octets[1]))
      || (octets[0] == 192 && octets[1] == 168)
      || (octets[0] == 169 && octets[1] == 254)
  }
}

struct NetworkDevice: Identifiable, Hashable, Sendable {
  let address: String
  let hostname: String?
  var openPorts: [UInt16]
  let lastSeen: Date
  let portObservations: [PortObservation]
  let testedPortCount: Int
  let timedOutPortCount: Int
  let deniedPortCount: Int
  let probeDurationMilliseconds: Double?

  var id: String { address }

  init(
    address: String,
    hostname: String?,
    openPorts: [UInt16],
    lastSeen: Date,
    portObservations: [PortObservation] = [],
    testedPortCount: Int = 0,
    timedOutPortCount: Int = 0,
    deniedPortCount: Int = 0,
    probeDurationMilliseconds: Double? = nil
  ) {
    self.address = address
    self.hostname = hostname
    self.openPorts = openPorts
    self.lastSeen = lastSeen
    self.portObservations = portObservations
    self.testedPortCount = max(testedPortCount, openPorts.count)
    self.timedOutPortCount = timedOutPortCount
    self.deniedPortCount = deniedPortCount
    self.probeDurationMilliseconds = probeDurationMilliseconds
  }

  var primaryName: String {
    if let hostname, !hostname.isEmpty, hostname != address {
      return hostname
    }
    return kind.title
  }

  var kind: DeviceKind {
    if address.hasSuffix(".1") {
      return .router
    }
    if openPorts.contains(9100) || openPorts.contains(631) || openPorts.contains(515) {
      return .printer
    }
    if openPorts.contains(554) {
      return .camera
    }
    if openPorts.contains(8008) || openPorts.contains(8009) || openPorts.contains(32400) {
      return .media
    }
    if openPorts.contains(1883) || openPorts.contains(8883) || openPorts.contains(6668) {
      return .smartHome
    }
    if !Set(openPorts).isDisjoint(with: [1433, 3306, 5432, 6379, 9200]) {
      return .server
    }
    if !Set(openPorts).isDisjoint(with: [22, 139, 445, 3389, 5900]) {
      return .computer
    }
    return .unknown
  }

  var exposure: ExposureLevel {
    let highExposure: Set<UInt16> = [21, 23, 139, 445, 2375, 3389, 5900, 6379]
    let mediumExposure: Set<UInt16> = [80, 554, 1883, 3306, 5432, 8080, 9100]
    let ports = Set(openPorts)

    if !ports.isDisjoint(with: highExposure) {
      return .high
    }
    if openPorts.count >= 5 || !ports.isDisjoint(with: mediumExposure) {
      return .medium
    }
    return .low
  }

  var serviceSummary: String {
    openPorts.map { PortCatalog.name(for: $0) }.joined(separator: " • ")
  }

  var encryptedServiceCount: Int {
    openPorts.filter { PortCatalog.info(for: $0).isEncrypted }.count
  }

  var unencryptedServiceCount: Int {
    openPorts.count - encryptedServiceCount
  }

  var closedPortCount: Int {
    max(testedPortCount - openPorts.count - timedOutPortCount - deniedPortCount, 0)
  }

  func latency(for port: UInt16) -> Double? {
    portObservations.first { $0.port == port }?.latencyMilliseconds
  }
}

struct KnownDeviceKey: Codable, Hashable, Sendable {
  let networkID: String
  let address: String
}

enum DeviceTrustStatus: String, Codable, Sendable {
  case trusted
  case unknown
}

enum DeviceRegistryStatus: Equatable, Sendable {
  case new
  case trusted
  case unknown

  init(record: KnownDeviceRecord?, isNew: Bool) {
    if isNew {
      self = .new
    } else if record?.trustStatus == .trusted {
      self = .trusted
    } else {
      self = .unknown
    }
  }

  var title: String {
    switch self {
    case .new: "Nowe"
    case .trusted: "Zaufane"
    case .unknown: "Nieznane"
    }
  }

  static func reviewCount(in statuses: [DeviceRegistryStatus]) -> Int {
    statuses.filter { $0 == .new || $0 == .unknown }.count
  }
}

struct KnownDeviceRecord: Codable, Identifiable, Equatable, Sendable {
  let id: UUID
  let key: KnownDeviceKey
  var hostname: String?
  var customName: String?
  var trustStatus: DeviceTrustStatus
  let firstSeen: Date
  var lastSeen: Date
  var openPorts: [UInt16]
  var kind: DeviceKind

  var normalizedCustomName: String? {
    guard let customName else { return nil }
    let trimmed = customName.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }
}

extension NetworkDevice {
  func displayName(using record: KnownDeviceRecord?) -> String {
    if let customName = record?.normalizedCustomName {
      return customName
    }
    if let hostname, !hostname.isEmpty, hostname != address {
      return hostname
    }
    return kind.title
  }
}

struct PortObservation: Hashable, Sendable {
  let port: UInt16
  let latencyMilliseconds: Double?
}

enum DeviceKind: String, CaseIterable, Codable, Sendable {
  case router
  case printer
  case camera
  case media
  case smartHome
  case computer
  case server
  case unknown

  var title: String {
    switch self {
    case .router: "Router lub brama"
    case .printer: "Drukarka"
    case .camera: "Kamera lub strumień"
    case .media: "Multimedia"
    case .smartHome: "Smart Home / IoT"
    case .computer: "Komputer"
    case .server: "Serwer"
    case .unknown: "Urządzenie sieciowe"
    }
  }

  var icon: String {
    switch self {
    case .router: "wifi.router"
    case .printer: "printer"
    case .camera: "video"
    case .media: "tv"
    case .smartHome: "homekit"
    case .computer: "desktopcomputer"
    case .server: "server.rack"
    case .unknown: "network"
    }
  }
}

enum ExposureLevel: Int, Comparable, Sendable {
  case low
  case medium
  case high

  static func < (lhs: Self, rhs: Self) -> Bool {
    lhs.rawValue < rhs.rawValue
  }

  var title: String {
    switch self {
    case .low: "Niska"
    case .medium: "Średnia"
    case .high: "Podwyższona"
    }
  }

  var recommendation: String {
    switch self {
    case .low:
      "Wykryto niewiele typowych usług. Nadal dbaj o aktualizacje urządzenia."
    case .medium:
      "Sprawdź, czy widoczne usługi są potrzebne i chronione aktualnym hasłem."
    case .high:
      "Wykryto usługę administracyjną lub starszy protokół. Ogranicz dostęp do zaufanej sieci i zweryfikuj konfigurację."
    }
  }
}

struct PortInfo: Sendable {
  let name: String
  let description: String
  let isEncrypted: Bool
  let category: String
}

struct ScanSummary: Codable, Identifiable, Equatable, Sendable {
  let id: UUID
  let startedAt: Date
  let finishedAt: Date
  let profile: ScanProfile
  let deviceCount: Int
  let openPortCount: Int
  let attentionCount: Int

  var duration: TimeInterval {
    finishedAt.timeIntervalSince(startedAt)
  }
}

struct ScanSessionDetails: Identifiable, Equatable, Sendable {
  let id: UUID
  let startedAt: Date
  var finishedAt: Date?
  let profile: ScanProfile
  let subnet: String
  let totalHosts: Int
  let portsPerHost: Int
  var completedHosts: Int
  var detectedDevices: Int
  var openPorts: Int
  var timedOutProbes: Int
  var deniedProbes: Int
  var resolvedHostnames: Int

  var plannedProbes: Int {
    totalHosts * portsPerHost
  }

  var completedProbes: Int {
    completedHosts * portsPerHost
  }

  var closedProbes: Int {
    max(completedProbes - openPorts - timedOutProbes - deniedProbes, 0)
  }

  var progress: Double {
    guard totalHosts > 0 else { return 0 }
    return Double(completedHosts) / Double(totalHosts)
  }

  var duration: TimeInterval {
    (finishedAt ?? Date()).timeIntervalSince(startedAt)
  }
}

struct BonjourServiceRecord: Identifiable, Hashable, Sendable {
  let name: String
  let type: String
  let domain: String
  let interfaceName: String?

  var id: String {
    "\(name)|\(type)|\(domain)|\(interfaceName ?? "")"
  }

  var friendlyType: String {
    BonjourCatalog.name(for: type)
  }
}

enum ScanProfile: String, CaseIterable, Identifiable, Codable, Sendable {
  case quick
  case standard
  case extended

  var id: Self { self }

  var title: String {
    switch self {
    case .quick: "Szybki"
    case .standard: "Standard"
    case .extended: "Rozszerzony"
    }
  }

  var subtitle: String {
    switch self {
    case .quick: "Najczęstsze usługi"
    case .standard: "Dom, multimedia i administracja"
    case .extended: "Serwery, bazy i więcej usług"
    }
  }

  var hostBatchSize: Int {
    switch self {
    case .quick: 18
    case .standard: 10
    case .extended: 6
    }
  }

  var ports: [UInt16] {
    switch self {
    case .quick:
      [22, 23, 53, 80, 443, 445, 554, 1883, 8080, 9100]
    case .standard:
      [
        21, 22, 23, 25, 53, 80, 110, 139, 143, 443, 445, 515, 548,
        554, 631, 993, 995, 1883, 3389, 5683, 5900, 6668, 7000,
        8008, 8009, 8080, 8443, 8883, 9100, 32400,
      ]
    case .extended:
      [
        20, 21, 22, 23, 25, 53, 80, 110, 111, 135, 139, 143, 389,
        443, 445, 465, 515, 548, 554, 587, 631, 993, 995, 1433,
        1883, 2049, 2375, 3000, 3306, 3389, 5000, 5432, 5683,
        5900, 6379, 6668, 7000, 8000, 8008, 8009, 8080, 8081,
        8443, 8883, 8888, 9000, 9100, 9200, 32400,
      ]
    }
  }
}

enum ScanPhase: Equatable {
  case idle
  case preparing
  case scanning(completed: Int, total: Int)
  case finished(Date)
  case cancelled
  case failed(String)

  var isScanning: Bool {
    switch self {
    case .preparing, .scanning: true
    default: false
    }
  }
}

enum ScanCompletion {
  static let localNetworkDeniedMessage =
    "Brak dostępu do sieci lokalnej. Włącz go w Ustawieniach iPhone’a: Prywatność i ochrona > Sieć lokalna."

  static func phase(
    deviceCount: Int,
    completedProbes: Int,
    deniedProbes: Int,
    finishedAt: Date
  ) -> ScanPhase {
    if deviceCount == 0,
      completedProbes > 0,
      deniedProbes == completedProbes
    {
      return .failed(localNetworkDeniedMessage)
    }
    return .finished(finishedAt)
  }
}

enum ScanStage: Int, CaseIterable, Identifiable, Sendable {
  case network
  case addressesAndPorts
  case namesAndServices
  case results

  var id: Self { self }

  var title: String {
    switch self {
    case .network: "Sieć"
    case .addressesAndPorts: "IP i porty"
    case .namesAndServices: "DNS i usługi"
    case .results: "Wyniki"
    }
  }

  var icon: String {
    switch self {
    case .network: "wifi"
    case .addressesAndPorts: "number"
    case .namesAndServices: "network"
    case .results: "checkmark"
    }
  }

  var progress: Double {
    switch self {
    case .network: 0.1
    case .addressesAndPorts: 0.55
    case .namesAndServices: 0.85
    case .results: 1
    }
  }
}

enum PortCatalog {
  static func name(for port: UInt16) -> String {
    info(for: port).name
  }

  static func info(for port: UInt16) -> PortInfo {
    switch port {
    case 20, 21:
      PortInfo(
        name: "FTP", description: "Transfer plików bez domyślnego szyfrowania.", isEncrypted: false,
        category: "Pliki")
    case 22:
      PortInfo(
        name: "SSH", description: "Szyfrowane zdalne zarządzanie.", isEncrypted: true,
        category: "Administracja")
    case 23:
      PortInfo(
        name: "Telnet", description: "Starsze zdalne zarządzanie bez szyfrowania.",
        isEncrypted: false, category: "Administracja")
    case 25, 465, 587:
      PortInfo(
        name: "SMTP", description: "Usługa wysyłania poczty.", isEncrypted: port == 465,
        category: "Poczta")
    case 53:
      PortInfo(
        name: "DNS", description: "Rozwiązywanie nazw sieciowych.", isEncrypted: false,
        category: "Sieć")
    case 80, 8000, 8080, 8081, 8888:
      PortInfo(
        name: "HTTP", description: "Panel lub usługa WWW bez gwarancji szyfrowania.",
        isEncrypted: false, category: "WWW")
    case 110, 995:
      PortInfo(
        name: port == 995 ? "POP3S" : "POP3", description: "Odbieranie poczty.",
        isEncrypted: port == 995, category: "Poczta")
    case 111, 2049:
      PortInfo(
        name: "NFS/RPC", description: "Udostępnianie plików w systemach Unix.", isEncrypted: false,
        category: "Pliki")
    case 135, 139:
      PortInfo(
        name: "NetBIOS/RPC", description: "Usługi sieciowe systemu Windows.", isEncrypted: false,
        category: "System")
    case 143, 993:
      PortInfo(
        name: port == 993 ? "IMAPS" : "IMAP", description: "Odbieranie poczty.",
        isEncrypted: port == 993, category: "Poczta")
    case 389:
      PortInfo(
        name: "LDAP", description: "Usługa katalogowa.", isEncrypted: false, category: "Katalog")
    case 443, 8443:
      PortInfo(
        name: "HTTPS", description: "Szyfrowany panel lub usługa WWW.", isEncrypted: true,
        category: "WWW")
    case 445:
      PortInfo(
        name: "SMB", description: "Udostępnianie plików Windows.", isEncrypted: false,
        category: "Pliki")
    case 515, 631, 9100:
      PortInfo(
        name: "Drukarka", description: "Drukowanie sieciowe.", isEncrypted: false, category: "Druk")
    case 548:
      PortInfo(
        name: "AFP", description: "Starsze udostępnianie plików Apple.", isEncrypted: false,
        category: "Pliki")
    case 554:
      PortInfo(
        name: "RTSP", description: "Strumień audio lub wideo, często kamera.", isEncrypted: false,
        category: "Multimedia")
    case 1433, 3306, 5432, 6379, 9200:
      PortInfo(
        name: databaseName(for: port), description: "Usługa bazy danych lub wyszukiwania.",
        isEncrypted: false, category: "Baza danych")
    case 1883, 8883:
      PortInfo(
        name: port == 8883 ? "MQTT TLS" : "MQTT", description: "Komunikacja urządzeń IoT.",
        isEncrypted: port == 8883, category: "IoT")
    case 2375:
      PortInfo(
        name: "Docker", description: "Zdalne API kontenerów.", isEncrypted: false,
        category: "Administracja")
    case 3000, 5000, 9000:
      PortInfo(
        name: "Aplikacja WWW", description: "Alternatywny port aplikacji lub panelu.",
        isEncrypted: false, category: "WWW")
    case 3389:
      PortInfo(
        name: "RDP", description: "Zdalny pulpit Windows.", isEncrypted: true,
        category: "Administracja")
    case 5683:
      PortInfo(
        name: "CoAP", description: "Lekki protokół urządzeń IoT.", isEncrypted: false,
        category: "IoT")
    case 5900:
      PortInfo(
        name: "VNC", description: "Zdalny pulpit.", isEncrypted: false, category: "Administracja")
    case 6668:
      PortInfo(
        name: "Tuya LAN", description: "Lokalna komunikacja urządzeń Tuya.", isEncrypted: false,
        category: "IoT")
    case 7000:
      PortInfo(
        name: "AirPlay", description: "Usługa multimedialna Apple.", isEncrypted: false,
        category: "Multimedia")
    case 8008, 8009:
      PortInfo(
        name: "Google Cast", description: "Sterowanie urządzeniem multimedialnym.",
        isEncrypted: false, category: "Multimedia")
    case 32400:
      PortInfo(
        name: "Plex", description: "Serwer multimediów Plex.", isEncrypted: false,
        category: "Multimedia")
    default:
      PortInfo(
        name: "TCP \(port)", description: "Nierozpoznana usługa TCP.", isEncrypted: false,
        category: "Inne")
    }
  }

  private static func databaseName(for port: UInt16) -> String {
    switch port {
    case 1433: "MS SQL"
    case 3306: "MySQL"
    case 5432: "PostgreSQL"
    case 6379: "Redis"
    case 9200: "Elasticsearch"
    default: "Baza danych"
    }
  }
}

enum BonjourCatalog {
  static let serviceTypes = [
    "_http._tcp", "_https._tcp", "_ssh._tcp", "_smb._tcp",
    "_ipp._tcp", "_printer._tcp", "_airplay._tcp", "_raop._tcp",
    "_googlecast._tcp", "_hap._tcp", "_matter._tcp", "_mqtt._tcp",
    "_workstation._tcp",
  ]

  static func name(for type: String) -> String {
    switch type {
    case "_http._tcp": "Strona HTTP"
    case "_https._tcp": "Strona HTTPS"
    case "_ssh._tcp": "Zdalny dostęp SSH"
    case "_smb._tcp": "Udostępnione pliki"
    case "_ipp._tcp", "_printer._tcp": "Drukarka"
    case "_airplay._tcp", "_raop._tcp": "AirPlay"
    case "_googlecast._tcp": "Google Cast"
    case "_hap._tcp": "Apple Home"
    case "_matter._tcp": "Matter"
    case "_mqtt._tcp": "MQTT"
    case "_workstation._tcp": "Komputer"
    default: type
    }
  }
}
