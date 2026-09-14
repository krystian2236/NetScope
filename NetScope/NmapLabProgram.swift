import Foundation

enum NmapLabProgram {
  static let definition = makeDefinition()

  private static func makeDefinition() -> LabProgram {
    let catalog = NmapCatalog.definition
    let lessons: [String: [LabMission]] = [
      "discovery": [mission(
        id: "nmap-discovery",
        title: "Odkrywanie hostów",
        summary: "Znajdź urządzenia bez skanowania portów.",
        intent: .discover(cidr: "192.168.50.0/24")
      )],
      "scan": [mission(
        id: "nmap-connect-scan",
        title: "Skan TCP Connect",
        summary: "Sprawdź porty 22 i 80 bez surowych pakietów.",
        intent: .inspect(host: "192.168.50.20", ports: [22, 80], versions: false)
      )],
      "service": [mission(
        id: "nmap-service-detection",
        title: "Rozpoznawanie usług",
        summary: "Połącz wybór portów z wykrywaniem wersji.",
        intent: .inspect(host: "192.168.50.20", ports: [22, 80], versions: true)
      )],
      "output": [mission(
        id: "nmap-readable-results",
        title: "Czytelny wynik diagnostyczny",
        summary: "Pokaż tylko otwarte porty i powód ich stanu.",
        intent: .nmapDiagnostic(host: "192.168.50.10")
      )],
    ]

    return LabProgram(
      id: .nmap,
      title: "Nmap",
      summary: "Od rozpoznania hostów do świadomej interpretacji usług i wyników.",
      icon: "dot.radiowaves.left.and.right",
      modules: catalog.categories.map { category in
        LabModule(
          id: category.id,
          title: category.title,
          summary: category.subtitle,
          access: .pro,
          lessons: lessons[category.id] ?? [],
          coverage: catalog.options
            .filter { $0.categoryID == category.id }
            .map { .init(optionID: $0.id, kind: coverageKind(for: $0)) }
        )
      }
    )
  }

  private static func coverageKind(for option: ToolOptionDefinition) -> LabLessonCoverage.Kind {
    switch option.risk {
    case .standard: .exercise
    case .caution: .diagnostic
    case .advanced(let reason): .explanationOnly(reason)
    }
  }

  private static func mission(
    id: String,
    title: String,
    summary: String,
    intent: LabCommandIntent
  ) -> LabMission {
    LabMission(
      id: id,
      title: title,
      summary: summary,
      isPro: true,
      steps: [
        LabStep(
          id: "command",
          objective: summary,
          hints: ["Zacznij od narzędzia nmap.", "Dobierz typ skanu, opcje i cel w sieci demonstracyjnej."],
          acceptedIntent: intent,
          explanation: "Polecenie działa wyłącznie na deterministycznym modelu sieci NetScope."
        )
      ]
    )
  }
}
