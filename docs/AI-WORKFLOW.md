# AI workflow i human merge gate

Przed merge użytkownik sprawdza na aktualnym commicie: zakres diffu, `git diff --check`, lokalny harness, właściwy build/test, wszystkie CI gates, niezależny review, dokumentację i zachowanie na przypisanym simulatorze/urządzeniu. Każdy actionable finding musi być poprawiony albo jawnie uzasadniony. Ten dokument nie przyznaje automatycznej zgody na merge.
