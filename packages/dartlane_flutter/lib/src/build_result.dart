import 'package:dartlane_flutter/src/flutter_build.dart';

/// What a [FlutterBuild] produced.
class BuildResult {
  /// Creates a result.
  const BuildResult({
    required this.path,
    required this.target,
    required this.mode,
    this.flavor,
    this.version,
  });

  /// Where the built file is, as reported by Flutter itself.
  ///
  /// Relative to the current directory, or joined with the build's
  /// `workingDirectory` when one was given.
  final String path;

  /// Whether this is an APK or an app bundle.
  final BuildTarget target;

  /// The build mode.
  final BuildMode mode;

  /// The flavor that was built, if any.
  final String? flavor;

  /// The version passed to the build, such as `1.2.3+45`.
  ///
  /// Only set when `buildName` was given. When it is null the build used the
  /// version from `pubspec.yaml`, which this result does not read.
  final String? version;
}
