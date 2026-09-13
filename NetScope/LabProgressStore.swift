import Combine
import Foundation

struct CompletedLabStep: Codable, Hashable, Sendable {
  let missionID: String
  let stepID: String
}

@MainActor
final class LabProgressStore: ObservableObject {
  @Published private(set) var completed: Set<CompletedLabStep>

  private let defaults: UserDefaults
  private let key = "NetScope.labProgress.v1"

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    completed = defaults.data(forKey: key)
      .flatMap { try? JSONDecoder().decode(Set<CompletedLabStep>.self, from: $0) }
      ?? []
  }

  func complete(missionID: String, stepID: String) {
    completed.insert(CompletedLabStep(missionID: missionID, stepID: stepID))
    if let data = try? JSONEncoder().encode(completed) {
      defaults.set(data, forKey: key)
    }
  }

  func isComplete(missionID: String, stepID: String) -> Bool {
    completed.contains(CompletedLabStep(missionID: missionID, stepID: stepID))
  }
}
