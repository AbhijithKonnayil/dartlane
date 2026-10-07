import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:dartlane/src/commands/init_command.dart';
import 'package:dartlane_core/dartlane_core.dart';

/// The `dartlane` command line tool.
///
/// It only launches things: `init` creates the nested `dartlane/` package, and
/// the lanes themselves run in the user's own program through `dartlane_core`.
class DartlaneCommandRunner extends CommandRunner<int> {
  /// Creates the runner.
  ///
  /// Pass [logger], [shell] and [workingDirectory] to control output, commands
  /// and the project folder in tests.
  DartlaneCommandRunner({
    LaneLogger? logger,
    LaneShell? shell,
    Directory? workingDirectory,
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
    addCommand(
      InitCommand(
        logger: _logger,
        shell: shell ?? const ProcessShell(),
        workingDirectory: workingDirectory ?? Directory.current,
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
