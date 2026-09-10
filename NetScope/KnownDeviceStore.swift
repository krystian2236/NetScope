import Foundation

@MainActor
final class KnownDeviceStore: ObservableObject {
  @Published private(set) var records: [KnownDeviceRecord] = []
  @Published private(set) var errorMessage: String?

  private let fileURL: URL
  private let fileManager: FileManager

  nonisolated static var defaultFileURL: URL {
    let applicationSupport = FileManager.default.urls(
      for: .applicationSupportDirectory,
      in: .userDomainMask
    ).first ?? FileManager.default.temporaryDirectory
    return applicationSupport
      .appending(path: "NetScope", directoryHint: .isDirectory)
      .appending(path: "known-devices.json")
  }

  init(
    fileURL: URL = KnownDeviceStore.defaultFileURL,
    fileManager: FileManager = .default
  ) {
    self.fileURL = fileURL
    self.fileManager = fileManager
    load()
  }

  func record(for device: NetworkDevice, networkID: String) -> KnownDeviceRecord? {
    record(for: KnownDeviceKey(networkID: networkID, address: device.address))
  }

  func record(for key: KnownDeviceKey) -> KnownDeviceRecord? {
    records.first { $0.key == key }
  }

  @discardableResult
  func merge(
    devices: [NetworkDevice],
    networkID: String,
    at date: Date = .now
  ) -> Set<KnownDeviceKey> {
    var inserted: Set<KnownDeviceKey> = []

    for device in devices {
      let key = KnownDeviceKey(networkID: networkID, address: device.address)
      if let index = records.firstIndex(where: { $0.key == key }) {
        records[index].hostname = device.hostname
        records[index].lastSeen = date
        records[index].openPorts = device.openPorts
        records[index].kind = device.kind
      } else {
        records.append(
          KnownDeviceRecord(
            id: UUID(),
            key: key,
            hostname: device.hostname,
            customName: nil,
            trustStatus: .unknown,
            firstSeen: date,
            lastSeen: date,
            openPorts: device.openPorts,
            kind: device.kind
          )
        )
        inserted.insert(key)
      }
    }

    persist()
    return inserted
  }

  func rename(_ key: KnownDeviceKey, customName: String) {
    guard let index = records.firstIndex(where: { $0.key == key }) else { return }
    let trimmed = customName.trimmingCharacters(in: .whitespacesAndNewlines)
    records[index].customName = trimmed.isEmpty ? nil : trimmed
    persist()
  }

  func setTrust(_ key: KnownDeviceKey, status: DeviceTrustStatus) {
    guard let index = records.firstIndex(where: { $0.key == key }) else { return }
    records[index].trustStatus = status
    persist()
  }

  func remove(_ key: KnownDeviceKey) {
    guard records.contains(where: { $0.key == key }) else { return }
    records.removeAll { $0.key == key }
    persist()
  }

  func clearError() {
    errorMessage = nil
  }

  private func load() {
    guard fileManager.fileExists(atPath: fileURL.path) else { return }

    do {
      let data = try Data(contentsOf: fileURL)
      records = try JSONDecoder().decode([KnownDeviceRecord].self, from: data)
    } catch {
      preserveCorruptFile()
      records = []
      errorMessage =
        "Nie udało się odczytać zapamiętanych urządzeń. Uszkodzony plik został zachowany jako kopia."
    }
  }

  private func persist() {
    do {
      try fileManager.createDirectory(
        at: fileURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
      )
      let data = try JSONEncoder().encode(records)
      try data.write(to: fileURL, options: .atomic)
    } catch {
      errorMessage =
        "Nie udało się zapisać zmian w zapamiętanych urządzeniach. Wyniki bieżącego skanu pozostają dostępne."
    }
  }

  private func preserveCorruptFile() {
    let timestamp = Int(Date.now.timeIntervalSince1970)
    let backupURL = fileURL
      .deletingPathExtension()
      .appendingPathExtension("json.corrupt-\(timestamp)")
    try? fileManager.moveItem(at: fileURL, to: backupURL)
  }
}
