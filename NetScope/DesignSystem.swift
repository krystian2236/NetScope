import SwiftUI

public enum NetScopeDesign {
  public static let accent = Color("NetScopeAccent", bundle: .main)
  public static let accentSoft = Color("NetScopeAccentSoft", bundle: .main)
  public static let cardBackground = Color("NetScopeCardBackground", bundle: .main)
  public static let surface = Color("NetScopeSurface", bundle: .main)
  public static let success = Color("NetScopeSuccess", bundle: .main)
  public static let warning = Color("NetScopeWarning", bundle: .main)
  public static let danger = Color("NetScopeDanger", bundle: .main)
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
      .background(NetScopeDesign.cardBackground, in: RoundedRectangle(cornerRadius: NetScopeDesign.radiusM, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: NetScopeDesign.radiusM, style: .continuous)
          .stroke(Color.secondary.opacity(0.08), lineWidth: 1)
      )
  }
}
