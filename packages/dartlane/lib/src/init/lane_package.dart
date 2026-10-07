import 'dart:io';

import 'package:dartlane/src/init/app_project.dart';
import 'package:dartlane/src/render_template.dart';
import 'package:dartlane/src/templates.g.dart';
import 'package:dartlane/src/version.dart';
import 'package:path/path.dart' as p;

/// The nested `dartlane/` package inside a project.
class LanePackage {
  /// Creates a handle for the package in [directory].
  const LanePackage(this.directory);

  /// The `dartlane/` package of [project].
  LanePackage.of(AppProject project)
    : directory = Directory(p.join(project.root.path, folderName));

  /// The folder name, relative to the project root.
  static const folderName = 'dartlane';

  /// The package folder.
  final Directory directory;

  /// Whether the folder already exists.
  bool get exists => directory.existsSync();

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
