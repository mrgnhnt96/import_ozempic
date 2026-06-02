enum ImportStyle {
  /// Resolves imports to their source library with `show` combinators.
  granular,

  /// Resolves package imports to barrel exports (`package:name/name.dart`)
  /// when the barrel file exists on disk.
  barrel,
}
