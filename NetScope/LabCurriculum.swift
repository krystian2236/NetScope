import Foundation
import StoreKit
import Combine

enum LabToolID: String, CaseIterable, Identifiable, Equatable, Sendable {
  case nmap, nuclei, dig, curl

  var id: String { rawValue }

  static let firstMilestone: [Self] = [.nmap, .nuclei, .dig, .curl]
}

enum LabAccessTier: Equatable, Sendable {
  case demo
  case pro
  case subscription
}

enum LabAccessState: Equatable, Sendable {
  case demo
  case pro
  case subscription
}

struct NetScopeStoreProductIdentifiers: Equatable, Sendable {
  let lifetimePro: String?
  let subscriptions: Set<String>

  init(lifetimePro: String? = nil, subscriptions: Set<String> = []) {
    self.lifetimePro = lifetimePro
    self.subscriptions = subscriptions
  }

  static func appConfiguration(bundle: Bundle = .main) -> Self {
    let lifetimePro = (bundle.object(
      forInfoDictionaryKey: "NetScopeProProductID"
    ) as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines)

    let rawSubscriptions = bundle.object(
      forInfoDictionaryKey: "NetScopeSubscriptionProductIDs"
    )

    let subscriptions: Set<String>
    if let values = rawSubscriptions as? [String] {
      subscriptions = Set(
        values
          .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
          .filter { !$0.isEmpty }
      )
    } else if let csv = rawSubscriptions as? String {
      subscriptions = Set(
        csv
          .split(separator: ",")
          .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
          .filter { !$0.isEmpty }
      )
    } else {
      subscriptions = []
    }

    return NetScopeStoreProductIdentifiers(
      lifetimePro: lifetimePro?.isEmpty == false ? lifetimePro : nil,
      subscriptions: subscriptions
    )
  }

  var isConfigured: Bool {
    lifetimePro?.isEmpty == false || !subscriptions.isEmpty
  }

  var all: Set<String> {
    var identifiers = subscriptions
    if let lifetimePro, !lifetimePro.isEmpty {
      identifiers.insert(lifetimePro)
    }
    return identifiers
  }
}

struct NetScopeEntitlementSnapshot: Equatable, Sendable {
  static let demo = NetScopeEntitlementSnapshot(
    hasLifetimePro: false,
    hasActiveSubscription: false
  )

  let hasLifetimePro: Bool
  let hasActiveSubscription: Bool

  var accessState: LabAccessState {
    if hasActiveSubscription { return .subscription }
    if hasLifetimePro { return .pro }
    return .demo
  }
}

enum NetScopeStoreKitResolver {
  static func currentSnapshot(
    productIDs: NetScopeStoreProductIdentifiers
  ) async -> NetScopeEntitlementSnapshot {
    guard productIDs.isConfigured else { return .demo }

    var hasLifetimePro = false
    var hasActiveSubscription = false

    for await verification in StoreKit.Transaction.currentEntitlements {
      guard case .verified(let transaction) = verification else { continue }
      guard transaction.revocationDate == nil else { continue }

      if let lifetimePro = productIDs.lifetimePro,
         transaction.productID == lifetimePro {
        hasLifetimePro = true
      }

      if productIDs.subscriptions.contains(transaction.productID) {
        hasActiveSubscription = true
      }
    }

    return NetScopeEntitlementSnapshot(
      hasLifetimePro: hasLifetimePro,
      hasActiveSubscription: hasActiveSubscription
    )
  }
}

enum NetScopeStorePurchaseOutcome: Equatable, Sendable {
  case purchased
  case pending
  case cancelled
  case unverified
  case productUnavailable
  case failed
}

@MainActor
final class NetScopeEntitlementStore: ObservableObject {
  @Published private(set) var snapshot: NetScopeEntitlementSnapshot
  @Published private(set) var products: [Product] = []
  @Published private(set) var isLoadingProducts = false
  @Published private(set) var isPurchasing = false
  @Published private(set) var lastError: String?

  private let productIDs: NetScopeStoreProductIdentifiers
  private var transactionUpdatesTask: Task<Void, Never>?

  init(
    productIDs: NetScopeStoreProductIdentifiers,
    initialSnapshot: NetScopeEntitlementSnapshot = .demo
  ) {
    self.productIDs = productIDs
    snapshot = initialSnapshot
  }

  var accessState: LabAccessState {
    snapshot.accessState
  }

  var isConfigured: Bool {
    productIDs.isConfigured
  }

  func startObservingTransactions() {
    guard productIDs.isConfigured, transactionUpdatesTask == nil else { return }

    transactionUpdatesTask = Task { [weak self] in
      for await verification in StoreKit.Transaction.updates {
        guard !Task.isCancelled else { return }
        guard case .verified(let transaction) = verification else { continue }
        guard let self, self.productIDs.all.contains(transaction.productID) else { continue }

        await transaction.finish()
        await self.refresh()
      }
    }
  }

  func refresh() async {
    snapshot = await NetScopeStoreKitResolver.currentSnapshot(
      productIDs: productIDs
    )
  }

  func loadProducts() async {
    guard productIDs.isConfigured else {
      products = []
      lastError = nil
      return
    }

    isLoadingProducts = true
    lastError = nil
    defer { isLoadingProducts = false }

    do {
      let loaded = try await Product.products(for: Array(productIDs.all))
      products = loaded.sorted { $0.id < $1.id }
    } catch {
      products = []
      lastError = "Nie udało się pobrać produktów ze StoreKit."
    }
  }

  func purchase(productID: String) async -> NetScopeStorePurchaseOutcome {
    guard let product = products.first(where: { $0.id == productID }) else {
      return .productUnavailable
    }

    isPurchasing = true
    lastError = nil
    defer { isPurchasing = false }

    do {
      switch try await product.purchase() {
      case .success(let verification):
        guard case .verified(let transaction) = verification else {
          return .unverified
        }

        await transaction.finish()
        await refresh()
        return .purchased

      case .pending:
        return .pending

      case .userCancelled:
        return .cancelled

      @unknown default:
        return .failed
      }
    } catch {
      lastError = "Zakup nie został zakończony."
      return .failed
    }
  }

  func restorePurchases() async -> Bool {
    lastError = nil

    do {
      try await AppStore.sync()
      await refresh()
      return true
    } catch {
      lastError = "Nie udało się przywrócić zakupów."
      return false
    }
  }

  deinit {
    transactionUpdatesTask?.cancel()
  }
}

struct LabLessonCoverage: Equatable, Sendable {
  enum Kind: Equatable, Sendable {
    case exercise
    case diagnostic
    case explanationOnly(String)
  }

  let optionID: String
  let kind: Kind
}

struct LabModule: Identifiable, Equatable, Sendable {
  let id: String
  let title: String
  let summary: String
  let access: LabAccessTier
  let lessons: [LabMission]
  let coverage: [LabLessonCoverage]
}

struct LabProgram: Identifiable, Equatable, Sendable {
  let id: LabToolID
  let title: String
  let summary: String
  let icon: String
  let modules: [LabModule]
}

enum LabCurriculum {
  static let firstMilestonePrograms: [LabProgram] = [
    NmapLabProgram.definition,
    NucleiLabProgram.definition,
    DigLabProgram.definition,
    CurlLabProgram.definition,
  ]
}

enum LabAccessPolicy {
  static func canOpen(
    _ tier: LabAccessTier,
    state: LabAccessState
  ) -> Bool {
    switch tier {
    case .demo:
      return true
    case .pro:
      return state == .pro || state == .subscription
    case .subscription:
      return state == .subscription
    }
  }
}

enum LabCommandSanitizer {
  static func redact(_ command: String, tool: ToolDefinition) -> String {
    tool.options.filter(\.isSecret).reduce(command) { current, option in
      option.flags.reduce(current) { value, flag in
        let escaped = NSRegularExpression.escapedPattern(for: flag)
        let pattern = "(?<!\\S)\(escaped)(?:=|\\s+)(?:'[^']*'|\"[^\"]*\"|\\S+)"
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return value }
        let range = NSRange(value.startIndex..., in: value)
        return expression.stringByReplacingMatches(
          in: value,
          range: range,
          withTemplate: "\(flag) [REDACTED]"
        )
      }
    }
  }

  static func redactForHistory(_ command: String) -> String {
    switch command.split(whereSeparator: \.isWhitespace).first?.lowercased() {
    case "nuclei": redact(command, tool: NucleiCatalog.definition)
    case "curl": redactCurl(redact(command, tool: CurlCatalog.definition))
    default: command
    }
  }

  private static func redactCurl(_ command: String) -> String {
    let pattern = "(?i)(Authorization:\\s*(?:Bearer\\s+)?)[^'\\\"\\s]+"
    guard let expression = try? NSRegularExpression(pattern: pattern) else { return command }
    return expression.stringByReplacingMatches(
      in: command,
      range: NSRange(command.startIndex..., in: command),
      withTemplate: "$1[REDACTED]"
    )
  }
}

enum LaboratorySectionID: Hashable {
  case learning
  case tool(LabToolID)

  static let navigationOrder: [Self] = [
    .learning, .tool(.nmap), .tool(.nuclei), .tool(.dig), .tool(.curl),
  ]

  var title: String {
    switch self {
    case .learning: "Nauka"
    case .tool(let tool): tool.rawValue.capitalized
    }
  }
}
