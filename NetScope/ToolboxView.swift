import SwiftUI

struct ToolboxView: View {
  @ObservedObject var scanner: NetworkScanner
  @Binding var workspaceRouteRaw: String

  var body: some View {
    NavigationStack {
      ScrollView {
        LazyVStack(spacing: 12) {
          #if NETSCOPE_DEV
          HStack {
            UIRefCopyButton(ref: .toolbox)
            Spacer()
          }
          #endif
          InfoBanner(
            icon: "arrow.up.circle.fill",
            title: "Northbyte Radar Toolbox",
            message: "Buduj poprawne polecenia krok po kroku i ucz się, co robi każdy fragment."
          )

          toolLink(
            title: "Nmap",
            subtitle: "Wybieraj opcje według kategorii",
            icon: "scope",
            color: .cyan
          ) {
            VStack {
              #if NETSCOPE_DEV
              HStack { UIRefCopyButton(ref: .toolboxNmap); Spacer() }
              #endif
              ToolLearningView(tool: NmapCatalog.definition, initialTarget: scanner.context?.scanRangeDescription ?? "")
            }
          }

          toolLink(
            title: "Nuclei",
            subtitle: "Buduj kontrole oparte na szablonach",
            icon: "checkmark.shield",
            color: .indigo
          ) {
            VStack {
              #if NETSCOPE_DEV
              HStack { UIRefCopyButton(ref: .toolboxNuclei); Spacer() }
              #endif
              ToolLearningView(tool: NucleiCatalog.definition, initialTarget: scanner.context?.address ?? "")
            }
          }

          referenceLink(title: "IP i CIDR", subtitle: "Prywatne, publiczne i zakresy sieci", icon: "number.square") {
            ipReferenceList
          }

          referenceLink(title: "Porty i usługi", subtitle: "Najczęściej spotykane porty TCP", icon: "door.left.hand.open") {
            portsReferenceList
          }

          referenceLink(title: "Statusy HTTP", subtitle: "Szybka interpretacja odpowiedzi web", icon: "arrow.left.arrow.right") {
            httpStatusReferenceList
          }

          InfoBanner(
            icon: "hand.raised.fill",
            title: "Tryb defensywny",
            message: "Uruchamiaj narzędzia tylko we własnej sieci lub za zgodą właściciela. Northbyte Radar nie udostępnia modułów eksploatacji ani łamania haseł."
          )
        }
        .padding(12)
      }
      .background(Color(.systemGroupedBackground))
      .navigationTitle("Toolbox")
      .navigationBarTitleDisplayMode(.inline)
    }
  }

  @ViewBuilder
  private var ipReferenceList: some View {
    #if NETSCOPE_DEV
    ReferenceListView(title: "IP i CIDR", items: [
      ("Prywatny IPv4", "10.0.0.0/8, 172.16.0.0/12 oraz 192.168.0.0/16 są przeznaczone dla sieci lokalnych."),
      ("CIDR", "/24 oznacza 256 adresów, z których zwykle 254 są adresami hostów."),
      ("Link-local", "169.254.0.0/16 pojawia się, gdy urządzenie nie otrzymało adresu z DHCP."),
    ], uiRef: .toolboxReferenceIPCIDR)
    #else
    ReferenceListView(title: "IP i CIDR", items: [
      ("Prywatny IPv4", "10.0.0.0/8, 172.16.0.0/12 oraz 192.168.0.0/16 są przeznaczone dla sieci lokalnych."),
      ("CIDR", "/24 oznacza 256 adresów, z których zwykle 254 są adresami hostów."),
      ("Link-local", "169.254.0.0/16 pojawia się, gdy urządzenie nie otrzymało adresu z DHCP."),
    ])
    #endif
  }

  @ViewBuilder
  private var portsReferenceList: some View {
    #if NETSCOPE_DEV
    ReferenceListView(title: "Porty i usługi", items: [
      ("22/tcp · SSH", "Zdalna powłoka; używaj tylko na własnych urządzeniach."),
      ("53/tcp · DNS", "Rozwiązywanie nazw; DNS często działa również przez UDP."),
      ("80/tcp · HTTP", "Nieszyfrowany ruch webowy."),
      ("443/tcp · HTTPS", "Szyfrowany ruch webowy."),
      ("445/tcp · SMB", "Udostępnianie plików w sieci lokalnej."),
      ("3306/tcp · MySQL", "Popularna usługa bazy danych."),
      ("5432/tcp · PostgreSQL", "Popularna usługa bazy danych."),
      ("8080/tcp · HTTP Alt", "Alternatywny port aplikacji webowych."),
    ], uiRef: .toolboxReferencePortsServices)
    #else
    ReferenceListView(title: "Porty i usługi", items: [
      ("22/tcp · SSH", "Zdalna powłoka; używaj tylko na własnych urządzeniach."),
      ("53/tcp · DNS", "Rozwiązywanie nazw; DNS często działa również przez UDP."),
      ("80/tcp · HTTP", "Nieszyfrowany ruch webowy."),
      ("443/tcp · HTTPS", "Szyfrowany ruch webowy."),
      ("445/tcp · SMB", "Udostępnianie plików w sieci lokalnej."),
      ("3306/tcp · MySQL", "Popularna usługa bazy danych."),
      ("5432/tcp · PostgreSQL", "Popularna usługa bazy danych."),
      ("8080/tcp · HTTP Alt", "Alternatywny port aplikacji webowych."),
    ])
    #endif
  }

  @ViewBuilder
  private var httpStatusReferenceList: some View {
    #if NETSCOPE_DEV
    ReferenceListView(title: "Statusy HTTP", items: [
      ("2xx", "Żądanie zakończyło się poprawnie."),
      ("3xx", "Przekierowanie lub zmiana lokalizacji zasobu."),
      ("4xx", "Problem po stronie żądania lub uprawnień."),
      ("5xx", "Problem po stronie serwera."),
    ], uiRef: .toolboxReferenceHTTPStatus)
    #else
    ReferenceListView(title: "Statusy HTTP", items: [
      ("2xx", "Żądanie zakończyło się poprawnie."),
      ("3xx", "Przekierowanie lub zmiana lokalizacji zasobu."),
      ("4xx", "Problem po stronie żądania lub uprawnień."),
      ("5xx", "Problem po stronie serwera."),
    ])
    #endif
  }

  private func toolLink<Destination: View>(
    title: String,
    subtitle: String,
    icon: String,
    color: Color,
    @ViewBuilder destination: () -> Destination
  ) -> some View {
    NavigationLink(destination: destination()) {
      HStack(spacing: 12) {
        Image(systemName: icon)
          .font(.title3)
          .foregroundStyle(.white)
          .frame(width: 42, height: 42)
          .background(color, in: RoundedRectangle(cornerRadius: 11))
        VStack(alignment: .leading, spacing: 3) {
          Text(title).font(.headline)
          Text(subtitle).font(.caption).foregroundStyle(.secondary)
        }
        Spacer()
        Image(systemName: "chevron.right")
          .font(.caption.weight(.bold))
          .foregroundStyle(.secondary)
      }
      .padding(12)
      .background(.background, in: RoundedRectangle(cornerRadius: 14))
    }
    .buttonStyle(.plain)
  }

  private func referenceLink<Destination: View>(title: String, subtitle: String, icon: String, @ViewBuilder destination: () -> Destination) -> some View {
    NavigationLink(destination: destination()) {
      HStack(spacing: 12) {
        Image(systemName: icon)
          .font(.title3)
          .foregroundStyle(.white)
          .frame(width: 42, height: 42)
          .background(.indigo, in: RoundedRectangle(cornerRadius: 11))
        VStack(alignment: .leading, spacing: 3) {
          Text(title).font(.headline)
          Text(subtitle).font(.caption).foregroundStyle(.secondary)
        }
        Spacer()
        Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.secondary)
      }
      .padding(12)
      .background(.background, in: RoundedRectangle(cornerRadius: 14))
    }
    .buttonStyle(.plain)
  }
}

private struct ReferenceListView: View {
  let title: String
  let items: [(String, String)]
  #if NETSCOPE_DEV
  let uiRef: UIRef
  #endif

  var body: some View {
    List {
      ForEach(Array(items.enumerated()), id: \.offset) { _, item in
      VStack(alignment: .leading, spacing: 5) {
        Text(item.0).font(.subheadline.weight(.semibold))
        Text(item.1).font(.caption).foregroundStyle(.secondary)
      }
      .padding(.vertical, 3)
      }
    }
    .navigationTitle(title)
    .navigationBarTitleDisplayMode(.inline)
    #if NETSCOPE_DEV
    .safeAreaInset(edge: .top) {
      HStack {
        UIRefCopyButton(ref: uiRef)
        Spacer()
      }
      .padding(.horizontal, 12)
      .padding(.top, 4)
      .background(.bar)
    }
    #endif
  }
}
