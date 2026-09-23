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

  @Environment(\.dismiss) private var dismiss
  @State private var input = ""
  @State private var entries: [TerminalEntry] = []
  @State private var revealedHintCount = 0
  @State private var isSolutionVisible = false
  @State private var completedStepID: String?

  private let engine = VirtualLabEngine(network: .demo)

  private var activeStep: LabStep? {
    mission.steps.first {
      !progressStore.isComplete(missionID: mission.id, stepID: $0.id)
    }
  }

  private var completedStep: LabStep? {
    if let completedStepID { return mission.steps.first { $0.id == completedStepID } }
    return activeStep == nil ? mission.steps.last : nil
  }

  private var nextStep: LabStep? {
    guard let completedStep, let index = mission.steps.firstIndex(of: completedStep) else { return nil }
    return mission.steps.dropFirst(index + 1).first {
      !progressStore.isComplete(missionID: mission.id, stepID: $0.id)
    }
  }

  private var state: TerminalLessonState {
    TerminalLessonState.resolve(
      isShowingCompletion: completedStep != nil,
      hasNextStep: nextStep != nil,
      revealedHintCount: revealedHintCount,
      isSolutionVisible: isSolutionVisible
    )
  }

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 14) {
          #if NETSCOPE_DEV
          HStack { UIRefCopyButton(ref: .labsMission); Spacer() }
          #endif
          switch state {
          case .completed:
            if let completedStep {
              completionState(for: completedStep)
            }
          case .active, .hints, .solution:
            if let activeStep {
              activeLessonState(for: activeStep)
            }
          }
        }
        .padding(16)
      }
      .background(Color(.systemGroupedBackground))
      .navigationTitle(mission.title)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar(.hidden, for: .tabBar)
      .onChange(of: entries.count) {
        withAnimation { proxy.scrollTo("terminal-bottom", anchor: .bottom) }
      }
    }
  }

  @ViewBuilder
  private func activeLessonState(for step: LabStep) -> some View {
    objectiveCard(step)
    terminal(for: step)
    lessonHelp(for: step)
  }

  private func objectiveCard(_ step: LabStep) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Label("Cel lekcji", systemImage: "target")
        .font(.headline)
        .foregroundStyle(.cyan)
      Text(step.learningObjective)
        .font(.callout)
      Label("TEST DATA • wirtualna sieć \(VirtualNetwork.demo.cidr)", systemImage: "lock.shield")
        .font(.caption2.monospaced())
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(14)
    .background(.background, in: RoundedRectangle(cornerRadius: 14))
  }

  private func terminal(for step: LabStep) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Label("Terminal", systemImage: "terminal")
        .font(.subheadline.weight(.semibold))
      history
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
      #if NETSCOPE_DEV
      HStack {
        Button("Wstaw odpowiedź") {
          input = LabCommandPresentation(intent: step.acceptedIntent).command
          UIAccessibility.post(notification: .announcement, argument: "Odpowiedź deweloperska wstawiona do terminala")
        }
        Button("Kopiuj") {
          UIPasteboard.general.string = LabCommandPresentation(intent: step.acceptedIntent).command
          UIAccessibility.post(notification: .announcement, argument: "Odpowiedź deweloperska skopiowana")
        }
      }
      .font(.caption.weight(.semibold))
      .buttonStyle(.bordered)
      .tint(.cyan)
      #endif
    }
    .padding(12)
    .background(Color.black.opacity(0.94), in: RoundedRectangle(cornerRadius: 13))
    .foregroundStyle(.white)
    .id("terminal-bottom")
  }

  @ViewBuilder
  private var history: some View {
    if entries.isEmpty {
      Text("Wpisz polecenie, aby rozpocząć.")
        .font(.caption)
        .foregroundStyle(.white.opacity(0.65))
    } else {
      ForEach(entries.suffix(2)) { entry in
        terminalEntry(entry)
      }
    }
  }

  private func lessonHelp(for step: LabStep) -> some View {
    VStack(alignment: .leading, spacing: 9) {
      if revealedHintCount == 0 {
        Button("Potrzebuję podpowiedzi") {
          revealedHintCount = min(1, step.hints.count)
        }
        .buttonStyle(.bordered)
      } else {
        Label("Podpowiedź \(revealedHintCount) z \(step.hints.count)", systemImage: "lightbulb")
          .font(.subheadline.weight(.semibold))
        ForEach(Array(step.hints.prefix(revealedHintCount).enumerated()), id: \.offset) { index, hint in
          Text("\(index + 1). \(hint)").font(.caption)
        }
        if revealedHintCount < step.hints.count {
          Button("Pokaż kolejną podpowiedź") { revealedHintCount += 1 }
            .buttonStyle(.bordered)
        } else if !isSolutionVisible {
          Button("Pokaż rozwiązanie") { isSolutionVisible = true }
            .buttonStyle(.bordered)
        }
        if isSolutionVisible {
          solutionCard(LabCommandPresentation(intent: step.acceptedIntent), title: "Rozwiązanie")
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .background(.background, in: RoundedRectangle(cornerRadius: 14))
  }

  private func completionState(for step: LabStep) -> some View {
    let finding = step.finding
    return VStack(alignment: .leading, spacing: 12) {
      Label("Lekcja ukończona", systemImage: "checkmark.seal.fill")
        .font(.headline)
        .foregroundStyle(.green)
      completionRow("Co wykryto", finding.title)
      completionRow("Co to oznacza", finding.what)
      completionRow("Dlaczego ma znaczenie", finding.whyItMatters)
      completionRow("Co zrobić", finding.recommendation)
      completionRow("Jak sprawdzić ponownie", finding.recheck)
      Text("Priorytet w tej lekcji: \(finding.priority.title.lowercased())")
        .font(.caption.weight(.semibold))
        .foregroundStyle(finding.priority == .high ? .red : finding.priority == .medium ? .orange : .green)

      if let entry = entries.last, !entry.result.explanations.isEmpty {
        DisclosureGroup("Jak czytać wynik") {
          Text(entry.result.explanations.map { "\($0.term): \($0.meaning)" }.joined(separator: "\n"))
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.top, 4)
        }
        .font(.caption.weight(.semibold))
      }

      Button(nextStep == nil ? "Zakończ lekcję" : "Następny krok", action: continueLesson)
        .buttonStyle(.borderedProminent)
        .tint(.cyan)

      HStack {
        Button("Sprawdź ponownie") { reopen(step) }
        Button("Powtórz") { repeatMission() }
        Button("Własna sieć", action: onTryOwnNetwork)
      }
      .buttonStyle(.bordered)
      .font(.caption.weight(.semibold))
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(14)
    .background(Color.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
  }

  private func completionRow(_ title: String, _ value: String) -> some View {
    VStack(alignment: .leading, spacing: 3) {
      Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
      Text(value).font(.callout)
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
          .foregroundStyle(.white.opacity(0.75))
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(10)
    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 11))
  }

  private func runCommand() {
    let command = input.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !command.isEmpty, let step = activeStep else { return }

    let result = engine.execute(command)
    entries.append(TerminalEntry(command: LabCommandSanitizer.redactForHistory(command), result: result))

    if step.accepts(command: command, result: result) {
      progressStore.complete(missionID: mission.id, stepID: step.id)
      completedStepID = step.id
      input = ""
      revealedHintCount = 0
      isSolutionVisible = false
      UIAccessibility.post(notification: .announcement, argument: "Krok lekcji ukończony")
    }
  }

  private func continueLesson() {
    guard nextStep != nil else {
      dismiss()
      return
    }
    completedStepID = nil
    input = ""
    revealedHintCount = 0
    isSolutionVisible = false
  }

  private func reopen(_ step: LabStep) {
    progressStore.uncomplete(missionID: mission.id, stepID: step.id)
    completedStepID = nil
    input = LabCommandPresentation(intent: step.acceptedIntent).command
    revealedHintCount = 0
    isSolutionVisible = false
  }

  private func repeatMission() {
    progressStore.reset(missionID: mission.id)
    completedStepID = nil
    input = ""
    entries = []
    revealedHintCount = 0
    isSolutionVisible = false
    UIAccessibility.post(notification: .announcement, argument: "Misja rozpoczęta ponownie")
  }

  private func solutionCard(_ presentation: LabCommandPresentation, title: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Label(title, systemImage: "hammer.fill")
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.purple)
      Text(presentation.command)
        .font(.caption.monospaced())
        .textSelection(.enabled)
      DisclosureGroup("Budowa polecenia") {
        VStack(alignment: .leading, spacing: 7) {
          ForEach(Array(presentation.segments.enumerated()), id: \.offset) { _, segment in
            Text("\(segment.value) — \(segment.explanation)")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
        .padding(.top, 4)
      }
      .font(.caption.weight(.semibold))
    }
    .padding(11)
    .background(Color.purple.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
  }

  private func color(for status: VirtualCommandResult.Status) -> Color {
    switch status {
    case .success: .green
    case .invalid: .secondary
    case .unsupported: .red
    }
  }
}
