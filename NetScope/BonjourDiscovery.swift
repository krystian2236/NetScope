import Foundation
import Network

@MainActor
final class BonjourDiscovery: ObservableObject {
  @Published private(set) var services: [BonjourServiceRecord] = []
  @Published private(set) var isRunning = false
  @Published private(set) var statusMessage = "Uruchom skan, aby wyszukać usługi Bonjour."

  private var browsers: [String: NWBrowser] = [:]

  private let queue = DispatchQueue(
    label: "pl.krystian.NetScope.bonjour",
    qos: .userInitiated
  )

  func start() {
    guard !isRunning else { return }

    services = []
    statusMessage = "Wyszukiwanie usług w sieci lokalnej…"
    isRunning = true

    for type in BonjourCatalog.serviceTypes {
      let parameters = NWParameters.tcp
      parameters.includePeerToPeer = true
      let browser = NWBrowser(
        for: .bonjour(type: type, domain: "local."),
        using: parameters
      )

      browser.stateUpdateHandler = { [weak self] state in
        guard case .waiting(let error) = state else { return }
        Task { @MainActor [weak self] in
          self?.statusMessage = "Bonjour oczekuje na dostęp: \(error.localizedDescription)"
        }
      }

      browser.browseResultsChangedHandler = { [weak self] results, _ in
        let records = results.compactMap { result -> BonjourServiceRecord? in
          guard case .service(let name, let foundType, let domain, let interface) = result.endpoint
          else {
            return nil
          }
          return BonjourServiceRecord(
            name: name,
            type: foundType,
            domain: domain,
            interfaceName: interface?.name
          )
        }

        Task { @MainActor [weak self] in
          self?.replaceServices(ofType: type, with: records)
        }
      }

      browsers[type] = browser
      browser.start(queue: queue)
    }
  }

  func stop() {
    for browser in browsers.values {
      browser.cancel()
    }
    browsers.removeAll()
    isRunning = false
    statusMessage =
      services.isEmpty
      ? "Nie znaleziono usług Bonjour."
      : "Znaleziono \(services.count) usług Bonjour."
  }

  private func replaceServices(
    ofType type: String,
    with newServices: [BonjourServiceRecord]
  ) {
    services.removeAll { $0.type == type }
    services.append(contentsOf: newServices)
    services.sort {
      if $0.friendlyType == $1.friendlyType {
        return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
      }
      return $0.friendlyType < $1.friendlyType
    }
    statusMessage =
      services.isEmpty
      ? "Wyszukiwanie usług w sieci lokalnej…"
      : "Znaleziono \(services.count) usług Bonjour."
  }
}
