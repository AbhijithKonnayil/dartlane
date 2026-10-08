import 'package:dartlane_core/dartlane_core.dart';

/// Runs `flutter pub get`.
///
/// Throws a `ShellException` if it fails, so the lane fails.
class FlutterPubGet extends LaneAction<void> {
  /// Creates the action.
  const FlutterPubGet({this.offline = false, this.workingDirectory});

  /// Whether to use only packages already in the pub cache (`--offline`).
  final bool offline;

  /// The Flutter project directory. Defaults to the current directory.
  final String? workingDirectory;

  /// The arguments passed to `flutter`.
  List<String> get arguments => ['pub', 'get', if (offline) '--offline'];

  @override
  String describe() => formatCommand('flutter', arguments);

  @override
  Future<void> run(LaneContext ctx) async {
    await ctx.sh('flutter', arguments, workingDirectory: workingDirectory);
  }
}

/// Runs `flutter analyze` as a gate.
///
/// Any finding that Flutter treats as fatal makes it exit non-zero, which
/// throws a `ShellException` and fails the lane. By default infos and warnings
/// are fatal, like `flutter analyze` itself; turn them off to fail only on
/// errors.
class FlutterAnalyze extends LaneAction<void> {
  /// Creates the action.
  const FlutterAnalyze({
    this.fatalInfos = true,
    this.fatalWarnings = true,
    this.workingDirectory,
  });

  /// Whether info level findings fail the lane.
  final bool fatalInfos;

  /// Whether warnings fail the lane.
  final bool fatalWarnings;

  /// The Flutter project directory. Defaults to the current directory.
  final String? workingDirectory;

  /// The arguments passed to `flutter`.
  List<String> get arguments => [
    'analyze',
    if (!fatalInfos) '--no-fatal-infos',
    if (!fatalWarnings) '--no-fatal-warnings',
  ];

  @override
  String describe() => formatCommand('flutter', arguments);

  @override
  Future<void> run(LaneContext ctx) async {
    await ctx.sh('flutter', arguments, workingDirectory: workingDirectory);
  }
}

/// Runs `flutter test` as a gate.
///
/// A failing test makes Flutter exit non-zero, which throws a
/// `ShellException` and fails the lane.
class FlutterTest extends LaneAction<void> {
  /// Creates the action.
  const FlutterTest({
    this.paths = const [],
    this.coverage = false,
    this.workingDirectory,
  });

  /// Test files or directories to run. Empty runs the whole `test/` folder.
  final List<String> paths;

  /// Whether to collect coverage (`--coverage`).
  final bool coverage;

  /// The Flutter project directory. Defaults to the current directory.
  final String? workingDirectory;

  /// The arguments passed to `flutter`.
  List<String> get arguments => [
    'test',
    if (coverage) '--coverage',
    ...paths,
  ];

  @override
  String describe() => formatCommand('flutter', arguments);

  @override
  Future<void> run(LaneContext ctx) async {
    await ctx.sh('flutter', arguments, workingDirectory: workingDirectory);
  }
}
