import SwiftUI

struct LaboratoryView: View {
  let missions: [LabMission]
  let programs: [LabProgram]
  let accessState: LabAccessState
  let onTryOwnNetwork: () -> Void
  let discoveredTargets: [String]

  @StateObject private var progressStore = LabProgressStore()
  @State private var confirmsResetAll = false
  @State private var selectedProMission: ProMissionPreview?
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
        HStack(spacing: 6) {
          DeveloperAreaTag(.navLaboratory)
          DeveloperAreaTag(.laboratoryScreen)
          Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)

        HStack(spacing: 6) {
          DeveloperAreaTag(.navLabSections)
          DeveloperAreaTag(selectedSectionNavigationArea)
          Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)

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
      .sheet(item: $selectedProMission) { item in
        NavigationStack {
          ContentUnavailableView(
            "NetScope Pro",
            systemImage: "lock.fill",
            description: Text(
              "\(item.programTitle) • \(item.moduleTitle)\n\n\(item.mission.title)\n\n\(item.mission.summary)"
            )
          )
          .toolbar {
            ToolbarItem(placement: .confirmationAction) {
              Button("Gotowe") {
                selectedProMission = nil
              }
            }
          }
          .padding()
        }
        .presentationDetents([.medium])
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
      List {
        DeveloperAreaTag(.learning(.missionList))

        Section("Dostępne teraz") {
          if missions.isEmpty {
            Text("Brak misji demo.")
              .font(.caption)
              .foregroundStyle(.secondary)
          } else {
            ForEach(missions) { mission in
              NavigationLink {
                TerminalLessonView(
                  mission: mission,
                  progressStore: progressStore,
                  onTryOwnNetwork: onTryOwnNetwork,
                  discoveredTargets: discoveredTargets
                )
              } label: {
                MissionRowView(
                  icon: missionIsComplete(mission) ? "checkmark.circle.fill" : "terminal",
                  iconColor: missionIsComplete(mission) ? .green : .cyan,
                  title: mission.title,
                  subtitle: mission.summary,
                  badge: nil
                )
              }
            }
          }
        }

        Section("Misje Pro") {
          if proMissions.isEmpty {
            Text("Brak dodatkowych misji Pro do odblokowania.")
              .font(.caption)
              .foregroundStyle(.secondary)
          } else {
            ForEach(proMissions) { item in
              Button {
                selectedProMission = item
              } label: {
                MissionRowView(
                  icon: "lock.fill",
                  iconColor: .yellow,
                  title: item.mission.title,
                  subtitle: "\(item.programTitle) • \(item.moduleTitle)",
                  badge: "PRO"
                )
              }
              .buttonStyle(.plain)
            }
          }
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

  private var proMissions: [ProMissionPreview] {
    programs.flatMap { program in
      program.modules
        .filter { !LabAccessPolicy.canOpen($0.access, state: accessState, variant: BuildVariant.current) }
        .flatMap { module in
          module.lessons.map { mission in
            ProMissionPreview(
              id: "\(program.id.rawValue)-\(module.id)-\(mission.id)",
              programTitle: program.title,
              moduleTitle: module.title,
              mission: mission
            )
          }
        }
    }
  }

  private struct ProMissionPreview: Identifiable {
    let id: String
    let programTitle: String
    let moduleTitle: String
    let mission: LabMission
  }

  private struct MissionRowView: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let badge: String?

    var body: some View {
      HStack(spacing: 12) {
        Image(systemName: icon)
          .font(.title3)
          .foregroundStyle(iconColor)
          .frame(width: 36)

        VStack(alignment: .leading, spacing: 3) {
          Text(title).font(.headline)
          Text(subtitle)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }

        Spacer()
        if let badge {
          Text(badge)
            .font(.caption.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.purple.opacity(0.16), in: Capsule())
            .foregroundStyle(.purple)
        }
      }
      .padding(.vertical, 4)
    }
  }

  private var selectedSectionNavigationArea: DeveloperAreaID {
    switch selectedSection {
    case .learning:
      return .navLabLearning
    case .tool(let toolID):
      return .navLabTool(DeveloperAreaTool(toolID))
    }
  }
}
