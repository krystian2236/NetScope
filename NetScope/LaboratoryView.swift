import SwiftUI

struct LaboratoryView: View {
  let missions: [LabMission]
  let programs: [LabProgram]
  let onTryOwnNetwork: () -> Void

  @StateObject private var progressStore = LabProgressStore()
  @State private var confirmsResetAll = false
  @State private var selectedSection = LaboratorySectionID.learning

  init(
    missions: [LabMission] = LabMission.demo,
    programs: [LabProgram] = [NmapLabProgram.definition, NucleiLabProgram.definition],
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
    let allSteps = missions.flatMap(\.steps)
    let completedSteps = allSteps.filter { step in
      missions.contains { mission in
        progressStore.isComplete(missionID: mission.id, stepID: step.id)
      }
    }.count
    let nextMission = missions.first { !missionIsComplete($0) }

    return VStack(alignment: .leading, spacing: 9) {
      HStack {
        Label("Postęp nauki", systemImage: "chart.bar.fill")
          .font(.subheadline.weight(.semibold))
        Spacer()
        Text("\(completedSteps)/\(allSteps.count)")
          .font(.caption.monospacedDigit().weight(.semibold))
          .foregroundStyle(.cyan)
      }

      ProgressView(value: Double(completedSteps), total: Double(max(allSteps.count, 1)))
        .tint(.cyan)

      if let nextMission {
        NavigationLink {
          TerminalLessonView(
            mission: nextMission,
            progressStore: progressStore,
            onTryOwnNetwork: onTryOwnNetwork
          )
        } label: {
          HStack(spacing: 8) {
            Image(systemName: "play.circle.fill")
            VStack(alignment: .leading, spacing: 1) {
              Text("Wznów naukę")
                .font(.caption.weight(.semibold))
              Text(nextMission.title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
              .font(.caption2.weight(.bold))
          }
          .foregroundStyle(.cyan)
        }
        .buttonStyle(.plain)
      } else {
        Label("Wszystkie dostępne misje ukończone", systemImage: "checkmark.seal.fill")
          .font(.caption.weight(.medium))
          .foregroundStyle(.green)
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
    mission.steps.allSatisfy {
      progressStore.isComplete(missionID: mission.id, stepID: $0.id)
    }
  }
}
