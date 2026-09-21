# NetScope — SPEC

## Cel
NetScope to natywna aplikacja Apple do nauki i bezpiecznej diagnostyki sieciowej. Łączy narzędzia diagnostyczne, skanowanie, laboratorium edukacyjne i materiały praktyczne bez przechowywania sekretów użytkownika.

## Zasady produktu
- Swift/SwiftUI i natywne API Apple.
- Funkcje sieciowe służą do legalnej diagnostyki własnych lub autoryzowanych systemów.
- Wersja App Store nie zawiera funkcji deweloperskich przeznaczonych wyłącznie do lokalnego laboratorium.
- Hasła, tokeny i klucze prywatne nie są zapisywane w repozytorium ani logach.
- UI ma pozostać spójne z istniejącym systemem komponentów NetScope.

## Główne obszary
1. Dashboard i stan aplikacji.
2. Scanner / Scan Details.
3. Diagnostics.
4. Port Scanner.
5. SSH Shortcut Library.
6. Toolbox.
7. Laboratory: programy, misje, terminal lessons i wirtualna sieć.
8. Rozdzielenie wariantu developerskiego i dystrybucyjnego.

## Kryteria jakości
Każda zmiana powinna:
- mieć mały, jednoznaczny zakres;
- kompilować się dla właściwego targetu;
- przejść najwęższe dostępne testy;
- przejść `git diff --check`;
- nie wprowadzać sekretów ani nieuzasadnionych uprawnień;
- mieć opisane kryterium akceptacji.

## Źródła prawdy
- `SPEC.md` — wymagania produktu.
- `ROADMAP.md` — kolejność większych etapów.
- `TASKS.md` — bieżąca kolejka pracy.
- `AGENTS.md` — zasady wykonywania pracy przez agentów.
