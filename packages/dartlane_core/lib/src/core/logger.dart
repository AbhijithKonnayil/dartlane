import 'package:logger/logger.dart';

class DLogger {
  factory DLogger() {
    return _instance;
  }
  DLogger._internal();
  final Logger _logger = Logger(
    filter: ProductionFilter(),
    printer: DefaultLogPrinter(),
  );
  final Logger _customLogger = Logger(
    filter: ProductionFilter(),
    printer: CustomLogPrinter(),
  );

  static final DLogger _instance = DLogger._internal();

  void err(String msg) {
    _logger.e(msg);
  }

  void info(String msg) {
    _logger.i(msg);
  }

  void success(String msg) {
    _customLogger.i('✓ $msg\n');
  }

  dynamic progress(String s) {}

  void detail(String msg) {
    _logger.d(msg);
  }
}

class DefaultLogPrinter extends PrettyPrinter {
  @override
  List<String> log(LogEvent event) {
    final message = stringifyMessage(event.message);
    final buffer = <String>[];
    final color = getLevelColor(event.level);

    for (final line in message.split('\n')) {
      buffer.add(color(line));
    }
    return buffer;
  }

  AnsiColor getLevelColor(Level level) {
    AnsiColor? color;
    if (colors) {
      color = levelColors?[level] ?? PrettyPrinter.defaultLevelColors[level];
    }
    return color ?? const AnsiColor.none();
  }
}

class CustomLogPrinter extends DefaultLogPrinter {
  @override
  final Map<Level, AnsiColor>? levelColors = {
    Level.info: const AnsiColor.fg(02),
  };
}
