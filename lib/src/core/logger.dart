import 'package:logger/logger.dart';

class DLogger {
  factory DLogger() {
    return _instance;
  }
  DLogger._internal();
  final Logger _logger = Logger(
    filter: ProductionFilter(),
    printer: Printer(),
  );

  static final DLogger _instance = DLogger._internal();

  void err(String msg) {
    _logger.e(msg);
  }

  void info(String msg) {
    _logger.i(msg);
  }

  progress(String s) {}

  void detail(String msg) {
    _logger.d(msg);
  }
}

class Printer extends PrettyPrinter {
  @override
  List<String> log(LogEvent event) {
    String message = stringifyMessage(event.message);
    List<String> buffer = [];
    AnsiColor color = _getLevelColor(event.level);

    for (var line in message.split('\n')) {
      buffer.add(color('$line'));
    }
    return buffer;
  }

  AnsiColor _getLevelColor(Level level) {
    AnsiColor? color;
    if (colors) {
      color = levelColors?[level] ?? PrettyPrinter.defaultLevelColors[level];
    }
    return color ?? const AnsiColor.none();
  }
}
