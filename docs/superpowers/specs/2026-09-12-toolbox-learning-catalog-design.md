# Northbyte Radar Toolbox — katalog edukacyjny Nmap i Nuclei

Data: 2026-09-12

## Cel

Toolbox ma uczyć składania poprawnych poleceń Nmap i Nuclei poprzez wybieranie opisanych fragmentów. Użytkownik widzi pełną składnię, znaczenie każdego elementu, wymagania, ostrzeżenia i wynikowe polecenie. Northbyte Radar nie wykonuje skanów — przygotowuje polecenie do świadomego użycia na własnych systemach lub za zgodą właściciela.

## Nawigacja

Ekran Toolbox zawiera dwa równorzędne kafelki:

1. Nmap — rozpoznanie hostów, portów, usług i systemów.
2. Nuclei — kontrole oparte na szablonach.

Każdy kreator ma stale widoczny nagłówek z poleceniem, przyciskiem kopiowania, opisem działania oraz listą błędów i ostrzeżeń. Poniżej znajduje się rozwijany katalog kategorii. W danym momencie rozwinięta jest jedna kategoria, aby ograniczyć bałagan na małym ekranie.

## Wspólny model katalogu

Każda opcja narzędzia opisuje:

- stabilny identyfikator,
- kategorię,
- krótką i długą nazwę flagi,
- polski tytuł oraz opis działania,
- rodzaj wartości: brak, tekst, liczba, czas, ścieżka, lista lub wybór,
- wartość przykładową i regułę walidacji,
- zależności oraz konflikty z innymi opcjami,
- poziom informacji: standardowy, ostrzeżenie lub zaawansowany,
- wymagania, takie jak podwyższone uprawnienia, dostęp sieciowy albo plik lokalny,
- kolejność fragmentu w poleceniu.

Stan kreatora przechowuje wybrane opcje, wartości parametrów i cel. Generator tworzy uporządkowane fragmenty polecenia oraz niezależne objaśnienie każdego fragmentu. Ponowne dotknięcie opcji usuwa ją wraz z niepotrzebną wartością.

## Kolory i walidacja

- Zielony oznacza poprawny podstawowy fragment.
- Fioletowy oznacza poprawną dodatkową opcję.
- Turkusowy oznacza cel.
- Pomarańczowy oznacza poprawną opcję wymagającą szczególnej uwagi.
- Czerwony oznacza błąd składni, brak wartości albo konflikt.

Poprawne polecenie pozostaje możliwe do skopiowania także wtedy, gdy zawiera pomarańczowe opcje. Czerwone fragmenty pozostają widoczne do nauki, lecz nie trafiają do kopiowanej komendy. Każdy błąd wyjaśnia, co należy poprawić.

## Katalog Nmap

Kategorie odpowiadają oficjalnej dokumentacji Nmap:

1. Specyfikacja celu.
2. Wykrywanie hostów.
3. Techniki skanowania.
4. Porty i kolejność.
5. Detekcja usług i wersji.
6. Detekcja systemu operacyjnego.
7. Wydajność i zależności czasowe.
8. Wyjście.
9. Różne.
10. Zaawansowane: firewall, IDS i podszywanie się.

Katalog obejmuje opcje ze skróconej pomocy aktualnego Nmap. Opcje zależne od plików, interfejsów, surowych pakietów lub podwyższonych uprawnień są widoczne i opisane, ale oznaczone jako wymagające uwagi. Nieaktualne aliasy z polskiego tłumaczenia, takie jak `-sP` i `-P0`, są prezentowane jako wiedza historyczna, natomiast generator używa współczesnych odpowiedników `-sn` i `-Pn`.

## Katalog Nuclei

Kategorie odpowiadają aktualnej pomocy Nuclei:

1. Common.
2. Target.
3. Target format.
4. Templates.
5. Filtering.
6. Output.
7. Configurations.
8. Interactsh.
9. Fuzzing i DAST.
10. Uncover.
11. Rate limit.
12. Optimizations.
13. Headless.
14. Debug.
15. Update.
16. Honeypot.
17. Statistics.
18. Cloud.
19. Authentication.

Minimalne poprawne polecenie wymaga celu albo trybu, który celu nie potrzebuje, na przykład listowania lub walidacji szablonów. Generator preferuje `-u` dla pojedynczego celu. Wartości wielokrotne są przechowywane jako lista i bezpiecznie cytowane.

Opcje DAST, Interactsh, Uncover, chmury, uwierzytelniania, własnych nagłówków, plików lokalnych, kodu, AI oraz aktualizacji są dostępne edukacyjnie. Otrzymują szczegółowe ostrzeżenia o ruchu sieciowym, usługach zewnętrznych, sekretach, kosztach lub modyfikacji lokalnego środowiska. Northbyte Radar nie zapisuje sekretów i nie oferuje gotowych wartości tokenów, haseł, kluczy ani ciasteczek.

## Źródła i aktualność

Metadane Nmap są oparte na oficjalnej skróconej pomocy i aktualnej składni programu. Metadane Nuclei są oparte na pomocy `nuclei -h` publikowanej przez Kali. Wersja źródła i data przeglądu są pokazywane w aplikacji. Katalog jest zapisany lokalnie i nie pobiera dokumentacji przy każdym uruchomieniu.

## Bezpieczeństwo danych

- Aplikacja nie uruchamia poleceń ani skanów Nmap/Nuclei.
- Aplikacja nie przechowuje historii wpisanych sekretów.
- Pola mogące zawierać sekret wyświetlają ostrzeżenie i nie są utrwalane.
- Cel publiczny jest dopuszczony składniowo, ale oznaczony ostrzeżeniem o wymaganej zgodzie.
- Funkcje modyfikujące instalację lub konfigurację są oddzielone od zwykłych opcji skanowania.

## Podział kodu

- `ToolboxCatalogModel.swift` — wspólne typy kategorii, opcji, wartości i poziomów informacji.
- `NmapCatalog.swift` — pełne metadane oraz reguły Nmap.
- `NucleiCatalog.swift` — pełne metadane oraz reguły Nuclei.
- `ToolCommandBuilder.swift` — bezpieczne składanie i cytowanie fragmentów.
- `ToolLearningView.swift` — wspólny interfejs kategorii, wyborów i opisów.
- `ToolboxView.swift` — lista narzędzi oraz wejścia do kreatorów.

Istniejące typy Nmap zostaną przeniesione stopniowo. Na każdym etapie aplikacja ma się kompilować, a zachowanie istniejącego kreatora pozostaje pokryte testami.

## Testy

Testy jednostkowe obejmują:

- kolejność kategorii i opcji,
- minimalne poprawne polecenia,
- opcje bez wartości oraz ze wszystkimi rodzajami wartości,
- cytowanie tekstu i list,
- dodawanie i usuwanie opcji,
- wymagane wartości, zakresy liczb i formaty czasu,
- zależności i konflikty,
- wykluczanie czerwonych fragmentów z kopiowanego polecenia,
- ostrzeżenia dla opcji zaawansowanych,
- brak utrwalania pól sekretów,
- zgodność dotychczasowego działania Nmap.

Po testach katalogu zostaną wykonane pełne testy aplikacji, `git diff --check`, świeży build i uruchomienie na iPhonie 17 Simulator. Instalacja na fizycznym iPhonie nastąpi dopiero po osobnym poleceniu użytkownika.

## Etapy wdrożenia

1. Wspólny model katalogu i generator poleceń.
2. Katalog oraz kreator Nuclei.
3. Migracja i uzupełnienie pełnego katalogu Nmap.
4. Wspólny interfejs edukacyjny i dopracowanie dostępności.
5. Regresja, kontrola diffu i test na symulatorze.

Każdy etap jest osobną małą zmianą z testem RED, minimalną implementacją GREEN i ponowną weryfikacją.
