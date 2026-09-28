import SwiftUI

public enum NetScopeDesign {
  public static let accent = Color.cyan
  public static let accentSoft = Color.cyan.opacity(0.12)
  public static let cardBackground = Color(UIColor.secondarySystemBackground)
  public static let surface = Color(UIColor.systemBackground)
  public static let success = Color.green
  public static let warning = Color.orange
  public static let danger = Color.red
  public static let textPrimary = Color.primary
  public static let textSecondary = Color.secondary

  public static let spacingXS: CGFloat = 4
  public static let spacingS: CGFloat = 8
  public static let spacingM: CGFloat = 12
  public static let spacingL: CGFloat = 16
  public static let spacingXL: CGFloat = 20

  public static let radiusS: CGFloat = 8
  public static let radiusM: CGFloat = 12
  public static let radiusL: CGFloat = 16
}

public struct NetScopeCard<Content: View>: View {
  let content: Content

  public init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  public var body: some View {
    content
      .padding(NetScopeDesign.spacingM)
      .background(
        NetScopeDesign.cardBackground,
        in: RoundedRectangle(cornerRadius: NetScopeDesign.radiusM, style: .continuous)
      )
      .overlay(
        RoundedRectangle(cornerRadius: NetScopeDesign.radiusM, style: .continuous)
          .stroke(Color.secondary.opacity(0.08), lineWidth: 1)
      )
  }
}

public struct NetScopeActionButtonStyle: ButtonStyle {
  public func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.subheadline.weight(.semibold))
      .padding(.horizontal, NetScopeDesign.spacingL)
      .padding(.vertical, NetScopeDesign.spacingS)
      .frame(maxWidth: .infinity, alignment: .center)
      .background(configuration.isPressed ? NetScopeDesign.accent.opacity(0.8) : NetScopeDesign.accent)
      .foregroundStyle(.white)
      .clipShape(RoundedRectangle(cornerRadius: NetScopeDesign.radiusS, style: .continuous))
  }
}
