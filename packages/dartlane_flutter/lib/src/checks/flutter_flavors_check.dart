import 'dart:io';

import 'package:dartlane_core/dartlane_core.dart';
import 'package:dartlane_flutter/src/android_flavors.dart';
import 'package:path/path.dart' as p;

/// Reports the Android product flavors the project defines.
///
/// It reads `android/app/build.gradle.kts` or `android/app/build.gradle`. This
/// is information to help you pick a `--flavor`, so it is not required: a
/// project without flavors, or without an `android/` folder, passes.
class FlutterFlavorsCheck extends DoctorCheck {
  /// Creates the check for the project in [projectDirectory], which defaults to
  /// the current directory.
  const FlutterFlavorsCheck({this.projectDirectory = '.'});

  /// The Flutter project folder.
  final String projectDirectory;

  @override
  String get name => 'Flavors';

  @override
  bool get isRequired => false;

  @override
  Future<DoctorResult> run(LaneContext ctx) async {
    final file = _gradleFile();
    if (file == null) {
      return const DoctorResult.pass(
        'no android/app/build.gradle found, nothing to check',
      );
    }

    final String gradle;
    try {
      gradle = file.readAsStringSync();
    } on FileSystemException catch (error) {
      return DoctorResult.fail(
        'could not read ${p.basename(file.path)}: ${error.message}',
        fix: 'Check that you can read ${file.path}.',
      );
    }

    final flavors = parseAndroidFlavors(gradle);
    return DoctorResult.pass(
      flavors.isEmpty ? 'none (a single build variant)' : flavors.join(', '),
    );
  }

  File? _gradleFile() {
    for (final name in ['build.gradle.kts', 'build.gradle']) {
      final file = File(p.join(projectDirectory, 'android', 'app', name));
      if (file.existsSync()) return file;
    }
    return null;
  }
}
