---
applyTo: "NetScope/Info.plist,NetScope/PrivacyInfo.xcprivacy,NetScope/**/*.entitlements,NetScope/Assets.xcassets/**,NetScope.xcodeproj/**"
---

# Wydanie i App Store

- Każdą zmianę oceniaj pod kątem zgodności z aktualnymi wymaganiami Apple; przy wymaganiach mogących się zmienić korzystaj z bieżącej dokumentacji Apple.
- Dodawaj wyłącznie uprawnienia i opisy użycia wymagane przez rzeczywiście działającą funkcję.
- Utrzymuj `PrivacyInfo.xcprivacy` zgodnie z używanymi API i faktycznym przetwarzaniem danych. Nie deklaruj śledzenia, jeśli aplikacja go nie wykonuje.
- Nie dodawaj prywatnych API, dynamicznego pobierania kodu wykonywalnego ani mechanizmów obchodzących App Review.
- Sprawdź zgodność identyfikatora pakietu, wersji, numeru buildu, ikon, obsługiwanej wersji iOS oraz deklaracji szyfrowania.
- Przed uznaniem wydania za gotowe uruchom `./scripts/pre-push-check.sh`, wykonaj testy na dostępnym symulatorze lub urządzeniu i wypisz elementy wymagające ręcznej kontroli w App Store Connect.
- Nie archiwizuj, nie podpisuj, nie wysyłaj buildu i nie zmieniaj danych App Store Connect bez osobnego zatwierdzenia użytkownika.
