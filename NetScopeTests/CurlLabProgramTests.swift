import Testing
@testable import NetScope

@Suite("Curl lab program")
struct CurlLabProgramTests {
  @Test("Curl explains method and target")
  func categorizedRequest() {
    let result = VirtualLabEngine(network: .demo).execute(
      "curl -X POST -H 'Content-Type: application/json' -d '{\"name\":\"lab\"}' http://api.lab/devices"
    )
    #expect(result.status == .success)
    #expect(result.explanations.map(\.term).contains("POST"))
    #expect(result.explanations.map(\.term).contains("Cel"))
    #expect(result.output.contains("201"))
  }

  @Test("Authorization values are never echoed")
  func redactsAuthorization() {
    let result = VirtualLabEngine(network: .demo).execute(
      "curl -H 'Authorization: Bearer demo-secret' http://api.lab/profile"
    )
    #expect(result.status == .success)
    #expect(!result.output.contains("demo-secret"))
    #expect(!result.explanations.map(\.meaning).joined().contains("demo-secret"))
    let history = LabCommandSanitizer.redactForHistory(
      "curl -H 'Authorization: Bearer demo-secret' http://api.lab/profile"
    )
    #expect(!history.contains("demo-secret"))
    #expect(history.contains("[REDACTED]"))
  }

  @Test("Curl rejects targets outside the demo network")
  func rejectsExternalTarget() {
    let result = VirtualLabEngine(network: .demo).execute("curl https://example.com")
    #expect(result.status == .invalid)
  }

  @Test("Head and redirect options use deterministic endpoints")
  func headAndRedirect() {
    let head = VirtualLabEngine(network: .demo).execute("curl -I http://web.lab")
    let redirect = VirtualLabEngine(network: .demo).execute("curl -L http://web.lab/start")
    #expect(head.status == .success)
    #expect(head.output.contains("HTTP/1.1 200"))
    #expect(redirect.status == .success)
    #expect(redirect.output.contains("dashboard"))
  }

  @Test("Program contains the planned modules")
  func modules() {
    #expect(CurlLabProgram.definition.modules.map(\.id) == [
      "target", "method", "headers", "body", "redirects", "tls", "timeout", "response",
    ])
    #expect(CurlLabProgram.definition.modules.flatMap(\.lessons).count == 8)
  }
}
