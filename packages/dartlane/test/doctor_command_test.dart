import 'dart:io';

import 'package:dartlane/dartlane.dart';
import 'package:dartlane/src/doctor/dart_sdk_check.dart';
import 'package:dartlane_core/dartlane_core.dart';
import 'package:dartlane_core/testing.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/fake_lanes_launcher.dart';

const _oldDart =
    'error: ✗ Dart SDK: 3.9.0 is older than the 3.10.0 that Dartlane needs.';
const _notInstalled =
    'error: ✗ Dependencies: The packages in dartlane/ have not been installed.';

void main() {
  late Directory project;
  late FakeLanesLauncher launcher;
  late FakeLaneLogger logger;

  Future<int> run(
    List<String> args, {
    String dartVersion = '3.12.2 (stable) (Tue Jun 9 2026)',
  }) => DartlaneCommandRunner(
    logger: logger,
    launcher: launcher,
    workingDirectory: project,
    dartSdkCheck: DartSdkCheck(version: dartVersion),
  ).run(args);

  void write(String relative, [String content = '']) =>
      File(p.join(project.path, relative))
        ..createSync(recursive: true)
        ..writeAsStringSync(content);

  setUp(() {
    project = Directory.systemTemp.createTempSync('dartlane_doctor_cmd_');
    write('pubspec.yaml', 'name: my_app\n');
    write('dartlane/lanes.dart');
    write('dartlane/.dart_tool/package_config.json', '{}');
    launcher = FakeLanesLauncher();
    logger = FakeLaneLogger();
  });

  tearDown(() => project.deleteSync(recursive: true));

  group('when the basic checks pass', () {
    test('prints them and hands over to the lanes program', () async {
      await run(['doctor']);

      expect(logger.lines, [
        '✓ Dart SDK: 3.12.2',
        '✓ Project: my_app',
        '✓ Lanes: dartlane/lanes.dart found',
        '✓ Dependencies: installed',
      ]);
      final call = launcher.calls.single;
      expect(call.arguments, ['--doctor']);
      expect(call.projectRoot.path, project.path);
    });

    test('exits with the code of the lanes program', () async {
      for (final code in [0, 1]) {
        launcher.exitCode = code;

        expect(await run(['doctor']), code);
      }
    });
  });

  group('when a basic check fails', () {
    test('an old Dart fails, skips the lanes program and exits 1', () async {
      final code = await run(['doctor'], dartVersion: '3.9.0');

      expect(code, ExitCodes.failure);
      expect(
        logger.lines,
        containsAllInOrder([
          _oldDart,
          '    Fix: Update Dart (3.10.0 or newer) or run `flutter upgrade`.',
          '✓ Project: my_app',
          'error: 1 required check failed.',
        ]),
      );
      expect(launcher.calls, isEmpty);
    });

    test('a project without lanes shows every problem and a fix', () async {
      Directory(p.join(project.path, 'dartlane')).deleteSync(recursive: true);

      final code = await run(['doctor']);

      expect(code, ExitCodes.failure);
      expect(
        logger.lines,
        containsAllInOrder([
          'error: ✗ Lanes: No dartlane/ folder found in this folder.',
          '    Fix: Run `dartlane init` to create it.',
          _notInstalled,
          '    Fix: Run `dart pub get` in the dartlane/ folder.',
          'error: 2 required checks failed.',
        ]),
      );
      expect(launcher.calls, isEmpty);
    });

    test('missing dependencies alone point to pub get', () async {
      File(
        p.join(project.path, 'dartlane', '.dart_tool', 'package_config.json'),
      ).deleteSync();

      final code = await run(['doctor']);

      expect(code, ExitCodes.failure);
      expect(
        logger.lines,
        contains('    Fix: Run `dart pub get` in the dartlane/ folder.'),
      );
      expect(logger.lines.last, 'error: 1 required check failed.');
      expect(launcher.calls, isEmpty);
    });

    test('a folder that is not a project fails with the init hint', () async {
      File(p.join(project.path, 'pubspec.yaml')).deleteSync();

      final code = await run(['doctor']);

      expect(code, ExitCodes.failure);
      expect(
        logger.lines,
        contains('error: ✗ Project: No pubspec.yaml found in this folder.'),
      );
    });
  });

  test('doctor takes no arguments', () async {
    final code = await run(['doctor', 'extra']);

    expect(code, ExitCodes.usage);
    expect(launcher.calls, isEmpty);
  });
}
