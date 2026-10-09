import 'package:dartlane_core/src/lane_logger.dart';
import 'package:mason_logger/mason_logger.dart' as mason;

/// A [LaneLogger] that records messages instead of printing them.
///
/// Errors are recorded as `error: <message>` and warnings as
/// `warning: <message>`; other levels are recorded as is. `detail` messages
/// are only recorded when [verbose] is true.
///
/// Questions are recorded as `confirm: <message>` and answered with
/// `confirmAnswer`, but only when `interactive` is true. It is false by
/// default, like on CI.
class FakeLaneLogger extends LaneLogger {
  /// Creates a logger that records into [lines].
  FakeLaneLogger({
    bool verbose = false,
    bool githubActions = false,
    bool interactive = false,
    bool confirmAnswer = true,
  }) : this._(
         <String>[],
         verbose: verbose,
         githubActions: githubActions,
         interactive: interactive,
         confirmAnswer: confirmAnswer,
       );

  FakeLaneLogger._(
    this.lines, {
    required bool verbose,
    required super.githubActions,
    required bool interactive,
    required bool confirmAnswer,
  }) : super(
         interactive: interactive,
         delegate: _RecordingMasonLogger(
           lines,
           confirmAnswer: confirmAnswer,
           level: verbose ? mason.Level.verbose : mason.Level.info,
         ),
       );

  /// Everything logged so far, in order.
  final List<String> lines;
}

class _RecordingMasonLogger extends mason.Logger {
  _RecordingMasonLogger(
    this.lines, {
    required this.confirmAnswer,
    super.level,
  });

  final List<String> lines;
  final bool confirmAnswer;

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

  @override
  bool confirm(String? message, {bool defaultValue = false}) {
    lines.add('confirm: $message');
    return confirmAnswer;
  }
}
