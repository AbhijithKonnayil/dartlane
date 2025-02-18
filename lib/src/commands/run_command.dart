import 'dart:io';
import 'dart:isolate';

import 'package:args/command_runner.dart';
import 'package:dartlane/src/core/execute_cusomlane.dart';
import 'package:dartlane/src/core/files.dart';
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

  Future<void> executeCustomLane({
    required String projectPath,
    required String laneName,
  }) async {
    final lanesFile = findDartlaneLanesFile(projectPath);
    if (lanesFile == null) {
      _logger.err('lanes.dart not found in $projectPath/dartlane');
      return;
    }

    // Spawn an isolate to run the custom lane
    final receivePort = ReceivePort();
    await Isolate.spawn(runCustomLaneInIsolate, receivePort.sendPort);

    // Send the path of the lanes file to the isolate
    final sendPort = await receivePort.first as SendPort;
    sendPort.send({
      'lanesFilePath': lanesFile.path,
      'laneName': laneName,
    });
  }
}
