# NetScope — historia zmian

## Unreleased

## 2.1

- domknięto lokalny przepływ Laboratory: Run → Result → Finding → Priority → Recommendation → Re-check,
- dodano deterministyczne scenariusze DNS, HTTP bez TLS i nietypowego portu oraz programy Dig i Curl w Laboratory,
- rozszerzono Scan Diff o zamknięte porty i zmienione hostname,
- zwiększono wersję aplikacji do 2.1 (build 8).

## 2.0

- dodano widoczny na ekranie Start identyfikator otwartego bundle: wersja, build, tryb i Bundle ID,
- ujednolicono identyfikację wersji między ekranem Start i O aplikacji,
- dodano kontrolę spójności wersji, buildu i changelogu przed push.

## 1.4

- przebudowano główną nawigację na **Start**, **Network**, **Security**, **Lab** i **Tools**,
- dodano produkcyjną zakładkę **Security** z przyczynami, priorytetami i zaleceniami zamiast sztucznej punktacji,
- dodano wykrywanie zmian między skanami: nowych urządzeń, usług oraz urządzeń niewidocznych,
- odświeżono pulpit i karty w stylu Apple Pro + Cyber Layer,
- zachowano osobny wariant developerski z UIREF, niewidoczny w aplikacji App Store,
- dodano ekran szczegółów przebiegu skanowania,
- dodano liczbę zaplanowanych i wykonanych prób TCP,
- dodano podział odpowiedzi na otwarte, zamknięte, bez odpowiedzi i bez dostępu,
- dodano czas wykrywania urządzenia oraz opóźnienie poszczególnych usług,
- dodano generator poleceń i skryptów dla iSH,
- dodano profile iSH: inwentaryzacja, rozszerzony TCP i szczegóły usług,
- ograniczono generowane cele iSH do prywatnych adresów IPv4,
- dodano samodzielny skrypt `NetScope-iSH-Toolkit.sh`,
- rozszerzono testy telemetrii i generatora poleceń.

## 1.3

- poprzednia wersja produkcyjna przed przebudową nawigacji i Security.

## 1.2

- przebudowano aplikację na pięć kompaktowych zakładek,
- dodano pulpit z podsumowaniem sieci i historią skanów,
- dodano profil rozszerzony i zwiększono zakres własny do 512 portów,
- dodano profile zdalnego dostępu oraz serwerów i baz danych,
- dodano odwrotne DNS i rozpoznawanie nazw urządzeń,
- dodano szacowanie typu urządzenia i poziomu ekspozycji,
- rozszerzono informacje o usługach: opis, kategoria i typowe szyfrowanie,
- dodano filtry urządzeń i bogatszy eksport CSV,
- zmniejszono typografię, odstępy i rozmiary kart,
- rozszerzono testy modeli, profili i walidacji portów.

## 1.1

- dodano moduł **My IP** z lokalnym IPv4 i opcjonalnym publicznym IPv4/IPv6,
- dodano rozwiązywanie nazw DNS,
- dodano **TCP Ping** z pomiarem czasu zestawienia połączenia,
- dodano test pojedynczego portu dla adresu IP lub domeny,
- dodano skaner portów **Nmap-style**,
- dodano profile Popularne, WWW i IoT,
- dodano własny zakres ograniczony do 256 portów,
- dodano zatrzymywanie skanu i filtrowanie zamkniętych portów,
- rozszerzono informacje o prywatności i ograniczeniach iOS,
- dodano testy walidacji hostów i portów.

## 1.0

- skanowanie prywatnej podsieci IPv4 `/24`,
- wykrywanie usług Bonjour,
- widok urządzeń i popularnych usług TCP,
- eksport wyników do CSV.
