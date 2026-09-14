import Foundation

enum DigCatalog {
  static let definition = ToolDefinition(
    id: "dig",
    executable: "dig",
    title: "Dig",
    helpVersion: "BIND 9.20",
    reviewedAt: "2026-09-13",
    usageParts: [
      .literal("dig"),
      .section(.init(id: "server", label: "[@server]", categoryIDs: ["server"], tone: .auxiliary)),
      .section(.init(id: "name", label: "{name}", categoryIDs: ["name"], tone: .target)),
      .section(.init(id: "type", label: "[type]", categoryIDs: ["type"], tone: .options)),
      .section(.init(id: "options", label: "[options]", categoryIDs: ["query", "output", "behavior"], tone: .options)),
    ],
    categories: [
      c("server", "Serwer DNS", "Resolver, do którego trafi zapytanie", "server.rack"),
      c("name", "Nazwa", "Domena lub adres do sprawdzenia", "scope"),
      c("type", "Typ rekordu", "Rodzaj informacji DNS", "list.bullet.rectangle"),
      c("query", "Zapytanie", "Klasa, port, pliki i odwrócone DNS", "questionmark.circle"),
      c("output", "Wynik", "Zakres i format wyświetlanych danych", "text.alignleft"),
      c("behavior", "Transport i zachowanie", "TCP, DNSSEC, timeouty i śledzenie", "gearshape.2"),
    ],
    options: featured(options)
  )

  private static let fileRisk: ToolRiskLevel = .caution(reason: "Opcja odczytuje plik z urządzenia uruchamiającego Dig.")
  private static let externalRisk: ToolRiskLevel = .caution(reason: "Zapytanie trafia do wybranego serwera DNS. Używaj serwera, któremu ufasz.")
  private static let traceRisk: ToolRiskLevel = .caution(reason: "Śledzenie odpytuje kolejne serwery DNS i ujawnia im nazwę zapytania.")
  private static let privacyRisk: ToolRiskLevel = .advanced(reason: "Ta opcja może ujawnić fragment adresu klienta serwerom DNS. Używaj tylko świadomie.")

  private static let options: [ToolOptionDefinition] = [
    v("server", "server", ["@"], "Serwer", "Kieruje zapytanie do konkretnego resolvera.", .text(example: "192.168.1.1"), 10, externalRisk, .attached, .beforeTarget),
    v("target", "name", [], "Nazwa", "Wskazuje domenę lub adres do sprawdzenia.", .text(example: "web.lab"), 20, .standard, .positional, .target),
    v("record-type", "type", [], "Typ rekordu", "Wybiera typ odpowiedzi DNS.", .choice(values: ["A", "AAAA", "PTR", "MX", "TXT", "NS", "SOA", "SRV", "CAA", "ANY"], example: "A"), 30, .standard, .positional),

    v("port", "query", ["-p"], "Port serwera", "Łączy się z DNS na wskazanym porcie.", .integer(range: 1...65_535, example: "53"), 100),
    v("source", "query", ["-b"], "Adres źródłowy", "Wybiera lokalny adres i opcjonalny port źródłowy.", .text(example: "192.168.1.20#5300"), 110, externalRisk),
    v("query-file", "query", ["-f"], "Plik zapytań", "Czyta nazwy do sprawdzenia z pliku.", .path(example: "names.txt"), 120, fileRisk),
    v("class", "query", ["-c"], "Klasa DNS", "Wybiera klasę rekordu.", .choice(values: ["IN", "CH", "HS", "ANY"], example: "IN"), 130),
    v("reverse", "query", ["-x"], "Odwrócony DNS", "Tworzy zapytanie PTR dla adresu IP.", .text(example: "192.168.1.1"), 140),
    v("tsig-key", "query", ["-k"], "Klucz TSIG", "Wczytuje klucz do podpisania zapytania.", .secret(example: "keyfile"), 150, fileRisk),
    v("tsig", "query", ["-y"], "Sekret TSIG", "Podaje nazwę, algorytm i sekret TSIG w poleceniu.", .secret(example: "name:secret"), 160, .advanced(reason: "Sekret będzie elementem polecenia. Nie wklejaj go do historii ani zrzutów ekranu.")),

    f("short", "output", ["+short"], "Krótki wynik", "Pokazuje tylko najważniejszą wartość odpowiedzi.", 200),
    f("answer", "output", ["+answer"], "Sekcja odpowiedzi", "Pokazuje sekcję Answer.", 210),
    f("authority", "output", ["+authority"], "Sekcja autorytetu", "Pokazuje sekcję Authority.", 220),
    f("additional", "output", ["+additional"], "Sekcja dodatkowa", "Pokazuje sekcję Additional.", 230),
    f("comments", "output", ["+comments"], "Komentarze", "Pokazuje komentarze i nagłówki odpowiedzi.", 240),
    f("stats", "output", ["+stats"], "Statystyki", "Pokazuje czas i parametry zapytania.", 250),
    f("multiline", "output", ["+multiline"], "Wiele wierszy", "Formatuje rekordy w czytelnych wierszach.", 260),
    f("ttlunits", "output", ["+ttlunits"], "Czytelny TTL", "Pokazuje TTL z jednostkami czasu.", 270),
    f("yaml", "output", ["+yaml"], "Format YAML", "Zwraca wynik w formacie YAML.", 280),
    f("noall", "output", ["+noall"], "Ukryj sekcje", "Wyłącza domyślne sekcje przed wybraniem potrzebnych.", 290),

    f("tcp", "behavior", ["+tcp"], "Użyj TCP", "Wysyła zapytanie DNS przez TCP.", 300),
    f("dnssec", "behavior", ["+dnssec"], "Żądaj DNSSEC", "Ustawia bit DO i prosi o rekordy DNSSEC.", 310),
    f("recurse", "behavior", ["+recurse"], "Rekurencja", "Prosi serwer o wykonanie zapytania rekurencyjnego.", 320),
    f("norecurse", "behavior", ["+norecurse"], "Bez rekurencji", "Wyłącza żądanie rekursji.", 330),
    f("search", "behavior", ["+search"], "Lista wyszukiwania", "Stosuje domeny z systemowej listy wyszukiwania.", 340),
    f("trace", "behavior", ["+trace"], "Śledź delegacje", "Śledzi drogę od serwerów root do odpowiedzi.", 350, traceRisk),
    v("timeout", "behavior", ["+timeout"], "Limit czasu", "Ustawia liczbę sekund oczekiwania.", .integer(range: 1...300, example: "5"), 360, .standard, .equals),
    v("retry", "behavior", ["+retry"], "Ponowienia", "Ustawia liczbę ponownych prób UDP.", .integer(range: 0...20, example: "2"), 370, .standard, .equals),
    v("edns", "behavior", ["+edns"], "Wersja EDNS", "Wybiera wersję rozszerzeń EDNS.", .integer(range: 0...255, example: "0"), 380, .standard, .equals),
    f("cookie", "behavior", ["+cookie"], "DNS Cookie", "Dodaje opcję DNS Cookie.", 390),
    v("subnet", "behavior", ["+subnet"], "Client subnet", "Dodaje EDNS Client Subnet.", .text(example: "192.168.1.0/24"), 400, privacyRisk, .equals),
    f("version", "behavior", ["-v"], "Wersja", "Wyświetla wersję Dig.", 410),
    f("help", "behavior", ["-h"], "Pomoc", "Wyświetla skróconą pomoc programu.", 420),
  ]

  private static let featuredIDs: Set<String> = ["server", "target", "record-type", "short", "tcp", "dnssec", "timeout", "retry"]

  private static func featured(_ options: [ToolOptionDefinition]) -> [ToolOptionDefinition] {
    options.map { item in
      var item = item
      item.isFeatured = featuredIDs.contains(item.id)
      return item
    }
  }

  private static func c(_ id: String, _ title: String, _ subtitle: String, _ icon: String) -> ToolCategoryDefinition {
    .init(id: id, title: title, subtitle: subtitle, icon: icon)
  }

  private static func f(_ id: String, _ category: String, _ flags: [String], _ title: String, _ summary: String, _ order: Int, _ risk: ToolRiskLevel = .standard) -> ToolOptionDefinition {
    .init(id: id, categoryID: category, flags: flags, title: title, summary: summary, valueKind: .none, risk: risk, order: order, argumentPhase: .afterTarget)
  }

  private static func v(_ id: String, _ category: String, _ flags: [String], _ title: String, _ summary: String, _ kind: ToolValueKind, _ order: Int, _ risk: ToolRiskLevel = .standard, _ placement: ToolValuePlacement = .separated, _ phase: ToolArgumentPhase = .afterTarget) -> ToolOptionDefinition {
    .init(id: id, categoryID: category, flags: flags, title: title, summary: summary, valueKind: kind, valuePlacement: placement, risk: risk, order: order, argumentPhase: phase)
  }
}
