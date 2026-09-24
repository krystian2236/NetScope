# Northbyte Radar Toolbox Workflow Design

## Cel

Zastąpić osobną zakładkę Nmap centralnym „Toolbox”, który prowadzi użytkownika przez defensywną analizę własnej sieci: od wykrycia hostów, przez porty i usługi, po narzędzia dobrane do faktycznie znalezionych danych.

## Nawigacja

Dolny pasek ma kolejność: Start, Skan, Toolbox, Urządzenia, Usługi. Toolbox jest środkową, wyróżnioną pozycją ze strzałką w górę. Start nie zawiera biblioteki poleceń ani skrótu iSH; pokazuje stan sieci, skróty do skanowania i historię.

## Model przepływu

Toolbox ma trzy etapy:

1. Discover — wykrycie prywatnej sieci i urządzeń.
2. Inspect — wybór jednego hosta, skan portów i rozpoznanie usług.
3. Verify — dobranie lekkich, defensywnych narzędzi do wykrytych usług.

Każde narzędzie określa wymagane dane wejściowe. Kafelek jest aktywny tylko wtedy, gdy bieżący stan dostarcza te dane. Zmiana hosta powoduje ponowne wyliczenie dostępności, dzięki czemu porty i usługi innego urządzenia nie odblokowują niepowiązanych działań.

## Zakres MVP

- Discover: natywny skan Northbyte Radar, Nmap host discovery, Netdiscover.
- Inspect: Nmap common ports, Nmap service detection, reverse DNS, traceroute.
- Verify: Dig dla DNS, Curl i WhatWeb dla HTTP, SSLScan dla TLS, Nikto dla HTTP oraz Enum4linux-ng dla SMB.
- Narzędzia uruchamiane poza iOS mają czytelne oznaczenie „Agent Mac/Kali”. MVP wykorzystuje istniejący bezpieczny handoff SSH; bez automatycznego wykonywania poleceń i bez przechowywania haseł.

## Reguły bezpieczeństwa

- Cele aktywnych narzędzi są ograniczone do prywatnych adresów IPv4 i prywatnych podsieci.
- Narzędzia wymagające hosta nie przyjmują CIDR.
- Działania dobierane do portów wymagają portu wykrytego na aktualnie wybranym urządzeniu.
- Brak modułów ofensywnych, brute force, eksploatacji, utrzymania dostępu i omijania zabezpieczeń.
- Interfejs przypomina, że skanowanie wymaga własności sieci lub zgody właściciela.

## Stan i sesja

Wybrana zakładka i otwarta trasa Toolbox pozostają w SceneStorage. Wybrany host pochodzi z bieżących wyników skanera. Nie utrwalamy wyników narzędzi zewnętrznych, dopóki nie powstanie zweryfikowany protokół NetScope Agent.

## Kryteria akceptacji

- Nmap nie jest osobną zakładką.
- Toolbox znajduje się pośrodku dolnego paska.
- Każdy kafelek pokazuje cel, wymagania, miejsce wykonania i przyczynę blokady.
- Po wykryciu urządzeń odblokowuje się wybór hosta i Inspect.
- Kafelki DNS/HTTP/TLS/SMB aktywują się tylko przy zgodnych danych wybranego hosta.
- Istniejące połączenie SSH do Maca nadal działa.
- Testy pokrywają kolejność etapów i reguły odblokowania.
