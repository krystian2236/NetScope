import SwiftUI
import UIKit

enum SSHShortcutSearch {
  static func filter(_ shortcuts: [SSHShortcut], query: String) -> [SSHShortcut] {
    let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !term.isEmpty else { return shortcuts }
    return shortcuts.filter {
      $0.title.localizedCaseInsensitiveContains(term)
        || $0.summary.localizedCaseInsensitiveContains(term)
        || $0.category.title.localizedCaseInsensitiveContains(term)
    }
  }
}

struct SSHShortcutLibraryView: View {
  let context: NetworkContext?
  let devices: [NetworkDevice]
  let preferredShortcut: SSHShortcutID?

  @AppStorage("NetScope.sshUsername") private var username = ""
  @AppStorage("NetScope.sshHost") private var host = ""
  @State private var target: String
  @State private var query = ""
  @State private var copiedID: SSHShortcutID?
  @State private var expandedIDs: Set<SSHShortcutID> = []
  @State private var preparationExpanded = false
  @AppStorage("NetScope.nmapCompletedSteps") private var completedSteps = 0

  init(
    context: NetworkContext?,
    devices: [NetworkDevice],
    preferredShortcut: SSHShortcutID?
  ) {
    self.context = context
    self.devices = devices
    self.preferredShortcut = preferredShortcut
    let suggestedTarget = context?.scanRangeDescription ?? devices.first?.address ?? ""
    _target = State(initialValue: suggestedTarget)
  }

  private var targets: [ISHTarget] {
    var result: [ISHTarget] = []
    if let context, ISHTargetValidator.isPrivate(context.scanRangeDescription) {
      result.append(
        ISHTarget(
          address: context.scanRangeDescription,
          title: "Cała sieć lokalna",
          subtitle: context.scanRangeDescription
        )
      )
    }
    result.append(
      contentsOf: devices.compactMap { device in
        guard ISHTargetValidator.isPrivate(device.address) else { return nil }
        return ISHTarget(
          address: device.address,
          title: device.primaryName,
          subtitle: "\(device.address) • \(device.kind.title)"
        )
      }
    )
    return result
  }

  private var filteredShortcuts: [SSHShortcut] {
    SSHShortcutSearch.filter(SSHShortcutLibrary.shortcuts, query: query)
  }

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(spacing: 12) {
          InfoBanner(
            icon: "doc.on.clipboard",
            title: "Tylko kopiowanie",
            message: "NetScope przygotowuje i kopiuje polecenia. Nie łączy się przez SSH i niczego nie uruchamia. Używaj tylko własnej sieci lub działaj za zgodą właściciela."
          )
          preparation
          configuration

          ForEach(SSHShortcutCategory.allCases) { category in
            let categoryShortcuts = filteredShortcuts.filter { $0.category == category }
            if !categoryShortcuts.isEmpty {
              VStack(alignment: .leading, spacing: 8) {
                Text(category.title)
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(.secondary)
                  .frame(maxWidth: .infinity, alignment: .leading)
                ForEach(categoryShortcuts) { shortcut in
                  shortcutCard(shortcut)
                    .id(shortcut.id)
                }
              }
            }
          }
        }
        .padding(12)
      }
      .onAppear {
        guard let preferredShortcut else { return }
        DispatchQueue.main.async {
          withAnimation { proxy.scrollTo(preferredShortcut, anchor: .center) }
        }
      }
    }
    .background(Color(.systemGroupedBackground))
    .navigationTitle("iSH + Mac przez SSH")
    .navigationBarTitleDisplayMode(.inline)
    .searchable(text: $query, prompt: "Nazwa, opis lub kategoria")
  }

  private var preparation: some View {
    DisclosureGroup("Jak przygotować iSH i Maca", isExpanded: $preparationExpanded) {
      VStack(alignment: .leading, spacing: 8) {
        requirement("iSH jest zainstalowany na iPhonie.")
        requirement("Na Macu włączono Zdalne logowanie dla właściwego użytkownika.")
        requirement("Znasz nazwę konta oraz prywatny adres lub nazwę Maca.")
        requirement("iPhone ma trasę do Maca: ta sama sieć, VPN albo świadomie skonfigurowany zdalny SSH.")
        requirement("Masz zgodę na diagnostykę wskazanego urządzenia i sieci.")
      }
      .padding(.top, 8)
    }
    .accessibilityLabel("Jak przygotować iSH i Maca")
    .accessibilityHint("Rozwija listę pięciu wymagań")
    .padding(12)
    .background(.background, in: RoundedRectangle(cornerRadius: 14))
  }

  private func requirement(_ text: String) -> some View {
    Label(text, systemImage: "checkmark.circle")
      .font(.caption)
      .foregroundStyle(.secondary)
      .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var configuration: some View {
    ToolCard(
      icon: "person.crop.circle.badge.key",
      title: "Dane połączenia",
      subtitle: "Lokalne dane bez haseł i kluczy"
    ) {
      VStack(spacing: 10) {
        TextField("Użytkownik", text: $username)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
          .textContentType(.username)
          .accessibilityLabel("Użytkownik SSH")
          .accessibilityHint("Opcjonalna nazwa konta na Macu")

        TextField("Host Maca", text: $host)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
          .keyboardType(.URL)
          .accessibilityLabel("Host Maca")
          .accessibilityHint("Opcjonalny prywatny adres lub nazwa Maca")

        if targets.isEmpty {
          Label("Najpierw wykryj prywatną sieć lub urządzenie.", systemImage: "lock.fill")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
          Picker("Cel prywatny", selection: $target) {
            ForEach(targets) { item in
              Text("\(item.title) — \(item.subtitle)").tag(item.address)
            }
          }
          .pickerStyle(.menu)
          .frame(maxWidth: .infinity, alignment: .leading)
          .accessibilityLabel("Prywatny cel diagnostyki")
          .accessibilityHint("Wybiera lokalną podsieć lub wykryte urządzenie")
        }

        Button("Wyczyść dane") {
          username = ""
          host = ""
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityHint("Usuwa zapisanego użytkownika i host Maca")
      }
      .textFieldStyle(.roundedBorder)
    }
  }

  private func shortcutCard(_ shortcut: SSHShortcut) -> some View {
    let resolution = SSHShortcutLibrary.resolve(
      shortcut.id,
      context: SSHShortcutContext(
        username: username,
        host: host,
        target: target.isEmpty ? nil : target
      )
    )
    return ToolCard(
      icon: shortcut.id == preferredShortcut ? "arrow.right.circle.fill" : "terminal",
      title: shortcut.title,
      subtitle: shortcut.summary
    ) {
      VStack(alignment: .leading, spacing: 9) {
        Label(shortcut.place.rawValue, systemImage: "location.fill")
          .font(.caption2.weight(.medium))
          .foregroundStyle(.secondary)

        switch resolution {
        case .blocked(let message):
          Label(message, systemImage: "lock.fill")
            .font(.caption)
            .foregroundStyle(.orange)
            .accessibilityLabel("Polecenie zablokowane. \(message)")
        case .command(let command):
          DisclosureGroup(
            "Pokaż polecenie",
            isExpanded: Binding(
              get: { expandedIDs.contains(shortcut.id) },
              set: { isExpanded in
                if isExpanded {
                  expandedIDs.insert(shortcut.id)
                } else {
                  expandedIDs.remove(shortcut.id)
                }
              }
            )
          ) {
            Text(command)
              .font(.caption2.monospaced())
              .textSelection(.enabled)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(9)
              .background(.black.opacity(0.06), in: RoundedRectangle(cornerRadius: 9))
              .padding(.top, 8)
          }
          .font(.caption.weight(.semibold))
          .accessibilityHint("Pokazuje lub ukrywa tekst polecenia")

          Button {
            UIPasteboard.general.string = command
            copiedID = shortcut.id
            UIAccessibility.post(notification: .announcement, argument: "Skopiowano")
          } label: {
            Label(
              copiedID == shortcut.id ? "Skopiowano" : "Kopiuj",
              systemImage: copiedID == shortcut.id ? "checkmark" : "doc.on.doc"
            )
            .frame(maxWidth: .infinity)
          }
          .buttonStyle(.borderedProminent)
          .tint(copiedID == shortcut.id ? .green : .cyan)
          .accessibilityLabel("Kopiuj polecenie: \(shortcut.title)")
          .accessibilityHint("Kopiuje tekst do schowka bez uruchamiania")
        }

        if shortcut.id == preferredShortcut, let step = guideStep(for: shortcut.id) {
          Button("Oznacz etap jako wykonany") {
            completedSteps = max(completedSteps, step.rawValue + 1)
          }
          .buttonStyle(.bordered)
          .accessibilityHint("Ręcznie zapisuje ukończenie tego etapu Nmap")
        }
      }
    }
    .overlay {
      if shortcut.id == preferredShortcut {
        RoundedRectangle(cornerRadius: 14)
          .stroke(.cyan, lineWidth: 2)
          .allowsHitTesting(false)
      }
    }
  }

  private func guideStep(for shortcutID: SSHShortcutID) -> NmapGuideStep? {
    NmapGuideStep.allCases.first { $0.shortcutID == shortcutID }
  }
}
