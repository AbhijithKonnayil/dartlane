import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:dartlane/src/init/app_project.dart';
import 'package:dartlane/src/init/gitignore.dart';
import 'package:dartlane/src/init/lane_package.dart';
import 'package:dartlane_core/dartlane_core.dart';
import 'package:path/path.dart' as p;

/// `dartlane init`: creates a nested `dartlane/` package with a first lane.
///
/// The app's own `pubspec.yaml` is never touched. Everything lives in
/// `dartlane/`, so removing that folder removes Dartlane from the project.
class InitCommand extends Command<int> {
  /// Creates the command.
  ///
  /// [workingDirectory] is the project root, [shell] runs `dart pub get`, and
  /// [logger] prints progress and asks questions.
  InitCommand({
    required this.logger,
    required this.shell,
    required this.workingDirectory,
  }) {
    argParser
      ..addFlag(
        'force',
        negatable: false,
        help:
            'Overwrite the generated files in an existing dartlane/ folder '
            'without asking.',
      )
      ..addOption(
        'local-repo',
        hide: true,
        help:
            'Path to a checkout of the Dartlane repository. Uses its '
            'packages instead of pub.dev, for developing Dartlane itself.',
      );
  }

  /// Where progress is printed and questions are asked.
  final LaneLogger logger;

  /// Runs `dart pub get`.
  final LaneShell shell;

  /// The project root.
  final Directory workingDirectory;

  @override
  String get name => 'init';

  @override
  String get description =>
      'Create a dartlane/ package with a first lane in this project.';

  /// What init keeps out of version control.
  static const _ignored = ['.dartlane/', '.env'];

  @override
  Future<int> run() async {
    final project = AppProject.read(workingDirectory);
    final package = LanePackage.of(project);
    final localRepo = _localRepo(argResults!['local-repo'] as String?);

    if (package.exists && !_mayOverwrite(force: argResults!['force'] as bool)) {
      logger.info('Nothing changed.');
      return ExitCodes.success;
    }

    _scaffold(package, project, localRepo);
    _updateGitignore(project);
    await _pubGet(package);

    logger.success(
      'Done. Run your first lane with: dartlane run build',
    );
    return ExitCodes.success;
  }

  /// Whether the existing `dartlane/` folder may be overwritten.
  ///
  /// True with `--force`. Otherwise asks, and throws a [UserError] when it
  /// cannot ask because there is no terminal.
  bool _mayOverwrite({required bool force}) {
    if (force) return true;
    if (!logger.interactive) {
      throw const UserError(
        'A dartlane/ folder already exists.',
        hint: 'Run `dartlane init --force` to overwrite its generated files.',
      );
    }
    return logger.confirm(
      'A dartlane/ folder already exists. Overwrite its generated files?',
    );
  }

  void _scaffold(LanePackage package, AppProject project, String? localRepo) {
    final written = package.write(project: project, localRepo: localRepo);
    for (final file in written) {
      logger.info('Wrote ${LanePackage.folderName}/$file');
    }
  }

  void _updateGitignore(AppProject project) {
    if (ensureGitignored(project.gitignore, _ignored)) {
      logger.info('Updated .gitignore');
    }
  }

  Future<void> _pubGet(LanePackage package) async {
    logger.info('Running dart pub get in ${LanePackage.folderName}/');
    final result = await shell.run(
      'dart',
      ['pub', 'get'],
      workingDirectory: package.directory.path,
    );
    if (!result.ok) {
      throw ShellException(commandLine: 'dart pub get', result: result);
    }
  }

  String? _localRepo(String? path) {
    if (path == null) return null;
    final repo = p.absolute(p.normalize(path));
    if (!Directory(p.join(repo, 'packages', 'dartlane_core')).existsSync()) {
      throw UserError(
        '"$path" is not a Dartlane repository.',
        hint: 'It should contain packages/dartlane_core.',
      );
    }
    return repo;
  }
}
