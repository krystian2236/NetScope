import Testing

@testable import NetScope

@Suite("Virtual lab engine")
struct VirtualLabEngineTests {
  let engine = VirtualLabEngine(network: .demo)

  @Test("Discovery returns only simulated hosts")
  func discovery() {
    let result = engine.execute("nmap -sn 192.168.50.0/24")

    #expect(result.status == .success)
    #expect(result.output.contains("192.168.50.20"))
    #expect(result.output.contains("web.lab"))
  }

  @Test("Unknown commands never execute")
  func unknownCommand() {
    let result = engine.execute("rm -rf /")

    #expect(result.status == .unsupported)
    #expect(result.output.contains("Laboratorium nie wykonuje tego polecenia"))
  }

  @Test("Invalid flag receives a correction")
  func invalidFlag() {
    let result = engine.execute("nmap -zz 192.168.50.20")

    #expect(result.status == .invalid)
    #expect(result.hint?.contains("-sV") == true)
  }

  @Test("TCP scan filters ports and explains versions")
  func tcpScan() {
    let result = engine.execute("nmap -sT -sV -p 80 192.168.50.20")

    #expect(result.status == .success)
    #expect(result.output.contains("80/tcp open http nginx"))
    #expect(!result.output.contains("22/tcp"))
  }

  @Test("Ping uses only a simulated host")
  func ping() {
    let result = engine.execute("ping 192.168.50.30")

    #expect(result.status == .success)
    #expect(result.output.contains("192.168.50.30"))
  }

  @Test("Reverse DNS returns the demo hostname")
  func reverseDNS() {
    let result = engine.execute("dig -x 192.168.50.1")

    #expect(result.status == .success)
    #expect(result.output.contains("router.lab"))
  }

  @Test("SSH is simulated only for hosts exposing port 22")
  func ssh() {
    let allowed = engine.execute("ssh learner@192.168.50.10")
    let unavailable = engine.execute("ssh learner@192.168.50.30")

    #expect(allowed.status == .success)
    #expect(allowed.output.contains("Żadne dane logowania nie zostały wysłane"))
    #expect(unavailable.status == .invalid)
  }

  @Test("Identical input produces identical output")
  func deterministicOutput() {
    let command = "nmap -sn 192.168.50.0/24"
    #expect(engine.execute(command) == engine.execute(command))
  }
}
