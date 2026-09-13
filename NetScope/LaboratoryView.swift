import SwiftUI

struct LaboratoryView: View {
  let missions: [LabMission]
  let programs: [LabProgram]
  let accessState: LabAccessState
  let onTryOwnNetwork: () -> Void
  let discoveredTargets: [String]

  @StateObject private var progressStore = LabProgressStore()
  @State private var confirmsResetAll = false
  @State private var selectedSection = LaboratorySectionID.learning

  init(
    missions: [LabMission] = LabMission.demo,
    programs: [LabProgram] = LabCurriculum.firstMilestonePrograms,
    accessState: LabAccessState = .demo,
    onTryOwnNetwork: @escaping () -> Void,
    discoveredTargets: [String] = []
  ) {
    self.missions = missions
    self.programs = programs
    self.accessState = accessState
    self.onTryOwnNetwork = onTryOwnNetwork
    self.discoveredTargets = discoveredTargets
  }

  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
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
            onTryOwnNetwork: onTryOwnNetwork,
            discoveredTargets: discoveredTargets
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
          accessState: accessState,
          progressStore: progressStore,
          onTryOwnNetwork: onTryOwnNetwork,
          discoveredTargets: discoveredTargets
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
