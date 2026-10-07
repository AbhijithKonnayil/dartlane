// Runs a real lanes program through `dartlane run`.
//
// This checks what the fake launcher cannot: that `dart run dartlane/lanes.dart`
// works from the project root, that the lane runs in that folder, that
// arguments arrive, and that the exit code comes back. It runs `dart pub get`,
// so it needs network access the first time.
import 'dart:io';

import 'package:dartlane/dartlane.dart';
import 'package:dartlane/src/run/lanes_launcher.dart';
import 'package:dartlane_core/dartlane_core.dart';
import 'package:dartlane_core/testing.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

const _lanes = r'''
import 'dart:io';

import 'package:dartlane_core/dartlane_core.dart';

Future<void> main(List<String> args) => dartlane(args, lanes: {
  'ok': Lane('Writes its arguments', (ctx) {
    final flavor = ctx.args.string('flavor');
    final positional = ctx.args.positional.join(',');
    File('args.txt').writeAsStringSync('flavor=$flavor positional=$positional');
  }),
  'fail': Lane('Always fails', (ctx) => throw const ActionFailed('nope')),
});
''';

void main() {
  late Directory project;

  setUpAll(() {
    // `dart test` runs from <repo>/packages/dartlane.
    final repo = p.normalize(p.join(Directory.current.path, '..', '..'));
    expect(
      Directory(p.join(repo, 'packages', 'dartlane_core')).existsSync(),
      isTrue,
      reason: 'Run this test from packages/dartlane in the Dartlane repo.',
    );

    project = Directory.systemTemp.createTempSync('dartlane_run_e2e_');
    final lanes = Directory(p.join(project.path, 'dartlane'))..createSync();
    File(p.join(lanes.path, 'lanes.dart')).writeAsStringSync(_lanes);
    File(p.join(lanes.path, 'pubspec.yaml')).writeAsStringSync('''
name: sample_dartlane
publish_to: none
environment:
  sdk: ^3.10.0
dependencies:
  dartlane_core: any
dependency_overrides:
  dartlane_core:
    path: $repo/packages/dartlane_core
''');
    final pubGet = Process.runSync(
      Platform.resolvedExecutable,
      ['pub', 'get'],
      workingDirectory: lanes.path,
    );
    expect(pubGet.exitCode, 0, reason: '${pubGet.stdout}\n${pubGet.stderr}');
  });

  tearDownAll(() => project.deleteSync(recursive: true));

  // The lanes program's output is not shown: the failing lanes below print
  // errors on purpose, and they would look like test failures in the log.
  Future<int> dartlane(List<String> args) => DartlaneCommandRunner(
    logger: FakeLaneLogger(),
    launcher: const ProcessLanesLauncher(inheritStdio: false),
    workingDirectory: project,
  ).run(args);

  test(
    'runs the lane from the project root with typed arguments, exit code 0',
    () async {
      final code = await dartlane(['run', 'ok', '--flavor=prod', 'x']);

      expect(code, ExitCodes.success);
      // The lane wrote this file relative to its working directory.
      expect(
        File(p.join(project.path, 'args.txt')).readAsStringSync(),
        'flavor=prod positional=x',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test('returns the exit code of a failing lane', () async {
    expect(await dartlane(['run', 'fail']), ExitCodes.failure);
  });

  test('returns the usage code for an unknown lane', () async {
    expect(await dartlane(['run', 'nope']), ExitCodes.usage);
  });

  test('returns the usage code when no lane is given', () async {
    expect(await dartlane(['run']), ExitCodes.usage);
  });
}
