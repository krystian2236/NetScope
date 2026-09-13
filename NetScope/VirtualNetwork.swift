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

struct VirtualNetwork: Equatable, Sendable {
  let cidr: String
  let hosts: [VirtualHost]

  func host(at address: String) -> VirtualHost? {
    hosts.first { $0.address == address }
  }

  func activeHosts(in cidr: String) -> [VirtualHost] {
    cidr == self.cidr ? hosts : []
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
        address: "192.168.50.30",
        hostname: "printer.lab",
        role: "Drukarka",
        services: [
          VirtualService(port: 631, transport: "tcp", name: "ipp", version: nil),
        ]
      ),
    ]
  )
}
