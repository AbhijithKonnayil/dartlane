import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:dartlane/src/commands/doctor_command.dart';
import 'package:dartlane/src/commands/init_command.dart';
import 'package:dartlane/src/commands/list_command.dart';
import 'package:dartlane/src/commands/run_command.dart';
import 'package:dartlane/src/commands/update_command.dart';
import 'package:dartlane/src/run/lanes_launcher.dart';
import 'package:dartlane/src/update/update_cache.dart';
import 'package:dartlane/src/update/update_checker.dart';
import 'package:dartlane/src/version.g.dart';
import 'package:dartlane_core/dartlane_core.dart';
import 'package:http/http.dart';
import 'package:pub_semver/pub_semver.dart';

/// Set this environment variable to anything to turn off the daily check for a
/// newer version.
const noUpdateCheckVariable = 'DARTLANE_NO_UPDATE_CHECK';

/// The `dartlane` command line tool.
///
/// It only launches things: `init` creates the nested `dartlane/` package, `run`
/// starts the user's own lanes program and passes the arguments and exit code
/// through, `list` asks that program for its lanes, `doctor` checks the setup
/// and asks the program for the checks that action packages contribute,
/// `update` installs a newer version, and the lanes themselves run in that
/// program through `dartlane_core`.
///
/// Once a day, on a terminal, a command also tells you if a newer version has
/// been published. See [UpdateChecker].
class DartlaneCommandRunner extends CommandRunner<int> {
  /// Creates the runner.
  ///
  /// Pass [logger], [shell], [launcher] and [workingDirectory] to control
  /// output, commands, the lanes program and the project folder in tests, and
  /// [dartSdkCheck] to pretend to run on another Dart version.
  ///
  /// [httpClientFactory], [cacheDirectory] and [environment] control the check
  /// for a newer version: how it reaches pub.dev, where it remembers the result
  /// (by default `~/.dartlane`), and the environment it reads.
  DartlaneCommandRunner({
    LaneLogger? logger,
    LaneShell? shell,
    LanesLauncher? launcher,
    Directory? workingDirectory,
    DoctorCheck? dartSdkCheck,
    Client Function()? httpClientFactory,
    Directory? cacheDirectory,
    Map<String, String>? environment,
  }) : _logger = logger ?? LaneLogger.fromEnvironment(Platform.environment),
       _environment = environment ?? Platform.environment,
       super(
         'dartlane',
         'Release automation for Flutter and Dart, written in Dart.',
       ) {
    argParser
      ..addFlag(
        'version',
        negatable: false,
        help: 'Print the dartlane version.',
      )
      ..addFlag('verbose', negatable: false, help: 'Show detail output.');

    final projectRoot = workingDirectory ?? Directory.current;
    final lanesLauncher = launcher ?? const ProcessLanesLauncher();
    final cacheFolder = cacheDirectory ?? _defaultCacheDirectory(_environment);
    _updateChecker = UpdateChecker(
      currentVersion: Version.parse(dartlaneVersion),
      clientFactory: httpClientFactory ?? Client.new,
      cache: cacheFolder == null ? null : UpdateCache(cacheFolder),
    );

    addCommand(
      InitCommand(
        logger: _logger,
        shell: shell ?? const ProcessShell(),
        workingDirectory: projectRoot,
      ),
    );
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
    addCommand(
      UpdateCommand(
        checker: _updateChecker,
        shell: shell ?? const ProcessShell(),
        logger: _logger,
      ),
    );
  }

  final LaneLogger _logger;
  final Map<String, String> _environment;
  late final UpdateChecker _updateChecker;

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
  Future<int?> runCommand(ArgResults topLevelResults) async {
    if (topLevelResults['verbose'] as bool) _logger.verbose = true;

    if (topLevelResults['version'] as bool) {
      _logger.info(dartlaneVersion);
      return ExitCodes.success;
    }

    // The check runs while the command does, so it adds no waiting.
    final notice = _shouldCheckForUpdates(topLevelResults.command?.name)
        ? _updateChecker.notice()
        : null;
    final code = await super.runCommand(topLevelResults);

    final text = await notice;
    if (text != null) _logger.info('\n$text');
    return code;
  }

  /// Only for a real command, on a terminal, and when not turned off.
  ///
  /// Never for `update`, which does its own check, or for `help`. Never when
  /// output is piped or on CI, where a notice would only be noise.
  bool _shouldCheckForUpdates(String? command) =>
      command != null &&
      command != 'update' &&
      command != 'help' &&
      _logger.interactive &&
      !_environment.containsKey(noUpdateCheckVariable);

  static Directory? _defaultCacheDirectory(Map<String, String> environment) {
    final home = environment['HOME'] ?? environment['USERPROFILE'];
    return home == null || home.isEmpty ? null : Directory('$home/.dartlane');
  }
}
