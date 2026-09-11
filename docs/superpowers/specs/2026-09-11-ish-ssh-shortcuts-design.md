# Panel iSH + Mac przez SSH

Data: 2026-09-11

## Cel

Usunąć ze Startu skróty dublujące pięć dolnych zakładek i zastąpić je jednym wejściem do uporządkowanej biblioteki poleceń dla użytkowników posiadających iPhone, iSH oraz Maca dostępnego przez SSH.

NetScope wyłącznie przygotowuje i kopiuje polecenia. Nie nawiązuje połączenia SSH, nie uruchamia poleceń, nie przechowuje hasła ani klucza prywatnego.

## Nawigacja

Ekran Start nie pokazuje przycisków „Skan”, „Urządzenia”, „Nmap” i „Usługi”, ponieważ te funkcje są stale dostępne na dolnym pasku.

W ich miejscu znajduje się jedna karta „iSH + Mac przez SSH” z krótkim opisem i strzałką. Karta otwiera ekran biblioteki skrótów w bieżącym stosie nawigacji; nie powstaje szósta zakładka.

## Ekran wymagań

Na początku biblioteki widoczna jest zwijana sekcja przygotowania:

1. iSH jest zainstalowany na iPhonie.
2. Na Macu włączono Zdalne logowanie dla właściwego użytkownika.
3. Użytkownik zna nazwę konta oraz prywatny adres lub nazwę Maca.
4. iPhone ma trasę do Maca: ta sama sieć, VPN albo świadomie skonfigurowany zdalny SSH.
5. Użytkownik ma zgodę na diagnostykę wskazanego urządzenia i sieci.

Formularz zawiera opcjonalne pola „Użytkownik” i „Host Maca”. Dane służą tylko do zbudowania tekstu poleceń. Są przechowywane lokalnie w `UserDefaults`; nie obejmują sekretów. Przycisk „Wyczyść dane” usuwa oba pola.

## Biblioteka skrótów

Polecenia są pogrupowane w kolejności pracy:

1. **Połączenie z Maciem** — test połączenia, pierwsze logowanie i wyjście z sesji.
2. **Informacje o sieci** — interfejs, adres IPv4, brama, DNS i tablica sąsiadów.
3. **Wykrywanie urządzeń** — lekkie rozpoznanie prywatnej podsieci.
4. **DNS i nazwy** — rozpoznanie nazwy hosta oraz odwrotnego DNS.
5. **Porty i usługi** — pięć zatwierdzonych etapów Nmap, od urządzeń do analizy pojedynczego hosta.
6. **Raporty** — utworzenie katalogu, zapis wyników tekstowych i podgląd ostatnich raportów.

Każdy skrót zawiera:

- przyjazny tytuł i jednozdaniowy opis skutku,
- etykietę miejsca wykonania: „Wklej w iSH przed SSH” albo „Wklej po zalogowaniu na Maca”,
- polecenie domyślnie zwinięte,
- przycisk „Kopiuj”, który zmienia stan na „Skopiowano”,
- blokadę z wyjaśnieniem, gdy polecenie wymaga nieuzupełnionego użytkownika lub hosta.

Lista jest wyszukiwalna po tytule, opisie i kategorii. Nie będzie ulubionych, historii poleceń ani synchronizacji w pierwszej wersji.

## Bezpieczeństwo

- Cele sieciowe muszą przejść istniejącą walidację prywatnych adresów IPv4 i podsieci.
- Polecenia wykorzystują bezpieczne cytowanie parametrów i nie łączą niesprawdzonego tekstu z powłoką.
- Brak poleceń destrukcyjnych, `sudo`, łamania haseł, exploitów, trwałej zmiany usług lub reguł zapory.
- Działania wymagające instalacji są wyraźnie oznaczone i tylko kopiowane.
- Widoczna informacja przypomina o używaniu wyłącznie własnej sieci lub pracy za zgodą właściciela.
- Aplikacja nie będzie deklarować, że polecenie zostało wykonane; potwierdza wyłącznie skopiowanie tekstu.

## Integracja z Nmap

Pięć etapów w zakładce Nmap pozostaje bez zmian. Otwarcie etapu prowadzi do odpowiadającego mu skrótu iSH/SSH oraz ustawia wykryty adres lub podsieć jako proponowany cel. Szczegóły techniczne pozostają domyślnie zwinięte.

Postęp jest ręczny: użytkownik oznacza etap jako ukończony dopiero po wykonaniu polecenia i sprawdzeniu wyniku. NetScope nie interpretuje jeszcze wklejonych raportów.

## Struktura kodu

- `DashboardView`: pojedyncza karta wejściowa zamiast zduplikowanych szybkich działań.
- `ISHToolkit`: modele kategorii, skrótów, wymagań oraz bezpieczne budowanie poleceń.
- `ISHToolkitView`: biblioteka, wyszukiwanie, konfiguracja użytkownika/hosta i kopiowanie.
- `AppShellView`: bez zmiany pięciu głównych zakładek.
- `NetScopeTests`: kolejność kategorii, blokady brakujących danych, walidacja prywatnych celów i dokładny tekst krytycznych poleceń.

Nie powstaje klient SSH ani nowa zależność zewnętrzna.

## Obsługa błędów i dostępność

Brak hosta lub użytkownika pokazuje instrukcję uzupełnienia danych zamiast niepoprawnego polecenia. Niedozwolony cel pokazuje komunikat o prywatnej sieci. Kopiowanie przekazuje użytkownikowi wizualne i dostępnościowe potwierdzenie.

Elementy mają pełne etykiety VoiceOver, odpowiedni obszar dotyku i nie opierają znaczenia wyłącznie na kolorze.

## Weryfikacja

1. Testy jednostkowe modeli i generatorów poleceń.
2. Kompilacja wszystkich testów dla symulatora.
3. Pełne uruchomienie testów na iPhonie 18 Pro, jeśli `CoreSimulatorService` działa.
4. Build Release dla fizycznego iOS oraz skrypt integralności bundle.
5. Ręczna kontrola na symulatorze: Start, karta wejściowa, wyszukiwanie, blokady, kopiowanie i powrót do zakładki Nmap.
6. `git diff --check` oraz potwierdzenie, że Porty, Ping i Bonjour nadal są dostępne w „Usługach”.

## Kryteria ukończenia

- Start nie dubluje dolnej nawigacji.
- Biblioteka jest dostępna przez jedną kartę i jasno wskazuje wymagania iSH/SSH.
- Skróty jedynie kopiują polecenia i nigdy nie wykonują ich w tle.
- Brak sekretów w pamięci aplikacji.
- Pięć etapów Nmap współdziała z biblioteką.
- Wszystkie dotychczasowe funkcje sieciowe pozostają dostępne.
