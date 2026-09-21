# Toolbox semantic colors and command layout design

## Cel

Toolbox ma jednoznacznie pokazywać, które elementy składni i opcje tworzą poprawne polecenie, które można jeszcze dodać, a które spowodują konflikt. Interfejs nadal służy do nauki: nie blokuje błędnych kombinacji, lecz natychmiast oznacza je na czerwono i wyjaśnia problem.

Zmiana dotyczy wyłącznie NetScope. Oznaczenia obszarów `TB-*` oraz możliwość ich kopiowania pozostają dostępne tylko w wariancie Developer.

## Układ ekranu

U góry pozostają nieruchome dwa obszary, w tej kolejności:

1. `[TB-COMMAND]`
2. `[TB-SYNTAX]`

Lista kategorii i opcji poniżej jest przewijana.

### TB-COMMAND

Obszar zawiera:

- wynikowe polecenie i przycisk kopiowania;
- `[TB-FRAGMENTS]` z rzeczywistą kolejnością fragmentów;
- tekst „Co zrobi”;
- opis działania albo dokładne wyjaśnienie błędu.

Nie powiela nawigacji po kategoriach ani pełnych opisów poszczególnych opcji.

### TB-SYNTAX

Pokazuje stałą składnię narzędzia. Każda wybieralna część ma własny kolor:

- typ skanu — niebieski;
- opcje — fioletowy;
- cel — turkusowy;
- pozostałe części składni innych narzędzi otrzymują stabilny kolor przypisany do sekcji.

Aktywna część ma pełne tło w swoim kolorze. Dotknięcie części składni zmienia jeden obszar treści poniżej. Jeżeli część ma kilka kategorii, najpierw widoczne są poziome kategorie, a pod nimi opcje aktywnej kategorii.

### TB-OPTIONS

Każda pozycja ma prosty pionowy układ:

```text
-sY
SCTP INIT
Skanuje usługi SCTP pakietami INIT.
```

Flaga jest elementem głównym i używa czcionki monospaced. Nazwa i opis znajdują się w kolejnych wierszach bez ograniczenia do jednej linii. Wymagania i powód konfliktu pojawiają się niżej tylko wtedy, gdy są potrzebne.

## Semantyczne stany opcji

Model udostępnia jeden stan prezentacji dla każdej opcji w kontekście bieżącego wyboru:

- `compatible` — niewybrana opcja może zostać dodana; używa koloru aktywnej sekcji;
- `selectedValid` — opcja jest wybrana i poprawna; świeci na zielono;
- `conflicting` — dodanie opcji albo jej aktualny wybór tworzy konflikt; jest czerwona;
- `incomplete` — wybranej opcji brakuje wartości lub wymaganej opcji; jest czerwona.

Stan jest informacyjny. Użytkownik może dotknąć czerwonej opcji, skopiować wynik i zobaczyć dokładne wyjaśnienie. Toolbox niczego nie wykonuje i niczego nie blokuje.

Kolor ostrzegający o ryzyku sieciowym pozostaje w opisie jako ikona i tekst. Nie zastępuje koloru poprawności, dzięki czemu pomarańczowy nie jest mylony z błędem składni.

## Konflikty Nmap

Ocena technik skanowania używa rodzin semantycznych zamiast ręcznego wpisywania każdej pary:

- najwyżej jedna podstawowa technika TCP;
- `-sU` może współistnieć z jedną techniką TCP;
- najwyżej jedna technika SCTP (`-sY` albo `-sZ`) może współistnieć z jedną techniką TCP;
- `-sO`, idle scan oraz FTP bounce są oceniane zgodnie z ograniczeniami swojej techniki;
- `--scanflags` uwzględnia wybraną bazową technikę TCP;
- istniejące wymagania i jawne konflikty katalogu nadal obowiązują.

Przykład: po wybraniu `-sS`, opcje `-sW` i `-b` stają się czerwone, a `-sU` pozostaje zgodne.

## Kolejność fragmentów i celu

Użytkownik nie przeciąga fragmentów ręcznie. Każdy katalog opisuje kanoniczne fazy argumentów:

1. program;
2. argumenty wymagane przed celem;
3. cel;
4. argumenty występujące po celu.

Builder automatycznie układa fragmenty według fazy, kolejności katalogowej i identyfikatora. Dzięki temu:

- Nmap otrzymuje techniki i opcje przed celem;
- Curl otrzymuje opcje przed URL;
- Dig otrzymuje serwer przed nazwą, a typ rekordu i przełączniki po nazwie;
- Nuclei zachowuje kanoniczną kolejność flag określoną w katalogu.

`[TB-FRAGMENTS]` zawsze pokazuje dokładnie tę samą kolejność, która trafi do kopiowanego polecenia.

## Opis polecenia i błędy

`[TB-COMMAND]` generuje zwięzły opis całego polecenia na podstawie wybranych fragmentów. Gdy polecenie jest niepoprawne:

- nadal zawiera wszystkie wybrane fragmenty;
- czerwone fragmenty pozostają kopiowalne;
- opis wskazuje konkretną brakującą wartość, zależność albo konflikt;
- nie pojawia się ogólny komunikat bez wskazania przyczyny.

## Model i komponenty

- `ToolOptionPresentationState` oblicza kolor i stan opcji.
- `ToolCompatibilityEvaluator` ocenia wymagania, jawne konflikty i reguły rodzin Nmap.
- `ToolArgumentPhase` opisuje pozycję fragmentu względem celu.
- `ToolCommandBuilder` układa polecenie i generuje opis bez blokowania błędnych fragmentów.
- `ToolLearningView` renderuje nieruchome `TB-COMMAND` i `TB-SYNTAX` oraz przewijaną listę.
- katalogi narzędzi pozostają źródłem flag, nazw, opisów, wymagań i ryzyka.

## Weryfikacja

Testy jednostkowe obejmą:

- wszystkie stany prezentacji opcji;
- konflikt `-sS` z `-sW` i `-b`;
- zgodność `-sS` z `-sU`;
- ponowne dotknięcie i usunięcie opcji;
- brak wartości i brak wymaganej opcji;
- automatyczną kolejność celu dla Nmap, Nuclei, Dig i Curl;
- identyczną kolejność w `TB-FRAGMENTS` i kopiowanym poleceniu;
- generowanie opisu poprawnej i błędnej komendy.

Końcowa kontrola obejmie pełne testy NetScope, build Developer, build App Store, `git diff --check` oraz instalację wyłącznie NetScope Developer na istniejącym symulatorze iPhone 17. Ręczna kontrola sprawdzi kolory, Dynamic Type, przewijanie kategorii i czy nieruchomy nagłówek nie zasłania listy.

## Poza zakresem

- wykonywanie poleceń z Toolbox;
- prawdziwe skanowanie zewnętrznych celów;
- zmiany w Laboratorium, CipherPath lub projektach Android;
- płatności i podział Demo/Pro;
- commit, push albo publikacja bez osobnej zgody użytkownika.

## Źródło reguł Nmap

- https://nmap.org/book/man-port-scanning-techniques.html
