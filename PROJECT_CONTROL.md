# PROJECT CONTROL

Ten plik jest punktem przekazania pracy między Głównym zarządzającym a lokalnymi agentami.

## Zasada nadrzędna

- GŁÓWNY wybiera i zatwierdza zadanie.
- Codex + Ollama wykonuje wyłącznie zadanie wpisane w sekcji ACTIVE TASK.
- Jeśli `Status` nie ma wartości `READY` albo `Agent` nie wskazuje lokalnego Codex + Ollama, agent nie modyfikuje plików.
- `main` nie jest gałęzią roboczą agenta.
- Agent nie wykonuje commit, push, merge, publikacji ani wysyłki do App Store bez osobnego polecenia.
- `AGENTS.md` pozostaje obowiązującym zestawem zasad repozytorium.

## ACTIVE TASK

Status: WAITING_FOR_MANAGER
Manager: Główny zarządzający
Agent: none
Target: none
Reference: none
Branch: none

### Task

Brak aktywnego zadania. Główny zarządzający musi uzupełnić tę sekcję przed uruchomieniem pracy agenta.

### Allowed files

- none

### Do not touch

- wszystkie pliki do czasu przydzielenia zadania

## WORKER REPORT

Status: NOT_STARTED
Branch: none

### Changed

- none

### Verified

- none

### Not verified

- none

### Risk

- none

### Result

- none

## HANDOFF

Po zakończeniu pracy lokalny agent zwraca Głównemu:
1. wynik zadania,
2. listę zmienionych plików,
3. wykonane testy/build,
4. `git diff --check`,
5. ryzyka i elementy nieweryfikowane,
6. nazwę gałęzi i aktualny `git status -sb`.

Główny decyduje o następnym zadaniu oraz o ewentualnym commit, push, PR, merge lub wydaniu.
