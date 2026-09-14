import Foundation

enum DigLabProgram {
  static let definition = LabProgram(
    id: .dig,
    title: "Dig",
    summary: "Zapytania DNS, wybór serwera i świadoma interpretacja odpowiedzi.",
    icon: "network",
    modules: [
      LabModule(
        id: "records",
        title: "Rekordy DNS",
        summary: "A, AAAA, PTR, MX, TXT i NS w lokalnej strefie demo.",
        access: .pro,
        lessons: [
          mission("dig-a", "Adres IPv4", .dig(name: "web.lab", type: "A", server: nil, short: false)),
          mission("dig-aaaa", "Adres IPv6", .dig(name: "web.lab", type: "AAAA", server: nil, short: false)),
          mission("dig-ptr", "Reverse DNS", .dig(name: "192.168.50.20", type: "PTR", server: nil, short: false), command: "dig -x 192.168.50.20"),
          mission("dig-mx", "Serwer poczty", .dig(name: "web.lab", type: "MX", server: nil, short: false)),
          mission("dig-txt", "Rekord tekstowy", .dig(name: "web.lab", type: "TXT", server: nil, short: false)),
          mission("dig-ns", "Serwer nazw", .dig(name: "web.lab", type: "NS", server: nil, short: false)),
        ],
        coverage: []
      ),
      LabModule(
        id: "server",
        title: "Wybór serwera",
        summary: "Jawne kierowanie zapytania do serwera DNS w laboratorium.",
        access: .pro,
        lessons: [mission("dig-server", "Zapytaj router.lab", .dig(name: "web.lab", type: "A", server: "router.lab", short: false))],
        coverage: []
      ),
      LabModule(
        id: "output",
        title: "Format odpowiedzi",
        summary: "Krótki wynik przydatny w skryptach i diagnostyce.",
        access: .pro,
        lessons: [mission("dig-short", "Tylko wartość", .dig(name: "web.lab", type: "A", server: nil, short: true))],
        coverage: []
      ),
      LabModule(
        id: "troubleshooting",
        title: "Diagnostyka",
        summary: "Rozpoznawanie odpowiedzi NXDOMAIN bez wykonywania zapytań zewnętrznych.",
        access: .pro,
        lessons: [mission("dig-nxdomain", "Nieistniejąca nazwa", .dig(name: "missing.lab", type: "A", server: nil, short: false), expectsFailure: true)],
        coverage: []
      ),
    ]
  )

  private static func mission(
    _ id: String,
    _ title: String,
    _ intent: LabCommandIntent,
    command: String? = nil,
    expectsFailure: Bool = false
  ) -> LabMission {
    let presentation = LabCommandPresentation(intent: intent)
    return LabMission(
      id: id,
      title: title,
      summary: "Wykonaj i zinterpretuj zapytanie DNS w sieci demonstracyjnej.",
      isPro: true,
      steps: [
        LabStep(
          id: "query",
          objective: "Użyj polecenia: \(command ?? presentation.command)",
          hints: ["Zacznij od dig.", "Dobierz nazwę, typ rekordu oraz opcjonalny serwer."],
          acceptedIntent: intent,
          explanation: "Wynik pochodzi wyłącznie z deterministycznej strefy DNS NetScope.",
          expectsFailure: expectsFailure
        ),
      ]
    )
  }
}
