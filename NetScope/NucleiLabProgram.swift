import Foundation

enum NucleiLabProgram {
  static let definition = makeDefinition()

  private static func makeDefinition() -> LabProgram {
    let catalog = NucleiCatalog.definition
    let templateMission = LabMission(
      id: "nuclei-template-scan",
      title: "Kontrola konfiguracji WWW",
      summary: "Uruchom bezpieczny zestaw szablonów na wirtualnym serwerze.",
      isPro: true,
      steps: [
        LabStep(
          id: "misconfiguration",
          objective: "Sprawdź web.lab szablonami z tagiem misconfiguration.",
          hints: ["Cel podaje opcja -u.", "Filtr szablonów według tagu podaje -tags."],
          acceptedIntent: .nuclei(target: "http://web.lab", tags: ["misconfiguration"]),
          explanation: "Nuclei dopasowuje szablony do celu; tutaj odpowiedzi pochodzą wyłącznie z sieci demo."
        )
      ]
    )

    return LabProgram(
      id: .nuclei,
      title: "Nuclei",
      summary: "Nauka selekcji celów, szablonów i bezpiecznej interpretacji wyników.",
      icon: "checkmark.shield",
      modules: catalog.categories.map { category in
        LabModule(
          id: category.id,
          title: category.title,
          summary: category.subtitle,
          access: .pro,
          lessons: category.id == "filtering" ? [templateMission] : [],
          coverage: catalog.options
            .filter { $0.categoryID == category.id }
            .map { .init(optionID: $0.id, kind: coverageKind(for: $0)) }
        )
      }
    )
  }

  private static func coverageKind(for option: ToolOptionDefinition) -> LabLessonCoverage.Kind {
    if option.isSecret {
      return .explanationOnly("Wartości sekretne omawiamy bez zapisywania i wyświetlania ich w laboratorium.")
    }
    return switch option.risk {
    case .standard: .exercise
    case .caution: .diagnostic
    case .advanced(let reason): .explanationOnly(reason)
    }
  }
}
