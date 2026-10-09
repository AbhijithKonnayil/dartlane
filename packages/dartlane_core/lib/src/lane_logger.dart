import 'dart:io';

import 'package:mason_logger/mason_logger.dart' as mason;

/// Writes lane output to the terminal.
///
/// This is the logger that `LaneContext` and actions depend on. It styles
/// output with `mason_logger`, hides [detail] messages unless [verbose], and
/// adapts to CI: on GitHub Actions errors and warnings become annotations, and
/// on CI it never waits for an answer.
///
/// ## CI support
///
/// Only the annotations are platform specific, and only GitHub Actions is
/// supported: [githubActions] switches `error` and `warn` to the
/// `::error::` and `::warning::` workflow commands. Other platforms print
/// plain text. Prompts are off on every platform that sets `CI=true` and
/// whenever no terminal is attached.
///
/// Other platforms use different formats (Azure Pipelines uses
/// `##vso[task.logissue]`, TeamCity uses `##teamcity[message]`), so there is no
/// single "CI mode". Supporting another one means replacing the [githubActions]
/// flag with a small formatter chosen in [LaneLogger.fromEnvironment]. That is
/// deliberately not built until a second platform is needed. See `docs/ci.md`.
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
  final Set<String> _secrets = {};

  /// Replaces [secret] with `***` in all output from now on.
  ///
  /// Called for every value read through `LaneContext.secrets`. Empty values
  /// are ignored.
  void mask(String secret) {
    if (secret.isNotEmpty) _secrets.add(secret);
  }

  String _masked(String message) {
    if (_secrets.isEmpty) return message;
    // Longest first, so a secret that contains another is hidden whole.
    final ordered = _secrets.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    return ordered.fold(message, (text, s) => text.replaceAll(s, '***'));
  }

  /// Whether errors and warnings are printed as GitHub Actions annotations.
  ///
  /// GitHub Actions only; see the class documentation for other platforms.
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
  void info(String message) => _delegate.info(_masked(message));

  /// Extra information, printed only when [verbose] is true.
  void detail(String message) => _delegate.detail(_masked(message));

  /// A step or lane finished successfully.
  void success(String message) => _delegate.success(_masked(message));

  /// Something looks wrong but the lane continues.
  ///
  /// An annotation on GitHub Actions.
  void warn(String message) {
    if (githubActions) {
      _delegate.info(_annotation('warning', _masked(message)));
    } else {
      _delegate.warn(_masked(message));
    }
  }

  /// Something failed.
  ///
  /// An annotation on GitHub Actions.
  void error(String message) {
    if (githubActions) {
      _delegate.info(_annotation('error', _masked(message)));
    } else {
      _delegate.err(_masked(message));
    }
  }

  /// Asks a yes or no question.
  ///
  /// When not [interactive] it does not ask and returns [defaultValue].
  bool confirm(String message, {bool defaultValue = false}) {
    if (!interactive) return defaultValue;
    return _delegate.confirm(_masked(message), defaultValue: defaultValue);
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
