import 'dart:isolate';

import 'package:dartlane/src/lanes/firebase_app_distribution/firebase_app_distribution_lane.dart';
import 'package:dartlane/src/lanes/flutter_build_lane/flutter_build_lane.dart';
import 'package:dartlane_core/dartlane_core.dart';

abstract class Lanes {
  static final DLogger _logger = DLogger();

  static final Map<String, Lane> _lanes = {
    ..._inbuiltLanes,
    ..._registeredLanes,
  };
  static final Map<String, Lane> _inbuiltLanes = {
    //'flutterBuild': FlutterBuildLane(),
    FirebaseAppDistributionLane().name: FirebaseAppDistributionLane(),
    FlutterBuildApkLane().name: FlutterBuildApkLane(),
    FlutterBuildAppBundleLane().name: FlutterBuildAppBundleLane(),
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
      sendPort.send(Status.completed.name);
    }
  }
}
