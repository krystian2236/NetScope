---
applyTo: "NetScope/**/*.swift,NetScopeTests/**/*.swift"
---

# Swift i testy

- Zachowuj istniejącą architekturę SwiftUI i nazewnictwo projektu.
- Preferuj małe, testowalne funkcje i jawne typy na granicach modułów.
- Nie dodawaj `force unwrap`, `try!`, niekontrolowanych zadań współbieżnych ani blokowania głównego wątku.
- Aktualizacje interfejsu wykonuj na głównym aktorze. Anulowanie zadań i błędy obsługuj jawnie.
- Nie rozszerzaj zakresu dostępu do sieci. Waliduj dane wejściowe przed zbudowaniem polecenia lub rozpoczęciem połączenia.
- Dla poprawki błędu najpierw dodaj możliwie mały test regresyjny, a następnie minimalną implementację.
- Uruchamiaj najwęższy zestaw testów obejmujący zmianę; pełny build wykonuj tylko przed zakończeniem lub gdy wymaga tego zmiana.
- Nie zmieniaj tekstów interfejsu używanych przez `scripts/test-project-integrity.sh` bez równoczesnej, świadomej aktualizacji kontroli integralności.
