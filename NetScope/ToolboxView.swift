import SwiftUI

struct ToolboxView: View {
  @ObservedObject var scanner: NetworkScanner
  @Binding var workspaceRouteRaw: String
  @AppStorage("NetScope.developerFavouriteTarget.nmap") private var nmapFavourite = ""
  @AppStorage("NetScope.developerFavouriteTarget.nuclei") private var nucleiFavourite = ""
  @AppStorage("NetScope.developerFavouriteTarget.dig") private var digFavourite = ""
  @AppStorage("NetScope.developerFavouriteTarget.curl") private var curlFavourite = ""

  var body: some View {
    NavigationStack {
      ScrollView {
        LazyVStack(spacing: 8) {
          toolboxIntroduction

          toolLink(
            tool: .nmap,
          ) {
            ToolLearningView(
              tool: NmapCatalog.definition,
              developerTool: .nmap,
              presetValues: presetValues(for: .nmap, definition: NmapCatalog.definition)
            )
          }

          toolLink(
            tool: .nuclei,
          ) {
            ToolLearningView(
              tool: NucleiCatalog.definition,
              developerTool: .nuclei,
              presetValues: presetValues(for: .nuclei, definition: NucleiCatalog.definition)
            )
          }

          toolLink(
            tool: .dig,
          ) {
            ToolLearningView(
              tool: DigCatalog.definition,
              developerTool: .dig,
              presetValues: presetValues(for: .dig, definition: DigCatalog.definition)
            )
          }

          toolLink(
            tool: .curl,
          ) {
            ToolLearningView(
              tool: CurlCatalog.definition,
              developerTool: .curl,
              presetValues: presetValues(for: .curl, definition: CurlCatalog.definition)
            )
          }

          defensiveNote
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
      }
      .background(Color(.systemGroupedBackground))
      .navigationTitle("Toolbox")
      .navigationBarTitleDisplayMode(.inline)
    }
  }

  private func toolLink<Destination: View>(
    tool: DeveloperAreaTool,
    @ViewBuilder destination: () -> Destination
  ) -> some View {
    let entry = ToolboxEntry(rawValue: tool.rawValue.lowercased()) ?? .nmap
    let color = color(for: entry.tileTone)

    return NavigationLink(destination: destination()) {
      VStack(alignment: .leading, spacing: 8) {
        DeveloperAreaTag(.toolbox(tool, .entry))

        HStack(spacing: 12) {
          Image(systemName: entry.icon)
            .font(.title2.weight(.semibold))
            .foregroundStyle(.white)
            .frame(width: 44, height: 44)
            .background(color, in: RoundedRectangle(cornerRadius: 12))

          VStack(alignment: .leading, spacing: 3) {
            Text(entry.title)
              .font(.headline)
              .foregroundStyle(color)
            Text(entry.subtitle)
              .font(.caption)
              .foregroundStyle(color.opacity(0.78))
              .lineLimit(2)
          }

          Spacer()
          Image(systemName: "chevron.right")
            .font(.caption.weight(.bold))
            .foregroundStyle(color)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(12)
      .background(color.opacity(0.11), in: RoundedRectangle(cornerRadius: 16))
      .overlay {
        RoundedRectangle(cornerRadius: 16)
          .stroke(color.opacity(0.3), lineWidth: 1)
      }
    }
    .buttonStyle(.plain)
  }

  private var toolboxIntroduction: some View {
    VStack(alignment: .leading, spacing: 7) {
      HStack(spacing: 6) {
        DeveloperAreaTag(AppTab.toolbox.developerAreaID)
        DeveloperAreaTag(.toolboxScreen)
        Spacer()
      }
      Text("Wybierz narzędzie i zbuduj polecenie krok po kroku.")
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(10)
    .background(.background, in: RoundedRectangle(cornerRadius: 14))
  }

  private var defensiveNote: some View {
    HStack(alignment: .top, spacing: 8) {
      Image(systemName: "hand.raised.fill")
        .foregroundStyle(.orange)
      Text("Tylko własna sieć lub systemy, na których testowanie masz zgodę.")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(10)
    .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
  }

  private func color(for tone: ToolboxTileTone) -> Color {
    switch tone {
    case .cyan: .cyan
    case .indigo: .indigo
    case .teal: .teal
    case .orange: .orange
    }
  }

  private func initialTarget(for tool: DeveloperAreaTool) -> String {
    let detectedTarget: String
    let storedFavourite: String

    switch tool {
    case .nmap:
      detectedTarget = scanner.context?.scanRangeDescription ?? ""
      storedFavourite = nmapFavourite
    case .nuclei:
      detectedTarget = scanner.context?.address ?? ""
      storedFavourite = nucleiFavourite
    case .dig:
      detectedTarget = scanner.context?.address ?? ""
      storedFavourite = digFavourite
    case .curl:
      detectedTarget = ""
      storedFavourite = curlFavourite
    }

    guard BuildVariant.current.includesDeveloperTools else {
      return detectedTarget
    }
    return ToolboxInitialTarget.resolve(
      storedFavourite: storedFavourite,
      detectedTarget: detectedTarget
    )
  }

  private func presetValues(
    for tool: DeveloperAreaTool,
    definition: ToolDefinition
  ) -> [String: String] {
    let target = initialTarget(for: tool)
    guard BuildVariant.current.includesDeveloperTools else {
      return ToolboxPresetValues.values(
        for: definition,
        primaryTarget: ""
      )
    }

    let overrides = ToolboxPresetValues.presetOptions(in: definition).reduce(
      into: [String: String]()
    ) { result, option in
      let key = "NetScope.developerPreset.\(tool.rawValue.lowercased()).\(option.id)"
      if let value = UserDefaults.standard.string(forKey: key) {
        result[option.id] = value
      }
    }
    return ToolboxPresetValues.values(
      for: definition,
      primaryTarget: target,
      overrides: overrides
    )
  }
}
