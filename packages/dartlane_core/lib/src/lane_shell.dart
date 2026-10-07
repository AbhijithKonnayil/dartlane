import 'dart:io';

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
  Future<ShellResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
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
class ShellException implements Exception {
  /// Creates an exception for [commandLine] that produced [result].
  const ShellException({required this.commandLine, required this.result});

  /// The command that failed, as typed, for example `flutter build apk`.
  final String commandLine;

  /// What the command produced.
  final ShellResult result;

  @override
  String toString() {
    final stderr = result.stderr.trim();
    final detail = stderr.isEmpty ? '' : '\n$stderr';
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
  }) async {
    final result = await Process.run(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
      // Tools such as flutter are .bat files on Windows.
      runInShell: Platform.isWindows,
    );
    return ShellResult(
      exitCode: result.exitCode,
      stdout: '${result.stdout}',
      stderr: '${result.stderr}',
    );
  }
}
