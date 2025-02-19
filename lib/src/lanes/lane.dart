import 'package:dartlane/src/core/logger.dart';

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
      _logger
        ..err('Lane "$name" not found.')
        ..info(
            '\nMake sure you have created and registered your lane in `dartlane/lane.dart`')
        ..detail('eg:\nLane.register($name)\n');
    }
  }

  void description();
  void execute();
}
