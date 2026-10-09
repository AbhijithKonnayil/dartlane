import 'dart:io';

import 'package:dartlane/dartlane.dart';
import 'package:dartlane_core/dartlane_core.dart';
import 'package:dartlane_core/testing.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/fake_lanes_launcher.dart';

void main() {
  late Directory project;
  late FakeLanesLauncher launcher;
  late FakeLaneLogger logger;

  Future<int> run(List<String> args) => DartlaneCommandRunner(
    logger: logger,
    launcher: launcher,
    workingDirectory: project,
  ).run(args);

  setUp(() {
    project = Directory.systemTemp.createTempSync('dartlane_run_test_');
    File(p.join(project.path, 'dartlane', 'lanes.dart'))
      ..createSync(recursive: true)
      ..writeAsStringSync('// lanes');
    launcher = FakeLanesLauncher();
    logger = FakeLaneLogger();
  });

  tearDown(() => project.deleteSync(recursive: true));

  group('run', () {
    test('launches the lane in the project root', () async {
      await run(['run', 'beta']);

      final call = launcher.calls.single;
      expect(call.arguments, ['beta']);
      expect(call.projectRoot.path, project.path);
    });

    test('forwards the arguments to the lane untouched', () async {
      await run(['run', 'beta', '--flavor=prod', '--dart-define=A=1', 'x']);

      expect(launcher.calls.single.arguments, [
        'beta',
        '--flavor=prod',
        '--dart-define=A=1',
        'x',
      ]);
    });

    test('forwards options that look like its own', () async {
      await run(['run', 'beta', '--verbose', '-h', '--force']);

      expect(launcher.calls.single.arguments, [
        'beta',
        '--verbose',
        '-h',
        '--force',
      ]);
    });

    test('forwards --dry-run to the lanes program', () async {
      await run(['run', 'beta', '--dry-run']);

      expect(launcher.calls.single.arguments, ['beta', '--dry-run']);
    });

    test('exits with the code of the lane', () async {
      for (final code in [0, 1, 7, 64]) {
        launcher.exitCode = code;

        expect(await run(['run', 'beta']), code);
      }
    });

    test(
      'with no lane it still launches, so the lanes can be listed',
      () async {
        await run(['run']);

        expect(launcher.calls.single.arguments, isEmpty);
      },
    );

    test('--help prints usage and launches nothing', () async {
      final code = await run(['run', '--help']);

      expect(code, ExitCodes.success);
      expect(launcher.calls, isEmpty);
    });

    test('the global --verbose is passed on to the lane', () async {
      await run(['--verbose', 'run', 'beta']);

      expect(launcher.calls.single.arguments, ['beta', '--verbose']);
    });

    test('the global --verbose is not passed on twice', () async {
      await run(['--verbose', 'run', 'beta', '--verbose']);

      expect(launcher.calls.single.arguments, ['beta', '--verbose']);
    });
  });

  group('run without a lanes file', () {
    test('a missing dartlane/ folder points to init', () async {
      Directory(p.join(project.path, 'dartlane')).deleteSync(recursive: true);

      final code = await run(['run', 'beta']);

      expect(code, ExitCodes.usage);
      expect(
        logger.lines,
        contains('error: No dartlane/ folder found in this folder.'),
      );
      expect(logger.lines, contains(contains('Hint: Run `dartlane init`')));
      expect(launcher.calls, isEmpty);
    });

    test('a folder without lanes.dart is reported', () async {
      File(p.join(project.path, 'dartlane', 'lanes.dart')).deleteSync();

      final code = await run(['run', 'beta']);

      expect(code, ExitCodes.usage);
      expect(
        logger.lines,
        contains('error: dartlane/lanes.dart was not found.'),
      );
      expect(launcher.calls, isEmpty);
    });
  });
}
