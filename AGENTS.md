# Zasady pracy nad NetScope

Te instrukcje obowiązują Codex, ChatGPT oraz GitHub Copilot podczas pracy w tym repozytorium.

## Sposób pracy

- Odpowiadaj po polsku, krótko i konkretnie.
- Najpierw sprawdź bieżący stan repozytorium, odpowiedni diff i wskazane pliki. Nie powtarzaj analizy, która została już wykonana i nadal jest aktualna.
- Domyślnie wykonuj diagnostykę tylko do odczytu. Zmieniaj pliki dopiero po jednoznacznym zatwierdzeniu zakresu.
- Realizuj jedną małą, logiczną zmianę naraz. Nie modyfikuj plików niezwiązanych z zadaniem.
- Nie uruchamiaj drugiego agenta nad tym samym zakresem zmian. Przed rozpoczęciem pracy ustal, czy bieżący diff należy do użytkownika, Copilota lub Codex.
- Używaj możliwie małego kontekstu: najpierw `git status`, potem diff wskazanych plików, następnie tylko pliki wymagane przez zadanie.
- Nie uruchamiaj pełnych skanów, wszystkich narzędzi ani wielokrotnych buildów, jeżeli węższa weryfikacja wystarcza.

## Bezpieczeństwo i Git

- Nigdy nie ujawniaj, zapisuj ani commituj tokenów, haseł, kluczy prywatnych, plików `.env`, danych uwierzytelniających lub danych osobowych.
- Diagnostykę sieci wykonuj wyłącznie dla prywatnych adresów użytkownika albo systemów, na których testowanie ma zgodę właściciela.
- NetScope może przygotowywać i kopiować polecenia SSH, ale nie może przechowywać haseł ani kluczy prywatnych.
- Nie wykonuj commita, pushu, instalacji, usuwania, zmiany uprawnień, publikacji ani wysyłki do App Store bez jednoznacznego polecenia użytkownika.
- Nie używaj force push i nie zmieniaj istniejącej historii Git.
- Przed proponowanym push uruchom `./scripts/pre-push-check.sh` i podaj jego rzeczywisty wynik.
- Stosuj małe commity Conventional Commits z angielskim tytułem do 72 znaków.

## Weryfikacja

Każdy nowy użytkowy ekran, zakładka, navigation destination, sheet, fullScreenCover, ekran szczegółów lub osobne narzędzie musi otrzymać stabilny UIREF przed uznaniem zadania za zakończone. Przy dodawaniu ekranu należy dodać case i metadane do pliku UIRef.swift, umieścić UIRefCopyButton bezpośrednio na właściwym ekranie, użyć prefiksu NETSCOPE, nie duplikować identyfikatorów, ograniczyć UIREF do NETSCOPE_DEV i uwzględnić go w raporcie końcowym. Jeśli funkcja dodaje kilka oddzielnych ekranów, każdy otrzymuje własny UIREF.

- Dobierz najwęższe testy obejmujące zmianę, następnie wykonaj `git diff --check`.
- Nie twierdź, że testy przeszły, jeśli zostały tylko skompilowane albo ich uruchomienie zablokował symulator.
- Po zakończeniu podaj: wynik, zmienione pliki, wykonaną weryfikację i jedno krótkie zalecenie lub wniosek.

## App Store

- Przy zmianach wydaniowych sprawdź `Info.plist`, `PrivacyInfo.xcprivacy`, używane uprawnienia, deklaracje prywatności, numer wersji i zasoby aplikacji.
- Nie dodawaj prywatnych API, nieuzasadnionych uprawnień, ukrytego śledzenia ani zbierania danych bez wyraźnej potrzeby i zgody użytkownika.
- Nie obchodź procesu App Review i nie wysyłaj buildu do App Store Connect bez osobnego zatwierdzenia.

## TARGET / REFERENCE

- Jeśli polecenie użytkownika zawiera `UIREF:`, traktuj wskazany identyfikator jako główny zakres zadania. Najpierw odnajdź powiązany View/symbol i jego bezpośrednie zależności. Nie rozszerzaj zmian poza ten obszar bez uzasadnienia lub zgody użytkownika.

- Gdy Codex ma dostęp do kilku repozytoriów, jawnie ustal przed zmianami:
  - TARGET — repozytorium, które wolno modyfikować,
  - REFERENCE — repozytorium wyłącznie do odczytu i porównań.
- Nie modyfikuj REFERENCE bez osobnego polecenia użytkownika.
- Przy przenoszeniu funkcji, UI lub logiki z REFERENCE do TARGET najpierw przeanalizuj implementację, zależności i różnice architektury.
- Nie kopiuj kodu mechanicznie; dopasuj rozwiązanie do TARGET.


## Simulator iOS

### NetScope schemes

- Przypisany Simulator: `NET`
- UDID: `BCD82989-D19C-4E11-B5E2-4735427F09B7`
- Dotyczy zarówno scheme `NetScope Dev`, jak i `NetScope App Store`; oba używają targetu `NetScope`.
- Wszystkie polecenia `xcodebuild`, `simctl`, install, launch oraz screenshoty dla NetScope wykonuj na tym UDID.
- Nie wybieraj automatycznie innego Simulatora.
- Jeśli ten UDID nie jest dostępny, zatrzymaj się i pokaż dostępne urządzenia zamiast wybierać inne.
- Dev i Production mogą być zainstalowane jednocześnie na `NET`, ponieważ używają różnych bundle ID.
- Nie resetuj ani nie wymazuj całego Simulatora bez osobnego polecenia użytkownika.
