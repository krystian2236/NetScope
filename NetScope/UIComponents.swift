import SwiftUI
import UIKit

enum DevUIReference: CaseIterable, Sendable {
  case start
  case scanner
  case devices
  case services
  case toolbox
  case toolboxNmap
  case toolboxNuclei
  case deviceDetail
  case portScan
  case diagnostics
  case bonjour
  case comingSoon

  var displayLabel: String { "[DEV: VECTORNET / \(technicalPath)]" }

  var uiRef: String {
    "UIREF app=VectorNet screen=\(screen) component=\(component) view=\(viewName)"
  }

  static func isVisible(isDebugBuild: Bool) -> Bool {
    isDebugBuild
  }

  private var technicalPath: String {
    switch self {
    case .start: "START"
    case .scanner: "START / SCANNER"
    case .devices: "START / DEVICES"
    case .services: "START / SERVICES"
    case .toolbox: "TOOLBOX"
    case .toolboxNmap: "TOOLBOX / NMAP"
    case .toolboxNuclei: "TOOLBOX / NUCLEI"
    case .deviceDetail: "DEVICE_DETAIL"
    case .portScan: "PORT_SCAN"
    case .diagnostics: "DIAGNOSTICS"
    case .bonjour: "BONJOUR"
    case .comingSoon: "COMING_SOON"
    }
  }

  private var screen: String {
    switch self {
    case .start, .scanner, .devices, .services: "start"
    case .toolbox, .toolboxNmap, .toolboxNuclei: "toolbox"
    case .deviceDetail: "devices"
    case .portScan, .diagnostics, .bonjour: "services"
    case .comingSoon: "comingSoon"
    }
  }

  private var component: String {
    switch self {
    case .start, .toolbox, .comingSoon: "root"
    case .scanner: "scanner"
    case .devices: "devices"
    case .services: "services"
    case .toolboxNmap: "nmap"
    case .toolboxNuclei: "nuclei"
    case .deviceDetail: "deviceDetail"
    case .portScan: "portScan"
    case .diagnostics: "diagnostics"
    case .bonjour: "bonjour"
    }
  }

  private var viewName: String {
    switch self {
    case .start, .scanner, .devices, .services: "ScannerView"
    case .toolbox: "ToolboxView"
    case .toolboxNmap, .toolboxNuclei: "ToolLearningView"
    case .deviceDetail: "DeviceDetailView"
    case .portScan: "PortScannerView"
    case .diagnostics: "DiagnosticsView"
    case .bonjour: "ServicesView"
    case .comingSoon: "ComingSoonView"
    }
  }
}

struct DevUIReferenceLabel: View {
  let reference: DevUIReference
  @State private var copied = false

  @ViewBuilder
  var body: some View {
    #if DEBUG
      HStack(spacing: 4) {
        Text(reference.displayLabel)
        if copied {
          Image(systemName: "checkmark")
        }
      }
      .font(.caption2.monospaced().weight(.semibold))
      .foregroundStyle(.secondary)
      .lineLimit(1)
      .minimumScaleFactor(0.55)
      .contentShape(Rectangle())
      .onTapGesture(perform: copyReference)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(reference.displayLabel)
      .accessibilityHint("Kopiuje techniczny identyfikator UI")
      .accessibilityAddTraits(.isButton)
      .accessibilityAction { copyReference() }
    #else
      EmptyView()
    #endif
  }

  private func copyReference() {
    #if DEBUG
      UIPasteboard.general.string = reference.uiRef
      copied = true
      UIAccessibility.post(
        notification: .announcement,
        argument: "Skopiowano \(reference.uiRef)"
      )
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
        copied = false
      }
    #endif
  }
}

extension View {
  @ViewBuilder
  func devUIReference(_ reference: DevUIReference) -> some View {
    #if DEBUG
      safeAreaInset(edge: .top, spacing: 0) {
        DevUIReferenceLabel(reference: reference)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 12)
          .padding(.vertical, 5)
          .background(.thinMaterial)
      }
    #else
      self
    #endif
  }
}

struct ToolCard<Content: View>: View {
  let icon: String
  let title: String
  let subtitle: String
  @ViewBuilder let content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 11) {
      HStack(spacing: 9) {
        Image(systemName: icon)
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(.cyan)
          .frame(width: 32, height: 32)
          .background(.cyan.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))
        VStack(alignment: .leading, spacing: 1) {
          Text(title)
            .font(.subheadline.weight(.semibold))
          Text(subtitle)
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
      }
      content
    }
    .padding(12)
    .background(.background, in: RoundedRectangle(cornerRadius: 14))
  }
}

struct AddressRow: View {
  let label: String
  let value: String

  var body: some View {
    HStack(alignment: .firstTextBaseline) {
      Text(label)
        .font(.caption)
        .foregroundStyle(.secondary)
      Spacer()
      Text(value)
        .font(.caption.monospaced())
        .multilineTextAlignment(.trailing)
        .textSelection(.enabled)
    }
  }
}

struct MetricCard: View {
  let title: String
  let value: String
  let icon: String
  var tint: Color = .cyan

  var body: some View {
    HStack(spacing: 9) {
      Image(systemName: icon)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(tint)
        .frame(width: 28, height: 28)
        .background(tint.opacity(0.11), in: RoundedRectangle(cornerRadius: 8))
      VStack(alignment: .leading, spacing: 1) {
        Text(value)
          .font(.subheadline.weight(.bold))
          .monospacedDigit()
        Text(title)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
      Spacer(minLength: 0)
    }
    .padding(10)
    .background(.background, in: RoundedRectangle(cornerRadius: 12))
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(title)
    .accessibilityValue(value)
  }
}

struct ExposureBadge: View {
  let level: ExposureLevel

  var body: some View {
    Text(level.title)
      .font(.caption2.weight(.semibold))
      .padding(.horizontal, 7)
      .padding(.vertical, 3)
      .foregroundStyle(color)
      .background(color.opacity(0.12), in: Capsule())
  }

  private var color: Color {
    switch level {
    case .low: .green
    case .medium: .orange
    case .high: .red
    }
  }
}

struct DiagnosticResultView: View {
  let result: HostDiagnosticResult

  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      Divider()
      Label(result.host, systemImage: "globe")
        .font(.caption.weight(.semibold))

      if result.resolvedAddresses.isEmpty {
        Label("DNS: brak odpowiedzi", systemImage: "xmark.circle")
          .font(.caption)
          .foregroundStyle(.orange)
      } else {
        ForEach(result.resolvedAddresses, id: \.self) { address in
          AddressRow(label: "DNS", value: address)
        }
      }

      HStack {
        Label(statusText, systemImage: statusIcon)
          .font(.caption.weight(.medium))
          .foregroundStyle(result.portResult.status.isOpen ? .green : .orange)
        Spacer()
        if let latency = result.portResult.latencyMilliseconds {
          Text(String(format: "%.1f ms", latency))
            .font(.caption2.monospaced())
            .foregroundStyle(.secondary)
        }
      }
    }
  }

  private var statusIcon: String {
    result.portResult.status.isOpen ? "checkmark.circle.fill" : "xmark.circle.fill"
  }

  private var statusText: String {
    switch result.portResult.status {
    case .open: "Port \(result.portResult.port) otwarty"
    case .closed: "Port \(result.portResult.port) zamknięty"
    case .timedOut: "Brak odpowiedzi portu \(result.portResult.port)"
    case .localNetworkDenied: "Brak dostępu do sieci lokalnej"
    }
  }
}

struct PortResultRow: View {
  let entry: PortScanEntry

  var body: some View {
    HStack(spacing: 9) {
      Circle()
        .fill(entry.status.isOpen ? .green : .secondary.opacity(0.35))
        .frame(width: 8, height: 8)
      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 5) {
          Text("\(entry.port)")
            .font(.caption.monospaced().weight(.semibold))
          Text(entry.serviceName)
            .font(.caption.weight(.semibold))
          if entry.status.isOpen && entry.info.isEncrypted {
            Image(systemName: "lock.fill")
              .font(.caption2)
              .foregroundStyle(.green)
          }
        }
        Text(entry.status.isOpen ? entry.info.description : statusText)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(2)
      }
      Spacer(minLength: 6)
      if let latency = entry.latencyMilliseconds {
        Text(String(format: "%.1f ms", latency))
          .font(.caption2.monospaced())
          .foregroundStyle(.secondary)
      }
    }
    .padding(10)
    .background(.background, in: RoundedRectangle(cornerRadius: 11))
  }

  private var statusText: String {
    switch entry.status {
    case .open: "Otwarty"
    case .closed: "Zamknięty"
    case .timedOut: "Brak odpowiedzi"
    case .localNetworkDenied: "Brak dostępu"
    }
  }
}
