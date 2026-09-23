import Foundation

struct VirtualService: Equatable, Sendable {
  let port: UInt16
  let transport: String
  let name: String
  let version: String?
}

struct VirtualHost: Identifiable, Equatable, Sendable {
  var id: String { address }

  let address: String
  let hostname: String
  let role: String
  let services: [VirtualService]
}

struct VirtualDNSRecord: Equatable, Sendable {
  let name: String
  let type: String
  let value: String
}

struct VirtualHTTPEndpoint: Equatable, Sendable {
  let host: String
  let path: String
  let method: String
  let status: Int
  let body: String
  let redirectPath: String?
}

struct VirtualNetwork: Equatable, Sendable {
  let cidr: String
  let hosts: [VirtualHost]
  let dnsRecords: [VirtualDNSRecord]
  let httpEndpoints: [VirtualHTTPEndpoint]

  func host(at address: String) -> VirtualHost? {
    hosts.first {
      $0.address == address || $0.hostname.caseInsensitiveCompare(address) == .orderedSame
    }
  }

  func activeHosts(in cidr: String) -> [VirtualHost] {
    cidr == self.cidr ? hosts : []
  }

  func records(named name: String, type: String) -> [VirtualDNSRecord] {
    dnsRecords.filter {
      $0.name.caseInsensitiveCompare(name) == .orderedSame
        && $0.type.caseInsensitiveCompare(type) == .orderedSame
    }
  }

  func endpoint(host: String, path: String, method: String) -> VirtualHTTPEndpoint? {
    httpEndpoints.first {
      $0.host.caseInsensitiveCompare(host) == .orderedSame
        && $0.path == path
        && $0.method.caseInsensitiveCompare(method) == .orderedSame
    }
  }

  static let demo = VirtualNetwork(
    cidr: "192.168.50.0/24",
    hosts: [
      VirtualHost(
        address: "192.168.50.1",
        hostname: "router.lab",
        role: "Router",
        services: [
          VirtualService(port: 53, transport: "tcp", name: "domain", version: nil),
          VirtualService(port: 443, transport: "tcp", name: "https", version: nil),
        ]
      ),
      VirtualHost(
        address: "192.168.50.10",
        hostname: "mac.lab",
        role: "Mac",
        services: [
          VirtualService(port: 22, transport: "tcp", name: "ssh", version: "OpenSSH"),
        ]
      ),
      VirtualHost(
        address: "192.168.50.20",
        hostname: "web.lab",
        role: "Serwer",
        services: [
          VirtualService(port: 22, transport: "tcp", name: "ssh", version: "OpenSSH"),
          VirtualService(port: 80, transport: "tcp", name: "http", version: "nginx"),
        ]
      ),
      VirtualHost(
        address: "192.168.50.21",
        hostname: "api.lab",
        role: "API",
        services: [
          VirtualService(port: 80, transport: "tcp", name: "http", version: "Northbyte Radar Demo API"),
        ]
      ),
      VirtualHost(
        address: "192.168.50.30",
        hostname: "printer.lab",
        role: "Drukarka",
        services: [
          VirtualService(port: 631, transport: "tcp", name: "ipp", version: nil),
        ]
      ),
    ],
    dnsRecords: [
      VirtualDNSRecord(name: "web.lab", type: "A", value: "192.168.50.20"),
      VirtualDNSRecord(name: "web.lab", type: "AAAA", value: "2001:db8:50::20"),
      VirtualDNSRecord(name: "web.lab", type: "MX", value: "10 mail.lab."),
      VirtualDNSRecord(name: "web.lab", type: "TXT", value: "\"netscope-demo\""),
      VirtualDNSRecord(name: "web.lab", type: "NS", value: "ns.lab."),
    ],
    httpEndpoints: [
      VirtualHTTPEndpoint(host: "web.lab", path: "/", method: "GET", status: 200, body: "Northbyte Radar demo web", redirectPath: nil),
      VirtualHTTPEndpoint(host: "web.lab", path: "/", method: "HEAD", status: 200, body: "", redirectPath: nil),
      VirtualHTTPEndpoint(host: "web.lab", path: "/start", method: "GET", status: 302, body: "", redirectPath: "/dashboard"),
      VirtualHTTPEndpoint(host: "web.lab", path: "/dashboard", method: "GET", status: 200, body: "dashboard", redirectPath: nil),
      VirtualHTTPEndpoint(host: "api.lab", path: "/devices", method: "POST", status: 201, body: "{\"created\":true}", redirectPath: nil),
      VirtualHTTPEndpoint(host: "api.lab", path: "/profile", method: "GET", status: 200, body: "{\"user\":\"learner\"}", redirectPath: nil),
    ]
  )
}
