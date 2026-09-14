import Testing
@testable import NetScope

@Suite("Nuclei lab program")
struct NucleiLabProgramTests {
  @Test("Every Nuclei option has educational coverage")
  func completeCoverage() {
    let covered = Set(NucleiLabProgram.definition.modules.flatMap(\.coverage).map(\.optionID))
    let catalog = Set(NucleiCatalog.definition.options.map(\.id))
    #expect(covered == catalog)
    #expect(NucleiLabProgram.definition.modules.map(\.id) == NucleiCatalog.definition.categories.map(\.id))
  }

  @Test("Nuclei scan stays inside the demo network")
  func simulatedTemplateScan() {
    let result = VirtualLabEngine(network: .demo).execute(
      "nuclei -u http://web.lab -tags misconfiguration"
    )
    #expect(result.status == .success)
    #expect(result.output.contains("web.lab"))
    #expect(result.output.contains("symulacja"))
  }

  @Test("Nuclei rejects targets outside the demo network")
  func rejectsExternalTarget() {
    let result = VirtualLabEngine(network: .demo).execute(
      "nuclei -u https://example.com -tags misconfiguration"
    )
    #expect(result.status == .invalid)
  }

  @Test("Secret option values are redacted before history")
  func redactsSecrets() {
    let command = "nuclei -u http://web.lab -itoken demo-secret -H 'Authorization: Bearer hidden'"
    let redacted = LabCommandSanitizer.redact(command, tool: NucleiCatalog.definition)
    #expect(!redacted.contains("demo-secret"))
    #expect(!redacted.contains("Bearer hidden"))
    #expect(redacted.contains("[REDACTED]"))
  }
}
