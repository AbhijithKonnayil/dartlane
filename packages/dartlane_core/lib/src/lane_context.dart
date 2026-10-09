import 'dart:io';

import 'package:dartlane_core/src/dry_run.dart';
import 'package:dartlane_core/src/lane_action.dart';
import 'package:dartlane_core/src/lane_args.dart';
import 'package:dartlane_core/src/lane_logger.dart';
import 'package:dartlane_core/src/lane_shell.dart';
import 'package:dartlane_core/src/secrets.dart';
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
  /// that writes to the terminal, [secretsProvider] to [env] and a `.env` file
  /// in the working directory, [shell] to a [ProcessShell], and [http] to a
  /// real client that is created on first use and closed by [close].
  LaneContext({
    Iterable<String> args = const [],
    this.dryRun = false,
    Map<String, String>? env,
    LaneLogger? logger,
    LaneShell? shell,
    Client? http,
    SecretsProvider? secretsProvider,
  }) : args = LaneArgs.parse(args),
       env = env ?? Platform.environment,
       logger = logger ?? LaneLogger(),
       shell = shell ?? const ProcessShell(),
       _injectedHttp = http {
    secrets = LaneSecrets(
      secretsProvider ?? EnvSecretsProvider(this.env),
      this.logger,
    );
  }

  /// Arguments given to the lane, after the lane name, parsed from the command
  /// line. See [LaneArgs] for the accepted forms and the typed getters.
  final LaneArgs args;

  /// Whether this is a dry run: the steps are described, not executed.
  ///
  /// Set by `--dry-run`. In a dry run [run] prints each action's
  /// `LaneAction.describe` and returns its `LaneAction.dryRunResult` without
  /// running it, [sh] runs nothing, and [http] refuses requests that would
  /// change something. This is best effort: code in a lane that has side
  /// effects some other way, such as writing a file, still runs. Check this
  /// flag before doing anything like that.
  final bool dryRun;

  final List<String> _dryRunSteps = [];

  /// The steps a dry run has described so far, in order.
  ///
  /// Empty unless [dryRun] is true.
  List<String> get dryRunSteps => List.unmodifiable(_dryRunSteps);

  /// Environment variables visible to the lane.
  final Map<String, String> env;

  /// Reads secrets from environment variables and an optional `.env` file, and
  /// masks what it returns in the log.
  ///
  /// Masking only covers values read through here, not [env]. See
  /// [LaneSecrets].
  late final LaneSecrets secrets;

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
  ///
  /// In a [dryRun] only requests that read (`GET` and `HEAD`) are sent; any
  /// other request stops the dry run with a [DryRunStopped].
  Client get http {
    final client = _injectedHttp ?? (_ownHttp ??= Client());
    return dryRun ? (_dryRunHttp ??= DryRunClient(client)) : client;
  }

  Client? _dryRunHttp;

  /// Runs [executable] with [arguments] and returns the result.
  ///
  /// In a [dryRun] the command is described and not run, and the result is a
  /// success with no output.
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
    if (dryRun) {
      _describeStep(line);
      return const ShellResult(exitCode: 0);
    }
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
  ///
  /// In a [dryRun] the action is not run: its line is printed and
  /// `LaneAction.dryRunResult` is returned instead.
  Future<R> run<R>(LaneAction<R> action) async {
    final name = action.describe();
    if (dryRun) {
      _describeStep(name);
      return action.dryRunResult(this);
    }
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

  void _describeStep(String description) {
    _dryRunSteps.add(description);
    logger.info('Would run: $description');
  }

  static String _format(Duration elapsed) {
    final ms = elapsed.inMilliseconds;
    return ms < 1000 ? '(${ms}ms)' : '(${(ms / 1000).toStringAsFixed(1)}s)';
  }
}
