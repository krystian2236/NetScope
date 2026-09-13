import SwiftUI
import UIKit

struct ToolLearningView: View {
  let tool: ToolDefinition

  @State private var selection: ToolSelection
  @State private var expandedCategoryID: String?
  @State private var copied = false

  init(tool: ToolDefinition, initialTarget: String = "") {
    self.tool = tool
    var initialSelection = ToolSelection()
    if !initialTarget.isEmpty, tool.options.contains(where: { $0.id == "target" }) {
      initialSelection.selectedOptionIDs.insert("target")
      initialSelection.values["target"] = initialTarget
    }
    _selection = State(initialValue: initialSelection)
    _expandedCategoryID = State(initialValue: tool.categories.first?.id)
  }

  private var draft: ToolCommandDraft {
    ToolCommandBuilder.build(tool: tool, selection: selection)
  }

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(spacing: 12) {
          ForEach(tool.categories) { category in
            categoryCard(category)
              .id(category.id)
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
        commandHeader(scrollProxy: proxy)
      }
    }
    .navigationTitle(tool.title)
    .navigationBarTitleDisplayMode(.inline)
  }

  private func commandHeader(scrollProxy: ScrollViewProxy) -> some View {
    VStack(alignment: .leading, spacing: 9) {
      usageHeader(scrollProxy: scrollProxy)

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 6) {
          ForEach(draft.fragments) { fragment in
            HStack(spacing: 4) {
              Text("\(fragment.position)").font(.caption2.bold())
              Text(fragment.value).font(.caption2.monospaced())
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .foregroundStyle(color(for: fragment.role))
            .background(color(for: fragment.role).opacity(0.13), in: Capsule())
          }
        }
      }

      HStack(alignment: .top, spacing: 8) {
        VStack(alignment: .leading, spacing: 5) {
          Text(draft.command)
            .font(.caption2.monospaced())
            .textSelection(.enabled)
            .lineLimit(4)

          Text("Co zrobi: \(draft.explanation)")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(5)
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

      messages
    }
    .padding(12)
    .background(.regularMaterial)
    .overlay(alignment: .bottom) { Divider() }
  }

  private func usageHeader(scrollProxy: ScrollViewProxy) -> some View {
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
            case .category(let label, let categoryID):
              Button {
                expandedCategoryID = categoryID
                withAnimation { scrollProxy.scrollTo(categoryID, anchor: .top) }
              } label: {
                Text(label)
                  .foregroundStyle(.purple)
                  .usageChip(background: Color.purple.opacity(0.13))
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
        Text("Czerwone fragmenty pozostają widoczne do nauki, ale nie są kopiowane.")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.red)
      }
      .padding(8)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }
  }

  private func categoryCard(_ category: ToolCategoryDefinition) -> some View {
    DisclosureGroup(
      isExpanded: Binding(
        get: { expandedCategoryID == category.id },
        set: { expandedCategoryID = $0 ? category.id : nil }
      )
    ) {
      VStack(alignment: .leading, spacing: 12) {
        ForEach(options(in: category)) { option in
          optionRow(option)
        }
      }
      .padding(.top, 10)
    } label: {
      HStack(spacing: 10) {
        Image(systemName: category.icon)
          .foregroundStyle(.cyan)
          .frame(width: 34, height: 34)
          .background(Color.cyan.opacity(0.1), in: RoundedRectangle(cornerRadius: 9))

        VStack(alignment: .leading, spacing: 2) {
          Text(category.title).font(.subheadline.weight(.semibold))
          Text(category.subtitle).font(.caption2).foregroundStyle(.secondary)
        }

        Spacer()

        let count = selectedCount(in: category)
        if count > 0 {
          Text("\(count)")
            .font(.caption2.bold())
            .foregroundStyle(.white)
            .frame(minWidth: 22, minHeight: 22)
            .background(.purple, in: Circle())
        }
      }
    }
    .padding(12)
    .background(.background, in: RoundedRectangle(cornerRadius: 14))
  }

  private func optionRow(_ option: ToolOptionDefinition) -> some View {
    let selected = selection.selectedOptionIDs.contains(option.id)
    let riskColor = color(for: option.risk)

    return VStack(alignment: .leading, spacing: 7) {
      Button {
        selection.toggle(optionID: option.id)
        copied = false
      } label: {
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: selected ? "checkmark.circle.fill" : "plus.circle")
            .foregroundStyle(selected ? riskColor : .secondary)

          VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
              Text(option.title).font(.subheadline.weight(.semibold))
              Spacer()
              Text(option.flags.joined(separator: " / "))
                .font(.caption2.monospaced())
                .foregroundStyle(riskColor)
                .multilineTextAlignment(.trailing)
            }

            Text(option.summary)
              .font(.caption2)
              .foregroundStyle(.secondary)
              .frame(maxWidth: .infinity, alignment: .leading)

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
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)

      if selected, option.valueKind.requiresValue {
        valueEditor(for: option)
          .padding(.leading, 34)
      }
    }
  }

  @ViewBuilder
  private func valueEditor(for option: ToolOptionDefinition) -> some View {
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
      Text("Przykład: \(example)")
        .font(.caption2)
        .foregroundStyle(.secondary)
    case .secret(let example):
      SecureField("np. \(example)", text: valueBinding(for: option))
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .textFieldStyle(.roundedBorder)
      Label("NetScope nie zapisuje tej wartości.", systemImage: "lock.fill")
        .font(.caption2)
        .foregroundStyle(.orange)
    case .integer(_, let example):
      TextField("np. \(example)", text: valueBinding(for: option))
        .keyboardType(.numberPad)
        .textFieldStyle(.roundedBorder)
    default:
      TextField("np. \(option.valueKind.example ?? "")", text: valueBinding(for: option))
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .textFieldStyle(.roundedBorder)
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

  private func options(in category: ToolCategoryDefinition) -> [ToolOptionDefinition] {
    tool.options
      .filter { $0.categoryID == category.id }
      .sorted { $0.order < $1.order }
  }

  private func selectedCount(in category: ToolCategoryDefinition) -> Int {
    options(in: category).filter { selection.selectedOptionIDs.contains($0.id) }.count
  }

  private func color(for risk: ToolRiskLevel) -> Color {
    switch risk {
    case .standard: .purple
    case .caution, .advanced: .orange
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
