import 'package:mason_logger/mason_logger.dart' as mason;

/// Writes lane output to the terminal.
///
/// This is the logger that `LaneContext` and actions depend on. It styles
/// output with `mason_logger` and is the one place to add CI-specific behaviour
/// later.
class LaneLogger {
  /// Creates a logger.
  ///
  /// Output goes to the terminal through `mason_logger`. Pass [delegate] to
  /// capture output in tests; [verbose] only applies when no [delegate] is
  /// given.
  LaneLogger({bool verbose = false, mason.Logger? delegate})
    : _delegate =
          delegate ??
          mason.Logger(level: verbose ? mason.Level.verbose : mason.Level.info);

  final mason.Logger _delegate;

  /// Whether [detail] messages are printed.
  bool get verbose => _delegate.level.index <= mason.Level.debug.index;

  /// A normal progress message.
  void info(String message) => _delegate.info(message);

  /// Extra information, printed only when [verbose] is true.
  void detail(String message) => _delegate.detail(message);

  /// A step or lane finished successfully.
  void success(String message) => _delegate.success(message);

  /// Something looks wrong but the lane continues.
  void warn(String message) => _delegate.warn(message);

  /// Something failed.
  void error(String message) => _delegate.err(message);
}
