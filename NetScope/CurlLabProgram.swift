import Foundation

enum CurlLabProgram {
  static let definition = LabProgram(
    id: .curl,
    title: "Curl",
    summary: "Budowanie i interpretacja bezpiecznych żądań HTTP w lokalnym laboratorium.",
    icon: "arrow.left.arrow.right",
    modules: [
      module("target", "Cel", "Lokalny adres URL.", .curl(method: "GET", url: "http://web.lab", headers: [], body: nil, head: false, follow: false, timeout: nil)),
      module("method", "Metoda", "Jawny wybór metody HTTP.", .curl(method: "POST", url: "http://api.lab/devices", headers: [], body: nil, head: false, follow: false, timeout: nil)),
      module("headers", "Nagłówki", "Nagłówki bez ujawniania sekretów.", .curl(method: "GET", url: "http://api.lab/profile", headers: ["Accept: application/json"], body: nil, head: false, follow: false, timeout: nil)),
      module("body", "Ciało", "Dane żądania POST.", .curl(method: "POST", url: "http://api.lab/devices", headers: ["Content-Type: application/json"], body: "{\"name\":\"lab\"}", head: false, follow: false, timeout: nil)),
      module("redirects", "Przekierowania", "Świadome użycie -L.", .curl(method: "GET", url: "http://web.lab/start", headers: [], body: nil, head: false, follow: true, timeout: nil)),
      module("tls", "TLS", "Schemat HTTPS w bezpiecznym demo.", .curl(method: "GET", url: "https://web.lab", headers: [], body: nil, head: false, follow: false, timeout: nil)),
      module("timeout", "Limit czasu", "Ograniczenie czasu operacji.", .curl(method: "GET", url: "http://web.lab", headers: [], body: nil, head: false, follow: false, timeout: 5)),
      module("response", "Odpowiedź", "Same nagłówki przez -I.", .curl(method: "HEAD", url: "http://web.lab", headers: [], body: nil, head: true, follow: false, timeout: nil)),
    ]
  )

  private static func module(_ id: String, _ title: String, _ summary: String, _ intent: LabCommandIntent) -> LabModule {
    LabModule(
      id: id,
      title: title,
      summary: summary,
      access: .pro,
      lessons: [LabMission(
        id: "curl-\(id)",
        title: title,
        summary: summary,
        isPro: true,
        steps: [LabStep(
          id: "request",
          objective: "Zbuduj żądanie zgodne z opisem lekcji.",
          hints: ["Zacznij od curl.", "Dobierz metodę, opcje i lokalny cel."],
          acceptedIntent: intent,
          explanation: "Żądanie jest oceniane lokalnie i nie opuszcza wirtualnego laboratorium."
        )]
      )],
      coverage: []
    )
  }
}
