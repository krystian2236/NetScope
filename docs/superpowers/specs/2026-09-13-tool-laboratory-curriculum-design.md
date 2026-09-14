# NetScope — program laboratoriów narzędziowych

## Cel

Połączyć edukacyjny Toolbox z osobnymi, kompletnymi programami laboratoriów dla
każdego narzędzia. Pierwszy etap obejmuje cztery pakiety: Nmap, Nuclei, Dig i
Curl. Po tym etapie interfejs zostanie zweryfikowany na symulatorze i pokazany
użytkownikowi przed rozpoczęciem kolejnych pakietów.

## Warianty i dostęp

### Demo

Demo pozostaje samodzielną, użyteczną aplikacją bez konta i zakupów. Zawiera
trzy obecne laboratoria Nmap: wykrywanie hostów, rozpoznawanie portów i usług
oraz podstawy SSH. Użytkownik wpisuje rozwiązania ręcznie i otrzymuje
stopniowane podpowiedzi.

### NetScope Pro

NetScope Pro jest jednym zakupem niekonsumowalnym. Pierwsze wydanie Pro
obejmuje sześć narzędzi: Nmap, Nuclei, Dig, Curl, WhatWeb i SSLScan. Zakup nie
wygasa i zawsze zachowuje dostęp do laboratoriów tych sześciu narzędzi.

Pierwszy etap implementacyjny kończy cztery pakiety: Nmap, Nuclei, Dig i Curl.
WhatWeb oraz SSLScan powstaną po akceptacji wyglądu i przepływu pierwszej
czwórki.

### NetScope Developer

Wariant Developer odblokowuje wszystkie lokalnie zaimplementowane pakiety,
gotowe rozwiązania oraz przyciski kopiowania i wstawiania. Wariant App Store
nie udostępnia tych ułatwień i nie zawiera przełącznika pozwalającego je
włączyć w czasie działania.

## Nawigacja Laboratorium

Laboratorium otrzymuje stały selektor programu:

1. **Nauka** — wprowadzenie, ścieżka, postęp i darmowe misje.
2. **Nmap** — osobne moduły zgodne z kategoriami katalogu Nmap.
3. **Nuclei** — osobne moduły zgodne z kategoriami katalogu Nuclei.
4. **Dig** — DNS i interpretacja odpowiedzi.
5. **Curl** — żądania HTTP, nagłówki, metody i odpowiedzi.

Selektor nie powiela Toolbox. Toolbox służy do składania poleceń, a
Laboratorium do wykonywania zadań w deterministycznym środowisku wirtualnym.

Każdy pakiet pokazuje kartę programu, liczbę ukończonych zadań i sekcje
tematyczne. Niedostępna zawartość pozostaje widoczna z oznaczeniem Pro oraz
krótkim opisem korzyści, ale bez atrap niedziałających przycisków.

## Model programu

Każde narzędzie definiuje:

- identyfikator, nazwę, ikonę i opis,
- poziom dostępu: Demo albo Pro,
- uporządkowane moduły odpowiadające kategoriom narzędzia,
- lekcje i zadania,
- powiązanie z opcjami istniejącego `ToolDefinition`,
- warunek ukończenia oparty na znaczeniu polecenia,
- objaśnienie wyniku oraz składni.

Katalog narzędzia jest źródłem prawdy. Test pokrycia wymaga, aby każda opcja
Nmap i Nuclei była przypisana do lekcji, ćwiczenia diagnostycznego albo jawnego
wyjaśnienia, dlaczego nie jest symulowana.

## Kombinacje poleceń

Program nie tworzy iloczynu wszystkich flag. Zamiast tego obejmuje:

- pojedyncze opcje wymagające wyjaśnienia,
- praktyczne, zgodne kombinacje używane w typowym przepływie,
- konflikty jako zadania uczące diagnozowania błędnej składni,
- warianty celów i wartości wpływające na wynik,
- bezpieczne przykłady wykonywane wyłącznie przez `VirtualLabEngine`.

Każde prezentowane polecenie jest rozdzielane na kategorie:

- Narzędzie,
- Typ lub operacja,
- Opcje,
- Cel,
- dodatkowe dane, np. użytkownik, port, nagłówek albo metoda HTTP.

Każdy fragment ma ikonę informacji oraz krótki opis. Rozdzielenie jest
realizowane przez model danych, a nie analizę tekstu w widoku SwiftUI.

## Zakres pierwszych czterech pakietów

### Nmap

Moduły odpowiadają katalogowi: cele, wykrywanie hostów, techniki skanowania,
porty, usługi i wersje, system operacyjny, czas, zapory, wynik i pozostałe
opcje. Symulator realizuje bezpieczne scenariusze; operacje wymagające surowych
pakietów lub specjalnego środowiska otrzymują kompletne ćwiczenia opisowe.

### Nuclei

Oddzielny program obejmuje cele, szablony, filtrowanie, wyjście, konfigurację,
tempo, optymalizacje i interpretację znalezisk. Laboratorium nie pobiera
szablonów, nie łączy się z Internetem i nie wykonuje prawdziwych testów.

### Dig

Program obejmuje zapytania A, AAAA, PTR, MX, TXT i NS, wybór serwera DNS,
krótką odpowiedź, sekcje odpowiedzi i podstawową diagnostykę typowych błędów.

### Curl

Program obejmuje URL, metodę, nagłówki, ciało żądania, przekierowania,
uwierzytelnienie jako wiedzę bez zapisywania sekretów, TLS, limity czasu oraz
interpretację statusu i nagłówków odpowiedzi. Wszystkie hosty i odpowiedzi są
lokalne i symulowane.

## Uprawnienia Pro

Warstwa dostępu rozróżnia `demo`, `pro` i kompilacyjny wariant Developer.
Darmowe misje działają bez StoreKit i Internetu. Uprawnienie Pro pochodzi z
StoreKit 2 i można je przywrócić. Niedostępność sklepu nie blokuje Demo.

StoreKit zostanie podłączony po ukończeniu i zaakceptowaniu struktury czterech
pakietów. Do tego czasu testy korzystają z wstrzykiwanego stanu dostępu, a
interfejs nie udaje przeprowadzenia prawdziwego zakupu.

## Postęp i reset

Postęp zapisuje identyfikator programu, modułu i zadania. Reset pojedynczej
misji nie wpływa na inne zadania. Reset programu czyści tylko wybrane
narzędzie, a reset całości wymaga potwierdzenia i usuwa wyłącznie lokalny
postęp laboratoriów.

## Bezpieczeństwo

- Żadne polecenie nie trafia do systemowej powłoki ani procesu zewnętrznego.
- Wszystkie odpowiedzi pochodzą z deterministycznych scenariuszy lokalnych.
- Aplikacja nie zapisuje haseł, tokenów, kluczy ani wartości pól oznaczonych
  jako sekretne.
- Prawdziwy skaner własnej sieci pozostaje osobnym, świadomym działaniem.
- Wariant App Store nie zawiera gotowych odpowiedzi Developer.

## Obsługa błędów

Niepoprawna składnia pozostaje w historii i otrzymuje neutralne wyjaśnienie z
ikoną informacji. Sprzeczne opcje wskazują konflikt i sposób poprawy. Brak
uprawnienia pokazuje zakres Pro, ale nie blokuje darmowych zadań ani całej
nawigacji.

## Weryfikacja

Automatyczne testy obejmują:

- kolejność programów i poziomy dostępu,
- mapowanie kategorii i pokrycie opcji katalogu,
- poprawne oraz konfliktowe kombinacje,
- deterministyczne wyniki czterech narzędzi,
- rozdzielenie polecenia na opisane fragmenty,
- zapis i reset postępu,
- brak gotowych odpowiedzi w wariancie App Store,
- pełny dostęp w wariancie Developer.

Po pierwszych czterech pakietach wykonywany jest build obu wariantów, testy
regresji i `git diff --check`. Następnie uruchamiany jest wyłącznie symulator
NetScope Developer i powstaje zrzut menu oraz przykładowego podziału polecenia.
Na tym etapie aplikacja nie jest instalowana na fizycznym iPhonie.

## Kryterium gotowości etapu

- Nmap, Nuclei, Dig i Curl mają osobne, działające programy laboratoriów.
- Każda opcja katalogu Nmap i Nuclei ma jawny status pokrycia edukacyjnego.
- Demo nadal zawiera trzy użyteczne laboratoria i działa bez zakupu.
- Pro i Developer odblokowują właściwe programy bez mieszania wariantów.
- Menu oraz budowa polecenia są czytelne na zrzucie z symulatora.
- Nie wykonano instalacji na fizycznym iPhonie.
