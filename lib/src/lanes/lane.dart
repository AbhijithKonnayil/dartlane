import 'package:dartlane/src/core/core.dart';

abstract interface class Lane {
  static final DLogger _logger = DLogger();
  static final Map<String, Lane> _lanes = {
    ..._inbuiltLanes,
    ..._registeredLanes,
  };
  static final Map<String, Lane> _inbuiltLanes = {};
  static final Map<String, Lane> _registeredLanes = {};

  static void register(String name, Lane lane) {
    if (_registeredLanes.containsKey(name)) {
      throw ArgumentError(
          'A lane with the name "$name" is already registered.');
    }
    _registeredLanes[name] = lane;
  }

  static void listLane() {
    _lanes.forEach((name, lane) {
      _logger.info(name);
    });
  }

  static void runLane(String name) {
    if (_lanes.containsKey(name)) {
      _lanes[name]!.execute();
    } else {
      _logger.err('Lane "$name" not found.');
    }
  }

  void description();
  void execute();
}
