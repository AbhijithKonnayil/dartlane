import 'dart:io';

import 'package:dartlane_core/dartlane_core.dart';
import 'package:test/test.dart';

void main() {
  group('ProcessShell', () {
    // The running Dart executable is a command that exists on every machine
    // that runs these tests.
    final dart = Platform.resolvedExecutable;

    test('returns output and a zero exit code on success', () async {
      final result = await const ProcessShell().run(dart, ['--version']);

      expect(result.ok, isTrue);
      expect(result.exitCode, 0);
      expect('${result.stdout}${result.stderr}', contains('Dart SDK'));
    });

    test('returns a non-zero exit code instead of throwing', () async {
      final result = await const ProcessShell().run(dart, ['--no-such-flag']);

      expect(result.ok, isFalse);
      expect(result.exitCode, isNot(0));
    });
  });

  group('ShellException', () {
    test('names the command, the exit code and the error output', () {
      final exception = ShellException(
        commandLine: 'flutter build apk',
        result: const ShellResult(exitCode: 2, stderr: 'boom\n'),
      );
      expect(
        '$exception',
        '`flutter build apk` exited with code 2.\nboom',
      );
    });

    test('omits the error output when there is none', () {
      final exception = ShellException(
        commandLine: 'flutter build apk',
        result: const ShellResult(exitCode: 2),
      );
      expect('$exception', '`flutter build apk` exited with code 2.');
    });
  });

  test('formatCommand joins the executable and arguments', () {
    expect(formatCommand('flutter', ['build', 'apk']), 'flutter build apk');
    expect(formatCommand('flutter', []), 'flutter');
  });
}
