import Testing
@testable import NetScope

@Suite("Nmap lab program")
struct NmapLabProgramTests {
  @Test("Every Nmap option has educational coverage")
  func completeCoverage() {
    let covered = Set(NmapLabProgram.definition.modules.flatMap(\.coverage).map(\.optionID))
    let catalog = Set(NmapCatalog.definition.options.map(\.id))
    #expect(covered == catalog)
    #expect(NmapLabProgram.definition.modules.map(\.id) == NmapCatalog.definition.categories.map(\.id))
  }

  @Test("Combined diagnostic command is evaluated semantically")
  func combinedMission() {
    let result = VirtualLabEngine(network: .demo).execute(
      "nmap --reason -Pn -sT --open 192.168.50.10"
    )
    #expect(result.status == .success)
    #expect(result.output.contains("22/tcp open ssh"))
    #expect(result.explanations.map(\.term).contains("--reason"))
  }
}
