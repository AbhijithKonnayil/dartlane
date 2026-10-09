import 'dart:io';

import 'package:dartlane_core/dartlane_core.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// The Flutter or Dart project that `dartlane init` is run in.
class AppProject {
  /// Creates a project rooted at [root] with the package name [name].
  const AppProject({required this.root, required this.name});

  /// Reads the project in [root] from its `pubspec.yaml`.
  ///
  /// Throws a [UserError] if there is no `pubspec.yaml` or it has no name.
  factory AppProject.read(Directory root) {
    final pubspec = File(p.join(root.path, 'pubspec.yaml'));
    if (!pubspec.existsSync()) {
      throw const UserError(
        'No pubspec.yaml found in this folder.',
        hint:
            'Run `dartlane init` from the root of your Flutter or Dart '
            'project.',
      );
    }
    final name = (loadYaml(pubspec.readAsStringSync()) as YamlMap?)?['name'];
    if (name is! String || name.isEmpty) {
      throw const UserError('pubspec.yaml has no package name.');
    }
    return AppProject(root: root, name: name);
  }

  /// The project folder.
  final Directory root;

  /// The package name from `pubspec.yaml`.
  final String name;

  /// The project's `.gitignore`, which may not exist yet.
  File get gitignore => File(p.join(root.path, '.gitignore'));
}
