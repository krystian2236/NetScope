# Northbyte Radar — standard pracy AI

## Zakres

Ten dokument opisuje warstwę procesu dla prac nad Northbyte Radar. Zakres produktu pozostaje w istniejących specyfikacjach `docs/superpowers/specs/` oraz w istniejącym planie `docs/superpowers/plans/2026-09-12-toolbox-workflow.md`, z checkoutem VectorNet jako referencją. Ten plik nie zastępuje tamtych decyzji.

## Zasady

- Zachować istniejące `AGENTS.md` i niecommitowane zmiany.
- Pracować na małych fazach i osobnych, reviewable diffach.
- Nie wykonywać push, merge, publikacji ani zmian branch protection bez zgody użytkownika.
- Dla ekranów respektować UIREF i przypisany simulator `NET` zgodnie z `AGENTS.md`.

## Acceptance criteria procesu

- Każda faza ma opis, zależności, kryteria akceptacji i dowód walidacji.
- Lokalny harness wykrywa brudny diff syntaktycznie, sekrety w nazwach śledzonych plików i problemy integralności projektu.
- Pull request uruchamia build/harness, CodeQL i dependency review na aktualnym commicie.
- Niezależny reviewer działa z nowym kontekstem i zapisuje decyzję przy każdym znalezisku.
- Merge następuje dopiero po ręcznym sprawdzeniu diffu, aktualnego CI, review, dokumentacji i zachowania na urządzeniu/symulatorze.
