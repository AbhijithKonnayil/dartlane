import 'dart:isolate';

import 'package:dartlane_core/src/core/logger.dart';

import 'enums.dart';

abstract class Lane {
  static final DLogger _logger = DLogger();

  String get description;
  String get name;
  Future<void> execute(Map<String, String> laneArgs);

  Future<void> executeAndSendStatus(SendPort mainSendPort) async {
    _logger.info('Executing $name Lane\n');
    final isolateReceivePort =
        ReceivePort()..listen((data) {
          if (data is Map<String, Map<String, String>>) {
            if (data.containsKey('execute')) {
              final args = data['execute']!;
              execute(args).whenComplete(() {
                mainSendPort.send(Status.completed.name);
              });
            } else {
              mainSendPort.send(Status.completed.name);
            }
          }
        });
    mainSendPort.send(isolateReceivePort.sendPort);
  }
}
