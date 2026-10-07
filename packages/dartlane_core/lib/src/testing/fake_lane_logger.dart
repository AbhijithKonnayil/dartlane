import 'package:dartlane_core/src/lane_logger.dart';
import 'package:mason_logger/mason_logger.dart' as mason;

/// A [LaneLogger] that records messages instead of printing them.
///
/// Errors are recorded as `error: <message>` and warnings as
/// `warning: <message>`; other levels are recorded as is. `detail` messages
/// are only recorded when [verbose] is true.
class FakeLaneLogger extends LaneLogger {
  /// Creates a logger that records into [lines].
  FakeLaneLogger({bool verbose = false}) : this._(<String>[], verbose: verbose);

  FakeLaneLogger._(this.lines, {required bool verbose})
    : super(
        delegate: _RecordingMasonLogger(
          lines,
          level: verbose ? mason.Level.verbose : mason.Level.info,
        ),
      );

  /// Everything logged so far, in order.
  final List<String> lines;
}

class _RecordingMasonLogger extends mason.Logger {
  _RecordingMasonLogger(this.lines, {super.level});

  final List<String> lines;

  @override
  void info(String? message, {mason.LogStyle? style}) => lines.add('$message');

  @override
  void detail(String? message, {mason.LogStyle? style}) {
    if (level.index <= mason.Level.debug.index) lines.add('$message');
  }

  @override
  void success(String? message, {mason.LogStyle? style}) =>
      lines.add('$message');

  @override
  void warn(String? message, {String tag = 'WARN', mason.LogStyle? style}) =>
      lines.add('warning: $message');

  @override
  void err(String? message, {mason.LogStyle? style}) =>
      lines.add('error: $message');
}
