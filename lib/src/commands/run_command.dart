import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:dartlane/src/core/execute_cusomlane.dart';
import 'package:io/io.dart';

import '../core/logger.dart';

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
    String laneName = argResults!.rest.first;
    final projectPath = Directory.current.path;
    await executeCustomLane(projectPath: projectPath, laneName: laneName);
    return ExitCode.success.code;
  }
}
