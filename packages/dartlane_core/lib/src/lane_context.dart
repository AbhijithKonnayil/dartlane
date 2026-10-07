import 'dart:io';

import 'package:dartlane_core/src/action.dart';
import 'package:dartlane_core/src/lane_logger.dart';

/// What a lane and its actions can see and use while running.
///
/// Shell and HTTP access are added with the interfaces for them.
class LaneContext {
  /// Creates a context.
  ///
  /// [env] defaults to the process environment and [logger] to a [LaneLogger]
  /// that writes to the terminal.
  LaneContext({
    this.args = const [],
    this.dryRun = false,
    Map<String, String>? env,
    LaneLogger? logger,
  }) : env = env ?? Platform.environment,
       logger = logger ?? LaneLogger();

  /// Arguments given to the lane, after the lane name.
  ///
  /// Typed parsing of `--key=value` is not part of the runner yet.
  final List<String> args;

  /// Whether the run should only describe what it would do.
  ///
  /// The runner does not set this yet and [run] does not act on it yet.
  final bool dryRun;

  /// Environment variables visible to the lane.
  final Map<String, String> env;

  /// Where progress and errors are written.
  final LaneLogger logger;

  /// Runs [action] and returns its result.
  ///
  /// This is the single place where a step is logged and timed. A failure is
  /// logged and rethrown, never swallowed.
  Future<R> run<P, R>(Action<P, R> action) async {
    final name = action.describe();
    logger.info('> $name');
    final stopwatch = Stopwatch()..start();
    try {
      final result = await action.run(this);
      logger.success('  done ${_format(stopwatch.elapsed)}');
      return result;
    } on Object {
      logger.error('$name failed ${_format(stopwatch.elapsed)}');
      rethrow;
    }
  }

  static String _format(Duration elapsed) {
    final ms = elapsed.inMilliseconds;
    return ms < 1000 ? '(${ms}ms)' : '(${(ms / 1000).toStringAsFixed(1)}s)';
  }
}
