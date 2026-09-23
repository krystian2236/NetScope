import SwiftUI

struct LabLearningLevel: Identifiable {
  let id: String
  let number: Int
  let title: String
  let section: LaboratorySectionID
  let missions: [LabMission]

  static func make(missions: [LabMission], programs: [LabProgram]) -> [Self] {
    let foundation = Self(
      id: "foundation",
      number: 1,
      title: "Podstawy",
      section: .learning,
      missions: missions
    )
    let toolLevels = programs.enumerated().map { index, program in
      Self(
        id: program.id.rawValue,
        number: index + 2,
        title: program.title,
        section: .tool(program.id),
        missions: program.modules.flatMap(\.lessons)
      )
    }
    return ([foundation] + toolLevels).filter { !$0.missions.isEmpty }
  }
}

struct LaboratoryView: View {
  let missions: [LabMission]
  let programs: [LabProgram]
  let onTryOwnNetwork: () -> Void

  @StateObject private var progressStore = LabProgressStore()
  @State private var confirmsResetAll = false
  @State private var selectedSection = LaboratorySectionID.learning
  @State private var isLearningPathExpanded = false

  init(
    missions: [LabMission] = LabMission.demo,
    programs: [LabProgram] = [
      NmapLabProgram.definition,
      NucleiLabProgram.definition,
      DigLabProgram.definition,
      CurlLabProgram.definition,
    ],
    onTryOwnNetwork: @escaping () -> Void
  ) {
    self.missions = missions
    self.programs = programs
    self.onTryOwnNetwork = onTryOwnNetwork
  }

  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        #if NETSCOPE_DEV
        HStack { UIRefCopyButton(ref: .labs); Spacer() }
          .padding(.horizontal, 12)
        #endif
        progressCard
        sectionPicker
        sectionContent
      }
      .navigationTitle("Laboratorium")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Resetuj postęp", systemImage: "arrow.counterclockwise") {
            confirmsResetAll = true
          }
          .disabled(progressStore.completed.isEmpty)
        }
      }
      .confirmationDialog(
        "Zacząć wszystkie misje od początku?",
        isPresented: $confirmsResetAll,
        titleVisibility: .visible
      ) {
        Button("Resetuj cały postęp", role: .destructive) {
          progressStore.resetAll()
        }
        Button("Anuluj", role: .cancel) {}
      } message: {
        Text("Usunięty zostanie wyłącznie lokalny postęp laboratorium.")
      }
    }
  }

  private var progressCard: some View {
    let levels = LabLearningLevel.make(missions: missions, programs: programs)
    let allSteps = levels.flatMap { $0.missions.flatMap(\.steps) }
    let completedSteps = levels.reduce(0) { partialResult, level in
      partialResult + completedStepCount(in: level)
    }
    let activeLevel = levels.first { level in
      level.missions.contains { !missionIsComplete($0) }
    }

    return VStack(alignment: .leading, spacing: 9) {
      Button {
        withAnimation(.easeInOut(duration: 0.2)) {
          isLearningPathExpanded.toggle()
        }
      } label: {
        HStack {
          Label("Ścieżka nauki", systemImage: "chart.bar.fill")
            .font(.subheadline.weight(.semibold))
          Spacer()
          Text("Łącznie \(completedSteps)/\(allSteps.count)")
            .font(.caption.monospacedDigit().weight(.semibold))
            .foregroundStyle(.cyan)
          Image(systemName: isLearningPathExpanded ? "chevron.up" : "chevron.down")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityValue(isLearningPathExpanded ? "Rozwinięta" : "Zwinięta")
      .accessibilityHint(isLearningPathExpanded ? "Zwiń listę poziomów" : "Rozwiń listę poziomów")

      if isLearningPathExpanded {
        VStack(alignment: .leading, spacing: 9) {
          ProgressView(value: Double(completedSteps), total: Double(max(allSteps.count, 1)))
            .tint(.cyan)

          ForEach(levels) { level in
            learningLevelRow(level)
          }

          if let activeLevel {
            Button {
              selectedSection = activeLevel.section
            } label: {
              Label("Otwórz poziom \(activeLevel.number): \(activeLevel.title)", systemImage: "play.circle.fill")
                .font(.caption.weight(.semibold))
            }
            .buttonStyle(.bordered)
            .tint(.cyan)
          } else {
            Label("Wszystkie poziomy ukończone", systemImage: "checkmark.seal.fill")
              .font(.caption.weight(.medium))
              .foregroundStyle(.green)
          }
        }
        .padding(.top, 8)
      }
    }
    .padding(12)
    .background(.background, in: RoundedRectangle(cornerRadius: 14))
    .overlay {
      RoundedRectangle(cornerRadius: 14)
        .stroke(Color.cyan.opacity(0.14), lineWidth: 1)
    }
    .padding(.horizontal, 12)
    .padding(.top, 4)
  }

  private func learningLevelRow(_ level: LabLearningLevel) -> some View {
    let completed = completedStepCount(in: level)
    let total = level.missions.reduce(0) { $0 + $1.steps.count }
    let isComplete = total > 0 && completed == total

    return HStack(spacing: 8) {
      Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
        .foregroundStyle(isComplete ? .green : .secondary)
      Text("Poziom \(level.number) · \(level.title)")
        .font(.caption.weight(.medium))
      Spacer()
      Text("\(completed)/\(total)")
        .font(.caption.monospacedDigit().weight(.semibold))
        .foregroundStyle(isComplete ? .green : .secondary)
    }
  }

  private func completedStepCount(in level: LabLearningLevel) -> Int {
    level.missions.reduce(0) { $0 + progressStore.completedStepCount(in: $1) }
  }

  private var sectionPicker: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        ForEach(LaboratorySectionID.navigationOrder, id: \.self) { section in
          Button(section.title) { selectedSection = section }
            .buttonStyle(.borderedProminent)
            .tint(selectedSection == section ? .cyan : .gray.opacity(0.28))
            .foregroundStyle(selectedSection == section ? .white : .primary)
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 10)
    }
  }

  @ViewBuilder
  private var sectionContent: some View {
    switch selectedSection {
    case .learning:
      if missions.isEmpty {
        ContentUnavailableView(
          "Brak misji",
          systemImage: "tray",
          description: Text("Misje Laboratory nie są jeszcze dostępne.")
        )
      } else {
        List(missions) { mission in
          NavigationLink {
            TerminalLessonView(
              mission: mission,
              progressStore: progressStore,
              onTryOwnNetwork: onTryOwnNetwork
            )
          } label: {
            HStack(spacing: 12) {
              Image(systemName: missionIsComplete(mission) ? "checkmark.circle.fill" : "terminal")
                .font(.title3)
                .foregroundStyle(missionIsComplete(mission) ? .green : .cyan)
                .frame(width: 36)
              VStack(alignment: .leading, spacing: 3) {
                Text(mission.title).font(.headline)
                Text(mission.summary)
                  .font(.caption)
                  .foregroundStyle(.secondary)
                  .lineLimit(2)
              }
            }
            .padding(.vertical, 4)
          }
        }
      }
    case .tool(let toolID):
      if let program = programs.first(where: { $0.id == toolID }) {
        LabProgramView(
          program: program,
          accessState: .demo,
          progressStore: progressStore,
          onTryOwnNetwork: onTryOwnNetwork
        )
      } else {
        ContentUnavailableView(
          "Program w przygotowaniu",
          systemImage: "hammer",
          description: Text("Pakiet \(toolID.rawValue.capitalized) pojawi się w tym etapie.")
        )
      }
    }
  }

  private func missionIsComplete(_ mission: LabMission) -> Bool {
    progressStore.isComplete(mission)
  }
}
