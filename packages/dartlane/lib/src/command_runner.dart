import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:dartlane/src/commands/doctor_command.dart';
import 'package:dartlane/src/commands/init_command.dart';
import 'package:dartlane/src/commands/list_command.dart';
import 'package:dartlane/src/commands/run_command.dart';
import 'package:dartlane/src/run/lanes_launcher.dart';
import 'package:dartlane_core/dartlane_core.dart';

/// The `dartlane` command line tool.
///
/// It only launches things: `init` creates the nested `dartlane/` package, `run`
/// starts the user's own lanes program and passes the arguments and exit code
/// through, `list` asks that program for its lanes, `doctor` checks the setup
/// and asks the program for the checks that action packages contribute, and the
/// lanes themselves run in that program through `dartlane_core`.
class DartlaneCommandRunner extends CommandRunner<int> {
  /// Creates the runner.
  ///
  /// Pass [logger], [shell], [launcher] and [workingDirectory] to control
  /// output, commands, the lanes program and the project folder in tests, and
  /// [dartSdkCheck] to pretend to run on another Dart version.
  DartlaneCommandRunner({
    LaneLogger? logger,
    LaneShell? shell,
    LanesLauncher? launcher,
    Directory? workingDirectory,
    DoctorCheck? dartSdkCheck,
  }) : _logger = logger ?? LaneLogger.fromEnvironment(Platform.environment),
       super(
         'dartlane',
         'Release automation for Flutter and Dart, written in Dart.',
       ) {
    argParser.addFlag(
      'verbose',
      negatable: false,
      help: 'Show detail output.',
    );
    final projectRoot = workingDirectory ?? Directory.current;
    addCommand(
      InitCommand(
        logger: _logger,
        shell: shell ?? const ProcessShell(),
        workingDirectory: projectRoot,
      ),
    );
    final lanesLauncher = launcher ?? const ProcessLanesLauncher();
    addCommand(
      RunCommand(launcher: lanesLauncher, workingDirectory: projectRoot),
    );
    addCommand(
      ListCommand(launcher: lanesLauncher, workingDirectory: projectRoot),
    );
    addCommand(
      DoctorCommand(
        logger: _logger,
        launcher: lanesLauncher,
        workingDirectory: projectRoot,
        dartSdkCheck: dartSdkCheck,
      ),
    );
  }

  final LaneLogger _logger;

  @override
  Future<int> run(Iterable<String> args) async {
    try {
      return await super.run(args) ?? ExitCodes.success;
    } on UsageException catch (error) {
      _logger
        ..error(error.message)
        ..info(error.usage);
      return ExitCodes.usage;
    } on LaneError catch (error, stackTrace) {
      _logger.error(error.message);
      if (error case UserError(:final hint?)) _logger.info('Hint: $hint');
      _logger.detail('$stackTrace');
      return error.exitCode;
    }
  }

  @override
  Future<int?> runCommand(ArgResults topLevelResults) {
    if (topLevelResults['verbose'] as bool) _logger.verbose = true;
    return super.runCommand(topLevelResults);
  }
}
