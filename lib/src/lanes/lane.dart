import 'package:dartlane/src/core/logger.dart';

abstract interface class Lane {
  static final DLogger _logger = DLogger();
  static final Map<String, Lane> _lanes = {};

  static void register(String name, Lane lane) {
    _lanes[name] = lane;
  }

  static void runLane(String name) {
    if (_lanes.containsKey(name)) {
      _lanes[name]!.execute();
    } else {
      _logger.alert('Lane "$name" not found.');
    }
  }

  void description();
  void execute();
}
