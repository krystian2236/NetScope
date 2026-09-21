import Foundation
import SwiftUI

struct AppReleaseIdentity: Equatable, Sendable {
  let displayName: String
  let version: String
  let build: String
  let bundleIdentifier: String
  let distribution: String

  var shortLabel: String { "\(version) (build \(build))" }
  var detailLabel: String { "\(shortLabel) • \(distribution)" }

  static var current: Self { Self(bundle: .main) }

  init(bundle: Bundle) {
    displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "NetScope"
    version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    bundleIdentifier = bundle.bundleIdentifier ?? "—"

    #if NETSCOPE_DEV
    distribution = "Developer"
    #else
    distribution = "App Store"
    #endif
  }
}

struct AppReleaseIdentityCard: View {
  let identity: AppReleaseIdentity

  init(identity: AppReleaseIdentity = .current) {
    self.identity = identity
  }

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: "app.badge.checkmark")
        .font(.headline.weight(.semibold))
        .foregroundStyle(.cyan)
        .frame(width: 34, height: 34)
        .background(.cyan.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))

      VStack(alignment: .leading, spacing: 2) {
        Text(identity.displayName)
          .font(.caption.weight(.semibold))
        Text(identity.detailLabel)
          .font(.caption2.monospaced())
          .foregroundStyle(.secondary)
      }

      Spacer()
    }
    .padding(10)
    .background(.background, in: RoundedRectangle(cornerRadius: 13))
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Otwarta wersja aplikacji")
    .accessibilityValue("\(identity.displayName), \(identity.detailLabel), \(identity.bundleIdentifier)")
  }
}
