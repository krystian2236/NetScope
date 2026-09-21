import SwiftUI
import UIKit

enum SSHShortcutSearch {
  static func filter(_ shortcuts: [SSHShortcut], query: String) -> [SSHShortcut] {
    filter(shortcuts, category: nil, query: query)
  }

  static func filter(
    _ shortcuts: [SSHShortcut],
    category: SSHShortcutCategory?,
    query: String
  ) -> [SSHShortcut] {
    let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
    return shortcuts.filter { shortcut in
      let matchesCategory = category == nil || shortcut.category == category
      let matchesQuery = term.isEmpty
        || shortcut.title.localizedCaseInsensitiveContains(term)
        || shortcut.summary.localizedCaseInsensitiveContains(term)
        || shortcut.category.title.localizedCaseInsensitiveContains(term)
      return matchesCategory && matchesQuery
    }
  }
}

struct SSHShortcutLibraryView: View {
  @Environment(\.openURL) private var openURL
  let context: NetworkContext?
  let devices: [NetworkDevice]
  let preferredShortcut: SSHShortcutID?

  @AppStorage("NetScope.sshProfileName") private var profileName = "Mój Mac"
  @AppStorage("NetScope.sshUsername") private var username = ""
  @AppStorage("NetScope.sshHost") private var host = ""
  @SceneStorage("NetScope.sshTarget") private var target = ""
  @SceneStorage("NetScope.sshQuery") private var query = ""
  @SceneStorage("NetScope.sshCategory") private var selectedCategoryRaw = SSHShortcutCategory.connection.rawValue
  @State private var copiedID: SSHShortcutID?
  @State private var sshClientUnavailable = false
  @SceneStorage("NetScope.sshExpandedShortcut") private var expandedShortcutRaw = ""
  @SceneStorage("NetScope.sshPreparationExpanded") private var preparationExpanded = false
  @AppStorage("NetScope.nmapCompletedSteps") private var completedSteps = 0

  init(
    context: NetworkContext?,
    devices: [NetworkDevice],
    preferredShortcut: SSHShortcutID?
  ) {
    self.context = context
    self.devices = devices
    self.preferredShortcut = preferredShortcut
  }

  private var selectedCategory: SSHShortcutCategory {
    get { SSHShortcutCategory(rawValue: selectedCategoryRaw) ?? .connection }
    nonmutating set { selectedCategoryRaw = newValue.rawValue }
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
    SSHShortcutSearch.filter(
      SSHShortcutLibrary.shortcuts,
      category: selectedCategory,
      query: query
    ).filter { $0.id != .connect }
  }

  private var quickConnectionResolution: SSHShortcutResolution {
    SSHShortcutLibrary.resolve(
      .connect,
      context: SSHShortcutContext(username: username, host: host, target: nil)
    )
  }

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(spacing: 12) {
          #if NETSCOPE_DEV
          HStack { UIRefCopyButton(ref: .ssh); Spacer() }
          #endif
          InfoBanner(
            icon: "link",
            title: "Połączenie i diagnostyka",
            message: "NetScope otwiera logowanie w zainstalowanym kliencie SSH. Dodatkowe polecenia diagnostyczne kopiuje do świadomego uruchomienia."
          )
          categoryPicker
          preparation
          configuration

          if filteredShortcuts.isEmpty {
            ContentUnavailableView.search(text: query)
              .frame(minHeight: 160)
          } else {
            VStack(alignment: .leading, spacing: 8) {
              Text(selectedCategory.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
              ForEach(filteredShortcuts) { shortcut in
                shortcutCard(shortcut)
                  .id(shortcut.id)
              }
            }
          }
        }
        .padding(12)
      }
      .onAppear {
        if target.isEmpty {
          target = context?.scanRangeDescription ?? devices.first?.address ?? ""
        }
        guard let preferredShortcut else { return }
        if let shortcut = SSHShortcutLibrary.shortcuts.first(where: { $0.id == preferredShortcut }) {
          selectedCategory = shortcut.category
        }
        DispatchQueue.main.async {
          withAnimation { proxy.scrollTo(preferredShortcut, anchor: .center) }
        }
      }
    }
    .background(Color(.systemGroupedBackground))
    .navigationTitle("Mac przez SSH")
    .navigationBarTitleDisplayMode(.inline)
    .searchable(text: $query, prompt: "Nazwa, opis lub kategoria")
  }

  private var categoryPicker: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        ForEach(SSHShortcutCategory.allCases) { category in
          Button {
            selectedCategory = category
          } label: {
            Text(category.title)
              .font(.caption.weight(.semibold))
              .padding(.horizontal, 11)
              .padding(.vertical, 8)
              .background(
                selectedCategory == category ? Color.cyan : Color(.secondarySystemGroupedBackground),
                in: Capsule()
              )
              .foregroundStyle(selectedCategory == category ? .white : .primary)
          }
          .buttonStyle(.plain)
          .accessibilityAddTraits(selectedCategory == category ? .isSelected : [])
        }
      }
      .padding(.horizontal, 1)
    }
    .accessibilityLabel("Kategorie poleceń SSH")
  }

  private var preparation: some View {
    DisclosureGroup("Jak przygotować klienta SSH i Maca", isExpanded: $preparationExpanded) {
      VStack(alignment: .leading, spacing: 8) {
        requirement("Klient SSH, np. Termius, jest zainstalowany na iPhonie.")
        requirement("Na Macu włączono Zdalne logowanie dla właściwego użytkownika.")
        requirement("Znasz nazwę konta oraz prywatny adres lub nazwę Maca.")
        requirement("iPhone ma trasę do Maca: ta sama sieć, VPN albo świadomie skonfigurowany zdalny SSH.")
        requirement("Masz zgodę na diagnostykę wskazanego urządzenia i sieci.")
      }
      .padding(.top, 8)
    }
    .accessibilityLabel("Jak przygotować klienta SSH i Maca")
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
      icon: "person.crop.circle",
      title: "Dane połączenia",
      subtitle: "Lokalne dane bez haseł i kluczy"
    ) {
      VStack(spacing: 10) {
        TextField("Nazwa profilu", text: $profileName)
          .textInputAutocapitalization(.words)
          .accessibilityLabel("Nazwa profilu SSH")

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
            if target.isEmpty {
              Text("Wybierz cel").tag("")
            }
            ForEach(targets) { item in
              Text("\(item.title) — \(item.subtitle)").tag(item.address)
            }
          }
          .pickerStyle(.menu)
          .frame(maxWidth: .infinity, alignment: .leading)
          .accessibilityLabel("Prywatny cel diagnostyki")
          .accessibilityHint("Wybiera lokalną podsieć lub wykryte urządzenie")
        }

        switch quickConnectionResolution {
        case .blocked(let message):
          Label(message, systemImage: "person.crop.circle.badge.exclamationmark")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        case .command:
          Button {
            guard let url = SSHShortcutLibrary.connectionURL(
              context: SSHShortcutContext(username: username, host: host, target: nil)
            ) else { return }
            openURL(url) { accepted in
              sshClientUnavailable = !accepted
            }
          } label: {
            Label(
              "Połącz z MacBookiem",
              systemImage: "rectangle.connected.to.line.below"
            )
            .frame(maxWidth: .infinity)
          }
          .buttonStyle(.borderedProminent)
          .tint(.cyan)
          .accessibilityHint("Otwiera połączenie w zainstalowanym kliencie SSH")
          .alert("Brak klienta SSH", isPresented: $sshClientUnavailable) {
            Button("Otwórz App Store") {
              if let url = URL(string: "itms-apps://apps.apple.com/app/id549039908") {
                openURL(url)
              }
            }
            Button("Anuluj", role: .cancel) {}
          } message: {
            Text("Zainstaluj Termius, aby otwierać sesje SSH bezpośrednio z NetScope.")
          }
        }

        Button("Wyczyść dane") {
          profileName = "Mój Mac"
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
              get: { expandedShortcutRaw == shortcut.id.rawValue },
              set: { isExpanded in
                expandedShortcutRaw = isExpanded ? shortcut.id.rawValue : ""
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
              copiedID == shortcut.id ? "Skopiowano" : "Kopiuj → iSH",
              systemImage: copiedID == shortcut.id ? "checkmark" : "doc.on.doc"
            )
            .frame(maxWidth: .infinity)
          }
          .buttonStyle(.borderedProminent)
          .tint(copiedID == shortcut.id ? .green : .cyan)
          .accessibilityLabel("Kopiuj polecenie: \(shortcut.title)")
          .accessibilityHint("Kopiuje tekst; następnie przełącz się do aplikacji iSH")
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
