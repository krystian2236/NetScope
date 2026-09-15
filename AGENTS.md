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

- Dobierz najwęższe testy obejmujące zmianę, następnie wykonaj `git diff --check`.
- Nie twierdź, że testy przeszły, jeśli zostały tylko skompilowane albo ich uruchomienie zablokował symulator.
- Po zakończeniu podaj: wynik, zmienione pliki, wykonaną weryfikację i jedno krótkie zalecenie lub wniosek.

## App Store

- Przy zmianach wydaniowych sprawdź `Info.plist`, `PrivacyInfo.xcprivacy`, używane uprawnienia, deklaracje prywatności, numer wersji i zasoby aplikacji.
- Nie dodawaj prywatnych API, nieuzasadnionych uprawnień, ukrytego śledzenia ani zbierania danych bez wyraźnej potrzeby i zgody użytkownika.
- Nie obchodź procesu App Review i nie wysyłaj buildu do App Store Connect bez osobnego zatwierdzenia.

## TARGET / REFERENCE

- Gdy Codex ma dostęp do kilku repozytoriów, jawnie ustal przed zmianami:
  - TARGET — repozytorium, które wolno modyfikować,
  - REFERENCE — repozytorium wyłącznie do odczytu i porównań.
- Nie modyfikuj REFERENCE bez osobnego polecenia użytkownika.
- Przy przenoszeniu funkcji, UI lub logiki z REFERENCE do TARGET najpierw przeanalizuj implementację, zależności i różnice architektury.
- Nie kopiuj kodu mechanicznie; dopasuj rozwiązanie do TARGET.


## Simulator iOS

- Domyślnym symulatorem projektu NetScope jest `NET` o UDID `F2410F8B-1636-4ECB-88F0-CEF922887673` z iOS 27.0.
- Przy poleceniach `xcodebuild` i `simctl` używaj tego urządzenia, jeśli zadanie dotyczy iPhone'a.
- Jeśli zadanie wymaga innego typu urządzenia, najpierw sprawdź dostępne `xcodebuild -showdestinations` i zaproponuj właściwe.
- Nie twórz, nie usuwaj ani nie resetuj Simulatora bez osobnego polecenia użytkownika.
