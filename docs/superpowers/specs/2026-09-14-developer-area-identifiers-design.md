# Developer Area Identifiers Design

**Date:** 2026-09-14  
**Status:** Approved design draft  
**Scope:** NetScope Developer only

## Goal

Add permanent, readable and copyable developer identifiers to every main tab,
important section and primary action. The identifiers let the user name the
exact part of the application when requesting a change, for example
`TB-NMAP-COMMAND` or `LAB-DIG-TERMINAL`.

The identifiers must not change application behavior and must not appear in the
App Store build.

## Naming convention

Every identifier uses uppercase ASCII words separated by hyphens:

`<AREA>-<TOOL-OR-SCREEN>-<ELEMENT>`

Main prefixes:

- `NAV` — main application navigation;
- `START` — network scan and its results;
- `TB` — Toolbox and command builders;
- `LAB` — Laboratory, programs, missions and simulated terminals;
- `CP` — CipherPath information tab.

Tool-specific identifiers always include the tool name. Generic Toolbox labels
such as `TB-COMMAND` become `TB-NMAP-COMMAND`, `TB-NUCLEI-COMMAND`,
`TB-DIG-COMMAND` or `TB-CURL-COMMAND`.

## Identifier coverage

The first implementation covers the four main tabs and their important child
flows.

### Navigation and Start

- `NAV-START`, `NAV-TOOLBOX`, `NAV-LABORATORY`, `NAV-CIPHERPATH`;
- `START-SCREEN`, `START-NETWORK-CONTEXT`, `START-DEVICES`,
  `START-SERVICES`, `START-SCAN-WORKFLOW`, `START-SCAN-ACTION`,
  `START-SCAN-RESULTS`.

### Toolbox

- `TB-SCREEN` and one entry identifier per tool;
- for Nmap, Nuclei, Dig and Curl: `SCREEN`, `COMMAND`, `FRAGMENTS`, `SYNTAX`,
  `SECTIONS`, `OPTIONS`, `VALUE` and `MESSAGES` identifiers carrying the tool
  name;
- example: `TB-NMAP-SYNTAX`, `TB-CURL-OPTIONS`.

### Laboratory

- `LAB-SCREEN` and one program identifier per tool;
- tool-specific `PROGRAM`, `MISSION-LIST`, `BRIEFING`, `TERMINAL`, `ANSWER`
  and `RESULT` identifiers;
- example: `LAB-NUCLEI-BRIEFING`, `LAB-DIG-TERMINAL`.

### CipherPath

- `CP-SCREEN`, `CP-FEATURES` and `CP-INTEGRATION`.

Small decorative text, repeated list-row content and system navigation controls
are not labelled. This keeps Developer usable while still making every relevant
product area unambiguous.

## Architecture

Create a central `DeveloperAreaID` catalog containing every supported stable
identifier. Tool-specific cases remain explicit rather than being assembled
from arbitrary strings. This makes the names searchable and allows tests to
detect omissions and duplicates.

A reusable `DeveloperAreaTag` SwiftUI component renders the identifier as a
small cyan monospaced capsule. Tapping the capsule copies its exact identifier
to the clipboard and posts a VoiceOver announcement. Labels are always visible
in Developer; there is no visibility toggle.

The existing Toolbox-only `ToolboxDeveloperArea` and `DeveloperSectionTag` are
replaced by the shared catalog and component. Views receive an identifier or a
tool identifier only where required; business models and scan/laboratory logic
remain unchanged.

## Build isolation

Rendering and clipboard behavior are enclosed by
`#if NETSCOPE_DEVELOPER_TOOLS`. The App Store configuration does not define this
condition, so it renders no identifiers and keeps its existing interface.

The production build receives no new permissions, storage, tracking or network
behavior.

## Interaction and layout

- A tag sits directly above the section or action it names.
- Tags do not cover controls and remain part of normal scrolling content.
- Existing fixed Toolbox command/syntax header keeps its current behavior.
- Tags use a consistent compact size and support Dynamic Type without truncating
  the identifier; long identifiers may wrap rather than shrink to illegibility.
- Copying a tag gives brief visual confirmation and an accessibility
  announcement.

## Tests and verification

Automated tests verify:

- all raw identifiers are unique;
- every identifier matches the naming grammar;
- all four Toolbox tools expose the complete required identifier set;
- all four Laboratory tools expose their required flow identifiers;
- legacy generic Toolbox identifiers no longer exist;
- the Developer and App Store schemes both compile.

Manual verification on the configured NetScope iPhone 17 checks one complete
path in every main tab and the full Nmap Toolbox flow. The App Store build is
checked separately to confirm that no developer capsules are visible.

## Non-goals

- No change to scanning, command construction, laboratory answers or access
  tiers.
- No identifiers in the App Store interface.
- No labelling of every text label, icon or repeated row.
- No commit, push or merge as part of implementation without a separate user
  instruction.
