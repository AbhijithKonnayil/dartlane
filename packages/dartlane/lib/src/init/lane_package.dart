import 'dart:io';

import 'package:dartlane/src/init/app_project.dart';
import 'package:dartlane/src/render_template.dart';
import 'package:dartlane/src/templates.g.dart';
import 'package:dartlane/src/version.g.dart';
import 'package:path/path.dart' as p;

/// The nested `dartlane/` package inside a project.
class LanePackage {
  /// Creates a handle for the package in [directory].
  const LanePackage(this.directory);

  /// The `dartlane/` package of [project].
  LanePackage.of(AppProject project)
    : directory = Directory(p.join(project.root.path, folderName));

  /// The `dartlane/` package of the project in [projectRoot], which may not
  /// exist.
  LanePackage.inProject(Directory projectRoot)
    : directory = Directory(p.join(projectRoot.path, folderName));

  /// The folder name, relative to the project root.
  static const folderName = 'dartlane';

  /// The name of the file that defines the lanes.
  static const lanesFileName = 'lanes.dart';

  /// The package folder.
  final Directory directory;

  /// Whether the folder already exists.
  bool get exists => directory.existsSync();

  /// The file that defines the lanes. It may not exist.
  File get lanesFile => File(p.join(directory.path, lanesFileName));

  /// Writes the generated files and returns their names, relative to
  /// [directory].
  ///
  /// Existing files with the same names are overwritten; other files in the
  /// folder are left alone. Pass [localRepo], an absolute path to a Dartlane
  /// checkout, to also write `pubspec_overrides.yaml` pointing at its
  /// packages.
  List<String> write({required AppProject project, String? localRepo}) {
    directory.createSync(recursive: true);
    final files = {
      'pubspec.yaml': renderTemplate(Templates.pubspec, {
        'package_name': '${project.name}_dartlane',
        'app_name': project.name,
        'version': dartlaneVersion,
        'minimum_dart': minimumDartVersion,
      }),
      'lanes.dart': Templates.lanes,
      'config.dart': Templates.config,
      if (localRepo != null)
        'pubspec_overrides.yaml': renderTemplate(Templates.overrides, {
          'repo': localRepo,
        }),
    };
    for (final MapEntry(:key, :value) in files.entries) {
      File(p.join(directory.path, key)).writeAsStringSync(value);
    }
    return files.keys.toList();
  }
}
