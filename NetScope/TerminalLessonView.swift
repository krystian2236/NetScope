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
  let discoveredTargets: [String]

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
          objectiveCard
          history
          prompt
          developerSolution
          hints
          completionCard
        }
        .padding(16)
      }
      .background(Color(.systemGroupedBackground))
      .navigationTitle(mission.title)
      .navigationBarTitleDisplayMode(.inline)
      .onAppear(perform: seedDiscoveredTarget)
      .onChange(of: discoveredTargets) { _, _ in
        seedDiscoveredTarget()
      }
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
        .font(.subheadline)
      Text("Sieć demonstracyjna: \(VirtualNetwork.demo.cidr)")
        .font(.caption.monospaced())
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(14)
    .background(.background, in: RoundedRectangle(cornerRadius: 14))
  }

  @ViewBuilder
  private var history: some View {
    if entries.isEmpty {
      ContentUnavailableView(
        "Terminal czeka",
        systemImage: "terminal",
        description: Text("Wpisz polecenie lub skorzystaj z podpowiedzi. Nic nie zostanie wykonane poza laboratorium.")
      )
      .frame(minHeight: 180)
    } else {
      VStack(alignment: .leading, spacing: 10) {
        ForEach(entries) { entry in
          terminalEntry(entry)
        }
      }
    }
  }

  private var prompt: some View {
    VStack(alignment: .leading, spacing: 10) {
      if !quickDiscoveredTargets.isEmpty {
        VStack(alignment: .leading, spacing: 8) {
          Text("Wstaw wykryty adres")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)

          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
              ForEach(quickDiscoveredTargets, id: \.self) { target in
                Button(target) {
                  input = target
                  UIAccessibility.post(notification: .announcement, argument: "Wstawiono \(target)")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .font(.caption.monospaced())
              }
            }
          }
        }
      }

      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Text("lab $")
          .font(.body.monospaced().bold())
          .foregroundStyle(.green)
          .accessibilityHidden(true)
        TextField("Wpisz polecenie", text: $input, axis: .vertical)
          .font(.body.monospaced())
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
          .submitLabel(.go)
          .onSubmit(runCommand)
          .accessibilityLabel("Polecenie laboratorium")
      }

      Button(action: runCommand) {
        Label("Uruchom w laboratorium", systemImage: "play.fill")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
    .padding(14)
    .background(Color.black, in: RoundedRectangle(cornerRadius: 14))
    .foregroundStyle(.white)
    .id("terminal-bottom")
  }

  @ViewBuilder
  private var developerSolution: some View {
    if BuildVariant.current.includesDeveloperTools, let step = activeStep {
      solutionCard(
        LabCommandPresentation(intent: step.acceptedIntent),
        title: "Gotowe rozwiązanie — Developer",
        allowsActions: true
      )
    }
  }

  @ViewBuilder
  private var hints: some View {
    if let step = activeStep {
      VStack(alignment: .leading, spacing: 9) {
        Label("Podpowiedzi", systemImage: "lightbulb")
          .font(.headline)
        ForEach(Array(step.hints.prefix(revealedHintCount).enumerated()), id: \.offset) { index, hint in
          Text("\(index + 1). \(hint)")
            .font(.subheadline)
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
      .padding(14)
      .background(.background, in: RoundedRectangle(cornerRadius: 14))
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

  private func terminalEntry(_ entry: TerminalEntry) -> some View {
    VStack(alignment: .leading, spacing: 7) {
      Text("$ \(entry.command)")
        .font(.subheadline.monospaced().bold())
      Text(entry.result.output)
        .font(.caption.monospaced())
        .foregroundStyle(color(for: entry.result.status))
      if let hint = entry.result.hint {
        Label(hint, systemImage: "info.circle.fill")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      if !entry.result.explanations.isEmpty {
        DisclosureGroup("Co oznacza to polecenie?") {
          ForEach(Array(entry.result.explanations.enumerated()), id: \.offset) { _, explanation in
            VStack(alignment: .leading, spacing: 2) {
              Text(explanation.term).font(.caption.monospaced().bold())
              Text(explanation.meaning).font(.caption).foregroundStyle(.secondary)
            }
            .padding(.top, 5)
          }
        }
        .font(.caption.weight(.semibold))
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .background(Color.black, in: RoundedRectangle(cornerRadius: 12))
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

  private var quickDiscoveredTargets: [String] {
    var unique: [String] = []
    var seen: Set<String> = []

    if let missionTarget = missionTargetsForQuickInsert,
       isIPv4Address(missionTarget),
       discoveredTargets.contains(missionTarget)
    {
      unique.append(missionTarget)
      seen.insert(missionTarget)
    }

    for address in discoveredTargets where isIPv4Address(address) {
      if seen.insert(address).inserted {
        unique.append(address)
      }
      if unique.count >= 5 {
        break
      }
    }

    return unique
  }

  private var missionTargetsForQuickInsert: String? {
    guard let step = activeStep else { return nil }
    switch step.acceptedIntent {
    case .inspect(let host, _, _):
      return host
    case .nmapDiagnostic(let host):
      return host
    case .connectSSH(_, let host):
      return host
    default:
      return nil
    }
  }

  private func seedDiscoveredTarget() {
    guard input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
    guard let step = activeStep else { return }
    guard !isDiscoveryStep(step) else { return }

    if let missionTarget = missionTargetsForQuickInsert,
       isIPv4Address(missionTarget),
       discoveredTargets.contains(missionTarget) {
      input = missionTarget
      return
    }

    if let firstTarget = quickDiscoveredTargets.first {
      input = firstTarget
    }
  }

  private func isIPv4Address(_ value: String) -> Bool {
    let parts = value.split(separator: ".")
    guard parts.count == 4 else { return false }

    let octets = parts.compactMap { Int($0) }
    return octets.count == 4 && octets.allSatisfy { (0...255).contains($0) }
  }

  private func isDiscoveryStep(_ step: LabStep) -> Bool {
    if case .discover = step.acceptedIntent {
      return true
    }
    return false
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
