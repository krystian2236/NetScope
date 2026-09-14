import SwiftUI
import UIKit

struct ToolLearningView: View {
  let tool: ToolDefinition
  let developerTool: DeveloperAreaTool
  let presetValues: [String: String]

  @State private var selection: ToolSelection
  @State private var selectedSectionID: String?
  @State private var categoryDisclosure = ToolCategoryDisclosureState()
  @State private var query = ""
  @State private var copied = false
  @State private var optionDisclosure = ToolOptionDisclosureState()

  init(
    tool: ToolDefinition,
    developerTool: DeveloperAreaTool,
    presetValues: [String: String] = [:]
  ) {
    self.tool = tool
    self.developerTool = developerTool
    self.presetValues = presetValues
    let initialSelection = ToolboxPresetValues.initialSelection(
      for: tool,
      presetValues: presetValues
    )
    let firstSection = tool.usageParts.compactMap { part -> ToolUsageSection? in
      if case .section(let section) = part { return section }
      return nil
    }.first
    _selection = State(initialValue: initialSelection)
    _selectedSectionID = State(initialValue: firstSection?.id)
  }

  private var draft: ToolCommandDraft {
    ToolCommandBuilder.build(tool: tool, selection: selection)
  }

  private var selectedSection: ToolUsageSection? {
    tool.usageParts.compactMap { part -> ToolUsageSection? in
      if case .section(let section) = part { return section }
      return nil
    }.first { $0.id == selectedSectionID }
  }

  private var visibleCategories: [ToolCategoryDefinition] {
    guard let selectedSection else { return [] }
    return ToolCatalogBrowser.categories(in: tool, sectionID: selectedSection.id)
  }

  private var visibleOptions: [ToolOptionDefinition] {
    guard let selectedCategoryID = categoryDisclosure.selectedCategoryID else { return [] }
    return ToolCatalogBrowser.options(
      in: tool,
      categoryID: selectedCategoryID,
      query: query
    )
  }

  var body: some View {
    ScrollView {
      LazyVStack(spacing: 12) {
        DeveloperAreaTag(.toolbox(developerTool, .screen))
        DeveloperAreaTag(.toolbox(developerTool, .sections))

        if !visibleCategories.isEmpty {
          categoryPicker
          if categoryDisclosure.selectedCategoryID == nil {
            Label("Wybierz kategorię, aby otworzyć jej komendy.", systemImage: "hand.tap")
              .font(.caption)
              .foregroundStyle(.secondary)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(12)
              .background(.background, in: RoundedRectangle(cornerRadius: 14))
          }
        }

        InfoBanner(
          icon: "hand.raised.fill",
          title: "Tylko za zgodą",
          message: "Kopiuj polecenie wyłącznie do nauki i testowania własnych systemów albo celów, na których sprawdzenie masz zgodę."
        )

        Text("Źródło pomocy: \(tool.title) \(tool.helpVersion) • przegląd \(tool.reviewedAt)")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .padding(12)
    }
    .background(Color(.systemGroupedBackground))
    .safeAreaInset(edge: .top, spacing: 0) {
      fixedHeader
    }
    .searchable(text: $query, prompt: "Flaga, nazwa lub opis")
    .navigationTitle(tool.title)
    .navigationBarTitleDisplayMode(.inline)
  }

  private var fixedHeader: some View {
    VStack(spacing: 0) {
      commandPanel
      Divider()
      syntaxPanel
    }
    .background(.regularMaterial)
  }

  private var commandPanel: some View {
    VStack(alignment: .leading, spacing: 9) {
      if developerTool != .dig {
        DeveloperAreaTag(.toolbox(developerTool, .command))
      }
      HStack(alignment: .top, spacing: 8) {
        VStack(alignment: .leading, spacing: 5) {
          Text(draft.command)
            .font(.caption2.monospaced())
            .textSelection(.enabled)
            .lineLimit(4)
        }

        Spacer(minLength: 4)

        Button {
          UIPasteboard.general.string = draft.command
          copied = true
        } label: {
          Image(systemName: copied ? "checkmark" : "doc.on.doc")
        }
        .buttonStyle(.borderedProminent)
        .tint(.cyan)
      }

      DeveloperAreaTag(.toolbox(developerTool, .fragments))
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(alignment: .top, spacing: 8) {
          ForEach(draft.fragments) { fragment in
            fragmentTile(fragment)
          }
        }
      }

      Text("Co zrobi: \(draft.explanation)")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .lineLimit(5)

      messages
      }
      .padding(12)
  }

  @ViewBuilder
  private func fragmentTile(_ fragment: ToolCommandFragment) -> some View {
    let tone = color(for: fragment.role)
    VStack(alignment: .leading, spacing: 4) {
      HStack(spacing: 4) {
        Text("\(fragment.position)").font(.caption2.bold())
        Text(fragment.value)
          .font(.caption2.monospaced())
          .lineLimit(1)
          .minimumScaleFactor(0.7)
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 5)

      Text(fragment.explanation)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .lineLimit(2)
        .minimumScaleFactor(0.85)
        .padding(.horizontal, 8)
        .padding(.bottom, 6)
        .frame(maxWidth: 230, alignment: .leading)
    }
    .foregroundStyle(tone)
    .background(tone.opacity(fragment.role == .required ? 0.20 : 0.12), in: RoundedRectangle(cornerRadius: 10))
    .overlay {
      RoundedRectangle(cornerRadius: 10)
        .stroke(tone.opacity(0.28), lineWidth: 1)
    }
  }

  private var syntaxPanel: some View {
    VStack(alignment: .leading, spacing: 7) {
      DeveloperAreaTag(.toolbox(developerTool, .syntax))
      usageHeader
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 9)
  }

  private var usageHeader: some View {
    VStack(alignment: .leading, spacing: 5) {
      Text("Usage:")
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.secondary)

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 5) {
          ForEach(Array(tool.usageParts.enumerated()), id: \.offset) { _, part in
            switch part {
            case .literal(let value):
              Text(value)
                .foregroundStyle(.green)
                .usageChip(background: Color.green.opacity(0.13))
            case .section(let section):
              let sectionColor = color(for: section.tone)
              Button {
                selectedSectionID = section.id
                categoryDisclosure.reset()
                query = ""
              } label: {
                Text(section.label)
                  .foregroundStyle(selectedSectionID == section.id ? .white : sectionColor)
                  .usageChip(
                    background: selectedSectionID == section.id
                      ? sectionColor : sectionColor.opacity(0.13)
                  )
              }
              .buttonStyle(.plain)
            }
          }
        }
        .font(.caption2.monospaced().weight(.semibold))
      }
    }
  }

  @ViewBuilder
  private var messages: some View {
    if !draft.warnings.isEmpty || !draft.errors.isEmpty {
      DeveloperAreaTag(.toolbox(developerTool, .messages))
    }

    if !draft.warnings.isEmpty {
      VStack(alignment: .leading, spacing: 4) {
        ForEach(draft.warnings, id: \.self) { warning in
          Label(warning, systemImage: "exclamationmark.triangle.fill")
            .font(.caption2)
            .foregroundStyle(.orange)
        }
      }
      .padding(8)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }

    if !draft.errors.isEmpty {
      VStack(alignment: .leading, spacing: 4) {
        ForEach(draft.errors, id: \.self) { error in
          Label(error, systemImage: "xmark.octagon.fill")
            .font(.caption2)
            .foregroundStyle(.red)
        }
        Text("Czerwone fragmenty pozostają w poleceniu. Przeczytaj opis błędu przed skopiowaniem.")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.red)
      }
      .padding(8)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }
  }

  private var categoryPicker: some View {
    let sectionColor = color(for: selectedSection?.tone ?? .options)
    let rows = ToolCategoryLayout.rows(visibleCategories, columns: 2)

    return LazyVStack(spacing: 8) {
      ForEach(rows) { row in
        VStack(spacing: 8) {
          HStack(alignment: .top, spacing: 8) {
            ForEach(row.categories) { category in
              categoryTile(category, color: sectionColor)
            }
            if row.categories.count == 1 {
              Color.clear
                .frame(maxWidth: .infinity, minHeight: 1)
            }
          }

          if let selectedCategoryID = categoryDisclosure.selectedCategoryID,
             row.contains(categoryID: selectedCategoryID),
             let category = tool.categories.first(where: { $0.id == selectedCategoryID }) {
            optionList(category)
          }
        }
      }
    }
  }

  private func categoryTile(
    _ category: ToolCategoryDefinition,
    color sectionColor: Color
  ) -> some View {
    let selected = categoryDisclosure.selectedCategoryID == category.id
    let optionCount = ToolCatalogBrowser.options(
      in: tool,
      categoryID: category.id,
      query: ""
    ).count

    return Button {
      withAnimation(.easeInOut(duration: 0.18)) {
        categoryDisclosure.toggle(categoryID: category.id)
        query = ""
      }
    } label: {
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Image(systemName: category.icon)
            .font(.headline)
          Spacer()
          Image(systemName: "chevron.down")
            .font(.caption.weight(.bold))
            .rotationEffect(.degrees(selected ? 180 : 0))
        }

        Text(category.title)
          .font(.subheadline.weight(.semibold))
          .lineLimit(2)
          .multilineTextAlignment(.leading)

        Text("\(optionCount) komend")
          .font(.caption2)
          .opacity(0.78)
      }
      .foregroundStyle(selected ? .white : sectionColor)
      .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
      .padding(10)
      .background(
        selected ? sectionColor : sectionColor.opacity(0.1),
        in: RoundedRectangle(cornerRadius: 14)
      )
      .overlay {
        RoundedRectangle(cornerRadius: 14)
          .stroke(sectionColor.opacity(0.32), lineWidth: 1)
      }
    }
    .frame(maxWidth: .infinity)
    .buttonStyle(.plain)
    .accessibilityLabel("\(category.title), \(optionCount) komend")
    .accessibilityHint(selected ? "Zamyka listę komend" : "Otwiera listę komend")
  }

  private func optionList(_ category: ToolCategoryDefinition) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      DeveloperAreaTag(.toolbox(developerTool, .options))

      HStack(spacing: 10) {
        Image(systemName: category.icon)
          .foregroundStyle(.cyan)
        VStack(alignment: .leading, spacing: 2) {
          Text(category.title).font(.headline)
          Text(category.subtitle).font(.caption).foregroundStyle(.secondary)
        }
      }

      if visibleOptions.isEmpty {
        Text("Brak opcji pasujących do wyszukiwania.")
          .font(.caption)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
      } else {
      VStack(alignment: .leading, spacing: 12) {
        ForEach(visibleOptions) { option in
          optionRow(option)
        }
      }
      }
    }
    .padding(12)
    .background(.background, in: RoundedRectangle(cornerRadius: 14))
  }

  private func optionRow(_ option: ToolOptionDefinition) -> some View {
    let selected = selection.selectedOptionIDs.contains(option.id)
    let expanded = optionDisclosure.isExpanded(optionID: option.id)
    let state = ToolCompatibilityEvaluator.presentationState(
      for: option,
      in: tool,
      selection: selection
    )
    let stateColor = color(
      for: state,
      sectionTone: selectedSection?.tone ?? .options
    )

    return VStack(alignment: .leading, spacing: 0) {
      VStack(alignment: .leading, spacing: 8) {
        HStack(alignment: .center, spacing: 10) {
          VStack(alignment: .leading, spacing: 3) {
            Text(option.flags.isEmpty ? option.title : option.flags.joined(separator: " / "))
              .font(.caption.monospaced().weight(.semibold))
              .foregroundStyle(stateColor)
              .lineLimit(1)
              .minimumScaleFactor(0.55)
              .allowsTightening(true)

            Text(option.title)
              .font(.caption2.weight(.semibold))
              .lineLimit(1)
              .minimumScaleFactor(0.75)
          }

          Spacer(minLength: 4)

          HStack(spacing: 4) {
            Button {
              selection.toggle(
                optionID: option.id,
                preservingValue: presetValues[option.id]
              )
              copied = false
            } label: {
              Image(systemName: selected ? "minus" : "plus")
                .font(.headline.weight(.bold))
                .foregroundStyle(selected ? .white : stateColor)
                .frame(width: 36, height: 36)
                .background(
                  selected ? stateColor : stateColor.opacity(0.12),
                  in: RoundedRectangle(cornerRadius: 10)
                )
            }
            .frame(minWidth: 44, minHeight: 44)
            .buttonStyle(.plain)
            .accessibilityLabel(selected ? "Usuń \(option.title)" : "Dodaj \(option.title)")

            Button {
              withAnimation(.easeInOut(duration: 0.18)) {
                optionDisclosure.toggle(optionID: option.id)
              }
            } label: {
              Image(systemName: "chevron.down")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(stateColor)
                .rotationEffect(.degrees(expanded ? 180 : 0))
                .frame(width: 36, height: 36)
                .background(stateColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
            }
            .frame(minWidth: 44, minHeight: 44)
            .buttonStyle(.plain)
            .accessibilityLabel(expanded ? "Ukryj informacje" : "Pokaż informacje")
          }
        }

        if expanded {
          Divider()

          VStack(alignment: .leading, spacing: 7) {
            Text(option.summary)
              .font(.caption)
              .foregroundStyle(.secondary)
              .frame(maxWidth: .infinity, alignment: .leading)

            if option.valueKind.requiresValue {
              VStack(alignment: .leading, spacing: 3) {
                Text("Przykład w prawdziwym terminalu:")
                  .font(.caption2.weight(.semibold))
                  .foregroundStyle(.secondary)
                Text(ToolTerminalGuidance.exampleCommand(
                  for: option,
                  executable: tool.executable
                ))
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
              }
              .frame(maxWidth: .infinity, alignment: .leading)
            }

            switch state {
            case .conflicting(let message), .incomplete(let message):
              Label(message, systemImage: "xmark.octagon.fill")
                .font(.caption2)
                .foregroundStyle(.red)
            case .compatible, .selectedValid:
              EmptyView()
            }

            if let requirements = option.requirements {
              Text("Wymagania: \(requirements)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            if case .caution(let reason) = option.risk {
              riskLabel(reason, color: .orange)
            }
            if case .advanced(let reason) = option.risk {
              riskLabel(reason, color: .orange)
            }
          }
        }

        if option.valueKind.requiresValue {
          Divider()

          VStack(alignment: .leading, spacing: 5) {
            DeveloperAreaTag(.toolbox(developerTool, .value))
            valueEditor(for: option)
          }
        }
      }
      .padding(10)
      .background(stateColor.opacity(selected ? 0.14 : 0.07), in: RoundedRectangle(cornerRadius: 12))
      .overlay {
        RoundedRectangle(cornerRadius: 12)
          .stroke(stateColor.opacity(0.35), lineWidth: 1)
      }
    }
  }

  @ViewBuilder
  private func valueEditor(for option: ToolOptionDefinition) -> some View {
    if let presetValue = presetValues[option.id],
       !presetValue.isEmpty {
      HStack(spacing: 8) {
        Text(presetValue)
          .font(.caption.monospaced())
          .textSelection(.enabled)
          .lineLimit(1)
          .minimumScaleFactor(0.6)
          .allowsTightening(true)
        Spacer()
        Image(systemName: "lock.fill")
          .foregroundStyle(.secondary)
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 9)
      .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 9))
    } else {
    switch option.valueKind {
    case .none:
      EmptyView()
    case .choice(let values, let example):
      Picker("Wartość", selection: valueBinding(for: option)) {
        Text("Wybierz…").tag("")
        ForEach(values, id: \.self) { value in
          Text(value).tag(value)
        }
      }
      .pickerStyle(.menu)
      .font(.caption)
      Text("Przykład: \(example)")
        .font(.caption2)
        .foregroundStyle(.secondary)
    case .secret(let example):
      SecureField("np. \(example)", text: valueBinding(for: option))
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .textFieldStyle(.roundedBorder)
        .font(.caption)
      Label("NetScope nie zapisuje tej wartości.", systemImage: "lock.fill")
        .font(.caption2)
        .foregroundStyle(.orange)
    case .integer(_, let example):
      TextField("np. \(example)", text: valueBinding(for: option))
        .keyboardType(.numberPad)
        .textFieldStyle(.roundedBorder)
        .font(.caption)
    default:
      TextField("np. \(option.valueKind.example ?? "")", text: valueBinding(for: option))
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .textFieldStyle(.roundedBorder)
        .font(.caption)
    }
    }
  }

  private func valueBinding(for option: ToolOptionDefinition) -> Binding<String> {
    Binding(
      get: { selection.values[option.id] ?? "" },
      set: {
        selection.values[option.id] = $0
        copied = false
      }
    )
  }

  private func color(for tone: ToolSyntaxTone) -> Color {
    switch tone {
    case .scan: .blue
    case .options: .purple
    case .target: .teal
    case .auxiliary: .indigo
    }
  }

  private func color(
    for state: ToolOptionPresentationState,
    sectionTone: ToolSyntaxTone
  ) -> Color {
    switch state {
    case .compatible: color(for: sectionTone)
    case .selectedValid: .green
    case .conflicting, .incomplete: .red
    }
  }

  private func color(for role: ToolCommandFragmentRole) -> Color {
    switch role {
    case .required: .green
    case .additional: .purple
    case .target: .teal
    case .caution: .orange
    case .invalid: .red
    }
  }

  private func riskLabel(_ text: String, color: Color) -> some View {
    Label(text, systemImage: "exclamationmark.triangle.fill")
      .font(.caption2)
      .foregroundStyle(color)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}

private extension View {
  func usageChip(background: Color) -> some View {
    padding(.horizontal, 7)
      .padding(.vertical, 6)
      .background(background, in: Capsule())
  }
}
