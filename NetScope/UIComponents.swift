import SwiftUI
#if NETSCOPE_DEV
import UIKit
#endif

#if NETSCOPE_DEV
struct UIRefCopyButton: View {
  let ref: UIRef
  @State private var copied = false

  var body: some View {
    Button {
      UIPasteboard.general.string = ref.clipboardText
      copied = true

      UIAccessibility.post(
        notification: .announcement,
        argument: "Skopiowano \(ref.rawValue)"
      )

      DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
        copied = false
      }
    } label: {
      Image(systemName: copied ? "checkmark" : "doc.on.doc")
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(5)
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Kopiuj UIREF \(ref.rawValue)")
  }
}
#endif

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

struct NetScopeCard<Content: View>: View {
  @ViewBuilder let content: Content

  var body: some View {
    content
      .background(.background, in: RoundedRectangle(cornerRadius: 16))
      .overlay {
        RoundedRectangle(cornerRadius: 16)
          .stroke(Color.cyan.opacity(0.14), lineWidth: 1)
      }
  }
}

struct StatusPill: View {
  let title: String
  var tint: Color = .cyan

  var body: some View {
    HStack(spacing: 5) {
      Circle()
        .fill(tint)
        .frame(width: 6, height: 6)
      Text(title)
        .font(.caption2.weight(.semibold))
        .textCase(.uppercase)
    }
    .foregroundStyle(tint)
    .padding(.horizontal, 8)
    .padding(.vertical, 5)
    .background(tint.opacity(0.1), in: Capsule())
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
    .overlay {
      RoundedRectangle(cornerRadius: 12)
        .stroke(Color.cyan.opacity(0.1), lineWidth: 1)
    }
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
      Label("Wynik diagnostyki", systemImage: "checkmark.seal")
        .font(.caption.weight(.semibold))

      DetailRow(label: "Cel", value: result.host, monospaced: true)

      if result.resolvedAddresses.isEmpty {
        DetailRow(label: "DNS", value: "Brak odpowiedzi")
      } else {
        ForEach(result.resolvedAddresses, id: \.self) { address in
          DetailRow(label: "DNS", value: address, monospaced: true)
        }
      }

      HStack {
        DetailRow(label: "Status", value: statusText)
        Spacer()
        if let latency = result.portResult.latencyMilliseconds {
          Text(String(format: "%.1f ms", latency))
            .font(.caption2.monospaced())
            .foregroundStyle(.secondary)
        }
      }

      DetailRow(label: "Znaczenie", value: meaning)
      DetailRow(label: "Możliwa przyczyna", value: possibleCause)
      DetailRow(label: "Następny krok", value: nextStep)

      ShareLink(item: reportText, subject: Text("Northbyte Radar — raport diagnostyczny")) {
        Label("Udostępnij bezpieczny raport", systemImage: "square.and.arrow.up")
          .font(.caption.weight(.semibold))
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.bordered)
      .tint(.cyan)

      Text("Raport zawiera wpisany cel i wyniki lokalnego testu. Nie dodaje publicznego IP ani danych konta.")
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
  }

  private var reportText: String {
    let addresses = result.resolvedAddresses.isEmpty
      ? "brak odpowiedzi"
      : result.resolvedAddresses.joined(separator: ", ")
    return """
    Northbyte Radar — raport diagnostyczny
    Cel: \(result.host)
    DNS: \(addresses)
    Port: \(result.portResult.port)
    Status: \(statusText)
    Czas: \(result.portResult.latencyMilliseconds.map { String(format: "%.1f ms", $0) } ?? "brak")
    Sprawdzono: \(result.checkedAt.formatted(date: .abbreviated, time: .shortened))
    """
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

  private var meaning: String {
    if result.resolvedAddresses.isEmpty {
      return "Nazwa hosta nie została rozpoznana przez DNS."
    }
    if result.portResult.status.isOpen {
      return "Host odpowiada, a wskazana usługa przyjmuje połączenia TCP."
    }
    return "Host został rozpoznany, ale wskazana usługa nie przyjęła połączenia."
  }

  private var possibleCause: String {
    switch result.portResult.status {
    case .open: "Usługa działa albo port jest dostępny w tej sieci."
    case .closed: "Usługa może być wyłączona albo chroniona przez zaporę."
    case .timedOut: "Host lub zapora nie odpowiedziały w wyznaczonym czasie."
    case .localNetworkDenied: "System nie udostępnił aplikacji dostępu do sieci lokalnej."
    }
  }

  private var nextStep: String {
    if result.resolvedAddresses.isEmpty {
      return "Sprawdź nazwę hosta i połączenie z siecią."
    }
    return result.portResult.status.isOpen
      ? "Zweryfikuj, czy ta usługa powinna być dostępna."
      : "Sprawdź adres hosta, port i reguły zapory."
  }
}

private struct DetailRow: View {
  let label: String
  let value: String
  var monospaced = false

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(label)
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.secondary)
      Text(value)
        .font(monospaced ? .caption.monospaced() : .caption)
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
