import SwiftUI

struct ToolboxView: View {
  @ObservedObject var scanner: NetworkScanner
  @Binding var workspaceRouteRaw: String

  var body: some View {
    NavigationStack {
      ScrollView {
        LazyVStack(spacing: 12) {
          DevUIReferenceLabel(reference: .toolbox)
            .frame(maxWidth: .infinity, alignment: .leading)
          InfoBanner(
            icon: "arrow.up.circle.fill",
            title: "NetScope Toolbox",
            message: "Buduj poprawne polecenia krok po kroku i ucz się, co robi każdy fragment."
          )

          toolLink(
            reference: .toolboxNmap,
            title: "Nmap",
            subtitle: "Wybieraj opcje według kategorii",
            icon: "scope",
            color: .cyan
          ) {
            ToolLearningView(
              tool: NmapCatalog.definition,
              initialTarget: scanner.context?.scanRangeDescription ?? ""
            )
          }

          toolLink(
            reference: .toolboxNuclei,
            title: "Nuclei",
            subtitle: "Buduj kontrole oparte na szablonach",
            icon: "checkmark.shield",
            color: .indigo
          ) {
            ToolLearningView(
              tool: NucleiCatalog.definition,
              initialTarget: scanner.context?.address ?? ""
            )
          }

          InfoBanner(
            icon: "hand.raised.fill",
            title: "Tryb defensywny",
            message: "Uruchamiaj narzędzia tylko we własnej sieci lub za zgodą właściciela. NetScope nie udostępnia modułów eksploatacji ani łamania haseł."
          )
        }
        .padding(12)
      }
      .background(Color(.systemGroupedBackground))
      .navigationTitle("Toolbox")
      .navigationBarTitleDisplayMode(.inline)
    }
  }

  private func toolLink<Destination: View>(
    reference: DevUIReference,
    title: String,
    subtitle: String,
    icon: String,
    color: Color,
    @ViewBuilder destination: () -> Destination
  ) -> some View {
    NavigationLink(destination: destination()) {
      VStack(alignment: .leading, spacing: 8) {
        DevUIReferenceLabel(reference: reference)
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
      }
      .padding(12)
      .background(.background, in: RoundedRectangle(cornerRadius: 14))
    }
    .buttonStyle(.plain)
  }
}
