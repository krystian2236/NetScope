import Darwin
import Foundation

enum LocalNetworkInfo {
  static func currentWiFiContext() -> NetworkContext? {
    var interfacePointer: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&interfacePointer) == 0, let first = interfacePointer else {
      return nil
    }
    defer { freeifaddrs(interfacePointer) }

    var fallback: NetworkContext?
    var pointer: UnsafeMutablePointer<ifaddrs>? = first

    while let interface = pointer?.pointee {
      defer { pointer = interface.ifa_next }

      guard let addressPointer = interface.ifa_addr,
        addressPointer.pointee.sa_family == UInt8(AF_INET)
      else {
        continue
      }

      let flags = Int32(interface.ifa_flags)
      guard (flags & IFF_UP) != 0, (flags & IFF_LOOPBACK) == 0 else {
        continue
      }

      let name = String(cString: interface.ifa_name)
      guard let address = numericAddress(from: addressPointer),
        let netmaskPointer = interface.ifa_netmask,
        let netmask = numericAddress(from: netmaskPointer)
      else {
        continue
      }

      let context = NetworkContext(
        address: address,
        netmask: netmask,
        interfaceName: name,
        ipv6Address: ipv6Address(for: name)
      )

      if name == "en0" {
        return context
      }
      if fallback == nil, context.isPrivateOrLinkLocal {
        fallback = context
      }
    }

    return fallback
  }

  private static func ipv6Address(for interfaceName: String) -> String? {
    var interfacePointer: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&interfacePointer) == 0, let first = interfacePointer else {
      return nil
    }
    defer { freeifaddrs(interfacePointer) }

    var pointer: UnsafeMutablePointer<ifaddrs>? = first
    while let interface = pointer?.pointee {
      defer { pointer = interface.ifa_next }

      guard String(cString: interface.ifa_name) == interfaceName,
        let addressPointer = interface.ifa_addr,
        addressPointer.pointee.sa_family == UInt8(AF_INET6),
        (Int32(interface.ifa_flags) & IFF_UP) != 0,
        let address = numericAddress(from: addressPointer)
      else {
        continue
      }

      return address
    }

    return nil
  }

  private static func numericAddress(
    from address: UnsafePointer<sockaddr>
  ) -> String? {
    var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
    let length = socklen_t(address.pointee.sa_len)
    let result = getnameinfo(
      address,
      length,
      &host,
      socklen_t(host.count),
      nil,
      0,
      NI_NUMERICHOST
    )
    guard result == 0 else { return nil }
    return String(cString: host)
  }
}
