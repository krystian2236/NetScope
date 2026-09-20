# NS-02 — lokalne testy StoreKit

## Cel

Zweryfikować Demo / Pro / Subscription lokalnie w Xcode, bez App Store Connect i bez prawdziwych opłat.

## Konfiguracja

1. Utwórz w Xcode lokalny **StoreKit Configuration File**.
2. Nazwij go `NetScope.storekit`.
3. Dodaj:
   - Non-Consumable: `local.netscope.pro`
   - Auto-Renewable Subscription: `local.netscope.subscription.monthly`
   - Auto-Renewable Subscription: `local.netscope.subscription.yearly`
4. Aktywuj plik tylko w schemacie **NetScope Developer**: Edit Scheme → Run → Options → StoreKit Configuration.
5. Schemat **NetScope App Store** pozostaw bez lokalnej konfiguracji.

## Lokalne Product ID

- `NetScopeProProductID = local.netscope.pro`
- `NetScopeSubscriptionProductIDs = local.netscope.subscription.monthly,local.netscope.subscription.yearly`

Nie są to produkcyjne Product ID.

## Scenariusze

### T01 — Demo bez zakupów
- accessState = demo;
- moduły Demo działają;
- Pro pozostaje zablokowane;
- Developer sam w sobie nie odblokowuje Pro.

### T02 — lifetime Pro
- zakup lokalnego non-consumable;
- accessState = pro;
- moduły Pro dostępne bez restartu.

### T03 — subskrypcja
- zakup lokalnej subskrypcji;
- accessState = subscription;
- Pro jest dostępne;
- przyszła zawartość subscription może być rozróżniana osobno.

### T04 — Pro + subskrypcja
- lifetime Pro pozostaje zapisane podczas subskrypcji;
- po wygaśnięciu subskrypcji stan wraca do pro.

### T05 — anulowanie
- anulowany zakup nie zmienia entitlementów.

### T06 — pending
- oczekujący zakup nie odblokowuje płatnej zawartości.

### T07 — interrupted purchase
- brak odblokowania przed zweryfikowaną transakcją;
- po rozwiązaniu `Transaction.updates` odświeża stan.

### T08 — restore bez zakupów
- przywracanie nie odblokowuje Pro;
- aplikacja pozostaje w demo.

### T09 — restore Pro
- po zakupie lifetime Pro i ponownym uruchomieniu stan wraca do pro.

### T10 — renewal / expiration
- aktywna subskrypcja = subscription;
- po wygaśnięciu:
  - z lifetime Pro → pro;
  - bez lifetime Pro → demo.

## Kontrola Release

Po testach Developer:
- uruchomić Release build / integrity check;
- potwierdzić, że Store UI nie zostało przypadkowo włączone;
- potwierdzić, że lokalne Product ID nie są wymagane przez build Store;
- prywatne narzędzia Developer nadal nie trafiają do powierzchni Store.

## Kryterium zakończenia

T01–T10 mają PASS/FAIL/BLOCKED dla dokładnego commita, a Release build i privacy check są zielone.
