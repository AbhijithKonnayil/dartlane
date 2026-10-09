import 'dart:io';

import 'package:dartlane/src/init/lane_package.dart';
import 'package:dartlane/src/run/lanes_launcher.dart';
import 'package:dartlane_core/dartlane_core.dart';

/// The lanes program of a project: its `dartlane/lanes.dart`.
///
/// The commands that need the user's lanes, such as `run` and `list`, go
/// through this, so they find the file and report a missing one the same way.
class LanesProgram {
  /// Creates a handle for the program of the project in [projectRoot].
  const LanesProgram({required this.projectRoot, required this.launcher});

  /// The project folder, which contains `dartlane/`.
  final Directory projectRoot;

  /// Starts the program.
  final LanesLauncher launcher;

  /// Runs the program with [arguments] and returns its exit code.
  ///
  /// Throws a [UserError] pointing to `dartlane init` if the project has no
  /// `dartlane/lanes.dart`.
  Future<int> run(List<String> arguments) {
    final package = LanePackage.inProject(projectRoot);
    if (!package.lanesFile.existsSync()) {
      throw UserError(
        package.exists
            ? 'dartlane/lanes.dart was not found.'
            : 'No dartlane/ folder found in this folder.',
        hint:
            'Run `dartlane init` to create one, or run this from the root of '
            'a project that has one.',
      );
    }
    return launcher.launch(projectRoot: projectRoot, arguments: arguments);
  }
}
