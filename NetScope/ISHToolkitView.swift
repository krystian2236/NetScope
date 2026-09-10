import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ISHToolkitView: View {
  let context: NetworkContext?
  let devices: [NetworkDevice]
  @State private var selectedAddress: String
  @State private var mode: ISHScanMode = .inventory
  @State private var isExporting = false
  @State private var copiedLabel: String?

  init(
    context: NetworkContext?,
    devices: [NetworkDevice],
    preferredAddress: String? = nil
  ) {
    self.context = context
    self.devices = devices
    let initialAddress =
      preferredAddress
      ?? context?.scanRangeDescription
      ?? devices.first?.address
      ?? ""
    _selectedAddress = State(initialValue: initialAddress)
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
          configuration
          installCard
          commandCard
          exportCard
        }
      }
      .padding(12)
    }
    .background(Color(.systemGroupedBackground))
    .navigationTitle("Narzędzia iSH")
    .navigationBarTitleDisplayMode(.inline)
    .fileExporter(
      isPresented: $isExporting,
      document: ISHScriptDocument(contents: script),
      contentType: .shellScript,
      defaultFilename: "netscope-ish.sh"
    ) { _ in }
  }

  private var intro: some View {
    InfoBanner(
      icon: "terminal.fill",
      title: "NetScope → iSH",
      message:
        "Przygotowuje polecenie Nmap i gotowy skrypt dla prywatnej sieci. NetScope niczego nie uruchamia automatycznie."
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
