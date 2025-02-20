import 'dart:io';
import 'dart:isolate';

import 'package:args/command_runner.dart';
import 'package:dartlane/src/core/enums.dart';
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
      },
    );
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

  String insertCode(String originalCode, String customCode) {
    // Find the index where the main function ends
    final mainEndIndex =
        originalCode.indexOf('}', originalCode.indexOf('Future<void> main'));

    // If the main function end is found,\ insert the custom code before the last '}'
    if (mainEndIndex != -1) {
      // Split the original code into two parts:
      //before and after the main function's closing brace
      final beforeMainEnd = originalCode.substring(0, mainEndIndex);
      final afterMainEnd = originalCode.substring(mainEndIndex);

      // Combine the parts with the custom code \ inserted before the closing brace of main
      return '$beforeMainEnd\n  $customCode\n$afterMainEnd';
    }

    // If the main function end is not found, return the original code
    return originalCode;
  }
}
