# Northbyte Radar — roadmap procesu AI

To roadmap procesu, nie konkurencyjny plan funkcjonalny. Istniejące specyfikacje w `docs/superpowers/specs/`, plan `docs/superpowers/plans/2026-09-12-toolbox-workflow.md` i checkout VectorNet jako referencja pozostają źródłem zakresu produktu.

## Fazy

1. **Fundament procesu** — `SPEC.md`, `TASKS.md`, harness, CI, CodeQL, dependency review i reviewer. Wyjście: wszystkie nowe artefakty przechodzą walidację składni.
2. **Jedna faza funkcjonalna** — wybrać najmniejszy niedokończony element z istniejącego planu. Wyjście: mały diff, test/harness, dokumentacja i ręczna kontrola.
3. **Pętla review** — niezależne findings → poprawka lub uzasadnienie → lokalna walidacja → świeże CI/review. Wyjście: brak nierozstrzygniętych actionable findings.
4. **Human merge gate** — użytkownik zatwierdza zakres, aktualny commit, CI, review i zachowanie runtime. Wyjście: decyzja użytkownika; merge pozostaje ręczny.
