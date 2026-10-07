/// Settings used by the lanes in `lanes.dart`. Edit them for your project.
abstract final class Config {
  /// The flavor to build, or null if the app has no flavors.
  static const String? flavor = null;

  /// Compile-time values, each written KEY=VALUE, for example `ENV=prod`.
  static const List<String> dartDefines = [];
}
