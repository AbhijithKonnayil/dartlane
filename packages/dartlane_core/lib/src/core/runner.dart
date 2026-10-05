import 'dart:async';

import 'package:dartlane_core/src/core/lane.dart';
import 'package:dartlane_core/src/core/logger.dart';
import 'package:dartlane_core/src/lanes/firebase_app_distribution/firebase_app_distribution_lane.dart';
import 'package:dartlane_core/src/lanes/flutter_build_lane/flutter_build_lane.dart';

class DartlaneRunner {
  static final DLogger _logger = DLogger();

  static Future<void> run(
    List<String> args, {
    required FutureOr<void> Function() setup,
  }) async {
    // 1. Run the user's setup closure to register lanes
    await setup();

    // 2. Parse the args (e.g., ["beta_deploy"])
    // If run via `dart run dartlane/lanes.dart beta_deploy`, then args[0] is the lane name.

    final laneName = args.firstOrNull;

    if (laneName == null) {
      _logger.err('No lane provided.');
      _printAvailableLanes();
      return;
    }

    // 3. Execute the registered lane
    await Lanes.runLane(laneName);
  }

  static void _printAvailableLanes() {
    _logger.info('Available lanes:');
    Lanes.listLanes();
  }
}

class Lanes {
  static final DLogger _logger = DLogger();
  // Auto-register built-in lanes here
  static final Map<String, Lane> _lanes = {
    FirebaseAppDistributionLane().name: FirebaseAppDistributionLane(),
    FlutterBuildApkLane().name: FlutterBuildApkLane(),
    FlutterBuildAppBundleLane().name: FlutterBuildAppBundleLane(),
  };

  static void register(String name, Lane lane) {
    if (_lanes.containsKey(name)) {
      throw ArgumentError(
        'A lane with the name "$name" is already registered.',
      );
    }
    _lanes[name] = lane;
  }

  static Future<void> runLane(String name) async {
    final lane = _lanes[name];
    if (lane != null) {
      await lane.execute({});
    } else {
      _logger.err('Lane "$name" not found.');
      // Help the user see what is available
      _logger.info('Available lanes: ${_lanes.keys.join(', ')}');
    }
  }

  static void listLanes() {
    _lanes.forEach((name, lane) {
      _logger.info('- $name: ${lane.description}');
    });
  }
}
