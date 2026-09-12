import SwiftUI
import UIKit

struct ToolboxView: View {
  @Environment(\.openURL) private var openURL
  @ObservedObject var scanner: NetworkScanner
  @Binding var workspaceRouteRaw: String
  @SceneStorage("NetScope.toolboxTarget") private var selectedAddress = ""
  @SceneStorage("NetScope.toolboxExpandedTool") private var expandedToolRaw = ""
  @State private var presentedCommand: ToolboxTool?

  private var selectedDevice: NetworkDevice? {
    scanner.devices.first { $0.address == selectedAddress }
  }

  private var hasNetwork: Bool {
    scanner.context?.isPrivateOrLinkLocal == true
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        LazyVStack(spacing: 12) {
          InfoBanner(
            icon: "arrow.up.circle.fill",
            title: "NetScope Toolbox",
            message: "Discover → Inspect → Verify. Każdy krok używa wyłącznie danych z bieżącej sieci i wybranego urządzenia."
          )

          NavigationLink {
            NmapCommandBuilderView(
              initialTarget: selectedAddress.isEmpty
                ? scanner.context?.scanRangeDescription ?? ""
                : selectedAddress
            )
          } label: {
            HStack(spacing: 12) {
              Image(systemName: "scope")
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(.cyan, in: RoundedRectangle(cornerRadius: 11))
              VStack(alignment: .leading, spacing: 3) {
                Text("Rozpoznanie").font(.headline)
                Text("Zbuduj polecenie Nmap krok po kroku")
                  .font(.caption).foregroundStyle(.secondary)
              }
              Spacer()
              Image(systemName: "chevron.right")
                .font(.caption.weight(.bold)).foregroundStyle(.secondary)
            }
            .padding(12)
            .background(.background, in: RoundedRectangle(cornerRadius: 14))
          }
          .buttonStyle(.plain)

          targetCard

          ForEach(ToolboxStage.allCases) { stage in
            stageSection(stage)
          }

          InfoBanner(
            icon: "hand.raised.fill",
            title: "Tryb defensywny",
            message: "Uruchamiaj narzędzia tylko we własnej sieci lub za zgodą właściciela. NetScope nie udostępnia modułów eksploatacji ani łamania haseł."
          )
        }
        .padding(12)
      }
      .background(Color(.systemGroupedBackground))
      .navigationTitle("Toolbox")
      .navigationBarTitleDisplayMode(.inline)
      .navigationDestination(item: $presentedCommand) { tool in
        ToolboxCommandView(
          tool: tool,
          resolution: ToolboxCommandBuilder.resolve(
            tool: tool,
            device: selectedDevice,
            network: scanner.context
          )
        )
      }
      .navigationDestination(isPresented: sshWorkspaceIsPresented) {
        SSHShortcutLibraryView(
          context: scanner.context,
          devices: scanner.devices,
          preferredShortcut: ISHWorkspaceRoute(rawValue: workspaceRouteRaw)?.shortcutID
        )
      }
      .onChange(of: scanner.devices.map(\.address)) { _, addresses in
        if !addresses.contains(selectedAddress) {
          selectedAddress = addresses.first ?? ""
        }
      }
    }
  }

  private var sshWorkspaceIsPresented: Binding<Bool> {
    Binding(
      get: { ISHWorkspaceRoute(rawValue: workspaceRouteRaw) != nil },
      set: { if !$0 { workspaceRouteRaw = "" } }
    )
  }

  private var targetCard: some View {
    ToolCard(
      icon: "scope",
      title: "Bieżący cel",
      subtitle: "Dalsze narzędzia korzystają tylko z tego urządzenia"
    ) {
      if scanner.devices.isEmpty {
        Label("Najpierw uruchom Skan NetScope.", systemImage: "lock.fill")
          .font(.caption)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
      } else {
        Picker("Urządzenie", selection: $selectedAddress) {
          Text("Wybierz urządzenie").tag("")
          ForEach(scanner.devices) { device in
            Text("\(device.primaryName) — \(device.address)").tag(device.address)
          }
        }
        .pickerStyle(.menu)

        if let selectedDevice {
          HStack {
            Label(selectedDevice.address, systemImage: selectedDevice.kind.icon)
            Spacer()
            Text("\(selectedDevice.openPorts.count) usług")
          }
          .font(.caption)
          .foregroundStyle(.secondary)
        }
      }
    }
  }

  private func stageSection(_ stage: ToolboxStage) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      VStack(alignment: .leading, spacing: 2) {
        Text(stage.title).font(.headline)
        Text(stage.subtitle).font(.caption).foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 2)

      ForEach(ToolboxTool.tools(for: stage)) { tool in
        toolCard(tool)
      }
    }
  }

  private func toolCard(_ tool: ToolboxTool) -> some View {
    let availability = ToolboxAvailability.evaluate(
      tool: tool,
      device: selectedDevice,
      hasNetwork: hasNetwork
    )
    let expanded = Binding(
      get: { expandedToolRaw == tool.rawValue },
      set: { expandedToolRaw = $0 ? tool.rawValue : "" }
    )

    return DisclosureGroup(isExpanded: expanded) {
      VStack(alignment: .leading, spacing: 9) {
        Text(tool.summary)
          .font(.caption)
          .foregroundStyle(.secondary)

        switch availability {
        case .available:
          Button {
            run(tool)
          } label: {
            Label(actionTitle(for: tool), systemImage: tool == .nativeDiscovery ? "play.fill" : "chevron.right")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.borderedProminent)
          .tint(.cyan)
        case .blocked(let reason):
          Label(reason, systemImage: "lock.fill")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      .padding(.top, 9)
    } label: {
      HStack(spacing: 10) {
        Image(systemName: tool.icon)
          .foregroundStyle(availability.isAvailable ? .cyan : .secondary)
          .frame(width: 34, height: 34)
          .background(
            (availability.isAvailable ? Color.cyan : Color.secondary).opacity(0.1),
            in: RoundedRectangle(cornerRadius: 9)
          )
        VStack(alignment: .leading, spacing: 2) {
          Text(tool.title).font(.subheadline.weight(.semibold))
          Text(tool.runner.rawValue).font(.caption2).foregroundStyle(.secondary)
        }
        Spacer()
        if !availability.isAvailable {
          Image(systemName: "lock.fill").font(.caption2).foregroundStyle(.tertiary)
        }
      }
    }
    .padding(12)
    .background(.background, in: RoundedRectangle(cornerRadius: 14))
    .opacity(availability.isAvailable ? 1 : 0.62)
  }

  private func actionTitle(for tool: ToolboxTool) -> String {
    tool == .nativeDiscovery ? "Rozpocznij skan" : "Przygotuj na agencie"
  }

  private func run(_ tool: ToolboxTool) {
    if tool == .nativeDiscovery {
      Task { await scanner.scan() }
    } else {
      presentedCommand = tool
    }
  }
}

private struct NmapCommandBuilderView: View {
  @State private var scanType: NmapScanType = .tcpConnect
  @State private var options: Set<NmapOption> = []
  @State private var ports = ""
  @State private var target: String
  @State private var copied = false

  init(initialTarget: String) {
    _target = State(initialValue: initialTarget)
  }

  private var draft: NmapCommandDraft {
    NmapCommandDraft(scanType: scanType, options: options, ports: ports, target: target)
  }

  var body: some View {
    VStack(spacing: 0) {
      commandPreview

      ScrollView {
        LazyVStack(spacing: 12) {
        InfoBanner(
          icon: "scope",
          title: "Kreator Nmap",
          message: "nmap [typ skanu] [opcje] {cel}. Dotknij elementów, a NetScope ułoży bezpieczne polecenie."
        )

        ToolCard(icon: "cursorarrow.click", title: "1. Typ skanu", subtitle: "Wybierz sposób rozpoznania") {
          ForEach(NmapScanType.allCases) { type in
            choiceButton(
              title: type.title,
              flag: type.flag,
              summary: type.summary,
              selected: scanType == type
            ) {
              scanType = type
              options = Set(options.filter { $0.isCompatible(with: type) })
              if type != .tcpConnect {
                ports = ""
              }
            }
            Text(type.requirement)
              .font(.caption2)
              .foregroundStyle(type.isCopyable ? Color.secondary : Color.orange)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
        }

        ToolCard(icon: "switch.2", title: "2. Opcje", subtitle: "Możesz zaznaczyć kilka") {
          ForEach(NmapOption.allCases) { option in
            let disabled = !option.isCompatible(with: scanType)
            choiceButton(
              title: option.title,
              flag: option.flag,
              summary: option.summary,
              selected: options.contains(option),
              disabled: disabled
            ) {
              if options.contains(option) { options.remove(option) } else { options.insert(option) }
            }
            if let reason = option.incompatibilityReason(with: scanType) {
              Text(reason)
                .font(.caption2)
                .foregroundStyle(.orange)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 30)
            }
          }
        }

        ToolCard(icon: "number", title: "3. Porty", subtitle: "Opcjonalnie: 22,80,443 lub 1-1024") {
          TextField("np. 22,80,443", text: $ports)
            .keyboardType(.numbersAndPunctuation)
            .textFieldStyle(.roundedBorder)
            .disabled(scanType != .tcpConnect)
        }

        ToolCard(icon: "scope", title: "4. Cel", subtitle: "Prywatny host lub podsieć CIDR") {
          TextField("np. 192.168.1.20 lub 192.168.1.0/24", text: $target)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .textFieldStyle(.roundedBorder)
        }

        InfoBanner(
          icon: "hand.raised.fill",
          title: "Tylko za zgodą",
          message: "Kopiuj polecenie wyłącznie do testowania własnej sieci lub systemu, na którego sprawdzenie masz zgodę."
        )
        }
        .padding(12)
      }
    }
    .background(Color(.systemGroupedBackground))
    .navigationTitle("Rozpoznanie")
    .navigationBarTitleDisplayMode(.inline)
  }

  private var commandPreview: some View {
    VStack(alignment: .leading, spacing: 7) {
      HStack {
        Label("Podgląd polecenia", systemImage: "terminal")
          .font(.caption.weight(.semibold))
        Spacer()
        if let command = draft.command {
          Button {
            UIPasteboard.general.string = command
            copied = true
          } label: {
            Label(copied ? "Skopiowano" : "Kopiuj", systemImage: copied ? "checkmark" : "doc.on.doc")
              .font(.caption.weight(.semibold))
          }
          .buttonStyle(.borderedProminent)
          .tint(.cyan)
        }
      }

      if let command = draft.command {
        Text(command)
          .font(.caption2.monospaced())
          .textSelection(.enabled)
          .lineLimit(3)
        Text("Co zrobi: \(draft.explanation). \(scanType.summary)")
          .font(.caption2)
          .foregroundStyle(.secondary)
      } else {
        Label(draft.blockingReason ?? "Uzupełnij kreator.", systemImage: "lock.fill")
          .font(.caption2)
          .foregroundStyle(.orange)
      }
    }
    .padding(12)
    .background(.regularMaterial)
    .overlay(alignment: .bottom) { Divider() }
  }

  private func choiceButton(
    title: String,
    flag: String,
    summary: String,
    selected: Bool,
    disabled: Bool = false,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
          .foregroundStyle(selected ? .cyan : .secondary)
        VStack(alignment: .leading, spacing: 2) {
          HStack {
            Text(title).font(.subheadline.weight(.semibold))
            Spacer()
            Text(flag).font(.caption.monospaced()).foregroundStyle(.cyan)
          }
          Text(summary).font(.caption2).foregroundStyle(.secondary)
        }
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(disabled)
    .opacity(disabled ? 0.4 : 1)
  }
}

private struct ToolboxCommandView: View {
  @Environment(\.openURL) private var openURL
  let tool: ToolboxTool
  let resolution: ToolboxCommandResolution
  @AppStorage("NetScope.sshUsername") private var username = ""
  @AppStorage("NetScope.sshHost") private var host = ""
  @State private var copied = false
  @State private var sshClientUnavailable = false

  var body: some View {
    ScrollView {
      LazyVStack(spacing: 12) {
        InfoBanner(
          icon: tool.icon,
          title: tool.title,
          message: tool.summary
        )

        ToolCard(
          icon: "desktopcomputer",
          title: "Wykonanie",
          subtitle: tool.runner.rawValue
        ) {
          switch resolution {
          case .command(let command):
            Text(command)
              .font(.caption.monospaced())
              .textSelection(.enabled)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(10)
              .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))

            Button {
              UIPasteboard.general.string = command
              copied = true
            } label: {
              Label(copied ? "Skopiowano" : "Kopiuj polecenie", systemImage: copied ? "checkmark" : "doc.on.doc")
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.cyan)

            Button {
              openAgent()
            } label: {
              Label("Połącz z agentem", systemImage: "rectangle.connected.to.line.below")
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
          case .blocked(let reason):
            Label(reason, systemImage: "lock.fill")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        InfoBanner(
          icon: "checkmark.shield",
          title: "Przed uruchomieniem",
          message: "Sprawdź cel i wykonuj polecenie wyłącznie na własnym urządzeniu lub za zgodą właściciela. Polecenia wymagające sudo poproszą o zgodę na agencie."
        )
      }
      .padding(12)
    }
    .background(Color(.systemGroupedBackground))
    .navigationTitle(tool.title)
    .navigationBarTitleDisplayMode(.inline)
    .alert("Brak klienta SSH", isPresented: $sshClientUnavailable) {
      Button("OK", role: .cancel) {}
    } message: {
      Text("Skonfiguruj host i użytkownika w bibliotece SSH, a następnie zainstaluj klienta SSH, np. Termius.")
    }
  }

  private func openAgent() {
    let context = SSHShortcutContext(username: username, host: host, target: nil)
    guard let url = SSHShortcutLibrary.connectionURL(context: context) else {
      sshClientUnavailable = true
      return
    }
    openURL(url) { accepted in
      sshClientUnavailable = !accepted
    }
  }
}
