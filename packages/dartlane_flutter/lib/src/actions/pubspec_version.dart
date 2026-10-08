import 'dart:io';

import 'package:dartlane_core/dartlane_core.dart';
import 'package:path/path.dart' as p;

/// A `version:` from `pubspec.yaml`, such as `1.2.3`, `1.2.3+45` or
/// `1.2.3-beta.1+45`.
class PubspecVersion {
  /// Creates a version.
  const PubspecVersion(
    this.major,
    this.minor,
    this.patch, {
    this.preRelease,
    this.build,
  });

  /// Parses [text]. Throws a [FormatException] if it is not a version.
  factory PubspecVersion.parse(String text) {
    final match = _pattern.firstMatch(text.trim());
    if (match == null) {
      throw FormatException('Not a valid version: "$text".');
    }
    return PubspecVersion(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      preRelease: match.group(4),
      build: match.group(5) == null ? null : int.parse(match.group(5)!),
    );
  }

  static final _pattern = RegExp(
    r'^(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?(?:\+(\d+))?$',
  );

  /// The major number.
  final int major;

  /// The minor number.
  final int minor;

  /// The patch number.
  final int patch;

  /// The pre-release part after `-`, such as `beta.1`, if any.
  final String? preRelease;

  /// The build number after `+`, if any.
  final int? build;

  /// This version after [kind] is applied.
  ///
  /// `major`, `minor` and `patch` reset the lower numbers and drop a
  /// pre-release part, and keep the build number. `build` adds one to the
  /// build number, starting at 1 when there is none.
  PubspecVersion bump(VersionBump kind) => switch (kind) {
    VersionBump.major => PubspecVersion(major + 1, 0, 0, build: build),
    VersionBump.minor => PubspecVersion(major, minor + 1, 0, build: build),
    VersionBump.patch => PubspecVersion(major, minor, patch + 1, build: build),
    VersionBump.build => PubspecVersion(
      major,
      minor,
      patch,
      preRelease: preRelease,
      build: (build ?? 0) + 1,
    ),
  };

  /// The version name without the build number, such as `1.2.3`. Suits
  /// `FlutterBuild.buildName`.
  String get name =>
      '$major.$minor.$patch${preRelease == null ? '' : '-$preRelease'}';

  /// The build number as text, or null. Suits `FlutterBuild.buildNumber`.
  String? get buildNumber => build?.toString();

  @override
  String toString() => build == null ? name : '$name+$build';
}

/// Which part of a [PubspecVersion] to increase.
enum VersionBump {
  /// `1.2.3` becomes `2.0.0`.
  major,

  /// `1.2.3` becomes `1.3.0`.
  minor,

  /// `1.2.3` becomes `1.2.4`.
  patch,

  /// `1.2.3+45` becomes `1.2.3+46`.
  build,
}

final _versionLine = RegExp(
  r'^(version:[ \t]*)([^\s#]+)([ \t]*(?:#.*)?)$',
  multiLine: true,
);

File _pubspec(String? workingDirectory) =>
    File(p.join(workingDirectory ?? '.', 'pubspec.yaml'));

PubspecVersion _readFrom(File file) {
  if (!file.existsSync()) {
    throw UserError(
      'No pubspec.yaml at ${file.path}.',
      hint: 'Run the lane from the Flutter project, or set workingDirectory.',
    );
  }
  final match = _versionLine.firstMatch(file.readAsStringSync());
  if (match == null) {
    throw UserError(
      '${file.path} has no version: line.',
      hint: 'Add one, for example "version: 1.0.0+1".',
    );
  }
  try {
    return PubspecVersion.parse(match.group(2)!);
  } on FormatException catch (e) {
    throw UserError('${file.path}: ${e.message}');
  }
}

/// Reads the `version:` from `pubspec.yaml`.
///
/// ```dart
/// final version = await ctx.run(const ReadPubspecVersion());
/// ```
class ReadPubspecVersion extends LaneAction<PubspecVersion> {
  /// Creates the action.
  const ReadPubspecVersion({this.workingDirectory});

  /// The Flutter project directory. Defaults to the current directory.
  final String? workingDirectory;

  @override
  String describe() => 'Read pubspec version';

  @override
  Future<PubspecVersion> run(LaneContext ctx) async =>
      _readFrom(_pubspec(workingDirectory));

  /// Reading changes nothing, so a dry run reads for real.
  @override
  PubspecVersion dryRunResult(LaneContext ctx) =>
      _readFrom(_pubspec(workingDirectory));
}

/// Bumps the `version:` in `pubspec.yaml` and returns the new version.
///
/// Only the version text on that line changes. The rest of the file, comments
/// included, and any comment after the version, are left as they were.
///
/// ```dart
/// final next = await ctx.run(const BumpPubspecVersion(VersionBump.patch));
/// ```
///
/// Throws a `UserError` if the file or the `version:` line is missing or
/// invalid. In a dry run the file is not written, and the result is the version
/// it would have.
class BumpPubspecVersion extends LaneAction<PubspecVersion> {
  /// Creates the action.
  const BumpPubspecVersion(this.bump, {this.workingDirectory});

  /// Which part to increase.
  final VersionBump bump;

  /// The Flutter project directory. Defaults to the current directory.
  final String? workingDirectory;

  @override
  String describe() => 'Bump pubspec version (${bump.name})';

  @override
  Future<PubspecVersion> run(LaneContext ctx) async {
    final file = _pubspec(workingDirectory);
    final next = _readFrom(file).bump(bump);
    file.writeAsStringSync(
      file.readAsStringSync().replaceFirstMapped(
        _versionLine,
        (m) => '${m.group(1)}$next${m.group(3)}',
      ),
    );
    ctx.logger.info('  version -> $next');
    return next;
  }

  @override
  PubspecVersion dryRunResult(LaneContext ctx) =>
      _readFrom(_pubspec(workingDirectory)).bump(bump);
}
