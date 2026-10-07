import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:dartlane/src/init/lane_package.dart';
import 'package:dartlane/src/run/lanes_launcher.dart';
import 'package:dartlane_core/dartlane_core.dart';

/// `dartlane run <lane> [arguments]`: runs a lane from `dartlane/lanes.dart`.
///
/// Everything after `run` is passed on to the lanes program untouched, so
/// options such as `--flavor=prod` reach the lane, and the command exits with
/// the lane's exit code.
class RunCommand extends Command<int> {
  /// Creates the command.
  ///
  /// [workingDirectory] is the project root and [launcher] starts the lanes
  /// program.
  RunCommand({required this.launcher, required this.workingDirectory});

  /// Starts the lanes program.
  final LanesLauncher launcher;

  /// The project root.
  final Directory workingDirectory;

  // Accepts any option, so the lane's own options are not rejected here.
  final _parser = ArgParser.allowAnything();

  @override
  ArgParser get argParser => _parser;

  @override
  String get name => 'run';

  @override
  String get description => 'Run a lane from dartlane/lanes.dart.';

  @override
  String get invocation => 'dartlane run <lane> [arguments]';

  @override
  String get usageFooter =>
      '\nEverything after the lane name is passed to the lane, for example '
      '`dartlane run build --flavor=prod`.\n'
      'Run `dartlane run` with no lane to list the lanes.';

  @override
  Future<int> run() async {
    final arguments = [...argResults!.rest];

    if (arguments.isNotEmpty && const ['--help', '-h'].contains(arguments[0])) {
      printUsage();
      return ExitCodes.success;
    }

    final package = LanePackage.inProject(workingDirectory);
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

    // `dartlane --verbose run beta` also makes the lane verbose.
    final verbose = globalResults?['verbose'] as bool? ?? false;
    if (verbose && !arguments.contains('--verbose')) arguments.add('--verbose');

    return launcher.launch(projectRoot: workingDirectory, arguments: arguments);
  }
}
