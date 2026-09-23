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

  @Test("Paid lab access is independent from build variant")
  func accessPolicy() {
    #expect(!LabAccessPolicy.canOpen(.pro, state: .demo))
    #expect(LabAccessPolicy.canOpen(.pro, state: .pro))
    #expect(LabAccessPolicy.canOpen(.pro, state: .subscription))
    #expect(!LabAccessPolicy.canOpen(.subscription, state: .pro))
    #expect(LabAccessPolicy.canOpen(.subscription, state: .subscription))
  }

  @Test("Store entitlement snapshot preserves lifetime Pro under subscription")
  func entitlementSnapshot() {
    let pro = NetScopeEntitlementSnapshot(
      hasLifetimePro: true,
      hasActiveSubscription: false
    )
    let both = NetScopeEntitlementSnapshot(
      hasLifetimePro: true,
      hasActiveSubscription: true
    )

    #expect(pro.accessState == .pro)
    #expect(both.accessState == .subscription)
    #expect(both.hasLifetimePro)
  }

  @Test("Unconfigured StoreKit refresh safely stays Demo")
  @MainActor
  func unconfiguredStoreKitRefresh() async {
    let store = NetScopeEntitlementStore(
      productIDs: NetScopeStoreProductIdentifiers(),
      initialSnapshot: NetScopeEntitlementSnapshot(
        hasLifetimePro: true,
        hasActiveSubscription: false
      )
    )

    await store.refresh()

    #expect(store.snapshot == .demo)
    #expect(store.accessState == .demo)
  }

  @Test("NetScope product identifiers are deduplicated")
  func productIdentifiers() {
    let ids = NetScopeStoreProductIdentifiers(
      lifetimePro: "pro",
      subscriptions: ["monthly", "yearly", "monthly"]
    )

    #expect(ids.all == Set(["pro", "monthly", "yearly"]))
  }

  @Test("Unconfigured product loading stays offline and empty")
  @MainActor
  func unconfiguredProductLoading() async {
    let store = NetScopeEntitlementStore(
      productIDs: NetScopeStoreProductIdentifiers()
    )

    await store.loadProducts()

    #expect(store.products.isEmpty)
    #expect(!store.isLoadingProducts)
    #expect(store.lastError == nil)
  }

  @Test("Purchase rejects an unloaded product")
  @MainActor
  func purchaseRejectsUnavailableProduct() async {
    let store = NetScopeEntitlementStore(
      productIDs: NetScopeStoreProductIdentifiers()
    )

    let result = await store.purchase(productID: "missing")

    #expect(result == .productUnavailable)
    #expect(!store.isPurchasing)
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
