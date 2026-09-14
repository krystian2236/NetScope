# Toolbox syntax navigation design

## Cel

Toolbox ma uczyć składni narzędzia, a nie grupować polecenia według celu użytkownika. Dla każdego narzędzia użytkownik zaczyna od jego oficjalnej składni, wybiera część składni, następnie kategorię i konkretną opcję. Z wybranych elementów powstaje stale widoczne polecenie z opisem działania.

Pierwszy zakres obejmuje te same cztery narzędzia co Laboratorium: Nmap, Nuclei, Dig i Curl.

## Wspólny przepływ

1. Toolbox pokazuje narzędzia w kolejności: Nmap, Nuclei, Dig, Curl.
2. Po wejściu w narzędzie nagłówek z jego składnią pozostaje widoczny u góry.
3. Kliknięcie części składni wybiera główną sekcję.
4. Jeżeli sekcja ma podkategorie, użytkownik wybiera podkategorię.
5. Lista pokazuje flagę, polską nazwę, opis, wymagania i poziom ostrożności.
6. Kliknięcie opcji dodaje ją do polecenia; ponowne kliknięcie ją usuwa.
7. Opcja wymagająca wartości udostępnia odpowiednie pole lub wybór.
8. Nagłówek pokazuje wynikowe polecenie, kolejność fragmentów i opis całości.
9. Polecenie można skopiować. NetScope go nie wykonuje.

## Hierarchia narzędzi

### Nmap

Stała składnia:

`nmap [Scan Type(s)] [Options] {target specification}`

- `Scan Type(s)`: techniki skanowania, między innymi `-sS`, `-sT`, `-sU`, `-sA`, `-sW`, `-sM`, `-sN`, `-sF`, `-sX`, `--scanflags`, `-sI`, `-sY`, `-sZ`, `-sO` i `-b`.
- `Options`: Host Discovery, Ports and Scan Order, Service/Version Detection, NSE Scripts, OS Detection, Timing and Performance, Firewall/Evasion, Output oraz Miscellaneous.
- `target specification`: bezpośredni host, adres lub CIDR oraz `-iL`, `-iR`, `--exclude` i `--excludefile`.

Kategorie mają odpowiadać oficjalnemu skrótowi pomocy Nmap. Nazwy w interfejsie będą polskie, a oryginalny nagłówek będzie widoczny jako mniejszy podpis.

### Nuclei

Stała składnia:

`nuclei [flags]`

Główne sekcje odpowiadają pomocy CLI: Target, Templates, Filtering, Output, Configurations, Interactsh, Fuzzing, Uncover, Rate Limit, Optimizations, Headless, Debug, Update, Statistics, Cloud i Authentication. Istniejący katalog pozostaje źródłem opcji; zmienia się przede wszystkim nawigacja.

### Dig

Stała składnia:

`dig [@server] {name} [type] [options]`

Sekcje: serwer DNS, nazwa celu, typ rekordu oraz opcje zapytania, wyniku i diagnostyki. Katalog obejmuje opcje publikowane przez bieżącą dokumentację Dig; elementy wykorzystywane przez Laboratorium są oznaczone jako najczęstsze.

### Curl

Stała składnia:

`curl [options] {URL}`

Sekcje odpowiadają kategoriom pomocy Curl, między innymi URL, HTTP, nagłówki, dane żądania, przekierowania, TLS, limity czasu, uwierzytelnianie, proxy, połączenie i wynik. Katalog obejmuje opcje publikowane przez sprawdzoną wersję dokumentacji; elementy wykorzystywane przez Laboratorium są oznaczone jako najczęstsze.

## Nawigacja i wyszukiwanie

Nagłówek składni pełni rolę pierwszego poziomu nawigacji. Pod nim pojawiają się podkategorie wybranej części, a dopiero niżej opcje. Interfejs zapamiętuje wybraną sekcję podczas budowania bieżącego polecenia.

Przełącznik `Najczęstsze / Wszystkie` domyślnie pokazuje najczęstsze opcje, ale nigdy nie usuwa pozostałych z katalogu. Wyszukiwarka działa na fladze, nazwie i opisie wewnątrz wybranej części składni.

## Walidacja i bezpieczeństwo

- Sprzeczne lub niekompletne fragmenty pozostają w podglądzie i kopiowanym poleceniu.
- Interfejs oznacza je na czerwono i dokładnie opisuje problem, ale nie blokuje użytkownika.
- Opcje aktywne, plikowe, sieciowe albo wymagające podwyższonych uprawnień otrzymują ostrzeżenie.
- Sekrety wpisane w polach są maskowane w historii i opisach; NetScope nie zapisuje haseł, tokenów ani kluczy prywatnych.
- Toolbox wyłącznie buduje i kopiuje polecenia. Laboratorium pozostaje osobnym, deterministycznym środowiskiem offline.

## Model danych i komponenty

- `ToolDefinition` opisuje składnię, sekcje, podkategorie i opcje narzędzia.
- `ToolUsagePart` wskazuje część składni wybieraną w nagłówku.
- `ToolLearningView` zarządza wybraną sekcją, filtrem i wyszukiwaniem.
- `ToolCommandBuilder` składa fragmenty w poprawnej kolejności oraz tworzy opisy i ostrzeżenia.
- `NmapCatalog` i `NucleiCatalog` zostaną dopasowane do nowej hierarchii.
- Powstaną `DigCatalog` i `CurlCatalog` używające tego samego modelu oraz widoku.
- `ToolboxView` wyświetli cztery narzędzia w kolejności zgodnej z Laboratorium.

## Obsługa błędów

Brak wymaganej wartości, konflikt opcji lub nierozpoznany format generuje komunikat przy konkretnym fragmencie i zbiorcze wyjaśnienie pod komendą. Użytkownik może nadal skopiować polecenie do nauki i samodzielnego testowania. Pusta komenda zawiera przynajmniej nazwę programu i nie powoduje błędu widoku.

## Testy i weryfikacja

- test kolejności czterech narzędzi w Toolbox i Laboratorium;
- test nawigacji części składni do właściwych kategorii;
- test obecności `-iL` w `target specification`, a nie w technikach skanowania;
- test dodawania i ponownego usuwania opcji;
- test kolejności fragmentów polecenia;
- test zachowania sprzecznych fragmentów w kopiowanym poleceniu;
- test maskowania wartości tajnych;
- testy reprezentatywnych poleceń Nmap, Nuclei, Dig i Curl;
- `git diff --check`, odpowiednie testy jednostkowe, build Developer i ręczna kontrola na symulatorze iPhone 17.

## Poza zakresem

- wykonywanie poleceń z Toolbox;
- prawdziwy shell lub skanowanie zewnętrznych celów;
- płatności i nowe poziomy dostępu;
- wybór piątego i szóstego narzędzia Pro;
- zmiany w CipherPath i NetScope Android Demo.

## Źródła

- Nmap Options Summary: https://nmap.org/book/man-briefoptions.html
- Nuclei Running and CLI flags: https://docs.projectdiscovery.io/opensource/nuclei/running
- Curl man page: https://curl.se/docs/manpage.html
- BIND 9 Dig manual: https://bind9.readthedocs.io/en/latest/manpages.html#dig-dns-lookup-utility
