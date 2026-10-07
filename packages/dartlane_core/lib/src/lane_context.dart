import 'dart:io';

import 'package:dartlane_core/src/lane_action.dart';
import 'package:dartlane_core/src/lane_args.dart';
import 'package:dartlane_core/src/lane_logger.dart';
import 'package:dartlane_core/src/lane_shell.dart';
import 'package:http/http.dart' show Client;

/// What a lane and its actions can see and use while running.
///
/// Actions run commands through [shell] or [sh] and make web requests through
/// [http], never through `Process` or `dart:io` directly, so tests can swap in
/// fakes.
class LaneContext {
  /// Creates a context.
  ///
  /// [args] are the raw words after the lane name, parsed into [LaneArgs].
  /// [env] defaults to the process environment, [logger] to a [LaneLogger]
  /// that writes to the terminal, [shell] to a [ProcessShell], and [http] to a
  /// real client that is created on first use and closed by [close].
  LaneContext({
    Iterable<String> args = const [],
    this.dryRun = false,
    Map<String, String>? env,
    LaneLogger? logger,
    LaneShell? shell,
    Client? http,
  }) : args = LaneArgs.parse(args),
       env = env ?? Platform.environment,
       logger = logger ?? LaneLogger(),
       shell = shell ?? const ProcessShell(),
       _injectedHttp = http;

  /// Arguments given to the lane, after the lane name, parsed from the command
  /// line. See [LaneArgs] for the accepted forms and the typed getters.
  final LaneArgs args;

  /// Whether the run should only describe what it would do.
  ///
  /// The runner does not set this yet and [run] does not act on it yet.
  final bool dryRun;

  /// Environment variables visible to the lane.
  final Map<String, String> env;

  /// Where progress and errors are written.
  final LaneLogger logger;

  /// Runs external commands. Prefer [sh] unless you need the exit code.
  final LaneShell shell;

  final Client? _injectedHttp;
  Client? _ownHttp;

  /// Makes web requests.
  ///
  /// A `package:http` [Client], so it can be wrapped, for example by
  /// `googleapis_auth`, or replaced with a fake in tests.
  Client get http => _injectedHttp ?? (_ownHttp ??= Client());

  /// Runs [executable] with [arguments] and returns the result.
  ///
  /// The command is logged at detail level, and its output is printed as it
  /// runs so a long build shows progress. Pass `streamOutput: false` for a
  /// command whose output you only want to read from the result, such as
  /// `git rev-parse HEAD`. Throws a [ShellException] if the command exits with
  /// a non-zero code.
  Future<ShellResult> sh(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool streamOutput = true,
  }) async {
    final line = formatCommand(executable, arguments);
    logger.detail(r'$ ' + line);
    final result = await shell.run(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
      onOutput: streamOutput ? logger.info : null,
    );
    if (!result.ok) {
      throw ShellException(
        commandLine: line,
        result: result,
        outputShown: streamOutput,
      );
    }
    return result;
  }

  /// Releases resources this context created itself.
  ///
  /// Closes the HTTP client only if the context created it. A client passed to
  /// the constructor stays open; its owner closes it.
  void close() => _ownHttp?.close();

  /// Runs [action] and returns its result.
  ///
  /// This is the single place where a step is logged and timed. A failure is
  /// logged and rethrown, never swallowed.
  Future<R> run<R>(LaneAction<R> action) async {
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
