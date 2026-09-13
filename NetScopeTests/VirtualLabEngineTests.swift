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

@Suite("Lab command presentation")
struct LabCommandPresentationTests {
  @Test("Nmap solution is split into learning categories")
  func categorizedNmapSolution() {
    let presentation = LabCommandPresentation(
      intent: .inspect(host: "192.168.50.20", ports: [22, 80], versions: true)
    )

    #expect(presentation.command == "nmap -sT -sV -p 22,80 192.168.50.20")
    #expect(presentation.segments == [
      .init(category: .tool, value: "nmap", explanation: "Program do rozpoznawania sieci i usług."),
      .init(category: .scanType, value: "-sT", explanation: "Pełne połączenie TCP używane bez uprawnień administratora."),
      .init(category: .option, value: "-sV", explanation: "Rozpoznaje usługę i jej wersję."),
      .init(category: .option, value: "-p 22,80", explanation: "Ogranicza sprawdzenie do portów 22 i 80."),
      .init(category: .target, value: "192.168.50.20", explanation: "Host analizowany w sieci demonstracyjnej."),
    ])
  }

  @Test("SSH solution separates user and host")
  func categorizedSSHSolution() {
    let presentation = LabCommandPresentation(
      intent: .connectSSH(user: "learner", host: "mac.lab")
    )

    #expect(presentation.command == "ssh learner@mac.lab")
    #expect(presentation.segments.map(\.category) == [.tool, .user, .target])
    #expect(presentation.segments.map(\.value) == ["ssh", "learner", "mac.lab"])
  }
}
