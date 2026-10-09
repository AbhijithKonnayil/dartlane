import 'dart:convert';
import 'dart:io';

import 'package:dartlane_core/src/lane_error.dart';

/// Runs external commands for a lane.
///
/// Actions reach this through `LaneContext.shell` or `LaneContext.sh`, never
/// through `Process` directly, so tests can replace it with a fake.
// An interface rather than a function type so the real shell and the fake can
// be named, documented and extended with more members later.
// ignore: one_member_abstracts
abstract interface class LaneShell {
  /// Runs [executable] with [arguments] and waits for it to finish.
  ///
  /// A non-zero exit code is returned in the result, not thrown.
  ///
  /// Pass [onOutput] to receive each line of output as the command prints it,
  /// from both standard output and standard error. The full output is still
  /// returned in the result.
  Future<ShellResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    void Function(String line)? onOutput,
  });
}

/// The outcome of a finished command.
class ShellResult {
  /// Creates a result.
  const ShellResult({
    required this.exitCode,
    this.stdout = '',
    this.stderr = '',
  });

  /// The process exit code. Zero means success.
  final int exitCode;

  /// Everything the command wrote to standard output.
  final String stdout;

  /// Everything the command wrote to standard error.
  final String stderr;

  /// Whether the command exited with code zero.
  bool get ok => exitCode == 0;
}

/// A command exited with a non-zero code.
class ShellException extends ActionFailed {
  /// Creates an exception for [commandLine] that produced [result].
  ///
  /// Set [outputShown] when the command's output was already printed as it
  /// ran, so the message does not repeat the error output.
  ShellException({
    required this.commandLine,
    required this.result,
    bool outputShown = false,
  }) : super(_describe(commandLine, result, outputShown: outputShown));

  /// The command that failed, as typed, for example `flutter build apk`.
  final String commandLine;

  /// What the command produced.
  final ShellResult result;

  static String _describe(
    String commandLine,
    ShellResult result, {
    required bool outputShown,
  }) {
    final stderr = result.stderr.trim();
    final detail = outputShown || stderr.isEmpty ? '' : '\n$stderr';
    return '`$commandLine` exited with code ${result.exitCode}.$detail';
  }
}

/// Formats [executable] and [arguments] as one line, for logs and messages.
String formatCommand(String executable, List<String> arguments) =>
    [executable, ...arguments].join(' ');

/// The real [LaneShell]: starts operating system processes.
class ProcessShell implements LaneShell {
  /// Creates a shell that runs real processes.
  const ProcessShell();

  @override
  Future<ShellResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    void Function(String line)? onOutput,
  }) async {
    // Tools such as flutter are .bat files on Windows.
    final runInShell = Platform.isWindows;

    if (onOutput == null) {
      final result = await Process.run(
        executable,
        arguments,
        workingDirectory: workingDirectory,
        environment: environment,
        runInShell: runInShell,
      );
      return ShellResult(
        exitCode: result.exitCode,
        stdout: '${result.stdout}',
        stderr: '${result.stderr}',
      );
    }

    final process = await Process.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
      runInShell: runInShell,
    );
    // Nothing is typed into the command, so a prompt must not wait for input.
    await process.stdin.close();

    final stdout = StringBuffer();
    final stderr = StringBuffer();
    Future<void> collect(Stream<List<int>> stream, StringBuffer buffer) {
      return stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .forEach((line) {
            buffer.writeln(line);
            onOutput(line);
          });
    }

    // Read both streams to the end before returning, or output is lost.
    final (_, _, exitCode) = await (
      collect(process.stdout, stdout),
      collect(process.stderr, stderr),
      process.exitCode,
    ).wait;

    return ShellResult(
      exitCode: exitCode,
      stdout: '$stdout',
      stderr: '$stderr',
    );
  }
}
