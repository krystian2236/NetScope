import Testing
@testable import NetScope

@Suite("Dig lab program")
struct DigLabProgramTests {
  @Test(arguments: ["A", "AAAA", "MX", "TXT", "NS"])
  func supportedRecordTypes(type: String) {
    let result = VirtualLabEngine(network: .demo).execute("dig web.lab \(type)")
    #expect(result.status == .success)
    #expect(result.output.contains(type))
  }

  @Test("Reverse lookup uses only demo DNS data")
  func reverseLookup() {
    let result = VirtualLabEngine(network: .demo).execute("dig -x 192.168.50.20")
    #expect(result.status == .success)
    #expect(result.output.contains("PTR web.lab."))
  }

  @Test("Short output returns only record values")
  func shortOutput() {
    let result = VirtualLabEngine(network: .demo).execute("dig web.lab A +short")
    #expect(result.status == .success)
    #expect(result.output == "192.168.50.20")
  }

  @Test("Unknown names produce NXDOMAIN")
  func unknownName() {
    let result = VirtualLabEngine(network: .demo).execute("dig missing.lab A")
    #expect(result.status == .invalid)
    #expect(result.output.contains("NXDOMAIN"))
  }

  @Test("Program contains the planned modules and record lessons")
  func modulesAndLessons() {
    let program = DigLabProgram.definition
    #expect(program.modules.map(\.id) == ["records", "server", "output", "troubleshooting"])
    #expect(program.modules.flatMap(\.lessons).count == 9)
  }
}
