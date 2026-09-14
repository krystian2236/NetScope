import Testing

@testable import NetScope

@Suite("Virtual network")
struct VirtualNetworkTests {
  @Test("Demo network has stable private hosts")
  func stableHosts() {
    let network = VirtualNetwork.demo

    #expect(network.cidr == "192.168.50.0/24")
    #expect(network.activeHosts(in: network.cidr).map(\.address) == [
      "192.168.50.1",
      "192.168.50.10",
      "192.168.50.20",
      "192.168.50.30",
    ])
    #expect(network.host(at: "192.168.50.20")?.services.map(\.port) == [22, 80])
  }
}
