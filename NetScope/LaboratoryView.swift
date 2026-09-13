import SwiftUI

struct LaboratoryView: View {
  let missions: [LabMission]
  let onTryOwnNetwork: () -> Void

  @StateObject private var progressStore = LabProgressStore()
  @State private var confirmsResetAll = false

  init(
    missions: [LabMission] = LabMission.demo,
    onTryOwnNetwork: @escaping () -> Void
  ) {
    self.missions = missions
    self.onTryOwnNetwork = onTryOwnNetwork
  }

  var body: some View {
    NavigationStack {
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

  private func missionIsComplete(_ mission: LabMission) -> Bool {
    mission.steps.allSatisfy {
      progressStore.isComplete(missionID: mission.id, stepID: $0.id)
    }
  }
}
