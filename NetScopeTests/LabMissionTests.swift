import Foundation
import Testing

@testable import NetScope

@MainActor
@Suite("Lab missions")
struct LabMissionTests {
  @Test("Equivalent discovery command completes first step")
  func semanticCompletion() {
    let step = LabMission.demo[0].steps[0]
    let command = "nmap  -sn  192.168.50.0/24"
    let result = VirtualLabEngine(network: .demo).execute(command)

    #expect(step.accepts(command: command, result: result))
  }

  @Test("Progress round trips through isolated defaults")
  func progressRoundTrip() {
    let suite = "LabProgressTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }

    let store = LabProgressStore(defaults: defaults)
    store.complete(missionID: "host-discovery", stepID: "discover")

    #expect(
      LabProgressStore(defaults: defaults).isComplete(
        missionID: "host-discovery",
        stepID: "discover"
      )
    )
  }

  @Test("Demo contains three free missions")
  func freeDemoMissions() {
    #expect(LabMission.demo.map(\.id) == ["host-discovery", "ports-services", "ssh-basics"])
    #expect(LabMission.demo.allSatisfy { !$0.isPro })
  }

  @Test("Inspection intent accepts equivalent option spacing")
  func inspectionIntent() {
    let step = LabMission.demo[1].steps[0]
    let command = "nmap -sT -p 22,80 -sV 192.168.50.20"
    let result = VirtualLabEngine(network: .demo).execute(command)

    #expect(step.accepts(command: command, result: result))
  }

  @Test("SSH mission uses a simulated hostname")
  func sshMission() {
    let step = LabMission.demo[2].steps[0]
    let command = "ssh learner@mac.lab"
    let result = VirtualLabEngine(network: .demo).execute(command)

    #expect(step.accepts(command: command, result: result))
  }
}
