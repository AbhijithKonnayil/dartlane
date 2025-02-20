import 'dart:io';
import 'dart:isolate';

import 'package:args/command_runner.dart';
import 'package:dartlane/src/core/enums.dart';
import 'package:dartlane/src/core/execute_cusomlane.dart';
import 'package:dartlane/src/core/files.dart';
import 'package:dartlane/src/core/logger.dart';
import 'package:io/io.dart';

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
    final laneName = argResults!.rest.first;
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
      _logger.err('`lanes.dart` not found in $projectPath/dartlane');
      return;
    }

    final receivePort = ReceivePort();
    receivePort.listen(
        (data) {
          if (data == Status.completed.name) {
            receivePort.close();
          }
        },
        onDone: () {},
        onError: (_) {
          _logger.err(_.toString());
        });
    try {
      final libraryUri = Uri.file(lanesFile.path);
      final library = await Isolate.resolvePackageUri(libraryUri);
      if (library == null) {
        throw Exception('Failed to resolve library URI: $libraryUri');
      }

      final laneFileContentFromRepo = File(lanesFile.path).readAsStringSync();

      final modifiedCode = insertCode(
        laneFileContentFromRepo,
        'await Lane.runLane("$laneName",sendPort);',
      );

      await Isolate.spawnUri(
        Uri.dataFromString(modifiedCode, mimeType: 'application/dart'),
        [],
        receivePort.sendPort,
      );
    } catch (e) {
      print(e);
    }
  }

  //
  Future<void> executeCustomLane_({
    required String projectPath,
    required String laneName,
  }) async {
    final lanesFile = findDartlaneLanesFile(projectPath);
    if (lanesFile == null) {
      _logger.err('`lanes.dart` not found in $projectPath/dartlane');
      return;
    }

    // Spawn an isolate to run the custom lane
    final receivePort = ReceivePort();
    await Isolate.spawn(runCustomLaneInIsolate, receivePort.sendPort)
        .then((isolate) {
      isolate.addOnExitListener(receivePort.sendPort);
    });

    // Send the path of the lanes file to the isolate
    final sendPort = await receivePort.first as SendPort;
    sendPort.send({
      'lanesFilePath': lanesFile.path,
      'laneName': laneName,
    });
  }
}

void isoMain(Object? message) {
  int i = 0;
  while (true) {
    print('I am alive ${i++}');
  }
}
