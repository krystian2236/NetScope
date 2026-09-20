# NetScope

NetScope to natywna aplikacja SwiftUI na iOS 17+ do bezpiecznego rozpoznawania własnej sieci lokalnej i nauki defensywnych narzędzi sieciowych.

Aplikacja nie służy do atakowania publicznych celów. Skaner sieci lokalnej działa w obrębie prywatnej lub link-localnej sieci użytkownika, a dodatkowe narzędzia należy uruchamiać wyłącznie wobec własnych systemów albo za zgodą właściciela.

## Aktualny interfejs

W bieżącym buildzie Release/App Store dolny pasek zawiera dwie główne sekcje:

- **Start** — skan prywatnej sieci, stan przebiegu, wykryte urządzenia i wejście do usług sieciowych,
- **Toolbox** — edukacyjne generatory poleceń Nmap i Nuclei z opisem składni i bezpiecznego użycia.

W buildzie developerskim może dodatkowo pojawiać się zakładka **Wkrótce** z podglądem planowanych funkcji. Nie jest ona częścią powierzchni Release.

## Start i skan sieci

NetScope oferuje:

- trzy profile skanu prywatnej podsieci IPv4 `/24`: szybki, standardowy i rozszerzony,
- wykrywanie typowych usług TCP bez logowania i wykonywania poleceń na urządzeniach,
- bieżący postęp skanu i statystyki przebiegu,
- wykrywanie nazw DNS i podstawową klasyfikację rodzaju urządzenia,
- ocenę ekspozycji opartą na widocznych usługach,
- lokalną historię ostatnich skanów,
- zapamiętywanie znanych urządzeń lokalnie na urządzeniu,
- wykrywanie usług Bonjour,
- widoki urządzeń i usług dostępne bezpośrednio ze Startu.

Skanowanie sieci lokalnej należy ostatecznie sprawdzić na prawdziwym iPhonie. Simulator nie odwzorowuje w pełni uprawnienia Local Network i może widzieć inną sieć niż telefon.

## Usługi i diagnostyka

Ze Startu dostępne są m.in.:

- skaner portów TCP,
- DNS oraz lokalny i opcjonalny publiczny adres IP,
- TCP Ping,
- wykrywanie usług Bonjour,
- szczegóły wykrytych urządzeń i ich usług.

Publiczny adres IP jest pobierany z `api64.ipify.org` dopiero po wybraniu odpowiedniej akcji przez użytkownika.

## Toolbox

Zakładka **Toolbox** jest częścią edukacyjną aplikacji.

Aktualnie zawiera:

- **Nmap** — budowanie poleceń krok po kroku według kategorii i opcji,
- **Nuclei** — budowanie kontroli opartych na szablonach,
- **Dig** — ćwiczenia i polecenia do diagnostyki DNS,
- **Curl** — budowanie kontrolowanych żądań HTTP i nauka opcji klienta,
- objaśnienia elementów polecenia i bezpiecznego zakresu użycia.

Toolbox przygotowuje polecenia do świadomego wykonania przez użytkownika. NetScope nie udostępnia modułów eksploatacji ani łamania haseł.

## iSH i SSH

Repozytorium nadal zawiera narzędzia i modele wspierające iSH oraz bibliotekę bezpiecznych skrótów SSH. Polecenia są przeznaczone do ręcznego skopiowania i wykonania przez użytkownika.

NetScope nie przechowuje haseł ani kluczy prywatnych.

Dołączony `NetScope-iSH-Toolkit.sh` ogranicza cele do prywatnego IPv4 i używa połączeń TCP bez surowych pakietów.

Przykład ręcznego użycia w iSH:

```sh
apk update && apk add nmap
chmod +x NetScope-iSH-Toolkit.sh
./NetScope-iSH-Toolkit.sh 192.168.1.0/24
```

## Prywatność

- brak konta wymaganego do używania bieżących funkcji,
- wyniki skanowania i rejestr urządzeń pozostają lokalnie,
- brak ukrytego śledzenia,
- dostęp do sieci lokalnej jest używany do funkcji sieciowych uruchamianych przez użytkownika,
- deklaracje aplikacji znajdują się w `NetScope/Info.plist` i `NetScope/PrivacyInfo.xcprivacy`.

## Zakres bezpieczeństwa

Skaner lokalny ogranicza się do prywatnego lub link-localnego IPv4 urządzenia i lokalnego `/24`.

Narzędzia diagnostyczne i polecenia Toolbox należy stosować wyłącznie wobec własnych systemów albo systemów objętych zgodą właściciela. Ocena rodzaju urządzenia i poziomu ekspozycji jest wskazówką opartą na widocznych portach; nie potwierdza podatności i nie zastępuje audytu bezpieczeństwa.

## Uruchomienie lokalne

Na Macu z Xcode:

1. Otwórz `NetScope.xcodeproj`.
2. Wybierz własny Apple Development Team dla targetu `NetScope`.
3. Wybierz Simulator albo podłączony iPhone.
4. Uruchom aplikację.
5. Na prawdziwym iPhonie zaakceptuj dostęp do sieci lokalnej przed skanem.

Przed proponowanym push uruchom:

```sh
./scripts/pre-push-check.sh
```
