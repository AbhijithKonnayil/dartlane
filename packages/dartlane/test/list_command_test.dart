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
    project = Directory.systemTemp.createTempSync('dartlane_list_test_');
    File(p.join(project.path, 'dartlane', 'lanes.dart'))
      ..createSync(recursive: true)
      ..writeAsStringSync('// lanes');
    launcher = FakeLanesLauncher();
    logger = FakeLaneLogger();
  });

  tearDown(() => project.deleteSync(recursive: true));

  group('list', () {
    test('asks the lanes program to list its lanes', () async {
      await run(['list']);

      final call = launcher.calls.single;
      expect(call.arguments, ['--list']);
      expect(call.projectRoot.path, project.path);
    });

    test('exits with the code of the program', () async {
      for (final code in [0, 1, 254]) {
        launcher.exitCode = code;

        expect(await run(['list']), code);
      }
    });

    test('takes no arguments', () async {
      final code = await run(['list', 'extra']);

      expect(code, ExitCodes.usage);
      expect(launcher.calls, isEmpty);
    });

    test('a missing dartlane/ folder points to init', () async {
      Directory(p.join(project.path, 'dartlane')).deleteSync(recursive: true);

      final code = await run(['list']);

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

      final code = await run(['list']);

      expect(code, ExitCodes.usage);
      expect(
        logger.lines,
        contains('error: dartlane/lanes.dart was not found.'),
      );
    });
  });
}
