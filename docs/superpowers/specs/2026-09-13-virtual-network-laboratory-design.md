# NetScope — wirtualne laboratorium sieciowe

## Cel

NetScope ma uczyć podstaw diagnostyki sieciowej w bezpiecznym, realistycznym
środowisku. Użytkownik najpierw rozwiązuje zadania w całkowicie lokalnej,
symulowanej sieci, a po ukończeniu lekcji może przejść do ograniczonego skanu
własnej prywatnej sieci.

Pierwsze wydanie korzysta z modelu freemium: darmowe demo oraz jednorazowy zakup
NetScope Pro. Subskrypcja nie wchodzi w zakres pierwszego wydania.

Projekt udostępnia dwa jawnie rozdzielone warianty kompilacji. `NetScope App
Store` jest jedynym wariantem przeznaczonym do dystrybucji i nie zawiera trybu
deweloperskiego. `NetScope Developer` służy wyłącznie do lokalnej nauki i testów,
ma osobny identyfikator aplikacji oraz zachowuje konstruktor poleceń, który nie
blokuje poprawnych składniowo kombinacji, lecz pokazuje ich ryzyko. Żaden wariant
nie wykonuje poleceń utworzonych przez konstruktor.

## Zasady bezpieczeństwa

- Laboratorium nie uruchamia systemowego shella ani pobranego kodu.
- Interpreter obsługuje wyłącznie jawnie zdefiniowane polecenia i argumenty.
- Wszystkie hosty, usługi i odpowiedzi w laboratorium są symulowane lokalnie.
- Tryb laboratoryjny działa bez Internetu i bez uprawnienia do sieci lokalnej.
- Przejście do prawdziwego skanera jest wyraźną, osobną czynnością użytkownika.
- Rzeczywisty skaner zachowuje ograniczenie do prywatnych i lokalnych adresów.
- Aplikacja nie przechowuje haseł ani kluczy prywatnych.
- Postęp i konfiguracja pozostają lokalnie na urządzeniu.
- Funkcje wariantu Developer są wyłączone kompilacyjnie w buildzie App Store.

## Warianty aplikacji

### NetScope App Store

- Bundle identifier: `pl.krystian.NetScope`.
- Zawiera laboratorium offline, bezpieczny skaner prywatnej sieci i NetScope Pro.
- Nie zawiera przełącznika, ukrytej trasy ani kodu uruchamiającego widoki
  przeznaczone wyłącznie dla wariantu Developer.
- Toolbox prezentuje wyłącznie funkcje zaakceptowane dla dystrybucji.

### NetScope Developer

- Bundle identifier: `pl.krystian.NetScope.dev`.
- Nazwa na urządzeniu: `NetScope Dev`.
- Jest instalowany lokalnie i nie jest wysyłany do App Store Connect.
- Zachowuje edukacyjny konstruktor Nmap/Nuclei: ostrzeżenia są informacyjne,
  polecenie pozostaje możliwe do skopiowania, a aplikacja go nie wykonuje.
- Używa oddzielnego kontenera danych dzięki osobnemu bundle identifier.

## Architektura

### VirtualLabEngine

Interpretuje tekst polecenia, normalizuje składnię i przekazuje poprawne
polecenia do symulatora. Zwraca jednoznaczny wynik: poprawne wykonanie, błąd
składni, nieobsługiwane polecenie albo podpowiedź edukacyjną. Nie korzysta z
`Process`, powłoki systemowej ani zdalnego wykonywania.

### VirtualNetwork

Opisuje deterministyczną sieć ćwiczeniową: router, Mac, serwer i dodatkowe
urządzenie. Każdy host ma stały adres, nazwę, porty oraz usługi. Model odpowiada
na obsługiwane zapytania tak, aby kolejne kroki misji dawały spójne wyniki.

### LabMission

Definiuje cel, treść wprowadzenia, dostępne podpowiedzi, akceptowane rozwiązania,
warunki ukończenia i objaśnienie rezultatu. Misja ocenia znaczenie polecenia, a
nie wyłącznie identyczność wpisanego tekstu.

### TerminalLessonView

Prezentuje historię poleceń i odpowiedzi, aktywny prompt, cel misji, postęp oraz
opcjonalne podpowiedzi. Wyniki zawierają rozwijane objaśnienia flag, adresów,
portów i usług. Ponowne otwarcie widoku przywraca bieżący etap.

### TryOnOwnNetwork

Po ukończeniu odpowiedniego etapu pokazuje różnicę pomiędzy symulacją a
rzeczywistym skanem. Następnie przekazuje użytkownika do istniejącego skanera z
bezpiecznym profilem startowym. Dopiero działanie w prawdziwym skanerze może
wywołać systemową prośbę o dostęp do sieci lokalnej.

### EntitlementStore

Izoluje integrację StoreKit 2 od interfejsu laboratoriów. Udostępnia stan demo,
NetScope Pro oraz przywracanie zakupu. Brak połączenia ze sklepem nie może
blokować darmowej zawartości.

## Przepływ użytkownika

1. Użytkownik wybiera laboratorium i ogląda schemat wirtualnej sieci.
2. Otrzymuje pojedynczy, jasno opisany cel.
3. Wpisuje polecenie w symulowanym terminalu.
4. Silnik zwraca realistyczny wynik i objaśnienie jego elementów.
5. Błędna składnia pozostaje widoczna oraz otrzymuje wskazówkę naprawczą.
6. Poprawne rozwiązanie zapisuje postęp i odblokowuje kolejny etap.
7. Po ukończeniu lekcji użytkownik może wybrać „Wypróbuj we własnej sieci”.
8. Aplikacja przechodzi do istniejącego skanera, nie wykonując skanu automatycznie.

## Zakres darmowego demo

Demo zawiera jedną wirtualną sieć oraz trzy kompletne laboratoria:

1. Wykrywanie hostów — rozpoznanie aktywnych urządzeń w prywatnej podsieci.
2. Porty i usługi — identyfikacja otwartych portów oraz znaczenia usług.
3. Podstawy SSH — zrozumienie hosta, użytkownika, klucza i bezpiecznego
   połączenia bez przechowywania danych uwierzytelniających.

Każde laboratorium zawiera wprowadzenie, zadania, stopniowane podpowiedzi,
realistyczne wyniki, objaśnienia i podsumowanie. Demo udostępnia ograniczony,
bezpieczny profil rzeczywistego skanowania. Nie wymaga konta ani chmury.

## NetScope Pro

NetScope Pro jest jednorazowym zakupem i odblokowuje:

- pełną bibliotekę laboratoriów dostępną w danej wersji aplikacji,
- rozszerzone profile skanowania,
- pełną historię i porównywanie wyników,
- dodatkowe narzędzia edukacyjne oznaczone jako Pro.

Darmowe lekcje pozostają użyteczne bez zakupu. Interfejs udostępnia cenę,
przywracanie zakupu i jasny opis odblokowywanej zawartości. Przyszła subskrypcja
może zostać zaprojektowana osobno dopiero wtedy, gdy aplikacja będzie dostarczać
regularne, istotne pakiety nowych laboratoriów.

## Obsługa błędów

- Nieznane polecenie: krótka informacja, lista najbliższych poleceń i podpowiedź.
- Niepoprawna flaga lub wartość: wskazanie fragmentu i przykład poprawnej składni.
- Poprawne alternatywne rozwiązanie: zaliczenie na podstawie znaczenia polecenia.
- Brak Internetu: pełna dostępność laboratorium i zapisanego postępu.
- Niedostępny StoreKit: demo działa, a zakup można ponowić później.
- Brak dostępu do sieci lokalnej: prawdziwy skan wyjaśnia problem; laboratorium
  pozostaje dostępne.

## Dane i prywatność

Lokalnie przechowywane są wyłącznie postęp, ustawienia lekcji, historia
symulowanych poleceń i stan odblokowania zwrócony przez StoreKit. Laboratorium
nie wysyła wpisanych poleceń ani wyników. Rzeczywiste wyniki skanowania pozostają
objęte istniejącą polityką lokalnego przechowywania NetScope.

## Weryfikacja

Automatyczne testy obejmują:

- parser poleceń i warianty poprawnej składni,
- odrzucanie nieobsługiwanych operacji bez ich wykonania,
- deterministyczne odpowiedzi wirtualnej sieci,
- warunki ukończenia i kolejność etapów,
- zapis oraz przywracanie postępu,
- przejście do bezpiecznego profilu rzeczywistego skanera,
- dostępność darmowych lekcji bez StoreKit,
- blokady Pro, zakup i przywracanie uprawnienia.

Weryfikacja ręczna obejmuje pełne przejście trzech laboratoriów na iPhonie 17,
tryb offline, odmowę dostępu do sieci lokalnej, Dynamic Type, VoiceOver oraz
zakupy StoreKit w środowisku testowym. Przed TestFlight wymagane są także build
Release, kontrola manifestu prywatności i kompletne informacje dla App Review.

## Kryteria gotowości demo

- Wszystkie trzy laboratoria można ukończyć bez połączenia z siecią.
- Żaden tekst terminala nie jest wykonywany poza symulatorem laboratorium.
- Błędy uczą poprawnego rozwiązania i nie niszczą postępu.
- Przejście do własnej sieci wymaga świadomego działania użytkownika.
- Darmowa zawartość działa bez zakupu i bez logowania.
- Testy automatyczne, build Release oraz ręczna ścieżka demo kończą się pomyślnie.
