import 'dart:isolate';

import 'package:dartlane/src/core/enums.dart';
import 'package:dartlane/src/core/logger.dart';

import 'flutter_build_lane.dart';

abstract class Lane {
  static final DLogger _logger = DLogger();
  static final Map<String, Lane> _lanes = {
    ..._inbuiltLanes,
    ..._registeredLanes,
  };
  static final Map<String, Lane> _inbuiltLanes = {
    //'flutterBuild': FlutterBuildLane(),
    'flutterBuildApk': FlutterBuildApkLane(),
  };
  static final Map<String, Lane> _registeredLanes = {};

  static void register(String name, Lane lane) {
    if (_registeredLanes.containsKey(name)) {
      throw ArgumentError(
        'A lane with the name "$name" is already registered.',
      );
    }
    _registeredLanes[name] = lane;
  }

  static void listLane() {
    _lanes.forEach((name, lane) {
      _logger.info(name);
    });
  }

  static Future<void> runLane(String name, SendPort sendPort) async {
    if (_lanes.containsKey(name)) {
      await _lanes[name]!.executeAndSendStatus(sendPort);
    } else {
      _logger
        ..err('Lane "$name" not found.')
        ..info(
          '\nMake sure you have created and registered your lane in `dartlane/lane.dart`',
        )
        ..detail('eg:\nLane.register($name)\n');
    }
  }

  String get description;
  Future<void> execute();

  Future<void> executeAndSendStatus(SendPort sendPort) async {
    await execute();
    sendPort.send(Status.completed.name);
  }
}
