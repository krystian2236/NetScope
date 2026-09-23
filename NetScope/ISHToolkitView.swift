import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct NmapGuideView: View {
  @ObservedObject var scanner: NetworkScanner
  @Binding var workspaceRouteRaw: String
  @AppStorage("NetScope.nmapCompletedSteps") private var completedSteps = 0

  var body: some View {
    NavigationStack {
      ScrollView {
        LazyVStack(spacing: 12) {
          InfoBanner(
            icon: "terminal.fill",
            title: "Nmap krok po kroku",
            message: "Najpierw wykryj urządzenia w Northbyte Radar. Potem przechodź przez analizy po kolei; komendy pozostają ukryte, dopóki ich nie otworzysz."
          )

          if scanner.devices.isEmpty {
            ContentUnavailableView(
              "Najpierw wykonaj skan",
              systemImage: "dot.radiowaves.left.and.right",
              description: Text("Etapy Nmap odblokują się po wykryciu urządzeń w prywatnej sieci.")
            )
            .frame(minHeight: 190)
          }

          ForEach(NmapGuideStep.allCases) { step in
            stepCard(step)
          }

          plannedTools
          InfoBanner(
            icon: "hand.raised.fill",
            title: "Tylko własna sieć",
            message: "Nmap i przyszłe narzędzia Kali używaj wyłącznie w swojej sieci lub za zgodą właściciela."
          )
        }
        .padding(12)
      }
      .background(Color(.systemGroupedBackground))
      .navigationTitle("Nmap")
      .navigationBarTitleDisplayMode(.inline)
      .navigationDestination(isPresented: workspaceIsPresented) {
        SSHShortcutLibraryView(
          context: scanner.context,
          devices: scanner.devices,
          preferredShortcut: ISHWorkspaceRoute(rawValue: workspaceRouteRaw)?.shortcutID
        )
      }
    }
  }

  private var workspaceIsPresented: Binding<Bool> {
    Binding(
      get: { ISHWorkspaceRoute(rawValue: workspaceRouteRaw) != nil },
      set: { if !$0 { workspaceRouteRaw = "" } }
    )
  }

  @ViewBuilder
  private func stepCard(_ step: NmapGuideStep) -> some View {
    let available = step.isAvailable(
      hasDevices: !scanner.devices.isEmpty,
      completedSteps: completedSteps
    )
    Group {
      if available {
        Button {
          workspaceRouteRaw = ISHWorkspaceRoute.shortcut(step.shortcutID).rawValue
        } label: {
          stepLabel(step, available: true)
        }
        .buttonStyle(.plain)
      } else {
        stepLabel(step, available: false)
      }
    }
  }

  private func stepLabel(_ step: NmapGuideStep, available: Bool) -> some View {
    HStack(spacing: 11) {
      ZStack {
        Circle().fill(step.rawValue < completedSteps ? Color.green.opacity(0.14) : Color.cyan.opacity(0.1))
        Image(systemName: step.rawValue < completedSteps ? "checkmark" : step.icon)
          .foregroundStyle(step.rawValue < completedSteps ? .green : (available ? .cyan : .secondary))
      }
      .frame(width: 38, height: 38)

      VStack(alignment: .leading, spacing: 3) {
        Text("\(step.rawValue + 1). \(step.title)").font(.subheadline.weight(.semibold))
        Text(step.subtitle).font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
      }
      Spacer(minLength: 4)
      Image(systemName: available ? "chevron.right" : "lock.fill")
        .font(.caption.weight(.bold)).foregroundStyle(.tertiary)
    }
    .padding(11)
    .background(.background, in: RoundedRectangle(cornerRadius: 14))
    .opacity(available ? 1 : 0.65)
  }

  private var plannedTools: some View {
    ToolCard(
      icon: "shippingbox.fill",
      title: "Kali Linux — kolejne moduły",
      subtitle: "Planowane po podłączeniu konkretnej maszyny lub VM"
    ) {
      VStack(alignment: .leading, spacing: 7) {
        ForEach([
          "ARP i pełna inwentaryzacja", "DNS i domeny lokalne", "WWW, TLS i SMB",
          "SNMP i ruch sieciowy", "Nuclei, GVM i raport porównawczy",
        ], id: \.self) { item in
          Label(item, systemImage: "clock.badge")
            .font(.caption).foregroundStyle(.secondary)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

struct ISHToolkitView: View {
  let context: NetworkContext?
  let devices: [NetworkDevice]
  let preferredStep: NmapGuideStep?
  @State private var selectedAddress: String
  @State private var mode: ISHScanMode
  @State private var isExporting = false
  @State private var copiedLabel: String?
  @State private var showTechnicalDetails = false
  @AppStorage("NetScope.nmapCompletedSteps") private var completedSteps = 0

  init(
    context: NetworkContext?,
    devices: [NetworkDevice],
    preferredAddress: String? = nil,
    preferredStep: NmapGuideStep? = nil
  ) {
    self.context = context
    self.devices = devices
    self.preferredStep = preferredStep
    let initialAddress =
      preferredAddress
      ?? context?.scanRangeDescription
      ?? devices.first?.address
      ?? ""
    _selectedAddress = State(initialValue: initialAddress)
    _mode = State(initialValue: preferredStep?.mode ?? .inventory)
  }

  private var targets: [ISHTarget] {
    var result: [ISHTarget] = []
    if let context {
      result.append(
        ISHTarget(
          address: context.scanRangeDescription,
          title: "Cała sieć lokalna",
          subtitle: context.scanRangeDescription
        )
      )
    }
    result.append(
      contentsOf: devices.map {
        ISHTarget(
          address: $0.address,
          title: $0.primaryName,
          subtitle: "\($0.address) • \($0.kind.title)"
        )
      }
    )
    return result
  }

  private var knownPorts: [UInt16] {
    devices.first { $0.address == selectedAddress }?.openPorts ?? []
  }

  private var command: String {
    ISHCommandBuilder.command(
      target: selectedAddress,
      mode: mode,
      knownPorts: knownPorts
    )
  }

  private var script: String {
    ISHCommandBuilder.script(
      target: selectedAddress,
      mode: mode,
      knownPorts: knownPorts
    )
  }

  var body: some View {
    ScrollView {
      LazyVStack(spacing: 12) {
        intro
        if targets.isEmpty {
          ContentUnavailableView(
            "Brak celu",
            systemImage: "terminal",
            description: Text("Połącz się z Wi‑Fi lub najpierw wykonaj skan sieci.")
          )
          .frame(minHeight: 220)
        } else {
          if let preferredStep {
            analysisCard(preferredStep)
          }
          configuration
          DisclosureGroup("Pokaż szczegóły techniczne", isExpanded: $showTechnicalDetails) {
            VStack(spacing: 12) {
              installCard
              commandCard
              exportCard
            }
            .padding(.top, 10)
          }
          .font(.caption.weight(.semibold))
          .padding(11)
          .background(.background, in: RoundedRectangle(cornerRadius: 14))
        }
      }
      .padding(12)
    }
    .background(Color(.systemGroupedBackground))
    .navigationTitle(preferredStep?.title ?? "Narzędzia iSH")
    .navigationBarTitleDisplayMode(.inline)
    .fileExporter(
      isPresented: $isExporting,
      document: ISHScriptDocument(contents: script),
      contentType: .shellScript,
      defaultFilename: "netscope-ish.sh"
    ) { _ in }
  }

  private func analysisCard(_ step: NmapGuideStep) -> some View {
    ToolCard(icon: step.icon, title: step.title, subtitle: step.subtitle) {
      Button {
        completedSteps = max(completedSteps, step.rawValue + 1)
      } label: {
        Label(
          completedSteps > step.rawValue ? "Etap wykonany" : "Oznacz jako wykonany",
          systemImage: completedSteps > step.rawValue ? "checkmark.circle.fill" : "circle"
        )
        .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      .tint(completedSteps > step.rawValue ? .green : .cyan)
    }
  }

  private var intro: some View {
    InfoBanner(
      icon: "terminal.fill",
      title: "Northbyte Radar → iSH",
      message:
        "Przygotowuje polecenie Nmap i gotowy skrypt dla prywatnej sieci. Northbyte Radar niczego nie uruchamia automatycznie."
    )
  }

  private var configuration: some View {
    ToolCard(
      icon: "slider.horizontal.3",
      title: "Konfiguracja",
      subtitle: "Wybierz lokalny cel i poziom szczegółów"
    ) {
      VStack(spacing: 9) {
        Picker("Cel", selection: $selectedAddress) {
          ForEach(targets) { target in
            VStack(alignment: .leading) {
              Text(target.title)
              Text(target.subtitle)
            }
            .tag(target.address)
          }
        }
        .pickerStyle(.menu)
        .frame(maxWidth: .infinity, alignment: .leading)

        Picker("Tryb", selection: $mode) {
          ForEach(ISHScanMode.allCases) { item in
            Text(item.title).tag(item)
          }
        }
        .pickerStyle(.segmented)

        Text(mode.subtitle)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .font(.caption)
    }
  }

  private var installCard: some View {
    CommandCard(
      title: "1. Zainstaluj Nmap w iSH",
      command: ISHCommandBuilder.installCommand,
      copied: copiedLabel == "install"
    ) {
      copy(ISHCommandBuilder.installCommand, label: "install")
    }
  }

  private var commandCard: some View {
    CommandCard(
      title: "2. Polecenie jednorazowe",
      command: command,
      copied: copiedLabel == "scan"
    ) {
      copy(command, label: "scan")
    }
  }

  private var exportCard: some View {
    ToolCard(
      icon: "doc.badge.arrow.up",
      title: "3. Skrypt do Plików",
      subtitle: "Zapisz, przenieś do iSH i uruchom"
    ) {
      VStack(alignment: .leading, spacing: 9) {
        Text("W iSH wykonaj:")
          .font(.caption)
          .foregroundStyle(.secondary)
        Text("chmod +x netscope-ish.sh && ./netscope-ish.sh")
          .font(.caption2.monospaced())
          .textSelection(.enabled)

        HStack {
          Button {
            isExporting = true
          } label: {
            Label("Zapisz .sh", systemImage: "square.and.arrow.down")
          }
          .buttonStyle(.borderedProminent)
          .tint(.cyan)

          ShareLink(item: script) {
            Label("Udostępnij", systemImage: "square.and.arrow.up")
          }
          .buttonStyle(.bordered)
        }
        .font(.caption.weight(.semibold))
      }
    }
  }

  private func copy(_ value: String, label: String) {
    UIPasteboard.general.string = value
    copiedLabel = label
  }
}

private struct CommandCard: View {
  let title: String
  let command: String
  let copied: Bool
  let onCopy: () -> Void

  var body: some View {
    ToolCard(
      icon: "terminal",
      title: title,
      subtitle: "Dotknij, aby skopiować"
    ) {
      VStack(alignment: .leading, spacing: 8) {
        Text(command)
          .font(.caption2.monospaced())
          .textSelection(.enabled)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(9)
          .background(.black.opacity(0.06), in: RoundedRectangle(cornerRadius: 9))

        Button(action: onCopy) {
          Label(copied ? "Skopiowano" : "Kopiuj", systemImage: copied ? "checkmark" : "doc.on.doc")
            .font(.caption.weight(.semibold))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
      }
    }
  }
}
