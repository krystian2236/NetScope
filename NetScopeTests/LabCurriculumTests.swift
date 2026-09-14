import Testing
@testable import NetScope

@Suite("Lab curriculum")
struct LabCurriculumTests {
  @Test("First milestone contains four ordered tools")
  func orderedTools() {
    #expect(LabToolID.firstMilestone == [.nmap, .nuclei, .dig, .curl])
  }

  @Test("Lab tools map to Developer identifier tools")
  func labToolsMapToDeveloperTools() {
    #expect(DeveloperAreaTool(.nmap) == .nmap)
    #expect(DeveloperAreaTool(.nuclei) == .nuclei)
    #expect(DeveloperAreaTool(.dig) == .dig)
    #expect(DeveloperAreaTool(.curl) == .curl)
  }

  @Test("First milestone exposes four complete lab programs")
  func firstMilestonePrograms() {
    #expect(LabCurriculum.firstMilestonePrograms.map(\.id) == [.nmap, .nuclei, .dig, .curl])
    #expect(LabCurriculum.firstMilestonePrograms.allSatisfy { !$0.modules.isEmpty })
  }

  @Test("Developer opens Pro while Demo does not")
  func accessPolicy() {
    #expect(LabAccessPolicy.canOpen(.pro, state: .demo, variant: .developer))
    #expect(!LabAccessPolicy.canOpen(.pro, state: .demo, variant: .appStore))
    #expect(LabAccessPolicy.canOpen(.pro, state: .pro, variant: .appStore))
  }

  @Test("Laboratory starts with learning then tool programs")
  func navigationOrder() {
    #expect(LaboratorySectionID.navigationOrder == [
      .learning, .tool(.nmap), .tool(.nuclei), .tool(.dig), .tool(.curl),
    ])
  }

  @Test("Briefing derives the target and objectives from the mission")
  func missionBriefing() {
    let mission = LabMission.demo[1]
    let briefing = LabBriefing(mission: mission)

    #expect(briefing.target == "192.168.50.20")
    #expect(briefing.objectives == [
      "Sprawdź porty 22 i 80 oraz wersje usług hosta 192.168.50.20.",
    ])
    #expect(briefing.stepCountLabel == "1 krok")
  }

  @Test("Terminal lesson presents the lesson before its current task")
  func terminalLessonPresentation() {
    let mission = LabMission.demo[1]
    let presentation = TerminalLessonPresentation(
      mission: mission,
      activeStep: mission.steps.first
    )

    #expect(presentation.lessonDescription == "Sprawdź porty i nazwy usług serwera WWW.")
    #expect(presentation.taskDescription == "Sprawdź porty 22 i 80 oraz wersje usług hosta 192.168.50.20.")
    #expect(presentation.terminalPrompt == "Terminal czeka. Wybierz gotowe polecenie albo wpisz własne.")
  }
}
