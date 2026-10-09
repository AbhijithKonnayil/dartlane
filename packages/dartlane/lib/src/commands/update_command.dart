import 'package:args/command_runner.dart';
import 'package:dartlane/src/update/pub_dev_client.dart';
import 'package:dartlane/src/update/update_checker.dart';
import 'package:dartlane_core/dartlane_core.dart';
import 'package:pub_semver/pub_semver.dart';

/// `dartlane update`: installs the newest version from pub.dev.
///
/// It asks pub.dev for the latest version and, if it is newer than the one
/// installed, runs `dart pub global activate dartlane <version>`.
class UpdateCommand extends Command<int> {
  /// Creates the command.
  ///
  /// [checker] asks pub.dev, [shell] runs `dart pub global activate` and
  /// [logger] prints progress.
  UpdateCommand({
    required this.checker,
    required this.shell,
    required this.logger,
  });

  /// Asks pub.dev for the newest version.
  final UpdateChecker checker;

  /// Runs `dart pub global activate`.
  final LaneShell shell;

  /// Where progress is printed.
  final LaneLogger logger;

  @override
  String get name => 'update';

  @override
  String get description => 'Update dartlane to the latest version on pub.dev.';

  @override
  bool get takesArguments => false;

  @override
  String get invocation => 'dartlane update';

  @override
  Future<int> run() async {
    final current = checker.currentVersion;
    logger.info('Checking for updates...');

    final latest = await _latest();
    if (latest == null) {
      throw const ActionFailed(
        'dartlane is not on pub.dev, so there is nothing to update to.',
      );
    }
    if (latest <= current) {
      logger.success('dartlane $current is already the latest version.');
      return ExitCodes.success;
    }

    logger.info('Updating dartlane $current → $latest');
    final result = await shell.run(
      'dart',
      ['pub', 'global', 'activate', dartlanePackageName, '$latest'],
      onOutput: logger.info,
    );
    if (!result.ok) {
      throw ShellException(
        commandLine: 'dart pub global activate $dartlanePackageName $latest',
        result: result,
        outputShown: true,
      );
    }

    logger.success('Updated dartlane to $latest.');
    return ExitCodes.success;
  }

  Future<Version?> _latest() async {
    try {
      return await checker.latestVersion();
    } on UpdateCheckException catch (error) {
      throw ActionFailed(error.message);
    }
  }
}
