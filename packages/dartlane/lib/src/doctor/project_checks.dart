import 'dart:io';

import 'package:dartlane/src/init/app_project.dart';
import 'package:dartlane/src/init/lane_package.dart';
import 'package:dartlane_core/dartlane_core.dart';
import 'package:path/path.dart' as p;

/// Checks that the folder is a Dart or Flutter project.
class ProjectCheck extends DoctorCheck {
  /// Creates the check for the project in [projectRoot].
  const ProjectCheck(this.projectRoot);

  /// The project folder.
  final Directory projectRoot;

  @override
  String get name => 'Project';

  @override
  Future<DoctorResult> run(LaneContext ctx) async {
    try {
      return DoctorResult.pass(AppProject.read(projectRoot).name);
    } on UserError catch (error) {
      return DoctorResult.fail(
        error.message,
        fix: error.hint ?? 'Run this from the root of your project.',
      );
    }
  }
}

/// Checks that `dartlane/lanes.dart` exists.
class LanesFileCheck extends DoctorCheck {
  /// Creates the check for the project in [projectRoot].
  const LanesFileCheck(this.projectRoot);

  /// The project folder.
  final Directory projectRoot;

  @override
  String get name => 'Lanes';

  @override
  Future<DoctorResult> run(LaneContext ctx) async {
    final package = LanePackage.inProject(projectRoot);
    if (package.lanesFile.existsSync()) {
      return const DoctorResult.pass('dartlane/lanes.dart found');
    }
    return DoctorResult.fail(
      package.exists
          ? 'dartlane/lanes.dart was not found.'
          : 'No dartlane/ folder found in this folder.',
      fix: 'Run `dartlane init` to create it.',
    );
  }
}

/// Checks that the packages `dartlane/lanes.dart` needs have been installed.
class LanesDependenciesCheck extends DoctorCheck {
  /// Creates the check for the project in [projectRoot].
  const LanesDependenciesCheck(this.projectRoot);

  /// The project folder.
  final Directory projectRoot;

  @override
  String get name => 'Dependencies';

  @override
  Future<DoctorResult> run(LaneContext ctx) async {
    final package = LanePackage.inProject(projectRoot);
    final packageConfig = File(
      p.join(package.directory.path, '.dart_tool', 'package_config.json'),
    );
    if (packageConfig.existsSync()) {
      return const DoctorResult.pass('installed');
    }
    return const DoctorResult.fail(
      'The packages in dartlane/ have not been installed.',
      fix: 'Run `dart pub get` in the dartlane/ folder.',
    );
  }
}
