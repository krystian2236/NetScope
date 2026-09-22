import SwiftUI
import UIKit

struct TerminalEntry: Identifiable, Equatable {
  let id = UUID()
  let command: String
  let result: VirtualCommandResult
}

struct TerminalLessonView: View {
  let mission: LabMission
  @ObservedObject var progressStore: LabProgressStore
  let onTryOwnNetwork: () -> Void

  @State private var input = ""
  @State private var entries: [TerminalEntry] = []
  @State private var revealedHintCount = 0
  @State private var copiedSolution = false

  private let engine = VirtualLabEngine(network: .demo)

  private var activeStep: LabStep? {
    mission.steps.first {
      !progressStore.isComplete(missionID: mission.id, stepID: $0.id)
    }
  }

  private var isComplete: Bool { activeStep == nil }

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 14) {
          #if NETSCOPE_DEV
          HStack { UIRefCopyButton(ref: .labsMission); Spacer() }
          #endif
          objectiveCard
          history
          prompt
          developerSolution
          hints
          findingCard
          completionCard
          explanationCard
        }
        .padding(16)
      }
      .background(Color(.systemGroupedBackground))
      .navigationTitle(mission.title)
      .navigationBarTitleDisplayMode(.inline)
      .onChange(of: entries.count) {
        withAnimation { proxy.scrollTo("terminal-bottom", anchor: .bottom) }
      }
    }
  }

  private var objectiveCard: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label(isComplete ? "Lekcja ukończona" : "Cel lekcji", systemImage: isComplete ? "checkmark.seal.fill" : "target")
        .font(.headline)
        .foregroundStyle(isComplete ? .green : .cyan)
      Text(activeStep?.objective ?? mission.summary)
        .font(.callout)
      Label("TEST DATA • wirtualna sieć \(VirtualNetwork.demo.cidr)", systemImage: "lock.shield")
        .font(.caption2.monospaced())
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(14)
    .background(.background, in: RoundedRectangle(cornerRadius: 14))
  }

  @ViewBuilder
  private var history: some View {
    if entries.isEmpty {
      HStack(spacing: 8) {
        Image(systemName: "terminal")
        Text("Wpisz polecenie, aby rozpocząć.")
      }
      .font(.caption)
      .foregroundStyle(.secondary)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 4)
    } else {
      VStack(alignment: .leading, spacing: 10) {
        ForEach(entries.suffix(3)) { entry in
          terminalEntry(entry)
        }
      }
    }
  }

  private var prompt: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Text("krg $")
          .font(.caption.monospaced().weight(.semibold))
          .foregroundStyle(.secondary)
          .accessibilityHidden(true)
        TextField("Wpisz polecenie", text: $input, axis: .vertical)
          .font(.callout.monospaced())
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
          .submitLabel(.go)
          .onSubmit(runCommand)
          .accessibilityLabel("Polecenie laboratorium")
      }

      Button(action: runCommand) {
        Label("Uruchom", systemImage: "play.fill")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
    .padding(12)
    .background(Color.black.opacity(0.94), in: RoundedRectangle(cornerRadius: 13))
    .foregroundStyle(.white)
    .id("terminal-bottom")
  }

  @ViewBuilder
  private var developerSolution: some View {
    if BuildVariant.current.includesDeveloperTools, let step = activeStep {
      DisclosureGroup("Rozwiązanie Developer") {
        solutionCard(
          LabCommandPresentation(intent: step.acceptedIntent),
          title: "Gotowe rozwiązanie",
          allowsActions: true
        )
      }
      .font(.caption.weight(.semibold))
      .padding(12)
      .background(.background, in: RoundedRectangle(cornerRadius: 12))
    }
  }

  @ViewBuilder
  private var hints: some View {
    if let step = activeStep {
      VStack(alignment: .leading, spacing: 9) {
        Label("Podpowiedzi", systemImage: "lightbulb")
          .font(.subheadline.weight(.semibold))
        ForEach(Array(step.hints.prefix(revealedHintCount).enumerated()), id: \.offset) { index, hint in
          Text("\(index + 1). \(hint)")
            .font(.caption)
        }
        if revealedHintCount >= step.hints.count, !step.hints.isEmpty {
          solutionCard(
            LabCommandPresentation(intent: step.acceptedIntent),
            title: "Sprawdź rozwiązanie",
            allowsActions: false
          )
        }
        Button(revealedHintCount < step.hints.count ? "Pokaż kolejną podpowiedź" : "Rozwiązanie jest widoczne") {
          revealedHintCount = min(revealedHintCount + 1, step.hints.count)
        }
        .disabled(revealedHintCount >= step.hints.count)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(12)
      .background(.background, in: RoundedRectangle(cornerRadius: 14))
    }
  }

  @ViewBuilder
  private var findingCard: some View {
    if let completedStep = mission.steps.last(where: {
      progressStore.isComplete(missionID: mission.id, stepID: $0.id)
    }) {
      let finding = completedStep.finding
      VStack(alignment: .leading, spacing: 9) {
        HStack {
          Label("Finding", systemImage: "exclamationmark.shield.fill")
            .font(.subheadline.weight(.semibold))
          Spacer()
          Text(finding.priority.title)
            .font(.caption.bold())
            .foregroundStyle(finding.priority == .high ? .red : finding.priority == .medium ? .orange : .green)
        }
        Text(finding.title).font(.callout.weight(.semibold))
        Text(finding.what).font(.caption)
        Text("Dlaczego to ważne: \(finding.whyItMatters)").font(.caption).foregroundStyle(.secondary)
        Text("Możliwy wpływ: \(finding.impact)").font(.caption).foregroundStyle(.secondary)
        Label(finding.recommendation, systemImage: "checklist")
          .font(.caption)
        Label(finding.recheck, systemImage: "arrow.triangle.2.circlepath")
          .font(.caption)
          .foregroundStyle(.cyan)
        Button("Przygotuj ponowną kontrolę") {
          input = LabCommandPresentation(intent: completedStep.acceptedIntent).command
          UIAccessibility.post(notification: .announcement, argument: "Polecenie ponownej kontroli wstawione")
        }
        .buttonStyle(.borderedProminent)
        .tint(.cyan)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(12)
      .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
    }
  }

  @ViewBuilder
  private var completionCard: some View {
    if isComplete {
      VStack(alignment: .leading, spacing: 10) {
        Text("Świetnie — cel został osiągnięty bez dotykania prawdziwej sieci.")
          .font(.subheadline)
        Button(action: onTryOwnNetwork) {
          Label("Wypróbuj we własnej sieci", systemImage: "wifi")
        }
        .buttonStyle(.bordered)

        Button(action: repeatMission) {
          Label("Powtórz misję", systemImage: "arrow.counterclockwise")
        }
        .buttonStyle(.borderedProminent)
        .tint(.cyan)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(14)
      .background(Color.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
    }
  }

  @ViewBuilder
  private var explanationCard: some View {
    if let entry = entries.last, !entry.result.explanations.isEmpty {
      VStack(alignment: .leading, spacing: 5) {
        Label("Jak czytać wynik", systemImage: "info.circle")
          .font(.caption.weight(.semibold))
        Text(entry.result.explanations.map { "\($0.term): \($0.meaning)" }.joined(separator: " • "))
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(11)
      .background(.background, in: RoundedRectangle(cornerRadius: 12))
    }
  }

  private func terminalEntry(_ entry: TerminalEntry) -> some View {
    VStack(alignment: .leading, spacing: 7) {
      Text("krg $ \(entry.command)")
        .font(.caption.monospaced().weight(.semibold))
      Text(entry.result.output)
        .font(.caption2.monospaced())
        .foregroundStyle(color(for: entry.result.status))
      if let hint = entry.result.hint {
        Label(hint, systemImage: "info.circle.fill")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(10)
    .background(Color.black.opacity(0.94), in: RoundedRectangle(cornerRadius: 11))
    .foregroundStyle(.white)
  }

  private func runCommand() {
    let command = input.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !command.isEmpty else { return }

    let step = activeStep
    let result = engine.execute(command)
    entries.append(TerminalEntry(command: LabCommandSanitizer.redactForHistory(command), result: result))

    if let step, step.accepts(command: command, result: result) {
      progressStore.complete(missionID: mission.id, stepID: step.id)
      input = ""
      revealedHintCount = 0
      copiedSolution = false
      UIAccessibility.post(notification: .announcement, argument: "Krok lekcji ukończony")
    }
  }

  private func repeatMission() {
    progressStore.reset(missionID: mission.id)
    input = ""
    entries = []
    revealedHintCount = 0
    copiedSolution = false
    UIAccessibility.post(notification: .announcement, argument: "Misja rozpoczęta ponownie")
  }

  private func solutionCard(
    _ presentation: LabCommandPresentation,
    title: String,
    allowsActions: Bool
  ) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Label(title, systemImage: "hammer.fill")
        .font(.headline)
        .foregroundStyle(.purple)

      Text(presentation.command)
        .font(.subheadline.monospaced())
        .textSelection(.enabled)

      if allowsActions {
        HStack {
          Button {
            UIPasteboard.general.string = presentation.command
            copiedSolution = true
          } label: {
            Label(copiedSolution ? "Skopiowano" : "Kopiuj", systemImage: copiedSolution ? "checkmark" : "doc.on.doc")
          }
          .buttonStyle(.bordered)

          Button {
            input = presentation.command
            copiedSolution = false
            UIAccessibility.post(notification: .announcement, argument: "Polecenie wstawione do terminala")
          } label: {
            Label("Wstaw do terminala", systemImage: "arrow.down.to.line")
          }
          .buttonStyle(.borderedProminent)
          .tint(.cyan)
        }
        .font(.caption.weight(.semibold))
      }

      DisclosureGroup {
        VStack(alignment: .leading, spacing: 10) {
          ForEach(Array(presentation.segments.enumerated()), id: \.offset) { _, segment in
            VStack(alignment: .leading, spacing: 3) {
              HStack(spacing: 6) {
                Label(segment.category.title, systemImage: segment.category.icon)
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(.cyan)
                Text(segment.value)
                  .font(.caption.monospaced().bold())
              }
              Label(segment.explanation, systemImage: "info.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
        }
        .padding(.top, 6)
      } label: {
        Label("Budowa polecenia", systemImage: "square.split.2x1")
          .font(.caption.weight(.semibold))
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(14)
    .background(Color.purple.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
  }

  private func color(for status: VirtualCommandResult.Status) -> Color {
    switch status {
    case .success: .green
    case .invalid: .secondary
    case .unsupported: .red
    }
  }
}
