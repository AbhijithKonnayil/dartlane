import 'dart:convert';
import 'dart:io';

import 'package:dartlane_core/src/lane_shell.dart';

/// One command that a [FakeLaneShell] was asked to run.
class ShellCall {
  /// Creates a record of a call.
  const ShellCall({
    required this.executable,
    required this.arguments,
    this.workingDirectory,
    this.environment,
  });

  /// The program that was run.
  final String executable;

  /// Its arguments.
  final List<String> arguments;

  /// The directory it was run in, if one was given.
  final String? workingDirectory;

  /// The extra environment it was run with, if one was given.
  final Map<String, String>? environment;

  /// The call as one line, for example `flutter build apk`.
  String get commandLine => formatCommand(executable, arguments);
}

/// A [LaneShell] that runs nothing. It records every call and answers with
/// results you set up.
///
/// When asked for output it replays the stubbed output line by line, standard
/// output first.
///
/// A command with no stub succeeds with empty output, so a lane that runs
/// many incidental commands only needs stubs for the ones that matter.
class FakeLaneShell implements LaneShell {
  /// Creates a fake shell.
  FakeLaneShell();

  final List<ShellCall> _calls = [];
  final Map<String, ShellResult> _stubs = {};
  final Set<String> _missing = {};

  /// Every command run so far, in order.
  List<ShellCall> get calls => List.unmodifiable(_calls);

  /// Every command run so far as lines, for example `['flutter build apk']`.
  List<String> get commands => [for (final call in _calls) call.commandLine];

  /// Makes [command] (written as one line, for example `flutter build apk`)
  /// answer with the given result. A later stub for the same command wins.
  void stub(
    String command, {
    int exitCode = 0,
    String stdout = '',
    String stderr = '',
  }) {
    _stubs[command] = ShellResult(
      exitCode: exitCode,
      stdout: stdout,
      stderr: stderr,
    );
  }

  /// Makes [executable] behave as if it is not installed: running it throws a
  /// [ProcessException], like the real shell does.
  void stubMissing(String executable) => _missing.add(executable);

  @override
  Future<ShellResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    void Function(String line)? onOutput,
  }) async {
    final call = ShellCall(
      executable: executable,
      arguments: arguments,
      workingDirectory: workingDirectory,
      environment: environment,
    );
    _calls.add(call);
    if (_missing.contains(executable)) {
      throw ProcessException(
        executable,
        arguments,
        'No such file or directory',
        2,
      );
    }
    final result = _stubs[call.commandLine] ?? const ShellResult(exitCode: 0);
    if (onOutput != null) {
      // Like the real shell: every line of output, standard output first.
      for (final text in [result.stdout, result.stderr]) {
        const LineSplitter().convert(text).forEach(onOutput);
      }
    }
    return result;
  }
}
