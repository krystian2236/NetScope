import Foundation

enum CurlCatalog {
  private static let optionCategoryIDs = [
    "auth", "connection", "curl", "dns", "file", "ftp", "http", "imap", "misc",
    "output", "pop3", "post", "proxy", "scp", "sftp", "smtp", "ssh", "telnet",
    "tftp", "tls", "upload", "verbose",
  ]

  static let definition = ToolDefinition(
    id: "curl",
    executable: "curl",
    title: "Curl",
    helpVersion: "8.7.1",
    reviewedAt: "2026-09-13",
    usageParts: [
      .literal("curl"),
      .section(.init(id: "options", label: "[options]", categoryIDs: optionCategoryIDs, tone: .options)),
      .section(.init(id: "url", label: "{URL}", categoryIDs: ["url"], tone: .target)),
    ],
    categories: categories,
    options: featured(options)
  )

  private static let categories: [ToolCategoryDefinition] = [
    c("url", "URL", "Adres zasobu", "link"),
    c("auth", "Uwierzytelnianie", "Metody logowania i poświadczenia", "person.badge.key"),
    c("connection", "Połączenie", "Interfejs, adres i zachowanie transportu", "network"),
    c("curl", "Program Curl", "Konfiguracja samego narzędzia", "terminal"),
    c("dns", "DNS", "Rozwiązywanie nazw i własne mapowania", "globe"),
    c("file", "FILE", "Obsługa lokalnych adresów file://", "doc"),
    c("ftp", "FTP", "Opcje protokołu FTP", "externaldrive.connected.to.line.below"),
    c("http", "HTTP i HTTPS", "Metoda, nagłówki i odpowiedź", "network.badge.shield.half.filled"),
    c("imap", "IMAP", "Opcje poczty IMAP", "tray.full"),
    c("misc", "Pozostałe", "Opcje ogólne", "ellipsis.circle"),
    c("output", "Pliki i wynik", "Zapis pobranych danych", "square.and.arrow.down"),
    c("pop3", "POP3", "Opcje poczty POP3", "tray.and.arrow.down"),
    c("post", "Dane POST", "Treść, formularze i upload HTTP", "paperplane"),
    c("proxy", "Proxy", "Pośrednik sieciowy i jego logowanie", "point.3.connected.trianglepath.dotted"),
    c("scp", "SCP", "Kopiowanie przez SSH", "doc.on.doc"),
    c("sftp", "SFTP", "Transfer plików przez SSH", "folder.badge.gearshape"),
    c("smtp", "SMTP", "Wysyłanie poczty", "envelope"),
    c("ssh", "SSH", "Klucze i hosty SSH", "key"),
    c("telnet", "Telnet", "Opcje protokołu Telnet", "cable.connector"),
    c("tftp", "TFTP", "Opcje protokołu TFTP", "arrow.left.arrow.right"),
    c("tls", "TLS", "Certyfikaty i wersje szyfrowania", "lock.shield"),
    c("upload", "Wysyłanie", "Przesyłanie plików i danych", "arrow.up.doc"),
    c("verbose", "Diagnostyka", "Szczegóły i śledzenie połączenia", "text.magnifyingglass"),
  ]

  private static let networkRisk: ToolRiskLevel = .caution(reason: "Polecenie wysyła ruch do podanego adresu. Testuj wyłącznie własny lub autoryzowany cel.")
  private static let secretRisk: ToolRiskLevel = .advanced(reason: "Wartość może zawierać sekret. NetScope jej nie zapisuje, ale schowek i historia terminala mogą ją ujawnić.")
  private static let fileRisk: ToolRiskLevel = .caution(reason: "Opcja odczytuje albo zapisuje plik na urządzeniu uruchamiającym Curl.")
  private static let insecureRisk: ToolRiskLevel = .advanced(reason: "Wyłącza kontrolę certyfikatu TLS. Używaj tylko w izolowanym laboratorium.")

  private static let options: [ToolOptionDefinition] = [
    v("target", "url", [], "URL", "Wskazuje adres żądania.", .text(example: "https://example.com"), 10_000, networkRisk, .separated, .target),

    v("user", "auth", ["-u", "--user"], "Użytkownik i hasło", "Przekazuje dane logowania serwera.", .secret(example: "user:password"), 100, secretRisk),
    f("basic", "auth", ["--basic"], "Basic", "Wybiera uwierzytelnianie HTTP Basic.", 110),
    f("digest", "auth", ["--digest"], "Digest", "Wybiera uwierzytelnianie HTTP Digest.", 120),
    f("negotiate", "auth", ["--negotiate"], "Negotiate", "Wybiera uwierzytelnianie SPNEGO.", 130),
    f("anyauth", "auth", ["--anyauth"], "Dobierz metodę", "Pozwala serwerowi wskazać obsługiwaną metodę logowania.", 140),
    v("oauth2-bearer", "auth", ["--oauth2-bearer"], "Token Bearer", "Przekazuje token OAuth 2.0.", .secret(example: "token"), 150, secretRisk),
    v("netrc-file", "auth", ["--netrc-file"], "Plik netrc", "Czyta dane logowania z wybranego pliku.", .path(example: "credentials.netrc"), 160, secretRisk),

    v("interface", "connection", ["--interface"], "Interfejs", "Wybiera interfejs lub lokalny adres.", .text(example: "en0"), 200),
    f("ipv4", "connection", ["-4", "--ipv4"], "Tylko IPv4", "Rozwiązuje i łączy wyłącznie przez IPv4.", 210),
    f("ipv6", "connection", ["-6", "--ipv6"], "Tylko IPv6", "Rozwiązuje i łączy wyłącznie przez IPv6.", 220),
    f("keepalive", "connection", ["--keepalive"], "Keepalive", "Włącza systemowe pakiety podtrzymujące TCP.", 230),
    v("connect-timeout", "connection", ["--connect-timeout"], "Limit połączenia", "Ogranicza czas zestawiania połączenia w sekundach.", .text(example: "5"), 840),
    v("max-time", "connection", ["--max-time", "-m"], "Limit całości", "Ogranicza łączny czas operacji w sekundach.", .text(example: "10"), 850),
    v("retry", "connection", ["--retry"], "Ponowienia", "Ponawia przejściowo nieudane żądanie.", .integer(range: 0...100, example: "3"), 860),
    v("retry-delay", "connection", ["--retry-delay"], "Odstęp ponowień", "Ustawia odstęp między próbami w sekundach.", .integer(range: 0...3600, example: "2"), 870),
    f("retry-all-errors", "connection", ["--retry-all-errors"], "Ponawiaj wszystkie błędy", "Rozszerza ponowienia na każdy rodzaj błędu.", 880, networkRisk),

    v("config", "curl", ["-K", "--config"], "Plik konfiguracji", "Czyta argumenty Curl z pliku.", .path(example: "curl.conf"), 300, fileRisk),
    f("disable", "curl", ["-q", "--disable"], "Bez domyślnej konfiguracji", "Nie czyta domyślnego pliku curlrc.", 310),
    f("parallel", "curl", ["-Z", "--parallel"], "Równolegle", "Wykonuje wiele transferów równolegle.", 320, networkRisk),
    f("version", "curl", ["-V", "--version"], "Wersja", "Wyświetla wersję i obsługiwane funkcje.", 330),
    f("help", "curl", ["-h", "--help"], "Pomoc", "Wyświetla pomoc programu.", 340),

    v("resolve", "dns", ["--resolve"], "Własne mapowanie", "Mapuje host i port na podany adres bez zmiany URL.", .text(example: "example.com:443:127.0.0.1"), 400, networkRisk),
    v("connect-to", "dns", ["--connect-to"], "Inny cel połączenia", "Zmienia host lub port transportu bez zmiany nazwy żądania.", .text(example: "host:443:127.0.0.1:8443"), 410, networkRisk),
    v("dns-servers", "dns", ["--dns-servers"], "Serwery DNS", "Używa wskazanych resolverów, jeśli build Curl to obsługuje.", .list(example: "1.1.1.1,8.8.8.8"), 420, networkRisk),

    f("ftp-create-dirs", "ftp", ["--ftp-create-dirs"], "Twórz katalogi FTP", "Tworzy brakujące katalogi podczas wysyłania.", 600, networkRisk),
    f("ftp-pasv", "ftp", ["--ftp-pasv"], "Pasywny FTP", "Używa pasywnego trybu transferu FTP.", 610),

    v("request", "http", ["-X", "--request"], "Metoda", "Wybiera metodę żądania, np. GET, POST lub DELETE.", .choice(values: ["GET", "HEAD", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"], example: "POST"), 700, networkRisk),
    f("head", "http", ["-I", "--head"], "Tylko nagłówki", "Pobiera nagłówki odpowiedzi bez treści.", 710),
    v("header", "http", ["-H", "--header"], "Nagłówek", "Dodaje lub zastępuje nagłówek żądania.", .secret(example: "Authorization: Bearer token"), 720, secretRisk),
    v("user-agent", "http", ["-A", "--user-agent"], "User-Agent", "Ustawia identyfikator klienta HTTP.", .text(example: "NetScope-Lab/1.0"), 730),
    v("referer", "http", ["-e", "--referer"], "Referer", "Ustawia nagłówek Referer.", .text(example: "https://example.com"), 740),
    v("cookie", "http", ["-b", "--cookie"], "Cookie", "Przekazuje ciasteczka lub czyta je z pliku.", .secret(example: "session=value"), 750, secretRisk),
    v("cookie-jar", "http", ["-c", "--cookie-jar"], "Zapis cookies", "Zapisuje ciasteczka po zakończeniu transferu.", .path(example: "cookies.txt"), 760, secretRisk),
    f("location", "http", ["-L", "--location"], "Śledź przekierowania", "Podąża za przekierowaniami HTTP.", 770, networkRisk),
    v("max-redirs", "http", ["--max-redirs"], "Limit przekierowań", "Ogranicza liczbę przekierowań.", .integer(range: 0...100, example: "10"), 780),
    f("fail-with-body", "http", ["--fail-with-body"], "Błąd z treścią", "Zwraca błąd dla HTTP 400+ i zachowuje treść odpowiedzi.", 790),
    f("include", "http", ["-i", "--include"], "Dołącz nagłówki", "Pokazuje nagłówki odpowiedzi razem z treścią.", 800),
    f("compressed", "http", ["--compressed"], "Kompresja", "Prosi o skompresowaną odpowiedź i rozpakowuje ją.", 810),
    f("http1-1", "http", ["--http1.1"], "HTTP/1.1", "Wymusza HTTP/1.1.", 820),
    f("http2", "http", ["--http2"], "HTTP/2", "Próbuje użyć HTTP/2.", 830),

    v("url-query", "misc", ["--url-query"], "Parametr URL", "Dodaje parametr zapytania do URL.", .text(example: "page=1"), 900),
    f("globoff", "misc", ["-g", "--globoff"], "Bez globbingu URL", "Wyłącza interpretowanie nawiasów w URL.", 910),

    v("output", "output", ["-o", "--output"], "Plik wyniku", "Zapisuje treść odpowiedzi do pliku.", .path(example: "response.json"), 1000, fileRisk),
    f("remote-name", "output", ["-O", "--remote-name"], "Nazwa z serwera", "Zapisuje plik pod nazwą wynikającą z URL.", 1010, fileRisk),
    f("silent", "output", ["-s", "--silent"], "Cicho", "Ukrywa pasek postępu i komunikaty.", 1020),
    f("show-error", "output", ["-S", "--show-error"], "Pokaż błąd", "Pokazuje błąd także w trybie cichym.", 1030),
    v("write-out", "output", ["-w", "--write-out"], "Format podsumowania", "Wyświetla wybrane metadane transferu.", .text(example: "%{http_code}"), 1040),

    v("data", "post", ["-d", "--data"], "Dane", "Wysyła treść żądania formularza lub JSON.", .secret(example: #"{"name":"lab"}"#), 1100, secretRisk),
    v("data-binary", "post", ["--data-binary"], "Dane binarne", "Wysyła treść bez przetwarzania znaków nowej linii.", .secret(example: "@payload.bin"), 1110, secretRisk),
    v("form", "post", ["-F", "--form"], "Formularz multipart", "Dodaje pole lub plik do formularza multipart.", .secret(example: "file=@report.txt"), 1120, secretRisk),
    v("json", "post", ["--json"], "JSON", "Wysyła JSON i ustawia odpowiednie nagłówki.", .secret(example: #"{"name":"lab"}"#), 1130, secretRisk),

    v("proxy", "proxy", ["-x", "--proxy"], "Proxy", "Kieruje połączenie przez proxy.", .text(example: "http://127.0.0.1:8080"), 1200, networkRisk),
    v("proxy-user", "proxy", ["-U", "--proxy-user"], "Login proxy", "Przekazuje dane logowania do proxy.", .secret(example: "user:password"), 1210, secretRisk),
    v("noproxy", "proxy", ["--noproxy"], "Pomiń proxy", "Pomija proxy dla wskazanych hostów.", .list(example: "localhost,.example.com"), 1220),

    v("key", "ssh", ["--key"], "Klucz prywatny", "Wczytuje klucz klienta TLS lub SSH.", .secret(example: "id_ed25519"), 1300, secretRisk),
    v("pubkey", "ssh", ["--pubkey"], "Klucz publiczny", "Wczytuje klucz publiczny SSH.", .path(example: "id_ed25519.pub"), 1310, fileRisk),

    v("telnet-option", "telnet", ["-t", "--telnet-option"], "Opcja Telnet", "Ustawia parametr protokołu Telnet.", .text(example: "TTYPE=xterm"), 1400),
    f("tftp-no-options", "tftp", ["--tftp-no-options"], "Bez opcji TFTP", "Nie wysyła rozszerzeń opcji TFTP.", 1500),

    f("tlsv1-2", "tls", ["--tlsv1.2"], "Minimum TLS 1.2", "Wymaga co najmniej TLS 1.2.", 1600),
    f("tlsv1-3", "tls", ["--tlsv1.3"], "Minimum TLS 1.3", "Wymaga co najmniej TLS 1.3.", 1610),
    v("cacert", "tls", ["--cacert"], "Certyfikat CA", "Weryfikuje serwer przy użyciu wskazanego pliku CA.", .path(example: "ca.pem"), 1620, fileRisk),
    v("cert", "tls", ["-E", "--cert"], "Certyfikat klienta", "Wczytuje certyfikat klienta i opcjonalne hasło.", .secret(example: "client.pem:password"), 1630, secretRisk),
    f("insecure", "tls", ["-k", "--insecure"], "Bez weryfikacji TLS", "Pozwala na połączenie bez potwierdzenia certyfikatu.", 1640, insecureRisk),
    v("pinnedpubkey", "tls", ["--pinnedpubkey"], "Przypięty klucz", "Wymaga konkretnego klucza publicznego serwera.", .path(example: "sha256//base64"), 1650, fileRisk),

    v("upload-file", "upload", ["-T", "--upload-file"], "Wyślij plik", "Wysyła wskazany plik do celu.", .path(example: "report.txt"), 1700, fileRisk),
    f("verbose", "verbose", ["-v", "--verbose"], "Szczegóły", "Pokazuje szczegóły połączenia i nagłówki; mogą zawierać sekrety.", 1800, secretRisk),
    v("trace", "verbose", ["--trace"], "Ślad transferu", "Zapisuje pełny ślad danych do pliku.", .path(example: "trace.txt"), 1810, secretRisk),
    f("trace-time", "verbose", ["--trace-time"], "Czas w śladzie", "Dodaje znaczniki czasu do śladu.", 1820),

    f("imap-ssl", "imap", ["--ssl-reqd"], "Wymagaj TLS", "Wymaga TLS dla protokołu pocztowego.", 1900),
    f("pop3-ssl", "pop3", ["--ssl"], "Spróbuj TLS", "Próbuje użyć TLS dla protokołu pocztowego.", 1910),
    v("mail-from", "smtp", ["--mail-from"], "Nadawca", "Ustawia adres nadawcy SMTP.", .text(example: "sender@example.com"), 1920, networkRisk),
    v("mail-rcpt", "smtp", ["--mail-rcpt"], "Odbiorca", "Dodaje odbiorcę SMTP.", .text(example: "recipient@example.com"), 1930, networkRisk),
    f("scp-path-as-is", "scp", ["--path-as-is"], "Ścieżka bez zmian", "Nie normalizuje sekwencji /../ w ścieżce URL.", 1940),
  ]

  private static let featuredIDs: Set<String> = [
    "target", "basic", "digest", "anyauth", "request", "head", "header", "data", "json", "location", "fail-with-body",
    "include", "output", "silent", "show-error", "compressed", "connect-timeout", "max-time",
    "retry", "tlsv1-2", "tlsv1-3", "cacert", "verbose", "version",
  ]

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
    .init(id: id, categoryID: category, flags: flags, title: title, summary: summary, valueKind: .none, risk: risk, order: order)
  }

  private static func v(_ id: String, _ category: String, _ flags: [String], _ title: String, _ summary: String, _ kind: ToolValueKind, _ order: Int, _ risk: ToolRiskLevel = .standard, _ placement: ToolValuePlacement = .separated, _ phase: ToolArgumentPhase = .beforeTarget) -> ToolOptionDefinition {
    .init(id: id, categoryID: category, flags: flags, title: title, summary: summary, valueKind: kind, valuePlacement: placement, risk: risk, order: order, argumentPhase: phase)
  }
}
