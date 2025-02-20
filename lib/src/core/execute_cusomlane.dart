import 'dart:io';
import 'dart:isolate';

import 'package:dartlane/src/core/logger.dart';

Future<void> runCustomLaneInIsolate(SendPort sendPort) async {
  final receivePort = ReceivePort();
  final messagePort = ReceivePort();
  final errorPort = ReceivePort();
  final exitPort = ReceivePort();
  final logger = DLogger();

  // Listen for regular messages
  messagePort.listen((message) {
    logger.info('Received message: $message');
  });

  // Listen for errors
  errorPort.listen((error) {
    if (error is List && error.length == 2 && error[0] == 'error') {
      logger.err('Isolate error: ${error[1]}');
    }
  });

  // Listen for exit notification
  exitPort.listen((_) {
    //_logger.info('Isolate exited.');
  });
  sendPort.send(receivePort.sendPort);

  // Wait for the path of the lanes file
  final data = await receivePort.first as Map<String, dynamic>;
  final lanesFilePath = data['lanesFilePath'] as String;
  final laneName = data['laneName'] as String;

  try {
    final libraryUri = Uri.file(lanesFilePath);
    final library = await Isolate.resolvePackageUri(libraryUri);
    if (library == null) {
      throw Exception('Failed to resolve library URI: $libraryUri');
    }

    final laneFileContentFromRepo = File(lanesFilePath).readAsStringSync();
    final modifiedCode =
        insertCode(laneFileContentFromRepo, 'Lane.runLane("$laneName");');
    await Isolate.spawnUri(
      Uri.dataFromString(modifiedCode, mimeType: 'application/dart'),
      [],
      messagePort.sendPort, // SendPort for regular messages
      onError: errorPort.sendPort, // Separate SendPort for errors
      onExit: exitPort.sendPort, // Separate SendPort for exit notification
      debugName: 'DynamicIsolate',
    );
  } catch (e) {
    logger.err('Error executing custom lane: $e');
  }
}

String insertCode(String originalCode, String customCode) {
  // Find the index where the main function ends
  final mainEndIndex =
      originalCode.indexOf('}', originalCode.indexOf('void main'));

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
