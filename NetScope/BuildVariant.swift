enum BuildVariant: Equatable, Sendable {
  case appStore
  case developer

  static var current: BuildVariant {
    #if NETSCOPE_DEV
    .developer
    #else
    .appStore
    #endif
  }

  var includesDeveloperTools: Bool { self == .developer }
}
