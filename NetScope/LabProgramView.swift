import SwiftUI

struct LabProgramView: View {
  let program: LabProgram
  let accessState: LabAccessState
  @ObservedObject var progressStore: LabProgressStore
  let onTryOwnNetwork: () -> Void

  @State private var showsProInformation = false

  var body: some View {
    List {
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
                  onTryOwnNetwork: onTryOwnNetwork
                )
              } label: {
                HStack {
                  Label(
                    mission.title,
                    systemImage: progressStore.isComplete(mission) ? "checkmark.circle.fill" : "terminal"
                  )
                  .foregroundStyle(progressStore.isComplete(mission) ? .green : .primary)
                  Spacer()
                  Text("\(progressStore.completedStepCount(in: mission))/\(mission.steps.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                }
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

      if program.modules.isEmpty {
        ContentUnavailableView(
          "Brak modułów",
          systemImage: "tray",
          description: Text("Program nie zawiera jeszcze żadnych lekcji.")
        )
      }
    }
    #if NETSCOPE_DEV
    .safeAreaInset(edge: .top) {
      HStack {
        UIRefCopyButton(ref: programUIRef)
        Spacer()
      }
      .padding(.horizontal, 12)
      .padding(.top, 4)
      .background(.bar)
    }
    #endif
    .sheet(isPresented: $showsProInformation) {
      NavigationStack {
        ContentUnavailableView(
          "Northbyte Radar Pro",
          systemImage: "graduationcap.fill",
          description: Text("Pełne programy narzędziowe będą dostępne jako jednorazowe odblokowanie. Ten ekran nie rozpoczyna zakupu.")
        )
        #if NETSCOPE_DEV
        .safeAreaInset(edge: .top) {
          HStack {
            UIRefCopyButton(ref: .labsPro)
            Spacer()
          }
          .padding(.horizontal, 12)
          .padding(.top, 4)
          .background(.bar)
        }
        #endif
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

  #if NETSCOPE_DEV
  private var programUIRef: UIRef {
    switch program.id {
    case .nmap: .labsProgramNmap
    case .nuclei: .labsProgramNuclei
    case .dig: .labsProgramDig
    case .curl: .labsProgramCurl
    }
  }
  #endif
}
