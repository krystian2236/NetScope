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
  let toolID: LabToolID?

  @State private var input = ""
  @State private var entries: [TerminalEntry] = []
  @State private var revealedHintCount = 0
  @State private var copiedSolution = false
  @State private var hasStarted = false

  private let engine = VirtualLabEngine(network: .demo)

  init(
    mission: LabMission,
    progressStore: LabProgressStore,
    onTryOwnNetwork: @escaping () -> Void,
    discoveredTargets: [String],
    toolID: LabToolID? = nil
  ) {
    self.mission = mission
    self._progressStore = ObservedObject(wrappedValue: progressStore)
    self.onTryOwnNetwork = onTryOwnNetwork
    self.discoveredTargets = discoveredTargets
    self.toolID = toolID
  }

  private var activeStep: LabStep? {
    mission.steps.first {
      !progressStore.isComplete(missionID: mission.id, stepID: $0.id)
    }
  }

  private var isComplete: Bool { activeStep == nil }
  private var briefing: LabBriefing { LabBriefing(mission: mission) }
  private var presentation: TerminalLessonPresentation {
    TerminalLessonPresentation(mission: mission, activeStep: activeStep)
  }

  var body: some View {
    Group {
      if hasStarted {
        terminalContent
      } else {
        briefingContent
      }
    }
    .background(Color(.systemGroupedBackground))
    .navigationTitle(hasStarted ? mission.title : "Odprawa")
    .navigationBarTitleDisplayMode(.inline)
  }

  private var terminalContent: some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 14) {
          DeveloperAreaTag(laboratoryArea(.terminal))
          lessonOverviewCard
          terminalPanel
          quickTargetTiles
          developerSolution
          hints
          completionCard
        }
        .padding(16)
      }
      .onAppear(perform: seedDiscoveredTarget)
      .onChange(of: discoveredTargets) { _, _ in
        seedDiscoveredTarget()
      }
      .onChange(of: entries.count) {
        withAnimation { proxy.scrollTo("terminal-bottom", anchor: .bottom) }
      }
    }
  }

  private var briefingContent: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 22) {
        DeveloperAreaTag(laboratoryArea(.briefing))
        VStack(alignment: .leading, spacing: 10) {
          Label(mission.isPro ? "PAKIET PRO" : "NAUKA", systemImage: "book.fill")
            .font(.caption.weight(.bold))
            .foregroundStyle(.cyan)
          Text(mission.title)
            .font(.largeTitle.bold())
          Text(mission.summary)
            .font(.title3)
            .foregroundStyle(.secondary)
        }

        HStack(spacing: 8) {
          briefingBadge(briefing.stepCountLabel, icon: "list.number")
          briefingBadge("Prowadzony", icon: "scope")
          briefingBadge("Offline", icon: "wifi.slash")
        }

        briefingSection("Twoja misja", icon: "target") {
          Text(briefing.objectives.first ?? mission.summary)
            .font(.body)
        }

        briefingSection("Czego się nauczysz", icon: "brain.head.profile") {
          VStack(alignment: .leading, spacing: 12) {
            ForEach(briefing.objectives, id: \.self) { objective in
              Label(objective, systemImage: "checkmark.circle.fill")
                .foregroundStyle(.secondary)
            }
          }
        }

        VStack(alignment: .leading, spacing: 8) {
          Label("Bezpieczna symulacja", systemImage: "lock.shield.fill")
            .font(.headline)
          Text("Polecenia działają wyłącznie na wbudowanej sieci demonstracyjnej. Nic nie zostanie wysłane do prawdziwego hosta.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
          Text("Cel: \(briefing.target)")
            .font(.caption.monospaced())
            .foregroundStyle(.cyan)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))

        Button {
          hasStarted = true
          seedDiscoveredTarget()
          UIAccessibility.post(notification: .announcement, argument: "Laboratorium uruchomione")
        } label: {
          Label("Rozpocznij laboratorium", systemImage: "play.fill")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(.cyan)
      }
      .padding(16)
      .padding(.bottom, 24)
    }
  }

  private func briefingBadge(_ title: String, icon: String) -> some View {
    Label(title, systemImage: icon)
      .font(.caption.weight(.semibold))
      .padding(.horizontal, 10)
      .padding(.vertical, 8)
      .background(.quaternary, in: Capsule())
  }

  private func briefingSection<Content: View>(
    _ title: String,
    icon: String,
    @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Label(title, systemImage: icon)
        .font(.title3.bold())
      content()
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var lessonOverviewCard: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("LEKCJA")
        .font(.caption.weight(.bold))
        .foregroundStyle(.cyan)
      Text(mission.title)
        .font(.title2.bold())
      Text(presentation.lessonDescription)
        .font(.subheadline)
        .foregroundStyle(.secondary)

      Divider().padding(.vertical, 4)

      Label(isComplete ? "Zadanie ukończone" : "Zadanie", systemImage: isComplete ? "checkmark.seal.fill" : "target")
        .font(.headline)
        .foregroundStyle(isComplete ? .green : .cyan)
      Text(presentation.taskDescription)
        .font(.body)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(16)
    .background(.background, in: RoundedRectangle(cornerRadius: 18))
  }

  private var terminalPanel: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Label("Terminal", systemImage: "terminal.fill")
          .font(.headline)
        Spacer()
        Text("OFFLINE")
          .font(.caption2.weight(.bold))
          .foregroundStyle(.green)
          .padding(.horizontal, 8)
          .padding(.vertical, 5)
          .background(Color.green.opacity(0.14), in: Capsule())
      }

      Text(presentation.terminalPrompt)
        .font(.caption2)
        .foregroundStyle(Color.white.opacity(0.68))

      terminalHistory

      Divider().overlay(Color.white.opacity(0.16))

      HStack(alignment: .center, spacing: 8) {
        Text("lab $")
          .font(.caption.monospaced().bold())
          .foregroundStyle(.green)
          .accessibilityHidden(true)
        TextField("Wpisz polecenie", text: $input, axis: .vertical)
          .font(.callout.monospaced())
          .foregroundColor(.white)
          .tint(.cyan)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
          .submitLabel(.go)
          .onSubmit(runCommand)
          .accessibilityLabel("Polecenie laboratorium")

        Button(action: runCommand) {
          Image(systemName: "arrow.up")
            .font(.headline.bold())
            .frame(width: 34, height: 34)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.circle)
        .tint(.cyan)
        .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .accessibilityLabel("Uruchom w laboratorium")
      }
      .padding(10)
      .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
    .padding(16)
    .background(Color.black, in: RoundedRectangle(cornerRadius: 18))
    .foregroundStyle(.white)
    .id("terminal-bottom")
  }

  @ViewBuilder
  private var terminalHistory: some View {
    if entries.isEmpty {
      VStack(alignment: .leading, spacing: 5) {
        Text("$ Wirtualne laboratorium gotowe.")
        Text("Wpisz help, aby zobaczyć dostępne polecenia.")
      }
      .font(.caption.monospaced())
      .foregroundStyle(.green)
      .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
    } else {
      VStack(alignment: .leading, spacing: 10) {
        ForEach(entries) { entry in
          terminalEntry(entry)
        }
      }
    }
  }

  @ViewBuilder
  private var quickTargetTiles: some View {
    if !quickDiscoveredTargets.isEmpty {
      VStack(alignment: .leading, spacing: 8) {
        Text("WSTAW WYKRYTY ADRES")
          .font(.caption.weight(.bold))
          .foregroundStyle(.secondary)

        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 8) {
            ForEach(quickDiscoveredTargets, id: \.self) { target in
              Button {
                input = target
                UIAccessibility.post(notification: .announcement, argument: "Wstawiono \(target)")
              } label: {
                Label(target, systemImage: "network")
                  .font(.caption.monospaced().weight(.semibold))
                  .padding(.vertical, 4)
              }
              .buttonStyle(.bordered)
              .tint(.cyan)
            }
          }
        }
      }
    }
  }

  @ViewBuilder
  private var developerSolution: some View {
    if BuildVariant.current.includesDeveloperTools, let step = activeStep {
      VStack(alignment: .leading, spacing: 8) {
        DeveloperAreaTag(laboratoryArea(.answer))
        solutionCard(
          LabCommandPresentation(intent: step.acceptedIntent),
          title: "Gotowe rozwiązanie — Developer",
          allowsActions: true
        )
      }
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
        DeveloperAreaTag(laboratoryArea(.result))
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

  private func laboratoryArea(_ part: DeveloperLaboratoryPart) -> DeveloperAreaID {
    if let toolID {
      return .laboratory(DeveloperAreaTool(toolID), part)
    }
    return .learning(part)
  }

  private func terminalEntry(_ entry: TerminalEntry) -> some View {
    VStack(alignment: .leading, spacing: 7) {
      Text("$ \(entry.command)")
        .font(.caption.monospaced().bold())
      Text(entry.result.output)
        .font(.caption2.monospaced())
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
    .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
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
    hasStarted = false
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
    case .invalid: .orange
    case .unsupported: .red
    }
  }
}
