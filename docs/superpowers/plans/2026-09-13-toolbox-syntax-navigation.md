# Toolbox Syntax Navigation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Toolbox present Nmap, Nuclei, Dig, and Curl through their real command syntax, official option sections, searchable descriptions, and a persistent command builder.

**Architecture:** Extend the existing static catalog model with syntax sections and featured-option metadata. Keep `ToolLearningView` generic: a syntax section exposes one or more catalog categories, category chips select the option list, and `ToolCommandBuilder` remains the only command-assembly boundary. Add offline Dig and Curl catalogs while preserving the existing Nmap and Nuclei definitions.

**Tech Stack:** Swift 5, SwiftUI, Swift Testing, XCTest, Xcode, iOS 17+.

**Spec:** `docs/superpowers/specs/2026-09-13-toolbox-syntax-navigation-design.md`

## Global Constraints

- Toolbox order is exactly Nmap, Nuclei, Dig, Curl.
- Toolbox builds and copies commands; it never executes them.
- The syntax header stays visible while the option list scrolls.
- Invalid or conflicting fragments remain visible and copyable with an explanation.
- Secret values are never persisted or written to logs.
- All catalog content is available offline.
- Do not modify CipherPath or NetScope Android Demo.
- Do not commit or push until the user explicitly authorizes it.
- Use simulator `iPhone 17` by UDID `0058F185-AD3B-4AE6-83B9-337E482F17F2` and DerivedData `/private/tmp/NetScope-566c-derived`.

---

### Task 1: Add syntax-section and filtering contracts

**Files:**
- Modify: `NetScope/ToolboxCatalogModel.swift`
- Modify: `NetScopeTests/NetScopeTests.swift`

**Interfaces:**
- Produces: `ToolUsageSection`, `ToolUsagePart.section(_:)`, `ToolOptionDefinition.isFeatured`, and `ToolValuePlacement.positional`.
- Produces: `ToolCatalogBrowser.categories(in:sectionID:)` and `ToolCatalogBrowser.options(in:categoryID:query:featuredOnly:)`.

- [ ] **Step 1: Write failing model tests**

Add `ToolCatalogBrowserTests` with a literal two-category fixture. Verify that one syntax section exposes both categories, search matches flag/name/summary case-insensitively, catalog order is preserved, and `featuredOnly` excludes an unfeatured option.

```swift
@Test func syntaxSectionExposesItsCategories() {
  #expect(ToolCatalogBrowser.categories(in: tool, sectionID: "options").map(\.id) == ["network", "output"])
}

@Test func searchAndFeaturedFilterOptions() {
  #expect(ToolCatalogBrowser.options(in: tool, categoryID: "network", query: "TIME", featuredOnly: true).map(\.id) == ["timeout"])
  #expect(ToolCatalogBrowser.options(in: tool, categoryID: "output", query: "", featuredOnly: true).isEmpty)
}
```

- [ ] **Step 2: Run tests and verify RED**

Run `xcodebuild` for `-only-testing:NetScopeTests/ToolCatalogBrowserTests` on the required simulator. Expected: compilation fails because `ToolUsageSection` and `ToolCatalogBrowser` do not exist.

- [ ] **Step 3: Implement the model**

```swift
struct ToolUsageSection: Identifiable, Equatable, Sendable {
  let id: String
  let label: String
  let categoryIDs: [String]
}

enum ToolUsagePart: Equatable, Sendable {
  case literal(String)
  case section(ToolUsageSection)
}
```

Add `var isFeatured = false` to `ToolOptionDefinition`. Implement `ToolCatalogBrowser` as pure filtering code using `localizedCaseInsensitiveContains` against flags, title, and summary.

Add `case positional` to `ToolValuePlacement`. In `ToolCommandBuilder`, positional values render without a flag and pass validation when their flag list is empty. This is required for Dig's query name and record type.

- [ ] **Step 4: Run `ToolCatalogBrowserTests` and verify GREEN**

- [ ] **Step 5: Run `git diff --check` and review only the model plus tests**

Do not commit without explicit user approval.

---

### Task 2: Keep invalid fragments in copied commands

**Files:**
- Modify: `NetScope/ToolCommandBuilder.swift`
- Modify: `NetScopeTests/NetScopeTests.swift`

**Interfaces:**
- Produces: `ToolCommandDraft.command` containing every selected fragment, including `.invalid` fragments.

- [ ] **Step 1: Replace the old exclusion test with a failing behavior test**

```swift
@Test("Invalid Nmap ports stay visible and copyable with an error")
func invalidNmapPortsStayVisibleAndCopyable() {
  let selection = ToolSelection(
    selectedOptionIDs: ["tcp-connect", "ports", "target"],
    values: ["ports": "22,wrong", "target": "192.168.1.20"]
  )
  let draft = ToolCommandBuilder.build(tool: NmapCatalog.definition, selection: selection)
  #expect(draft.command == "nmap -sT -p '22,wrong' '192.168.1.20'")
  #expect(draft.fragments.first { $0.optionID == "ports" }?.role == .invalid)
  #expect(draft.errors.contains { $0.contains("Nieprawidłowy zakres portów") })
}
```

- [ ] **Step 2: Run `ToolCommandCatalogTests` and verify RED**

Expected: the command omits the invalid port fragment.

- [ ] **Step 3: Build `command` from all fragments**

Continue building the natural-language success explanation only from valid fragments.

- [ ] **Step 4: Run `ToolCommandCatalogTests` and verify GREEN**

- [ ] **Step 5: Run `git diff --check` and stop at the review checkpoint**

---

### Task 3: Map Nmap syntax to official sections

**Files:**
- Modify: `NetScope/NmapCatalog.swift`
- Modify: `NetScopeTests/NetScopeTests.swift`

**Interfaces:**
- Produces syntax sections `scan-types`, `options`, and `target-specification`.

- [ ] **Step 1: Write the failing syntax test**

```swift
#expect(NmapCatalog.definition.usageParts == [
  .literal("nmap"),
  .section(.init(id: "scan-types", label: "[Scan Type(s)]", categoryIDs: ["scan"])),
  .section(.init(id: "options", label: "[Options]", categoryIDs: ["discovery", "ports", "service", "scripts", "os", "timing", "evasion", "output", "misc"])),
  .section(.init(id: "target-specification", label: "{target specification}", categoryIDs: ["target"])),
])
#expect(NmapCatalog.definition.options.first { $0.id == "input-list" }?.categoryID == "target")
```

- [ ] **Step 2: Run `NmapCatalogTests` and verify RED**

- [ ] **Step 3: Replace only `usageParts` and mark introductory options featured**

Featured IDs: `target`, `input-list`, `exclude`, `ping-scan`, `skip-discovery`, `tcp-connect`, `udp-scan`, `ports`, `fast-scan`, `top-ports`, `service-detection`, `default-scripts`, `os-detection`, `timing-template`, `host-timeout`, `open-only`, `reason`, `verbose`, `ipv6`, `version`, and `help`.

- [ ] **Step 4: Run Nmap catalog and builder tests**

- [ ] **Step 5: Compare category order with the official Nmap Options Summary and run `git diff --check`**

---

### Task 4: Adapt Nuclei to syntax navigation

**Files:**
- Modify: `NetScope/NucleiCatalog.swift`
- Modify: `NetScopeTests/NetScopeTests.swift`

**Interfaces:**
- Produces one `flags` section exposing every existing Nuclei category.

- [ ] **Step 1: Write the failing syntax test**

Assert that `[flags]` maps, in catalog order, to `common`, `target`, `target-format`, `templates`, `filtering`, `output`, `configurations`, `interactsh`, `fuzzing`, `uncover`, `rate-limit`, `optimizations`, `headless`, `debug`, `update`, `honeypot`, `statistics`, `cloud`, and `authentication`.

- [ ] **Step 2: Run `NucleiCatalogTests` and verify RED**

- [ ] **Step 3: Add the complete Nuclei syntax section**

Preserve every existing option and risk. Feature target/list input, templates, tags, severity, JSONL output, rate limit, timeout, retries, verbose, version, and template-update checks. Do not feature AI, DAST, Uncover, Interactsh tokens, cloud upload, authentication files, or secret-bearing options.

- [ ] **Step 4: Run Nuclei catalog, builder, and sanitizer tests**

- [ ] **Step 5: Compare headings with ProjectDiscovery CLI documentation and run `git diff --check`**

---

### Task 5: Add the Dig Toolbox catalog

**Files:**
- Create: `NetScope/DigCatalog.swift`
- Modify: `NetScope.xcodeproj/project.pbxproj`
- Modify: `NetScopeTests/NetScopeTests.swift`

**Interfaces:**
- Produces: `DigCatalog.definition: ToolDefinition`.
- Produces syntax sections `server`, `name`, `type`, and `options`.

- [ ] **Step 1: Write failing Dig catalog tests**

Assert syntax `dig [@server] {name} [type] [options]`; record choices include `A`, `AAAA`, `PTR`, `MX`, `TXT`, `NS`, `SOA`, `SRV`, `CAA`, and `ANY`; options include `+short`, `+trace`, `+tcp`, `+dnssec`, `+timeout`, and `+retry`; and the builder emits exactly `dig @router.lab web.lab A +short`.

- [ ] **Step 2: Run `DigCatalogTests` and verify RED**

Expected: `DigCatalog` is missing.

- [ ] **Step 3: Implement ordered Dig categories**

Create `server`, `name`, `type`, `query`, `output`, and `behavior`. Use option ID `target` in category `name` with `.positional`, and option ID `record-type` in category `type` with `.positional`. Populate the remaining entries from the pinned BIND 9 Dig manual. Include transport family, port, source address, reverse lookup, query file, class, TSIG, output sections, multiline/TTL/YAML, TCP, DNSSEC, recursion, search, trace, timeout, retries, EDNS, cookie, and client subnet. Give query files, TSIG, trace, custom servers, and client subnet explicit risk descriptions.

- [ ] **Step 4: Mark common Dig options featured**

Feature server, name, A/AAAA/PTR/MX/TXT/NS, `+short`, `+tcp`, `+dnssec`, `+timeout`, and `+retry`.

- [ ] **Step 5: Add `DigCatalog.swift` to the NetScope target in `project.pbxproj`**

Add exactly one file reference, one build file, one group entry, and one Sources entry.

- [ ] **Step 6: Run Dig catalog, builder, and `DigLabProgramTests`**

- [ ] **Step 7: Run `git diff --check` and review against the BIND manual**

---

### Task 6: Add the Curl Toolbox catalog

**Files:**
- Create: `NetScope/CurlCatalog.swift`
- Modify: `NetScope.xcodeproj/project.pbxproj`
- Modify: `NetScopeTests/NetScopeTests.swift`

**Interfaces:**
- Produces: `CurlCatalog.definition: ToolDefinition`.
- Produces syntax sections `options` and `url`.

- [ ] **Step 1: Write failing Curl catalog tests**

Assert syntax `curl [options] {URL}` and the pinned help categories. Verify exact representative commands:

```text
curl -X POST -H 'Content-Type: application/json' -d '{"name":"lab"}' 'http://api.lab/devices'
curl -I -L --max-time 5 'http://web.lab/start'
```

- [ ] **Step 2: Run `CurlCatalogTests` and verify RED**

Expected: `CurlCatalog` is missing.

- [ ] **Step 3: Implement the pinned Curl catalog**

Use categories returned by `curl --help category` and flags from `curl --help all` for the recorded `helpVersion`. Every option receives aliases, Polish title, Polish summary, value kind, order, risk, and featured state. Treat headers, cookies, bearer tokens, passwords, private keys, proxy credentials, form data, and request bodies as secret or caution values when disclosure is possible.

- [ ] **Step 4: Mark common Curl options featured**

Feature URL, GET/HEAD/POST controls, headers, data, redirects, fail-with-body, include headers, output, silent/show-error, compression, connect timeout, max time, retry, TLS version, CA certificate, verbose, and version.

- [ ] **Step 5: Add `CurlCatalog.swift` to the NetScope target in `project.pbxproj`**

Add exactly one file reference, one build file, one group entry, and one Sources entry with identifiers not already used.

- [ ] **Step 6: Run Curl catalog, builder, sanitizer, and `CurlLabProgramTests`**

- [ ] **Step 7: Run `git diff --check` and compare with the pinned Curl man page**

---

### Task 7: Implement the shared syntax-first interface

**Files:**
- Modify: `NetScope/ToolLearningView.swift`
- Modify: `NetScope/ToolboxView.swift`
- Modify: `NetScope/ToolboxModel.swift`
- Modify: `NetScopeTests/LabCurriculumTests.swift`

**Interfaces:**
- Consumes all four catalog definitions and `ToolCatalogBrowser`.
- Produces one generic syntax-first screen for every Toolbox tool.

- [ ] **Step 1: Write the failing Toolbox order test**

Assert `ToolboxEntry.allCases == [.nmap, .nuclei, .dig, .curl]` and that their raw values equal `LabToolID.firstMilestone.map(\.rawValue)`.

- [ ] **Step 2: Run the order test and verify RED**

Expected: Toolbox currently contains only reconnaissance and Nuclei.

- [ ] **Step 3: Add four Toolbox links**

Use `ToolLearningView` with `NmapCatalog.definition`, `NucleiCatalog.definition`, `DigCatalog.definition`, and `CurlCatalog.definition`. Seed Nmap with `scanner.context?.scanRangeDescription`, Nuclei with `scanner.context?.address`, Dig with `scanner.context?.address`, and leave Curl URL empty. Both Nuclei and Dig catalogs use option ID `target`, so the existing initializer selects the right field.

- [ ] **Step 4: Add syntax-first view state**

```swift
@State private var selectedSectionID: String?
@State private var selectedCategoryID: String?
@State private var query = ""
@State private var featuredOnly = true
```

Keep the command header in `.safeAreaInset(edge: .top)`. Syntax buttons select a section and its first category. Below it render horizontal category chips, a `Najczęstsze / Wszystkie` picker, and `.searchable(text: $query, prompt: "Flaga, nazwa lub opis")`. Render options returned by `ToolCatalogBrowser` for the selected category.

- [ ] **Step 5: Preserve the existing learning behavior**

Keep tap-to-add, tap-again-to-remove, value editors, descriptions, warning colors, fragment numbering, and command copy. Replace the old message with: `Czerwone fragmenty pozostają w poleceniu. Przeczytaj opis błędu przed skopiowaniem.`

- [ ] **Step 6: Run Toolbox browser, catalog, builder, and curriculum tests**

- [ ] **Step 7: Run `git diff --check` and inspect Dynamic Type behavior**

Confirm no description uses a fixed one-line limit and category chips remain horizontally scrollable.

---

### Task 8: Verify and install on the simulator

**Files:**
- Verification only unless a failing check identifies a defect within this feature.

- [ ] **Step 1: Run focused test suites**

Run suites for `ToolCatalogBrowser`, `ToolCommandBuilder`, Nmap, Nuclei, Dig, Curl, command sanitization, and laboratory curriculum. Record the actual executed test count and failures.

- [ ] **Step 2: Build NetScope Developer**

```bash
xcodebuild -project NetScope.xcodeproj -scheme 'NetScope Developer' -destination 'platform=iOS Simulator,id=0058F185-AD3B-4AE6-83B9-337E482F17F2' -derivedDataPath /private/tmp/NetScope-566c-derived build
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Inspect repository state**

Run `git diff --check` and `git status --short --branch`. Review every modified and untracked path. Confirm no credentials, generated build output, CipherPath files, or Android files are included.

- [ ] **Step 4: Install only NetScope Developer**

Boot the existing simulator if needed, install from the dedicated DerivedData path, and launch `pl.krystian.NetScope.dev`. Do not erase or reset the simulator.

- [ ] **Step 5: Perform the manual UI matrix**

For every tool verify: sticky syntax, syntax-section switching, category switching, flag/name/description search, `Najczęstsze / Wszystkie`, add/remove on repeated tap, value entry, exact visible copy, and copyable invalid combinations with clear red explanations.

- [ ] **Step 6: Present the commit checkpoint**

Report changed files, exact test/build results, remaining visual issues, and one Conventional Commit title. Wait for explicit permission before staging, committing, pushing, or installing on a physical iPhone.
