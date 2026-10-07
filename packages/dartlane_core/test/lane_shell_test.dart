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

  group('ProcessShell streaming', () {
    late Directory dir;
    final dart = Platform.resolvedExecutable;

    setUp(() => dir = Directory.systemTemp.createTempSync('dartlane_shell_'));
    tearDown(() => dir.deleteSync(recursive: true));

    String script(String body) {
      final file = File('${dir.path}/script.dart')
        ..writeAsStringSync("import 'dart:io';\n$body");
      return file.path;
    }

    test('delivers each line and still returns the full output', () async {
      final path = script('''
void main() {
  stdout.writeln('one');
  stderr.writeln('two');
  stdout.write('three');
  exit(3);
}
''');
      final lines = <String>[];

      final result = await const ProcessShell().run(
        dart,
        [path],
        onOutput: lines.add,
      );

      expect(result.exitCode, 3);
      expect(lines, unorderedEquals(['one', 'two', 'three']));
      expect(result.stdout, 'one\nthree\n');
      expect(result.stderr, 'two\n');
    });

    test('delivers lines while the command is still running', () async {
      final path = script('''
Future<void> main() async {
  stdout.writeln('first');
  await stdout.flush();
  await Future<void>.delayed(const Duration(milliseconds: 800));
  stdout.writeln('second');
}
''');
      DateTime? firstSeen;

      await const ProcessShell().run(
        dart,
        [path],
        onOutput: (line) {
          if (line == 'first') firstSeen = DateTime.now();
        },
      );
      final finished = DateTime.now();

      expect(firstSeen, isNotNull);
      expect(
        finished.difference(firstSeen!),
        greaterThan(const Duration(milliseconds: 500)),
      );
    });

    test('a command that waits for input does not hang', () async {
      final path = script('''
void main() {
  final line = stdin.readLineSync();
  stdout.writeln('got ' + (line ?? 'nothing'));
}
''');
      final lines = <String>[];

      final result = await const ProcessShell()
          .run(dart, [path], onOutput: lines.add)
          .timeout(const Duration(seconds: 30));

      expect(result.ok, isTrue);
      expect(lines, ['got nothing']);
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
