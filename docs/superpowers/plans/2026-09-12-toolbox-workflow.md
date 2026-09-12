# NetScope Toolbox Workflow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Zbudować centralny Toolbox z defensywnym przepływem Discover → Inspect → Verify i kontekstowym odblokowaniem narzędzi.

**Architecture:** Czysty model domenowy opisze narzędzia, wymagania i dostępność dla wybranego urządzenia. Widok SwiftUI wyrenderuje sekcje i przekaże dostępne działania do istniejącej biblioteki SSH, bez uruchamiania procesów na iOS.

**Tech Stack:** Swift 6, SwiftUI, XCTest, Swift Testing, iOS 17+

**Spec:** `docs/superpowers/specs/2026-09-12-toolbox-workflow-design.md`

## Global Constraints

- iOS 17.0+.
- Cele aktywnych narzędzi są ograniczone do prywatnych adresów IPv4 i prywatnych podsieci.
- Brak automatycznego wykonywania poleceń oraz przechowywania haseł w MVP.
- Zachować istniejące niezacommitowane zmiany.

---

### Task 1: Model narzędzi i dostępności

**Files:**
- Create: `NetScope/ToolboxModel.swift`
- Modify: `NetScope.xcodeproj/project.pbxproj`
- Test: `NetScopeTests/NetScopeTests.swift`

**Interfaces:**
- Consumes: `NetworkDevice`, `SSHShortcutID`.
- Produces: `ToolboxStage`, `ToolboxTool`, `ToolboxAvailability.evaluate(tool:device:hasNetwork:)`.

- [ ] **Step 1: Write failing tests for stable stages and contextual unlock rules**
- [ ] **Step 2: Run the focused tests and confirm failure**
- [ ] **Step 3: Implement tool metadata and pure availability evaluation**
- [ ] **Step 4: Run focused tests and confirm success**

### Task 2: Central Toolbox interface

**Files:**
- Create: `NetScope/ToolboxView.swift`
- Modify: `NetScope.xcodeproj/project.pbxproj`
- Modify: `NetScope/AppShellView.swift`

**Interfaces:**
- Consumes: `NetworkScanner`, `ToolboxTool`, `ToolboxAvailability`.
- Produces: central Toolbox tab and routes to existing `SSHShortcutLibraryView`.

- [ ] **Step 1: Replace the Nmap tab with a central Toolbox tab**
- [ ] **Step 2: Add device selection and Discover, Inspect, Verify sections**
- [ ] **Step 3: Render blocked reasons and agent labels on every tile**
- [ ] **Step 4: Connect available Nmap actions to the existing SSH workspace**

### Task 3: Simplify Start and restore sessions

**Files:**
- Modify: `NetScope/DashboardView.swift`
- Modify: `NetScope/AppShellView.swift`
- Test: `NetScopeTests/NetScopeTests.swift`

**Interfaces:**
- Consumes: `AppTab.toolbox`, current scanner state.
- Produces: command-free Start and stable Toolbox restoration.

- [ ] **Step 1: Update restoration tests for Toolbox**
- [ ] **Step 2: Remove the SSH command card from Start**
- [ ] **Step 3: Verify the selected tab and Toolbox route survive navigation**

### Task 4: Project verification

**Files:**
- Verify: `NetScope.xcodeproj`
- Verify: `scripts/pre-push-check.sh`

**Interfaces:**
- Consumes: complete Toolbox implementation.
- Produces: build and test evidence without creating a commit.

- [ ] **Step 1: Run whitespace and repository integrity checks**
- [ ] **Step 2: Build for an available iPhone simulator**
- [ ] **Step 3: Run all unit tests**
- [ ] **Step 4: Inspect the final scoped diff and secret scan**
