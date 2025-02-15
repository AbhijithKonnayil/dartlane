import 'package:mason_logger/mason_logger.dart';

class DLogger extends Logger {
  factory DLogger() {
    return _instance;
  }

  DLogger._internal();

  static final DLogger _instance = DLogger._internal();
}
