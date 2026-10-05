import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:dartlane_core/dartlane_core.dart';
import 'package:mason_logger/mason_logger.dart';

class RunCommand extends Command<int> {
  RunCommand({
    required DLogger logger,
  }) : _logger = logger;

  @override
  String get description => 'Execute the custom lane ';

  @override
  String get name => 'run';

  final DLogger _logger;

  @override
  Future<int> run() async {
    final laneName = argResults!.rest.firstOrNull;
    if (laneName == null) {
      _logger.err('No lane name provided.');
      return ExitCode.usage.code;
    }

    final laneArgs = LaneArgsParser(argResults!.rest).parse();
    final projectPath = Directory.current.path;

    await executeCustomLane(
      projectPath: projectPath,
      laneName: laneName,
      laneArgs: laneArgs,
    );
    return ExitCode.success.code;
  }

  Future<void> executeCustomLane({
    required String projectPath,
    required String laneName,
    required Map<String, String> laneArgs,
  }) async {
    final lanesFile = findDartlaneLanesFile(projectPath);
    if (lanesFile == null) {
      _logger.err('`lanes.dart` not found in $projectPath/dartlane');
      return;
    }

    try {
      _logger.info('Running lane: $laneName');

      // We pass the lane name as the first argument to the user's script.
      // Any additional args should ideally be passed too.
      // For now, we construct the basic command.

      final process = await Process.start(
        'dart',
        ['run', lanesFile.path, laneName],
        mode: ProcessStartMode.inheritStdio,
        workingDirectory: projectPath,
      );

      final exitCode = await process.exitCode;

      if (exitCode != ExitCode.success.code) {
        _logger.err('Lane execution failed with exit code: $exitCode');
        exit(exitCode);
      }
    } catch (e) {
      _logger.err('$e');
    }
  }
}
