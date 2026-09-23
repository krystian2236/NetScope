import Foundation

enum NmapCatalog {
  static let definition = ToolDefinition(
    id: "nmap",
    executable: "nmap",
    title: "Nmap",
    helpVersion: "7.991",
    reviewedAt: "2026-09-12",
    usageParts: [
      .literal("nmap"),
      .category(label: "[Scan Type(s)]", categoryID: "scan"),
      .category(label: "[Options]", categoryID: "discovery"),
      .category(label: "{target specification}", categoryID: "target"),
    ],
    categories: categories,
    options: options
  )

  private static let categories: [ToolCategoryDefinition] = [
    c("target", "Cel", "Hosty, adresy, sieci i listy wejściowe", "scope"),
    c("discovery", "Wykrywanie hostów", "Sprawdzanie, które urządzenia odpowiadają", "dot.radiowaves.left.and.right"),
    c("scan", "Technika skanowania", "Sposób sprawdzania portów i protokołów", "waveform.path.ecg"),
    c("ports", "Porty i kolejność", "Zakres oraz kolejność sprawdzanych portów", "rectangle.3.group"),
    c("service", "Usługi i wersje", "Rozpoznawanie programów na otwartych portach", "info.circle"),
    c("scripts", "Skrypty NSE", "Wbudowane skrypty diagnostyczne Nmap", "scroll"),
    c("os", "System operacyjny", "Rozpoznawanie systemu celu", "desktopcomputer"),
    c("timing", "Czas i wydajność", "Tempo, timeouty i liczba prób", "speedometer"),
    c("evasion", "Pakiety i zapory", "Zaawansowane sterowanie pakietami", "shield.lefthalf.filled"),
    c("output", "Wyniki", "Szczegółowość i zapis rezultatów", "square.and.arrow.down"),
    c("misc", "Pozostałe", "IPv6, dane programu i tryb uprawnień", "ellipsis.circle"),
  ]

  private static let active: ToolRiskLevel = .caution(
    reason: "Ta opcja generuje aktywny ruch. Używaj jej tylko we własnej sieci lub za zgodą właściciela."
  )
  private static let raw: ToolRiskLevel = .advanced(
    reason: "Ta opcja wymaga surowych pakietów lub podwyższonych uprawnień i może zakłócić działanie sieci."
  )
  private static let evasion: ToolRiskLevel = .advanced(
    reason: "Ta opcja zmienia lub ukrywa źródło ruchu. Stosuj ją wyłącznie w kontrolowanym, autoryzowanym laboratorium."
  )
  private static let file: ToolRiskLevel = .caution(
    reason: "Ta opcja odczytuje albo zapisuje plik na urządzeniu uruchamiającym Nmap."
  )

  private static let options: [ToolOptionDefinition] = [
    // TARGET SPECIFICATION
    v("input-list", "target", ["-iL"], "Lista celów", "Czyta hosty lub sieci z pliku.", .path(example: "hosts.txt"), 900, file),
    v("random-targets", "target", ["-iR"], "Losowe cele", "Wybiera podaną liczbę losowych hostów.", .integer(range: 1...1_000_000, example: "10"), 910, active),
    v("exclude", "target", ["--exclude"], "Wyklucz cele", "Pomija podane hosty lub sieci.", .list(example: "192.168.1.1,192.168.1.10"), 920),
    v("exclude-file", "target", ["--excludefile"], "Plik wykluczeń", "Czyta cele do pominięcia z pliku.", .path(example: "exclude.txt"), 930, file),
    v("target", "target", [""], "Cel", "Wskazuje nazwę hosta, adres IP lub sieć CIDR.", .text(example: "192.168.1.0/24"), 10_000),

    // HOST DISCOVERY
    f("list-scan", "discovery", ["-sL"], "Lista bez skanowania", "Wyświetla cele bez wysyłania skanu portów.", 200),
    f("ping-scan", "discovery", ["-sn"], "Tylko wykrywanie hostów", "Wykrywa aktywne hosty bez skanowania portów.", 210),
    f("skip-discovery", "discovery", ["-Pn"], "Pomiń wykrywanie", "Traktuje wszystkie cele jako dostępne.", 220, active),
    v("syn-ping", "discovery", ["-PS"], "TCP SYN discovery", "Wykrywa hosty pakietami SYN do wskazanych portów.", .list(example: "22,80,443"), 230, raw, .attached),
    v("ack-ping", "discovery", ["-PA"], "TCP ACK discovery", "Wykrywa hosty pakietami ACK.", .list(example: "80,443"), 240, raw, .attached),
    v("udp-ping", "discovery", ["-PU"], "UDP discovery", "Wykrywa hosty datagramami UDP.", .list(example: "53,161"), 250, raw, .attached),
    v("sctp-ping", "discovery", ["-PY"], "SCTP discovery", "Wykrywa hosty pakietami SCTP INIT.", .list(example: "80"), 260, raw, .attached),
    f("icmp-echo", "discovery", ["-PE"], "ICMP echo", "Używa żądania ICMP Echo.", 270, raw),
    f("icmp-timestamp", "discovery", ["-PP"], "ICMP timestamp", "Używa żądania znacznika czasu ICMP.", 280, raw),
    f("icmp-netmask", "discovery", ["-PM"], "ICMP netmask", "Używa żądania maski sieci ICMP.", 290, raw),
    v("ip-protocol-ping", "discovery", ["-PO"], "IP Protocol Ping", "Wykrywa hosty wskazanymi protokołami IP.", .list(example: "1,2,4"), 300, raw, .attached),
    f("no-dns", "discovery", ["-n"], "Bez DNS", "Nie rozwiązuje nazw DNS.", 310),
    f("always-dns", "discovery", ["-R"], "Zawsze DNS", "Zawsze próbuje rozwiązać nazwy DNS.", 320),
    v("dns-servers", "discovery", ["--dns-servers"], "Serwery DNS", "Używa wskazanych resolverów DNS.", .list(example: "1.1.1.1,8.8.8.8"), 330),
    f("system-dns", "discovery", ["--system-dns"], "Systemowy DNS", "Używa resolvera systemu operacyjnego.", 340),
    f("traceroute", "discovery", ["--traceroute"], "Trasa do hosta", "Pokazuje kolejne węzły prowadzące do celu.", 350, active),

    // SCAN TECHNIQUES
    f("tcp-syn", "scan", ["-sS"], "TCP SYN", "Skanuje TCP bez pełnego zestawienia połączenia.", 100, raw),
    f("tcp-connect", "scan", ["-sT"], "TCP Connect", "Używa systemowego połączenia TCP.", 100),
    f("tcp-ack", "scan", ["-sA"], "TCP ACK", "Pomaga rozpoznać filtrowanie przez zaporę.", 110, raw),
    f("tcp-window", "scan", ["-sW"], "TCP Window", "Analizuje pole okna odpowiedzi TCP.", 120, raw),
    f("tcp-maimon", "scan", ["-sM"], "TCP Maimon", "Wysyła pakiety FIN/ACK.", 130, raw),
    f("udp-scan", "scan", ["-sU"], "UDP", "Sprawdza porty UDP.", 140, active),
    f("tcp-null", "scan", ["-sN"], "TCP Null", "Wysyła pakiety TCP bez flag.", 150, evasion),
    f("tcp-fin", "scan", ["-sF"], "TCP FIN", "Wysyła pakiety TCP z flagą FIN.", 160, evasion),
    f("tcp-xmas", "scan", ["-sX"], "TCP Xmas", "Wysyła pakiety z flagami FIN, PSH i URG.", 170, evasion),
    v("scan-flags", "scan", ["--scanflags"], "Własne flagi TCP", "Ustawia ręcznie flagi skanu TCP.", .text(example: "SYNACK"), 180, evasion),
    v("idle-scan", "scan", ["-sI"], "Idle scan", "Używa wskazanego hosta pośredniczącego.", .text(example: "192.168.1.50:80"), 190, evasion),
    f("sctp-init", "scan", ["-sY"], "SCTP INIT", "Skanuje usługi SCTP pakietami INIT.", 195, raw),
    f("sctp-cookie", "scan", ["-sZ"], "SCTP COOKIE-ECHO", "Skanuje SCTP pakietami COOKIE-ECHO.", 196, raw),
    f("ip-protocol-scan", "scan", ["-sO"], "Protokoły IP", "Sprawdza obsługiwane protokoły IP.", 197, raw),
    v("ftp-bounce", "scan", ["-b"], "FTP bounce", "Próbuje skanować przez serwer FTP.", .text(example: "ftp.example.com"), 198, evasion),

    // PORTS
    v("ports", "ports", ["-p"], "Zakres portów", "Ogranicza skan do wskazanych portów.", .list(example: "22,80,443"), 500),
    v("exclude-ports", "ports", ["--exclude-ports"], "Wyklucz porty", "Pomija wskazane porty.", .list(example: "25,445"), 510),
    f("fast-scan", "ports", ["-F"], "Szybki zakres", "Skanuje mniej portów niż domyślnie.", 520),
    f("sequential-ports", "ports", ["-r"], "Kolejno", "Nie losuje kolejności portów.", 530),
    v("top-ports", "ports", ["--top-ports"], "Najczęstsze porty", "Skanuje podaną liczbę najpopularniejszych portów.", .integer(range: 1...65_535, example: "100"), 540),
    v("port-ratio", "ports", ["--port-ratio"], "Próg popularności", "Skanuje porty częstsze niż podany współczynnik.", .text(example: "0.01"), 550),

    // SERVICE/VERSION
    f("service-detection", "service", ["-sV"], "Rozpoznaj usługi", "Bada usługę i jej wersję na otwartym porcie.", 400, active),
    v("version-intensity", "service", ["--version-intensity"], "Intensywność sond", "Ustawia intensywność wykrywania od 0 do 9.", .integer(range: 0...9, example: "7"), 410, active, .separated, ["service-detection"]),
    f("version-light", "service", ["--version-light"], "Lekkie wykrywanie", "Używa najbardziej prawdopodobnych sond.", 420, .standard, ["service-detection"], ["version-all"]),
    f("version-all", "service", ["--version-all"], "Wszystkie sondy", "Próbuje każdej sondy rozpoznawania wersji.", 430, active, ["service-detection"], ["version-light"]),
    f("version-trace", "service", ["--version-trace"], "Ślad wykrywania", "Pokazuje szczegóły działania sond wersji.", 440, .standard, ["service-detection"]),

    // SCRIPT SCAN
    f("default-scripts", "scripts", ["-sC"], "Domyślne skrypty", "Uruchamia domyślny zestaw skryptów NSE.", 600, active),
    v("script", "scripts", ["--script"], "Wybór skryptów", "Wybiera skrypty, katalogi lub kategorie NSE.", .list(example: "default,safe"), 610, active, .equals),
    v("script-args", "scripts", ["--script-args"], "Argumenty skryptów", "Przekazuje wartości do skryptów NSE.", .text(example: "user=value"), 620, active, .equals),
    v("script-args-file", "scripts", ["--script-args-file"], "Plik argumentów", "Czyta argumenty NSE z pliku.", .path(example: "nse-args.txt"), 630, file, .equals),
    f("script-trace", "scripts", ["--script-trace"], "Ślad skryptów", "Pokazuje dane wysyłane i odbierane przez NSE.", 640),
    f("script-updatedb", "scripts", ["--script-updatedb"], "Aktualizuj bazę NSE", "Odświeża lokalną bazę skryptów.", 650, file),
    v("script-help", "scripts", ["--script-help"], "Pomoc skryptu", "Pokazuje pomoc wskazanych skryptów lub kategorii.", .list(example: "safe"), 660, .standard, .equals),

    // OS DETECTION
    f("os-detection", "os", ["-O"], "Rozpoznaj system", "Próbuje określić system operacyjny celu.", 700, raw),
    f("osscan-limit", "os", ["--osscan-limit"], "Tylko obiecujące cele", "Ogranicza wykrywanie systemu do odpowiednich hostów.", 710, .standard, ["os-detection"]),
    f("osscan-guess", "os", ["--osscan-guess"], "Agresywne zgadywanie", "Pokazuje także mniej pewne dopasowania systemu.", 720, active, ["os-detection"]),

    // TIMING
    v("timing-template", "timing", ["-T"], "Szablon tempa", "Ustawia tempo od 0 (najwolniej) do 5 (najszybciej).", .integer(range: 0...5, example: "4"), 1000, active, .attached),
    v("min-hostgroup", "timing", ["--min-hostgroup"], "Minimalna grupa hostów", "Ustawia minimalny rozmiar równoległej grupy.", .integer(range: 1...65_535, example: "16"), 1010),
    v("max-hostgroup", "timing", ["--max-hostgroup"], "Maksymalna grupa hostów", "Ustawia maksymalny rozmiar grupy.", .integer(range: 1...65_535, example: "256"), 1020, active),
    v("min-parallelism", "timing", ["--min-parallelism"], "Minimalna równoległość", "Ustawia minimalną liczbę sond równoległych.", .integer(range: 1...10_000, example: "10"), 1030),
    v("max-parallelism", "timing", ["--max-parallelism"], "Maksymalna równoległość", "Ustawia maksymalną liczbę sond równoległych.", .integer(range: 1...10_000, example: "100"), 1040, active),
    v("min-rtt-timeout", "timing", ["--min-rtt-timeout"], "Minimalny RTT", "Ustawia minimalny timeout odpowiedzi.", .duration(example: "100ms"), 1050),
    v("max-rtt-timeout", "timing", ["--max-rtt-timeout"], "Maksymalny RTT", "Ustawia maksymalny timeout odpowiedzi.", .duration(example: "2s"), 1060),
    v("initial-rtt-timeout", "timing", ["--initial-rtt-timeout"], "Początkowy RTT", "Ustawia początkowy timeout odpowiedzi.", .duration(example: "500ms"), 1070),
    v("max-retries", "timing", ["--max-retries"], "Limit ponowień", "Ogranicza retransmisje sond.", .integer(range: 0...100, example: "3"), 1080),
    v("host-timeout", "timing", ["--host-timeout"], "Timeout hosta", "Kończy pracę nad hostem po wskazanym czasie.", .duration(example: "5m"), 1090),
    v("scan-delay", "timing", ["--scan-delay"], "Odstęp sond", "Ustawia minimalny odstęp między sondami.", .duration(example: "100ms"), 1100),
    v("max-scan-delay", "timing", ["--max-scan-delay"], "Maksymalny odstęp", "Ogranicza adaptacyjny odstęp między sondami.", .duration(example: "1s"), 1110),
    v("min-rate", "timing", ["--min-rate"], "Minimalne tempo", "Wymusza minimalną liczbę pakietów na sekundę.", .integer(range: 1...1_000_000, example: "100"), 1120, active),
    v("max-rate", "timing", ["--max-rate"], "Maksymalne tempo", "Ogranicza liczbę pakietów na sekundę.", .integer(range: 1...1_000_000, example: "100"), 1130),

    // FIREWALL / IDS
    f("fragment", "evasion", ["-f"], "Fragmentuj pakiety", "Dzieli nagłówki sond na fragmenty.", 1200, evasion),
    v("mtu", "evasion", ["--mtu"], "Własne MTU", "Fragmentuje pakiety według podanej wielokrotności ośmiu.", .integer(range: 8...65_528, example: "24"), 1210, evasion),
    v("decoys", "evasion", ["-D"], "Adresy pozorne", "Miesza źródło skanu z adresami pozornymi.", .list(example: "RND:3,ME"), 1220, evasion),
    v("source-address", "evasion", ["-S"], "Adres źródłowy", "Ustawia ręcznie źródłowy adres IP.", .text(example: "192.168.1.20"), 1230, evasion),
    v("interface", "evasion", ["-e"], "Interfejs", "Wybiera interfejs sieciowy.", .text(example: "en0"), 1240, raw),
    v("source-port", "evasion", ["-g", "--source-port"], "Port źródłowy", "Ustawia port źródłowy pakietów.", .integer(range: 0...65_535, example: "53"), 1250, evasion),
    v("proxies", "evasion", ["--proxies"], "Łańcuch proxy", "Przekazuje połączenia przez proxy HTTP lub SOCKS4.", .list(example: "http://127.0.0.1:8080"), 1260, evasion),
    v("data", "evasion", ["--data"], "Dane szesnastkowe", "Dodaje własny ładunek hex do pakietów.", .text(example: "DEADBEEF"), 1270, evasion),
    v("data-string", "evasion", ["--data-string"], "Dane tekstowe", "Dodaje tekstowy ładunek do pakietów.", .text(example: "Northbyte Radar"), 1280, evasion),
    v("data-length", "evasion", ["--data-length"], "Losowe dane", "Dodaje wskazaną liczbę losowych bajtów.", .integer(range: 0...65_535, example: "16"), 1290, evasion),
    v("ip-options", "evasion", ["--ip-options"], "Opcje IP", "Dodaje wskazane opcje nagłówka IP.", .text(example: "R"), 1300, evasion),
    v("ttl", "evasion", ["--ttl"], "TTL", "Ustawia pole czasu życia pakietu IP.", .integer(range: 0...255, example: "64"), 1310, evasion),
    v("spoof-mac", "evasion", ["--spoof-mac"], "Zmień MAC", "Ustawia pozorny adres lub producenta MAC.", .text(example: "Apple"), 1320, evasion),
    f("badsum", "evasion", ["--badsum"], "Błędna suma", "Wysyła pakiety z nieprawidłową sumą kontrolną.", 1330, evasion),

    // OUTPUT
    v("normal-output", "output", ["-oN"], "Zapis zwykły", "Zapisuje czytelny raport tekstowy.", .path(example: "scan.txt"), 1400, file),
    v("xml-output", "output", ["-oX"], "Zapis XML", "Zapisuje raport XML.", .path(example: "scan.xml"), 1410, file),
    v("script-kiddie-output", "output", ["-oS"], "Zapis stylizowany", "Zapisuje raport w historycznym formacie s|<rIpt kIddi3.", .path(example: "scan.script"), 1420, file),
    v("grepable-output", "output", ["-oG"], "Zapis grepable", "Zapisuje starszy format łatwy do filtrowania.", .path(example: "scan.gnmap"), 1430, file),
    v("all-output", "output", ["-oA"], "Trzy główne formaty", "Zapisuje raport zwykły, XML i grepable.", .path(example: "scan"), 1440, file),
    f("verbose", "output", ["-v"], "Więcej informacji", "Zwiększa szczegółowość wyników.", 1450),
    f("debug", "output", ["-d"], "Debug", "Zwiększa szczegółowość diagnostyczną.", 1460),
    f("reason", "output", ["--reason"], "Powód stanu", "Wyjaśnia, dlaczego port ma dany stan.", 1470),
    f("open-only", "output", ["--open"], "Tylko otwarte", "Pokazuje tylko porty otwarte lub prawdopodobnie otwarte.", 300),
    f("packet-trace", "output", ["--packet-trace"], "Ślad pakietów", "Pokazuje wszystkie wysłane i odebrane pakiety.", 1490, raw),
    f("interface-list", "output", ["--iflist"], "Interfejsy i trasy", "Wyświetla lokalne interfejsy i tablicę tras.", 1500),
    f("append-output", "output", ["--append-output"], "Dopisz wynik", "Dopisuje zamiast nadpisywać pliki wyjściowe.", 1510, file),
    v("resume", "output", ["--resume"], "Wznów skan", "Wznawia przerwany skan z pliku.", .path(example: "scan.nmap"), 1520, file),
    f("noninteractive", "output", ["--noninteractive"], "Bez klawiatury", "Wyłącza sterowanie podczas działania.", 1530),
    v("stylesheet", "output", ["--stylesheet"], "Arkusz XSL", "Wskazuje arkusz dla raportu XML.", .text(example: "nmap.xsl"), 1540, file),
    f("webxml", "output", ["--webxml"], "Arkusz z Nmap.org", "Odwołuje raport XML do arkusza Nmap.org.", 1550, active),
    f("no-stylesheet", "output", ["--no-stylesheet"], "Bez arkusza XSL", "Nie łączy raportu XML z arkuszem stylów.", 1560),

    // MISC
    f("ipv6", "misc", ["-6"], "IPv6", "Włącza skanowanie adresów IPv6.", 1600),
    f("aggressive", "misc", ["-A"], "Rozpoznanie rozszerzone", "Łączy wykrywanie systemu, usług, skrypty i traceroute.", 1610, raw),
    v("data-directory", "misc", ["--datadir"], "Katalog danych", "Wskazuje własny katalog danych Nmap.", .path(example: "/usr/local/share/nmap"), 1620, file),
    f("send-ethernet", "misc", ["--send-eth"], "Surowe ramki Ethernet", "Wysyła ruch jako surowe ramki Ethernet.", 1630, raw),
    f("send-ip", "misc", ["--send-ip"], "Surowe pakiety IP", "Wysyła ruch jako surowe pakiety IP.", 1640, raw),
    f("privileged", "misc", ["--privileged"], "Tryb uprzywilejowany", "Zakłada dostęp do surowych pakietów.", 1650, raw),
    f("unprivileged", "misc", ["--unprivileged"], "Tryb bez uprawnień", "Zakłada brak dostępu do surowych pakietów.", 1660),
    f("version", "misc", ["-V"], "Wersja", "Wyświetla wersję Nmap.", 1670),
    f("help", "misc", ["-h"], "Pomoc", "Wyświetla skróconą pomoc Nmap.", 1680),
  ]

  private static func c(_ id: String, _ title: String, _ subtitle: String, _ icon: String) -> ToolCategoryDefinition {
    .init(id: id, title: title, subtitle: subtitle, icon: icon)
  }

  private static func f(
    _ id: String, _ category: String, _ flags: [String], _ title: String,
    _ summary: String, _ order: Int, _ risk: ToolRiskLevel = .standard,
    _ requires: Set<String> = [], _ conflicts: Set<String> = []
  ) -> ToolOptionDefinition {
    .init(id: id, categoryID: category, flags: flags, title: title, summary: summary,
          valueKind: .none, risk: risk, requiresOptionIDs: requires,
          conflictsWithOptionIDs: conflicts, order: order)
  }

  private static func v(
    _ id: String, _ category: String, _ flags: [String], _ title: String,
    _ summary: String, _ kind: ToolValueKind, _ order: Int,
    _ risk: ToolRiskLevel = .standard, _ placement: ToolValuePlacement = .separated,
    _ requires: Set<String> = [], _ conflicts: Set<String> = []
  ) -> ToolOptionDefinition {
    .init(id: id, categoryID: category, flags: flags, title: title, summary: summary,
          valueKind: kind, valuePlacement: placement, risk: risk,
          requiresOptionIDs: requires, conflictsWithOptionIDs: conflicts, order: order)
  }
}
