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

class _AlwaysOk extends DoctorCheck {
  const _AlwaysOk();

  @override
  String get name => 'Always OK';

  @override
  Future<DoctorResult> run(LaneContext ctx) async =>
      const DoctorResult.pass('fine');
}

/// Fails while a file named fail.flag exists in the project folder.
class _FlagFile extends DoctorCheck {
  const _FlagFile();

  @override
  String get name => 'Flag file';

  @override
  Future<DoctorResult> run(LaneContext ctx) async =>
      File('fail.flag').existsSync()
      ? const DoctorResult.fail('fail.flag exists', fix: 'Delete fail.flag')
      : const DoctorResult.pass();
}

class _Optional extends DoctorCheck {
  const _Optional();

  @override
  String get name => 'Optional thing';

  @override
  bool get isRequired => false;

  @override
  Future<DoctorResult> run(LaneContext ctx) async =>
      const DoctorResult.fail('not set', fix: 'Set the optional thing');
}

Future<void> main(List<String> args) => dartlane(args, lanes: {
  'ok': Lane('Writes its arguments', (ctx) {
    final flavor = ctx.args.string('flavor');
    final positional = ctx.args.positional.join(',');
    File('args.txt').writeAsStringSync('flavor=$flavor positional=$positional');
  }),
  'fail': Lane('Always fails', (ctx) => throw const ActionFailed('nope')),
}, checks: [_AlwaysOk(), _FlagFile(), _Optional()]);
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
    File(p.join(project.path, 'pubspec.yaml')).writeAsStringSync(
      'name: sample_app\n',
    );
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

  test('list shows the lanes of the real program', () {
    // The command `dartlane list` launches.
    final result = Process.runSync(
      Platform.resolvedExecutable,
      ['run', 'dartlane/lanes.dart', '--list'],
      workingDirectory: project.path,
    );

    expect(result.exitCode, 0);
    expect(result.stdout, contains('Available lanes:'));
    expect(result.stdout, contains('  ok   : Writes its arguments'));
    expect(result.stdout, contains('  fail : Always fails'));
  });

  test('dartlane list exits 0 through the real launcher', () async {
    expect(await dartlane(['list']), ExitCodes.success);
  });

  group('doctor', () {
    File flag() => File(p.join(project.path, 'fail.flag'));

    ProcessResult runProgram() => Process.runSync(
      Platform.resolvedExecutable,
      ['run', 'dartlane/lanes.dart', '--doctor'],
      workingDirectory: project.path,
    );

    tearDown(() {
      if (flag().existsSync()) flag().deleteSync();
    });

    test('the program runs the checks it was given', () {
      final result = runProgram();

      expect(result.exitCode, 0);
      expect(result.stdout, contains('✓ Always OK: fine'));
      expect(result.stdout, contains('✓ Flag file'));
      expect(result.stderr, contains('Optional thing: not set'));
      expect(result.stdout, contains('Fix: Set the optional thing'));
      expect(
        result.stdout,
        contains('All required checks passed (1 warning).'),
      );
    });

    test('the program exits 1 when a required check fails', () {
      flag().writeAsStringSync('');

      final result = runProgram();

      expect(result.exitCode, 1);
      expect(result.stderr, contains('✗ Flag file: fail.flag exists'));
      expect(result.stdout, contains('Fix: Delete fail.flag'));
      expect(result.stderr, contains('1 required check failed (1 warning).'));
    });

    test('dartlane doctor exits 0 when everything passes', () async {
      expect(await dartlane(['doctor']), ExitCodes.success);
    });

    test('dartlane doctor exits 1 when a check in the program fails', () async {
      flag().writeAsStringSync('');

      expect(await dartlane(['doctor']), ExitCodes.failure);
    });
  });

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
