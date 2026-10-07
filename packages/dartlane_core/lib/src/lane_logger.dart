import 'dart:io';

import 'package:mason_logger/mason_logger.dart' as mason;

/// Writes lane output to the terminal.
///
/// This is the logger that `LaneContext` and actions depend on. It styles
/// output with `mason_logger`, hides [detail] messages unless [verbose], and
/// adapts to CI: on GitHub Actions errors and warnings become annotations, and
/// on CI it never waits for an answer.
class LaneLogger {
  /// Creates a logger.
  ///
  /// Output goes to the terminal through `mason_logger`. Pass [delegate] to
  /// capture output in tests; [verbose] only applies when no [delegate] is
  /// given. Set [githubActions] to print errors and warnings as GitHub Actions
  /// annotations. [interactive] says whether it is fine to ask the user a
  /// question; it defaults to whether a terminal is attached.
  LaneLogger({
    bool verbose = false,
    this.githubActions = false,
    bool? interactive,
    mason.Logger? delegate,
  }) : interactive = interactive ?? (stdin.hasTerminal && stdout.hasTerminal),
       _delegate =
           delegate ??
           mason.Logger(
             level: verbose ? mason.Level.verbose : mason.Level.info,
           );

  /// Creates a logger configured from the process environment [env].
  ///
  /// `GITHUB_ACTIONS=true` turns on annotations. That or `CI=true` also turns
  /// off prompts, so a lane never hangs waiting for input on a runner.
  factory LaneLogger.fromEnvironment(
    Map<String, String> env, {
    bool verbose = false,
  }) {
    final github = env['GITHUB_ACTIONS'] == 'true';
    final ci = github || env['CI'] == 'true';
    return LaneLogger(
      verbose: verbose,
      githubActions: github,
      interactive: ci ? false : null,
    );
  }

  final mason.Logger _delegate;

  /// Whether errors and warnings are printed as GitHub Actions annotations.
  final bool githubActions;

  /// Whether it is fine to ask the user a question.
  ///
  /// False on CI and when no terminal is attached.
  final bool interactive;

  /// Whether [detail] messages are printed.
  bool get verbose => _delegate.level.index <= mason.Level.debug.index;

  set verbose(bool value) =>
      _delegate.level = value ? mason.Level.verbose : mason.Level.info;

  /// A normal progress message.
  void info(String message) => _delegate.info(message);

  /// Extra information, printed only when [verbose] is true.
  void detail(String message) => _delegate.detail(message);

  /// A step or lane finished successfully.
  void success(String message) => _delegate.success(message);

  /// Something looks wrong but the lane continues.
  ///
  /// An annotation on GitHub Actions.
  void warn(String message) {
    if (githubActions) {
      _delegate.info(_annotation('warning', message));
    } else {
      _delegate.warn(message);
    }
  }

  /// Something failed.
  ///
  /// An annotation on GitHub Actions.
  void error(String message) {
    if (githubActions) {
      _delegate.info(_annotation('error', message));
    } else {
      _delegate.err(message);
    }
  }

  /// Asks a yes or no question.
  ///
  /// When not [interactive] it does not ask and returns [defaultValue].
  bool confirm(String message, {bool defaultValue = false}) {
    if (!interactive) return defaultValue;
    return _delegate.confirm(message, defaultValue: defaultValue);
  }

  // https://docs.github.com/actions/reference/workflow-commands-for-github-actions
  static String _annotation(String level, String message) {
    final escaped = message
        .replaceAll('%', '%25')
        .replaceAll('\r', '%0D')
        .replaceAll('\n', '%0A');
    return '::$level::$escaped';
  }
}
