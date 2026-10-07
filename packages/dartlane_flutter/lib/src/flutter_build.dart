import 'package:dartlane_core/dartlane_core.dart';
import 'package:dartlane_flutter/src/build_result.dart';
import 'package:path/path.dart' as p;

/// What kind of file `flutter build` produces.
enum BuildTarget {
  /// An Android APK: `flutter build apk`.
  apk(extension: 'apk'),

  /// An Android app bundle: `flutter build appbundle`.
  appbundle(extension: 'aab');

  const BuildTarget({required this.extension});

  /// The extension of the built file.
  final String extension;
}

/// The Flutter build mode.
enum BuildMode {
  /// `--debug`.
  debug,

  /// `--profile`.
  profile,

  /// `--release`.
  release,
}

/// Builds an APK or an app bundle with `flutter build`.
///
/// ```dart
/// final build = await ctx.run(
///   FlutterBuild(target: BuildTarget.apk, flavor: 'prod'),
/// );
/// print(build.path);
/// ```
///
/// Throws a `ShellException` if `flutter build` fails, so a failed build fails
/// the lane. Throws a `UserError` for options that cannot work, such as a dart
/// define without `=` or `obfuscate` without `splitDebugInfo`.
class FlutterBuild extends LaneAction<BuildResult> {
  /// Creates a build.
  const FlutterBuild({
    required this.target,
    this.mode = BuildMode.release,
    this.flavor,
    this.dartDefines = const [],
    this.buildName,
    this.buildNumber,
    this.obfuscate = false,
    this.splitDebugInfo,
    this.workingDirectory,
  });

  /// Builds an APK. Same as `FlutterBuild(target: BuildTarget.apk)`.
  const FlutterBuild.apk({
    this.mode = BuildMode.release,
    this.flavor,
    this.dartDefines = const [],
    this.buildName,
    this.buildNumber,
    this.obfuscate = false,
    this.splitDebugInfo,
    this.workingDirectory,
  }) : target = BuildTarget.apk;

  /// Builds an app bundle. Same as
  /// `FlutterBuild(target: BuildTarget.appbundle)`.
  const FlutterBuild.appBundle({
    this.mode = BuildMode.release,
    this.flavor,
    this.dartDefines = const [],
    this.buildName,
    this.buildNumber,
    this.obfuscate = false,
    this.splitDebugInfo,
    this.workingDirectory,
  }) : target = BuildTarget.appbundle;

  /// Whether to build an APK or an app bundle.
  final BuildTarget target;

  /// The build mode. Defaults to release.
  final BuildMode mode;

  /// The flavor to build, passed as `--flavor`.
  final String? flavor;

  /// Compile-time values, each written `KEY=VALUE`.
  ///
  /// Every entry becomes its own `--dart-define`.
  final List<String> dartDefines;

  /// The user-visible version, passed as `--build-name`, for example `1.2.3`.
  final String? buildName;

  /// The internal build number, passed as `--build-number`, for example `45`.
  final String? buildNumber;

  /// Whether to obfuscate the Dart code. Needs [splitDebugInfo].
  final bool obfuscate;

  /// The directory for debug symbols, passed as `--split-debug-info`.
  final String? splitDebugInfo;

  /// The Flutter project directory. Defaults to the current directory.
  final String? workingDirectory;

  /// The arguments passed to `flutter`.
  List<String> get arguments => [
    'build',
    target.name,
    '--${mode.name}',
    if (flavor != null) '--flavor=$flavor',
    for (final define in dartDefines) '--dart-define=$define',
    if (buildName != null) '--build-name=$buildName',
    if (buildNumber != null) '--build-number=$buildNumber',
    if (obfuscate) '--obfuscate',
    if (splitDebugInfo != null) '--split-debug-info=$splitDebugInfo',
  ];

  @override
  String describe() => formatCommand('flutter', arguments);

  @override
  Future<BuildResult> run(LaneContext ctx) async {
    _validate();

    final result = await ctx.sh(
      'flutter',
      arguments,
      workingDirectory: workingDirectory,
    );

    return BuildResult(
      path: _builtPath(result.stdout),
      target: target,
      mode: mode,
      flavor: flavor,
      version: buildName == null
          ? null
          : buildNumber == null
          ? buildName
          : '$buildName+$buildNumber',
    );
  }

  void _validate() {
    for (final define in dartDefines) {
      if (!define.contains('=')) {
        throw UserError(
          'Invalid dart define "$define".',
          hint: 'Write it as KEY=VALUE, for example ENV=prod.',
        );
      }
    }
    if (obfuscate && splitDebugInfo == null) {
      throw const UserError(
        'obfuscate needs splitDebugInfo.',
        hint:
            'Set splitDebugInfo to a directory, for example '
            '"build/debug-info".',
      );
    }
  }

  /// Reads the artifact path from Flutter's own `Built <path>` line.
  ///
  /// The path is never guessed from the `build/` folder layout: Flutter says
  /// where it put the file, including for flavors, and a missing line is an
  /// error rather than a guess.
  String _builtPath(String stdout) {
    final match = RegExp(
      'Built (.+?\\.${target.extension})',
    ).firstMatch(stdout);
    if (match == null) {
      throw ActionFailed(
        '`flutter build` finished but did not report a .${target.extension} '
        'file.',
      );
    }
    final path = match.group(1)!;
    return workingDirectory == null ? path : p.join(workingDirectory!, path);
  }
}
