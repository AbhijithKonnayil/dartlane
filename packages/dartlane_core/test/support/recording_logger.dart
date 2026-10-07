import 'package:dartlane_core/dartlane_core.dart';
import 'package:mason_logger/mason_logger.dart' as mason;

/// Records messages instead of writing them to the terminal.
///
/// Errors are recorded as `error: <message>` and warnings as
/// `warning: <message>`; everything else is recorded as is.
class RecordingMasonLogger extends mason.Logger {
  /// Creates a recorder that appends to [lines].
  RecordingMasonLogger(this.lines, {super.level});

  /// Everything logged so far, in order.
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

/// A [LaneLogger] that records into [lines] instead of printing.
LaneLogger recordingLogger(List<String> lines) =>
    LaneLogger(delegate: RecordingMasonLogger(lines));
