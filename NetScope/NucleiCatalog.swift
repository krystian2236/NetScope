import Foundation

enum NucleiCatalog {
  static let definition = ToolDefinition(
    id: "nuclei",
    executable: "nuclei",
    title: "Nuclei",
    helpVersion: "3.11.1",
    reviewedAt: "2026-09-12",
    usageParts: [
      .literal("nuclei"),
      .category(label: "[Options]", categoryID: "common"),
      .category(label: "{target}", categoryID: "target"),
    ],
    categories: categories,
    options: options
  )

  private static let categories: [ToolCategoryDefinition] = [
    c("common", "Podstawowe", "Ogólne ograniczenia działania", "slider.horizontal.3"),
    c("target", "Cel", "Adresy, listy i wersje IP", "scope"),
    c("target-format", "Format celu", "Sposób interpretacji danych wejściowych", "doc.text"),
    c("templates", "Szablony", "Wybór, kontrola i źródła szablonów", "doc.badge.gearshape"),
    c("filtering", "Filtrowanie", "Autor, tag, identyfikator, poziom i protokół", "line.3.horizontal.decrease.circle"),
    c("output", "Wyniki", "Format, zapis i eksport rezultatów", "square.and.arrow.down"),
    c("configurations", "Konfiguracja", "Przekierowania, DNS, TLS i sieć", "gearshape.2"),
    c("interactsh", "Interactsh", "Zewnętrzne interakcje OAST", "antenna.radiowaves.left.and.right"),
    c("fuzzing", "Fuzzing i DAST", "Aktywne testy parametrów aplikacji", "waveform.path.ecg"),
    c("uncover", "Uncover", "Wyszukiwanie celów w usługach zewnętrznych", "globe"),
    c("rate-limit", "Limity ruchu", "Szybkość i współbieżność", "speedometer"),
    c("optimizations", "Optymalizacja", "Timeouty, ponowienia i strategia", "gauge.with.dots.needle.67percent"),
    c("headless", "Przeglądarka", "Szablony wymagające przeglądarki", "macwindow"),
    c("debug", "Diagnostyka", "Śledzenie żądań i stanu", "ladybug"),
    c("update", "Aktualizacje", "Aktualizacja lokalnych szablonów", "arrow.triangle.2.circlepath"),
    c("honeypot", "Honeypot", "Wykrywanie możliwych pułapek", "shield.lefthalf.filled"),
    c("statistics", "Statystyki", "Postęp, metryki i statusy HTTP", "chart.bar"),
    c("cloud", "Chmura", "ProjectDiscovery Cloud Platform", "cloud"),
    c("authentication", "Uwierzytelnianie", "Pliki sekretów dla skanów autoryzowanych", "key"),
  ]

  private static let scanRisk: ToolRiskLevel = .advanced(
    reason: "Ta funkcja może generować aktywny ruch testowy. Używaj wyłącznie na własnym celu lub za zgodą właściciela."
  )
  private static let externalRisk: ToolRiskLevel = .advanced(
    reason: "Ta funkcja kontaktuje się z usługą zewnętrzną i może przekazać jej dane celu."
  )
  private static let secretRisk: ToolRiskLevel = .advanced(
    reason: "Ta opcja używa danych uwierzytelniających. Northbyte Radar nie zapisuje wpisanej wartości."
  )
  private static let trafficRisk: ToolRiskLevel = .caution(
    reason: "Ta opcja może zwiększyć ruch, czas pracy albo obciążenie celu."
  )
  private static let fileRisk: ToolRiskLevel = .caution(
    reason: "Ta opcja czyta lub zapisuje plik na urządzeniu wykonującym polecenie."
  )
  private static let updateRisk: ToolRiskLevel = .caution(
    reason: "Ta opcja modyfikuje lokalne dane lub konfigurację Nuclei."
  )

  private static let options: [ToolOptionDefinition] = [
    // COMMON
    v("max-time", "common", ["-mt", "-max-time"], "Maksymalny czas", "Kończy cały proces po wskazanym czasie.", .duration(example: "30m"), 10),

    // TARGET
    v("target", "target", ["-u", "-target"], "Pojedynczy cel", "Wskazuje adres URL lub host do kontroli.", .text(example: "https://example.com"), 100),
    v("list", "target", ["-l", "-list"], "Lista celów", "Czyta cele z pliku, po jednym w wierszu.", .path(example: "hosts.txt"), 110, fileRisk),
    v("targets-inline", "target", ["-targets-inline"], "Cele w tekście", "Przekazuje wielowierszową listę celów dla profilu.", .list(example: "host1,host2"), 120),
    v("exclude-hosts", "target", ["-eh", "-exclude-hosts"], "Wyklucz hosty", "Pomija wskazane adresy, nazwy lub sieci CIDR.", .list(example: "192.168.1.10"), 130),
    v("resume", "target", ["-resume"], "Wznów skan", "Wznawia skan na podstawie wskazanego pliku.", .path(example: "resume.cfg"), 140, fileRisk),
    f("scan-all-ips", "target", ["-sa", "-scan-all-ips"], "Wszystkie adresy DNS", "Skanuje wszystkie adresy IP przypisane do nazwy.", 150, trafficRisk),
    v("ip-version", "target", ["-iv", "-ip-version"], "Wersja IP", "Wybiera IPv4, IPv6 albo obie wersje.", .choice(values: ["4", "6"], example: "4"), 160),

    // TARGET FORMAT
    v("input-mode", "target-format", ["-im", "-input-mode"], "Tryb wejścia", "Określa format pliku wejściowego.", .choice(values: ["list", "burp", "jsonl", "yaml", "openapi", "swagger"], example: "list"), 200),
    f("required-only", "target-format", ["-ro", "-required-only"], "Tylko wymagane pola", "Generuje żądania jedynie z wymaganych pól.", 210),
    f("skip-format-validation", "target-format", ["-sfv", "-skip-format-validation"], "Pomiń walidację formatu", "Akceptuje wejście z brakującymi zmiennymi.", 220, trafficRisk),
    f("vars-text-templating", "target-format", ["-vtt", "-vars-text-templating"], "Szablony tekstowe zmiennych", "Włącza szablonowanie zmiennych dla YAML.", 230),
    v("var-file-paths", "target-format", ["-vfp", "-var-file-paths"], "Pliki zmiennych", "Wczytuje zmienne z plików YAML.", .list(example: "vars.yaml"), 240, fileRisk),

    // TEMPLATES
    f("new-templates", "templates", ["-nt", "-new-templates"], "Nowe szablony", "Uruchamia tylko szablony z najnowszego wydania.", 300),
    v("new-templates-version", "templates", ["-ntv", "-new-templates-version"], "Nowe od wersji", "Uruchamia szablony dodane w podanej wersji.", .list(example: "v10.2.0"), 310),
    f("automatic-scan", "templates", ["-as", "-automatic-scan"], "Skan automatyczny", "Dobiera tagi po rozpoznaniu technologii Wappalyzer.", 320, trafficRisk),
    v("templates", "templates", ["-t", "-templates"], "Szablony", "Wybiera pliki lub katalogi szablonów.", .list(example: "http/cves"), 330, fileRisk),
    v("template-url", "templates", ["-turl", "-template-url"], "URL szablonu", "Pobiera szablony z podanych adresów.", .list(example: "https://example.com/template.yaml"), 340, externalRisk),
    v("prompt", "templates", ["-ai", "-prompt"], "Szablon z AI", "Generuje i uruchamia szablon na podstawie polecenia.", .text(example: "sprawdź nagłówki bezpieczeństwa"), 350, scanRisk),
    v("workflows", "templates", ["-w", "-workflows"], "Workflow", "Wybiera pliki lub katalogi workflow.", .list(example: "workflows/http.yaml"), 360, fileRisk),
    v("workflow-url", "templates", ["-wurl", "-workflow-url"], "URL workflow", "Pobiera workflow z podanych adresów.", .list(example: "https://example.com/workflow.yaml"), 370, externalRisk),
    f("validate", "templates", ["-validate"], "Waliduj szablony", "Sprawdza poprawność przekazanych szablonów.", 380),
    f("no-strict-syntax", "templates", ["-nss", "-no-strict-syntax"], "Luźna składnia", "Wyłącza ścisłą kontrolę składni szablonów.", 390, trafficRisk),
    f("template-display", "templates", ["-td", "-template-display"], "Pokaż szablony", "Wyświetla treść wybranych szablonów.", 400),
    f("template-list", "templates", ["-tl"], "Lista szablonów", "Wyświetla szablony pasujące do filtrów.", 410),
    f("tag-list", "templates", ["-tgl"], "Lista tagów", "Wyświetla wszystkie dostępne tagi.", 420),
    f("sign", "templates", ["-sign"], "Podpisz szablony", "Podpisuje szablony kluczem ze zmiennej środowiskowej.", 430, secretRisk),
    f("code", "templates", ["-code"], "Szablony kodu", "Pozwala ładować szablony wykonujące protokół code.", 440, scanRisk),
    f("disable-unsigned-templates", "templates", ["-dut", "-disable-unsigned-templates"], "Tylko podpisane", "Pomija niepodpisane lub błędnie podpisane szablony.", 450),
    f("enable-self-contained", "templates", ["-esc", "-enable-self-contained"], "Szablony samodzielne", "Włącza samodzielne szablony.", 460, scanRisk),
    f("enable-global-matchers", "templates", ["-egm", "-enable-global-matchers"], "Globalne matchery", "Włącza globalne dopasowania szablonów.", 470, trafficRisk),
    f("file", "templates", ["-file"], "Szablony plikowe", "Pozwala szablonom analizować pliki.", 480, fileRisk),

    // FILTERING
    v("author", "filtering", ["-a", "-author"], "Autor", "Filtruje szablony według autora.", .list(example: "projectdiscovery"), 500),
    v("tags", "filtering", ["-tags"], "Tagi", "Uruchamia szablony o wybranych tagach.", .list(example: "ssl,http"), 510),
    v("exclude-tags", "filtering", ["-etags", "-exclude-tags"], "Wyklucz tagi", "Pomija szablony o wskazanych tagach.", .list(example: "dos,fuzz"), 520),
    v("include-tags", "filtering", ["-itags", "-include-tags"], "Dołącz tagi", "Włącza tagi mimo domyślnych wykluczeń.", .list(example: "http"), 530),
    v("template-id", "filtering", ["-id", "-template-id"], "ID szablonu", "Wybiera identyfikatory szablonów.", .list(example: "http-missing-security-headers"), 540),
    v("exclude-id", "filtering", ["-eid", "-exclude-id"], "Wyklucz ID", "Pomija wskazane identyfikatory szablonów.", .list(example: "template-id"), 550),
    v("include-templates", "filtering", ["-it", "-include-templates"], "Dołącz szablony", "Włącza wskazane pliki mimo wykluczeń.", .list(example: "custom.yaml"), 560, fileRisk),
    v("exclude-templates", "filtering", ["-et", "-exclude-templates"], "Wyklucz szablony", "Pomija wskazane pliki lub katalogi.", .list(example: "unsafe/"), 570, fileRisk),
    v("exclude-matchers", "filtering", ["-em", "-exclude-matchers"], "Wyklucz matchery", "Pomija wskazane dopasowania w wynikach.", .list(example: "matcher-name"), 580),
    v("severity", "filtering", ["-s", "-severity"], "Poziom ważności", "Filtruje według poziomu znaleziska.", .list(example: "low,medium,high"), 590),
    v("exclude-severity", "filtering", ["-es", "-exclude-severity"], "Wyklucz ważność", "Pomija wskazane poziomy znalezisk.", .list(example: "info,unknown"), 600),
    v("type", "filtering", ["-pt", "-type"], "Typ protokołu", "Wybiera typy protokołów szablonów.", .list(example: "http,ssl,dns"), 610),
    v("exclude-type", "filtering", ["-ept", "-exclude-type"], "Wyklucz typ", "Pomija wskazane typy protokołów.", .list(example: "headless,code"), 620),
    v("template-condition", "filtering", ["-tc", "-template-condition"], "Warunek szablonu", "Filtruje szablony wyrażeniem warunkowym.", .text(example: "contains(tags,'http')"), 630),

    // OUTPUT
    v("output", "output", ["-o", "-output"], "Plik wyników", "Zapisuje znalezione problemy do pliku.", .path(example: "nuclei.txt"), 700, fileRisk),
    f("store-resp", "output", ["-sresp", "-store-resp"], "Zapisz odpowiedzi", "Zapisuje kompletne żądania i odpowiedzi.", 710, fileRisk),
    v("store-resp-dir", "output", ["-srd", "-store-resp-dir"], "Katalog odpowiedzi", "Wybiera katalog zapisu żądań i odpowiedzi.", .path(example: "output"), 720, fileRisk),
    f("silent", "output", ["-silent"], "Tylko znaleziska", "Ukrywa zwykłe komunikaty programu.", 730),
    f("no-color", "output", ["-nc", "-no-color"], "Bez kolorów", "Wyłącza sekwencje kolorów ANSI.", 740),
    f("jsonl", "output", ["-j", "-jsonl"], "Format JSONL", "Zapisuje każdy wynik jako osobny obiekt JSON.", 750),
    f("include-rr", "output", ["-irr", "-include-rr"], "Dołącz ruch", "Dołącza pary żądanie–odpowiedź do wyników.", 760, fileRisk),
    f("omit-raw", "output", ["-or", "-omit-raw"], "Pomiń surowe dane", "Nie zapisuje surowych żądań i odpowiedzi.", 770),
    f("omit-template", "output", ["-ot", "-omit-template"], "Pomiń szablon", "Nie dołącza zakodowanego szablonu do JSON.", 780),
    f("no-meta", "output", ["-nm", "-no-meta"], "Bez metadanych", "Ukrywa metadane wyników.", 790),
    f("timestamp", "output", ["-ts", "-timestamp"], "Znacznik czasu", "Dodaje czas do wyników.", 800),
    v("report-db", "output", ["-rdb", "-report-db"], "Baza raportów", "Utrwala dane raportowe w bazie.", .path(example: "reports.db"), 810, fileRisk),
    f("matcher-status", "output", ["-ms", "-matcher-status"], "Status matcherów", "Pokazuje także nieudane dopasowania.", 820),
    v("markdown-export", "output", ["-me", "-markdown-export"], "Eksport Markdown", "Eksportuje wyniki do katalogu Markdown.", .path(example: "report-md"), 830, fileRisk),
    v("sarif-export", "output", ["-se", "-sarif-export"], "Eksport SARIF", "Eksportuje wyniki w formacie SARIF.", .path(example: "report.sarif"), 840, fileRisk),
    v("json-export", "output", ["-je", "-json-export"], "Eksport JSON", "Eksportuje wyniki do pliku JSON.", .path(example: "report.json"), 850, fileRisk),
    v("jsonl-export", "output", ["-jle", "-jsonl-export"], "Eksport JSONL", "Eksportuje wyniki do pliku JSONL.", .path(example: "report.jsonl"), 860, fileRisk),
    v("pdf-export", "output", ["-pe", "-pdf-export"], "Eksport PDF", "Eksportuje wyniki do pliku PDF.", .path(example: "report.pdf"), 870, fileRisk),
    v("redact", "output", ["-rd", "-redact"], "Redaguj dane", "Usuwa wskazane klucze z nagłówków, parametrów i treści.", .list(example: "authorization,cookie"), 880),

    // CONFIGURATIONS
    v("config", "configurations", ["-config"], "Plik konfiguracji", "Wczytuje konfigurację Nuclei.", .path(example: "config.yaml"), 900, fileRisk),
    v("profile", "configurations", ["-tp", "-profile"], "Profil szablonów", "Wczytuje profil wyboru szablonów.", .path(example: "profile.yaml"), 910, fileRisk),
    f("profile-list", "configurations", ["-tpl", "-profile-list"], "Lista profili", "Wyświetla profile społeczności.", 920),
    f("follow-redirects", "configurations", ["-fr", "-follow-redirects"], "Śledź przekierowania", "Śledzi przekierowania HTTP między hostami.", 930, trafficRisk, ["disable-redirects"]),
    f("follow-host-redirects", "configurations", ["-fhr", "-follow-host-redirects"], "Przekierowania hosta", "Śledzi przekierowania tylko w obrębie hosta.", 940),
    v("max-redirects", "configurations", ["-mr", "-max-redirects"], "Limit przekierowań", "Ogranicza liczbę przekierowań.", .integer(range: 0...100, example: "10"), 950),
    f("disable-redirects", "configurations", ["-dr", "-disable-redirects"], "Wyłącz przekierowania", "Nie podąża za przekierowaniami HTTP.", 960, .standard, ["follow-redirects"]),
    v("report-config", "configurations", ["-rc", "-report-config"], "Konfiguracja raportów", "Wczytuje ustawienia modułu raportowego.", .path(example: "reporting.yaml"), 970, fileRisk),
    v("header", "configurations", ["-H", "-header"], "Nagłówek HTTP", "Dodaje własny nagłówek lub ciasteczko do żądań.", .secret(example: "Header: value"), 980, secretRisk),
    v("var", "configurations", ["-V", "-var"], "Zmienna", "Ustawia zmienną w formacie nazwa=wartość.", .text(example: "name=value"), 990),
    v("resolvers", "configurations", ["-r", "-resolvers"], "Lista resolverów", "Wczytuje serwery DNS z pliku.", .path(example: "resolvers.txt"), 1000, fileRisk),
    f("system-resolvers", "configurations", ["-sr", "-system-resolvers"], "Systemowy DNS", "Używa systemowego DNS jako zapasowego.", 1010),
    f("disable-clustering", "configurations", ["-dc", "-disable-clustering"], "Bez grupowania", "Wyłącza grupowanie podobnych żądań.", 1020, trafficRisk),
    f("passive", "configurations", ["-passive"], "Tryb pasywny", "Przetwarza dostarczone odpowiedzi HTTP bez aktywnego pobierania.", 1030),
    f("force-http2", "configurations", ["-fh2", "-force-http2"], "Wymuś HTTP/2", "Wymusza połączenia HTTP/2.", 1040),
    f("env-vars", "configurations", ["-ev", "-env-vars"], "Zmienne środowiskowe", "Udostępnia zmienne środowiskowe szablonom.", 1050, secretRisk),
    v("client-cert", "configurations", ["-cc", "-client-cert"], "Certyfikat klienta", "Wczytuje certyfikat klienta PEM.", .path(example: "client.crt"), 1060, secretRisk),
    v("client-key", "configurations", ["-ck", "-client-key"], "Klucz klienta", "Wczytuje prywatny klucz klienta PEM.", .secret(example: "client.key"), 1070, secretRisk),
    v("client-ca", "configurations", ["-ca", "-client-ca"], "CA klienta", "Wczytuje urząd certyfikacji klienta.", .path(example: "ca.crt"), 1080, fileRisk),
    f("show-match-line", "configurations", ["-sml", "-show-match-line"], "Pokaż pasujący wiersz", "Pokazuje wiersze znalezione przez ekstraktory plikowe.", 1090),
    f("ztls", "configurations", ["-ztls"], "Biblioteka ztls", "Włącza przestarzały przełącznik ztls.", 1100, trafficRisk),
    v("sni", "configurations", ["-sni"], "Nazwa SNI", "Ustawia nazwę hosta dla TLS SNI.", .text(example: "example.com"), 1110),
    v("dialer-keep-alive", "configurations", ["-dka", "-dialer-keep-alive"], "Keep-alive", "Ustawia czas utrzymania połączeń sieciowych.", .duration(example: "30s"), 1120),
    f("allow-local-file-access", "configurations", ["-lfa", "-allow-local-file-access"], "Dostęp do plików lokalnych", "Pozwala szablonom czytać pliki z całego systemu.", 1130, scanRisk),
    f("restrict-local-network-access", "configurations", ["-lna", "-restrict-local-network-access"], "Blokuj sieć lokalną", "Blokuje połączenia z adresami prywatnymi.", 1140),
    v("interface", "configurations", ["-i", "-interface"], "Interfejs sieciowy", "Wybiera interfejs dla skanu sieciowego.", .text(example: "en0"), 1150, trafficRisk),
    v("attack-type", "configurations", ["-at", "-attack-type"], "Typ kombinacji", "Wybiera sposób łączenia payloadów.", .choice(values: ["batteringram", "pitchfork", "clusterbomb"], example: "batteringram"), 1160, scanRisk),
    v("source-ip", "configurations", ["-sip", "-source-ip"], "Adres źródłowy", "Wybiera źródłowy adres IP.", .text(example: "192.168.1.20"), 1170, trafficRisk),
    v("response-size-read", "configurations", ["-rsr", "-response-size-read"], "Limit odczytu", "Ogranicza rozmiar odczytanej odpowiedzi.", .integer(range: 1...100_000_000, example: "1048576"), 1180),
    v("response-size-save", "configurations", ["-rss", "-response-size-save"], "Limit zapisu", "Ogranicza rozmiar zapisanej odpowiedzi.", .integer(range: 1...100_000_000, example: "1048576"), 1190),
    f("reset", "configurations", ["-reset"], "Reset danych", "Usuwa konfigurację i dane Nuclei wraz z szablonami.", 1200, updateRisk),
    f("tls-impersonate", "configurations", ["-tlsi", "-tls-impersonate"], "Losowy TLS ClientHello", "Eksperymentalnie zmienia odcisk TLS klienta.", 1210, scanRisk),
    v("http-api-endpoint", "configurations", ["-hae", "-http-api-endpoint"], "HTTP API", "Uruchamia eksperymentalny punkt API.", .text(example: "127.0.0.1:9090"), 1220, scanRisk),

    // INTERACTSH
    v("interactsh-server", "interactsh", ["-iserver", "-interactsh-server"], "Serwer Interactsh", "Wybiera serwer OAST.", .text(example: "https://oast.example"), 1300, externalRisk),
    v("interactsh-token", "interactsh", ["-itoken", "-interactsh-token"], "Token Interactsh", "Uwierzytelnia własny serwer Interactsh.", .secret(example: "token"), 1310, secretRisk),
    v("interactions-cache-size", "interactsh", ["-interactions-cache-size"], "Pamięć interakcji", "Ustala liczbę interakcji przechowywanych w pamięci.", .integer(range: 1...100_000, example: "5000"), 1320, externalRisk),
    v("interactions-eviction", "interactsh", ["-interactions-eviction"], "Usuwanie interakcji", "Ustala czas przechowywania interakcji w sekundach.", .integer(range: 1...86_400, example: "60"), 1330, externalRisk),
    v("interactions-poll-duration", "interactsh", ["-interactions-poll-duration"], "Częstotliwość odpytywania", "Ustala odstęp odpytywania Interactsh.", .integer(range: 1...3600, example: "5"), 1340, externalRisk),
    v("interactions-cooldown-period", "interactsh", ["-interactions-cooldown-period"], "Okres końcowy", "Ustala dodatkowy czas oczekiwania na interakcje.", .integer(range: 1...3600, example: "5"), 1350, externalRisk),
    f("no-interactsh", "interactsh", ["-ni", "-no-interactsh"], "Bez Interactsh", "Wyłącza OAST i zależne od niego szablony.", 1360),

    // FUZZING
    v("fuzzing-type", "fuzzing", ["-ft", "-fuzzing-type"], "Typ fuzzingu", "Wybiera modyfikację wartości parametru.", .choice(values: ["replace", "prefix", "postfix", "infix"], example: "replace"), 1400, scanRisk),
    v("fuzzing-mode", "fuzzing", ["-fm", "-fuzzing-mode"], "Tryb fuzzingu", "Wybiera pojedyncze lub wielokrotne parametry.", .choice(values: ["multiple", "single"], example: "single"), 1410, scanRisk),
    f("fuzz", "fuzzing", ["-fuzz"], "Stary tryb fuzz", "Włącza przestarzałe szablony fuzzingu.", 1420, scanRisk),
    f("dast", "fuzzing", ["-dast"], "DAST", "Uruchamia aktywne szablony fuzzingu DAST.", 1430, scanRisk),
    f("dast-server", "fuzzing", ["-dts", "-dast-server"], "Serwer DAST", "Uruchamia serwer do aktywnego fuzzingu.", 1440, scanRisk),
    f("dast-report", "fuzzing", ["-dtr", "-dast-report"], "Raport DAST", "Zapisuje raport aktywnego skanu.", 1450, fileRisk),
    v("dast-server-token", "fuzzing", ["-dtst", "-dast-server-token"], "Token serwera DAST", "Uwierzytelnia serwer DAST.", .secret(example: "token"), 1460, secretRisk),
    v("dast-server-address", "fuzzing", ["-dtsa", "-dast-server-address"], "Adres serwera DAST", "Ustawia adres nasłuchu serwera DAST.", .text(example: "localhost:9055"), 1470, scanRisk),
    f("display-fuzz-points", "fuzzing", ["-dfp", "-display-fuzz-points"], "Punkty fuzzingu", "Pokazuje miejsca modyfikowane przez fuzzer.", 1480),
    v("fuzz-param-frequency", "fuzzing", ["-fuzz-param-frequency"], "Częstotliwość parametru", "Pomija nieciekawe, często występujące parametry.", .integer(range: 1...10_000, example: "10"), 1490, scanRisk),
    v("fuzz-aggression", "fuzzing", ["-fa", "-fuzz-aggression"], "Agresywność fuzzingu", "Ustala liczbę payloadów.", .choice(values: ["low", "medium", "high"], example: "low"), 1500, scanRisk),
    v("fuzz-scope", "fuzzing", ["-cs", "-fuzz-scope"], "Zakres fuzzingu", "Ogranicza fuzzer wyrażeniem regularnym.", .list(example: "^https://example.com/"), 1510, scanRisk),
    v("fuzz-out-scope", "fuzzing", ["-cos", "-fuzz-out-scope"], "Poza zakresem", "Wyklucza adresy pasujące do wyrażenia.", .list(example: "/logout"), 1520, scanRisk),

    // UNCOVER
    f("uncover", "uncover", ["-uc", "-uncover"], "Włącz Uncover", "Wyszukuje cele przez zewnętrzne wyszukiwarki.", 1600, externalRisk),
    v("uncover-query", "uncover", ["-uq", "-uncover-query"], "Zapytanie Uncover", "Przekazuje zapytanie do wyszukiwarki.", .list(example: "port:443"), 1610, externalRisk),
    v("uncover-engine", "uncover", ["-ue", "-uncover-engine"], "Silnik Uncover", "Wybiera zewnętrzną wyszukiwarkę.", .list(example: "shodan"), 1620, externalRisk),
    v("uncover-field", "uncover", ["-uf", "-uncover-field"], "Pole wyniku", "Wybiera zwracane pole celu.", .choice(values: ["ip", "port", "host", "ip:port"], example: "ip:port"), 1630, externalRisk),
    v("uncover-limit", "uncover", ["-ul", "-uncover-limit"], "Limit wyników", "Ogranicza liczbę celów.", .integer(range: 1...10_000, example: "100"), 1640, externalRisk),
    v("uncover-ratelimit", "uncover", ["-ur", "-uncover-ratelimit"], "Limit Uncover", "Ogranicza zapytania na minutę.", .integer(range: 1...10_000, example: "60"), 1650, externalRisk),

    // RATE LIMIT
    v("rate-limit", "rate-limit", ["-rl", "-rate-limit"], "Żądania na sekundę", "Ogranicza liczbę żądań na sekundę.", .integer(range: 1...10_000, example: "50"), 1700),
    v("rate-limit-duration", "rate-limit", ["-rld", "-rate-limit-duration"], "Okno limitu", "Ustawia okres dla limitu żądań.", .duration(example: "1s"), 1710),
    f("per-host-rate-limit", "rate-limit", ["-per-host-rate-limit"], "Limit na host", "Stosuje limit osobno do każdego hosta.", 1720),
    v("rate-limit-minute", "rate-limit", ["-rlm", "-rate-limit-minute"], "Żądania na minutę", "Ustawia przestarzały limit minutowy.", .integer(range: 1...600_000, example: "600"), 1730),
    v("bulk-size", "rate-limit", ["-bs", "-bulk-size"], "Hosty równolegle", "Ustala liczbę hostów analizowanych równolegle.", .integer(range: 1...1000, example: "25"), 1740, trafficRisk),
    v("concurrency", "rate-limit", ["-c", "-concurrency"], "Szablony równolegle", "Ustala współbieżność szablonów.", .integer(range: 1...1000, example: "25"), 1750, trafficRisk),
    v("headless-bulk-size", "rate-limit", ["-hbs", "-headless-bulk-size"], "Hosty headless", "Ustala równoległość hostów dla przeglądarki.", .integer(range: 1...1000, example: "10"), 1760, trafficRisk),
    v("headless-concurrency", "rate-limit", ["-headc", "-headless-concurrency"], "Szablony headless", "Ustala współbieżność szablonów przeglądarkowych.", .integer(range: 1...1000, example: "10"), 1770, trafficRisk),
    v("js-concurrency", "rate-limit", ["-jsc", "-js-concurrency"], "Runtime JavaScript", "Ustala liczbę równoległych środowisk JavaScript.", .integer(range: 1...1000, example: "120"), 1780, trafficRisk),
    v("payload-concurrency", "rate-limit", ["-pc", "-payload-concurrency"], "Payloady równolegle", "Ustala współbieżność payloadów.", .integer(range: 1...1000, example: "25"), 1790, trafficRisk),
    v("probe-concurrency", "rate-limit", ["-prc", "-probe-concurrency"], "Sondy HTTP", "Ustala współbieżność sond httpx.", .integer(range: 1...1000, example: "50"), 1800, trafficRisk),
    v("template-loading-concurrency", "rate-limit", ["-tlc", "-template-loading-concurrency"], "Ładowanie szablonów", "Ustala współbieżność ładowania szablonów.", .integer(range: 1...1000, example: "50"), 1810, trafficRisk),

    // OPTIMIZATIONS
    v("timeout", "optimizations", ["-timeout"], "Timeout żądania", "Ustala czas oczekiwania na odpowiedź w sekundach.", .integer(range: 1...3600, example: "10"), 1900),
    v("retries", "optimizations", ["-retries"], "Ponowienia", "Ustala liczbę ponowień nieudanego żądania.", .integer(range: 0...20, example: "1"), 1910),
    f("leave-default-ports", "optimizations", ["-ldp", "-leave-default-ports"], "Zachowaj porty", "Nie usuwa domyślnych portów HTTP i HTTPS.", 1920),
    v("max-host-error", "optimizations", ["-mhe", "-max-host-error"], "Limit błędów hosta", "Pomija host po wskazanej liczbie błędów.", .integer(range: 1...10_000, example: "30"), 1930),
    v("track-error", "optimizations", ["-te", "-track-error"], "Śledzone błędy", "Dodaje typy błędów do limitu hosta.", .list(example: "timeout"), 1940),
    f("no-mhe", "optimizations", ["-nmhe", "-no-mhe"], "Bez limitu błędów", "Nie pomija hostów z wieloma błędami.", 1950, trafficRisk),
    f("project", "optimizations", ["-project"], "Tryb projektu", "Unika wielokrotnego wysyłania tych samych żądań.", 1960, fileRisk),
    v("project-path", "optimizations", ["-project-path"], "Ścieżka projektu", "Wybiera katalog danych projektu.", .path(example: "nuclei-project"), 1970, fileRisk),
    f("stop-at-first-match", "optimizations", ["-spm", "-stop-at-first-match"], "Pierwsze dopasowanie", "Kończy szablon po pierwszym dopasowaniu.", 1980),
    f("stream", "optimizations", ["-stream"], "Tryb strumieniowy", "Rozpoczyna pracę bez sortowania wejścia.", 1990),
    v("scan-strategy", "optimizations", ["-ss", "-scan-strategy"], "Strategia skanu", "Wybiera kolejność hostów i szablonów.", .choice(values: ["auto", "host-spray", "template-spray"], example: "auto"), 2000),
    v("input-read-timeout", "optimizations", ["-irt", "-input-read-timeout"], "Timeout wejścia", "Ogranicza czas oczekiwania na wejście.", .duration(example: "3m"), 2010),
    f("no-httpx", "optimizations", ["-nh", "-no-httpx"], "Bez sondy httpx", "Wyłącza wstępne sondowanie hostów bez URL.", 2020),
    f("preflight-portscan", "optimizations", ["-preflight-portscan"], "Wstępny skan portów", "Filtruje cele przez rozwiązanie nazw i skan TCP.", 2030, trafficRisk),
    f("no-stdin", "optimizations", ["-no-stdin"], "Bez standardowego wejścia", "Nie czyta celów ze standardowego wejścia.", 2040),

    // HEADLESS
    f("headless", "headless", ["-headless"], "Tryb przeglądarkowy", "Włącza szablony wymagające przeglądarki.", 2100, trafficRisk),
    v("page-timeout", "headless", ["-page-timeout"], "Timeout strony", "Ustala czas oczekiwania strony w sekundach.", .integer(range: 1...3600, example: "20"), 2110),
    f("show-browser", "headless", ["-sb", "-show-browser"], "Pokaż przeglądarkę", "Wyświetla okno przeglądarki podczas pracy.", 2120),
    v("headless-options", "headless", ["-ho", "-headless-options"], "Opcje przeglądarki", "Przekazuje dodatkowe ustawienia Chrome.", .list(example: "disable-gpu"), 2130, trafficRisk),
    f("system-chrome", "headless", ["-sc", "-system-chrome"], "Systemowy Chrome", "Używa lokalnej instalacji Chrome.", 2140),
    v("cdp-endpoint", "headless", ["-cdpe", "-cdp-endpoint"], "Punkt CDP", "Łączy się ze zdalnym Chrome DevTools Protocol.", .text(example: "http://127.0.0.1:9222"), 2150, externalRisk),
    f("list-headless-action", "headless", ["-lha", "-list-headless-action"], "Akcje headless", "Wyświetla dostępne akcje przeglądarkowe.", 2160),

    // DEBUG
    f("debug", "debug", ["-debug"], "Pełny debug", "Pokazuje wszystkie żądania i odpowiedzi.", 2200, fileRisk),
    f("debug-req", "debug", ["-dreq", "-debug-req"], "Debug żądań", "Pokazuje wysyłane żądania.", 2210, fileRisk),
    f("debug-resp", "debug", ["-dresp", "-debug-resp"], "Debug odpowiedzi", "Pokazuje otrzymane odpowiedzi.", 2220, fileRisk),
    v("proxy", "debug", ["-p", "-proxy"], "Proxy", "Kieruje ruch przez proxy HTTP lub SOCKS5.", .list(example: "http://127.0.0.1:8080"), 2230, trafficRisk),
    f("proxy-internal", "debug", ["-pi", "-proxy-internal"], "Proxy wewnętrzne", "Kieruje przez proxy również ruch wewnętrzny.", 2240, trafficRisk),
    f("list-dsl-function", "debug", ["-ldf", "-list-dsl-function"], "Funkcje DSL", "Wyświetla dostępne funkcje DSL.", 2250),
    v("trace-log", "debug", ["-tlog", "-trace-log"], "Log śledzenia", "Zapisuje ślad wysłanych żądań.", .path(example: "trace.log"), 2260, fileRisk),
    v("error-log", "debug", ["-elog", "-error-log"], "Log błędów", "Zapisuje błędy żądań.", .path(example: "errors.log"), 2270, fileRisk),
    f("version", "debug", ["-version"], "Wersja", "Wyświetla wersję Nuclei.", 2280),
    f("hang-monitor", "debug", ["-hm", "-hang-monitor"], "Monitor zawieszeń", "Włącza monitorowanie zatrzymania procesu.", 2290),
    f("verbose", "debug", ["-v", "-verbose"], "Więcej informacji", "Pokazuje rozszerzone komunikaty.", 2300),
    v("profile-mem", "debug", ["-profile-mem"], "Profil pamięci", "Zapisuje profil sterty i ślad pamięci.", .path(example: "memory-profile"), 2305, fileRisk),
    f("very-verbose", "debug", ["-vv"], "Załadowane szablony", "Pokazuje załadowane szablony.", 2310),
    f("show-var-dump", "debug", ["-svd", "-show-var-dump"], "Zrzut zmiennych", "Pokazuje wartości zmiennych diagnostycznych.", 2320, secretRisk),
    v("var-dump-limit", "debug", ["-vdl", "-var-dump-limit"], "Limit zrzutu", "Ogranicza długość zrzutu zmiennych.", .integer(range: 1...1_000_000, example: "255"), 2330),
    f("enable-pprof", "debug", ["-ep", "-enable-pprof"], "Profilowanie pprof", "Uruchamia diagnostyczny serwer pprof.", 2340, trafficRisk),
    f("templates-version", "debug", ["-tv", "-templates-version"], "Wersja szablonów", "Pokazuje wersję lokalnych szablonów.", 2350),
    f("health-check", "debug", ["-hc", "-health-check"], "Kontrola stanu", "Uruchamia diagnostykę instalacji.", 2360),

    // UPDATE
    f("update-templates", "update", ["-ut", "-update-templates"], "Aktualizuj szablony", "Pobiera najnowsze szablony.", 2400, updateRisk),
    v("update-template-dir", "update", ["-ud", "-update-template-dir"], "Katalog aktualizacji", "Wybiera katalog instalacji szablonów.", .path(example: "nuclei-templates"), 2410, updateRisk),
    f("disable-update-check", "update", ["-duc", "-disable-update-check"], "Bez sprawdzania aktualizacji", "Wyłącza automatyczne sprawdzanie wersji.", 2420),

    // HONEYPOT
    f("honeypot-detect", "honeypot", ["-hpd", "-honeypot-detect"], "Wykryj honeypot", "Szacuje pułapkę na podstawie liczby dopasowań.", 2500),
    v("honeypot-threshold", "honeypot", ["-hpt", "-honeypot-threshold"], "Próg honeypot", "Ustala liczbę różnych wyników dla oznaczenia.", .integer(range: 1...10_000, example: "15"), 2510),
    f("suppress-honeypot", "honeypot", ["-shp", "-suppress-honeypot"], "Ukryj honeypot", "Pomija wyniki hostów oznaczonych jako pułapka.", 2520),

    // STATISTICS
    f("stats", "statistics", ["-stats"], "Statystyki", "Pokazuje postęp skanu.", 2600),
    f("stats-json", "statistics", ["-sj", "-stats-json"], "Statystyki JSONL", "Pokazuje statystyki w formacie JSONL.", 2610),
    v("stats-interval", "statistics", ["-si", "-stats-interval"], "Interwał statystyk", "Ustala odstęp raportowania w sekundach.", .integer(range: 1...3600, example: "5"), 2620),
    v("metrics-port", "statistics", ["-mp", "-metrics-port"], "Port metryk", "Udostępnia metryki na lokalnym porcie.", .integer(range: 1...65_535, example: "9092"), 2630, trafficRisk),
    f("http-stats", "statistics", ["-hps", "-http-stats"], "Statusy HTTP", "Eksperymentalnie zbiera kody odpowiedzi HTTP.", 2640),

    // CLOUD
    f("auth", "cloud", ["-auth"], "Konfiguruj chmurę", "Konfiguruje uwierzytelnienie ProjectDiscovery Cloud.", 2700, secretRisk),
    v("team-id", "cloud", ["-tid", "-team-id"], "Zespół", "Wysyła wynik do wskazanego zespołu.", .text(example: "team-id"), 2710, externalRisk),
    f("cloud-upload", "cloud", ["-cup", "-cloud-upload"], "Wyślij do chmury", "Wysyła wyniki do pulpitu chmurowego.", 2720, externalRisk),
    v("scan-id", "cloud", ["-sid", "-scan-id"], "ID skanu", "Dołącza wyniki do istniejącego skanu.", .text(example: "scan-id"), 2730, externalRisk),
    v("scan-name", "cloud", ["-sname", "-scan-name"], "Nazwa skanu", "Nadaje nazwę skanowi chmurowemu.", .text(example: "audyt-testowy"), 2740, externalRisk),
    f("dashboard", "cloud", ["-pd", "-dashboard"], "Pulpit PDCP", "Wysyła i pokazuje wyniki w chmurze.", 2750, externalRisk),
    v("dashboard-upload", "cloud", ["-pdu", "-dashboard-upload"], "Wyślij plik do PDCP", "Wysyła plik wyników do pulpitu.", .path(example: "report.jsonl"), 2760, externalRisk),

    // AUTHENTICATION
    v("secret-file", "authentication", ["-sf", "-secret-file"], "Plik sekretów", "Wczytuje sekrety dla skanu uwierzytelnionego.", .secret(example: "secrets.yaml"), 2800, secretRisk),
    f("prefetch-secrets", "authentication", ["-ps", "-prefetch-secrets"], "Wczytaj sekrety wcześniej", "Pobiera sekrety przed rozpoczęciem skanu.", 2810, secretRisk),
  ]

  private static func c(
    _ id: String,
    _ title: String,
    _ subtitle: String,
    _ icon: String
  ) -> ToolCategoryDefinition {
    ToolCategoryDefinition(id: id, title: title, subtitle: subtitle, icon: icon)
  }

  private static func f(
    _ id: String,
    _ categoryID: String,
    _ flags: [String],
    _ title: String,
    _ summary: String,
    _ order: Int,
    _ risk: ToolRiskLevel = .standard,
    _ conflicts: Set<String> = []
  ) -> ToolOptionDefinition {
    ToolOptionDefinition(
      id: id,
      categoryID: categoryID,
      flags: flags,
      title: title,
      summary: summary,
      valueKind: .none,
      risk: risk,
      conflictsWithOptionIDs: conflicts,
      order: order
    )
  }

  private static func v(
    _ id: String,
    _ categoryID: String,
    _ flags: [String],
    _ title: String,
    _ summary: String,
    _ valueKind: ToolValueKind,
    _ order: Int,
    _ risk: ToolRiskLevel = .standard
  ) -> ToolOptionDefinition {
    ToolOptionDefinition(
      id: id,
      categoryID: categoryID,
      flags: flags,
      title: title,
      summary: summary,
      valueKind: valueKind,
      risk: risk,
      order: order
    )
  }
}
