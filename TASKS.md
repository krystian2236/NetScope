# NetScope — TASKS

## Teraz
- [ ] T001: zinwentaryzować lokalne zmiany względem origin/main.
  - Bez modyfikacji plików.
  - Wynik: lista zmian pogrupowana według funkcji.
  - Uwaga: zdalne repo nie widzi niecommitowanego lokalnego diffu; zadanie kończy lokalny agent/Codex.
- [x] T002: ustalić właściwy schemat/target dla CI na podstawie projektu Xcode.
  - Projekt: `NetScope.xcodeproj`.
  - Target/scheme: `NetScope`.
  - Platforma CI: iOS Simulator, bez code signing.
- [ ] T003: uruchomić lokalny `./scripts/pre-push-check.sh` po zsynchronizowaniu brancha workflow.

## Następnie
- [ ] T010: przegląd architektury Laboratory.
- [ ] T011: testy VirtualLabEngine.
- [ ] T012: przegląd izolacji funkcji NETSCOPE_DEV.
- [ ] T013: zsynchronizować roadmapę z istniejącymi issue VectorNet i planowanym technicznym rename.

## Definition of Done
Zadanie jest zakończone dopiero gdy zakres jest zgodny ze SPEC, wykonano właściwą weryfikację, `git diff --check` nie zgłasza błędów i wynik został opisany w PR.
