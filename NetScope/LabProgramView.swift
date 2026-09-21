import SwiftUI

struct LabProgramView: View {
  let program: LabProgram
  let accessState: LabAccessState
  @ObservedObject var progressStore: LabProgressStore
  let onTryOwnNetwork: () -> Void
  let discoveredTargets: [String]

  @State private var showsProInformation = false

  var body: some View {
    List {
      DeveloperAreaTag(.laboratory(developerTool, .program))
      DeveloperAreaTag(.laboratory(developerTool, .missionList))

      Section {
        Label(program.summary, systemImage: program.icon)
          .font(.subheadline)
      } header: {
        Text(program.title)
      }

      ForEach(program.modules) { module in
        Section {
          if canOpen(module) {
            ForEach(module.lessons) { mission in
              NavigationLink {
                TerminalLessonView(
                  mission: mission,
                  progressStore: progressStore,
                  onTryOwnNetwork: onTryOwnNetwork,
                  discoveredTargets: discoveredTargets,
                  toolID: program.id
                )
              } label: {
                Label(mission.title, systemImage: "terminal")
              }
            }

            if module.lessons.isEmpty {
              Label("Materiał opisowy: \(module.coverage.count) opcji", systemImage: "book.pages")
                .foregroundStyle(.secondary)
            }
          } else {
            Button {
              showsProInformation = true
            } label: {
              HStack {
                VStack(alignment: .leading, spacing: 4) {
                  Text(module.summary)
                  Text("Dowiedz się o Pro")
                    .font(.caption)
                    .foregroundStyle(.cyan)
                }
                Spacer()
                Text("PRO")
                  .font(.caption.bold())
                  .padding(.horizontal, 8)
                  .padding(.vertical, 4)
                  .background(.purple.opacity(0.16), in: Capsule())
              }
            }
            .buttonStyle(.plain)
          }
        } header: {
          Text(module.title)
        } footer: {
          Text(module.summary)
        }
      }
    }
    .sheet(isPresented: $showsProInformation) {
      NavigationStack {
        ContentUnavailableView(
          "NetScope Pro",
          systemImage: "graduationcap.fill",
          description: Text("Pełne programy narzędziowe będą dostępne jako jednorazowe odblokowanie. Ten ekran nie rozpoczyna zakupu.")
        )
        .toolbar {
          ToolbarItem(placement: .confirmationAction) {
            Button("Gotowe") { showsProInformation = false }
          }
        }
      }
      .presentationDetents([.medium])
    }
  }

  private func canOpen(_ module: LabModule) -> Bool {
    LabAccessPolicy.canOpen(module.access, state: accessState, variant: BuildVariant.current)
  }

  private var developerTool: DeveloperAreaTool {
    DeveloperAreaTool(program.id)
  }
}
