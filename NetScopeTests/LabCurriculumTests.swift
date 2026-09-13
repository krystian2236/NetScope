import Testing
@testable import NetScope

@Suite("Lab curriculum")
struct LabCurriculumTests {
  @Test("First milestone contains four ordered tools")
  func orderedTools() {
    #expect(LabToolID.firstMilestone == [.nmap, .nuclei, .dig, .curl])
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
}
