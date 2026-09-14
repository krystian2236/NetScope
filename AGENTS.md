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

## Spójność produktu

- Przy zmianie nawigacji, nazw funkcji, dostępności funkcji w Release albo zachowania Toolboxa sprawdź, czy `README.md` i `CHANGELOG.md` nadal opisują faktyczny stan aplikacji.
- Funkcje oznaczone jako planowane, demonstracyjne albo nieukończone nie powinny być widoczne w buildzie Release/App Store, chyba że jest to świadoma decyzja produktu.
- Zmiany funkcji sieciowych i Toolboxa powinny mieć testy najbliżej zmienianego modelu lub buildera poleceń.
- Nie przedstawiaj generatora poleceń jako automatycznego wykonania. Użytkownik ma widzieć cel, zakres i polecenie przed jego użyciem.

## Bezpieczeństwo i Git

- Nigdy nie ujawniaj, zapisuj ani commituj tokenów, haseł, kluczy prywatnych, plików `.env`, danych uwierzytelniających lub danych osobowych.
- Diagnostykę sieci wykonuj wyłącznie dla prywatnych adresów użytkownika albo systemów, na których testowanie ma zgodę właściciela.
- NetScope może przygotowywać i kopiować polecenia SSH, ale nie może przechowywać haseł ani kluczy prywatnych.
- Nie wykonuj commita, pushu, instalacji, usuwania, zmiany uprawnień, publikacji ani wysyłki do App Store bez jednoznacznego polecenia użytkownika.
- Nie używaj force push i nie zmieniaj istniejącej historii Git.
- Przed proponowanym push uruchom `./scripts/pre-push-check.sh` i podaj jego rzeczywisty wynik.
- Stosuj małe commity Conventional Commits z angielskim tytułem do 72 znaków.

## Weryfikacja

- Najpierw uruchom najwęższe testy obejmujące zmianę, potem odpowiedni szerszy zestaw testów, a na końcu `git diff --check`.
- Zmiana przygotowywana do Release powinna przejść testy jednostkowe oraz kontrolę builda Release/integralności bundle.
- Nie twierdź, że testy przeszły, jeśli zostały tylko skompilowane albo ich uruchomienie zablokował Simulator.
- Jeżeli CI jest dostępne, sprawdź wynik workflow dla dokładnego commita przed uznaniem zmiany za gotową do scalenia.
- Po zakończeniu podaj: wynik, zmienione pliki, wykonaną weryfikację i jedno krótkie zalecenie lub wniosek.

## Simulator iOS

- Nie zakładaj stałego UDID Simulatora.
- Preferuj dostępny Simulator po nazwie projektu; jeśli go nie ma, użyj aktywnego lub pierwszego dostępnego iPhone Simulatora i jawnie podaj wybrany destination.
- Nie wymazuj ani nie resetuj Simulatora bez osobnego polecenia użytkownika.

## App Store

- Przy zmianach wydaniowych sprawdź `Info.plist`, `PrivacyInfo.xcprivacy`, używane uprawnienia, deklaracje prywatności, numer wersji, numer buildu i zasoby aplikacji.
- Sprawdź faktyczną powierzchnię builda Release: widoczne zakładki, funkcje, opisy oraz zgodność z README i deklaracjami prywatności.
- Nie dodawaj prywatnych API, nieuzasadnionych uprawnień, ukrytego śledzenia ani zbierania danych bez wyraźnej potrzeby i zgody użytkownika.
- Nie obchodź procesu App Review i nie wysyłaj buildu do App Store Connect bez osobnego zatwierdzenia.
