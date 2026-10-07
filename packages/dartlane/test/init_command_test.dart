import 'dart:io';

import 'package:dartlane/dartlane.dart';
import 'package:dartlane/src/version.g.dart';
import 'package:dartlane_core/dartlane_core.dart';
import 'package:dartlane_core/testing.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

const _appPubspec = '''
name: my_app
description: A Flutter app.
dependencies:
  flutter:
    sdk: flutter
''';

void main() {
  late Directory project;
  late FakeLaneShell shell;
  late FakeLaneLogger logger;

  String read(String relative) =>
      File(p.join(project.path, relative)).readAsStringSync();
  bool exists(String relative) =>
      File(p.join(project.path, relative)).existsSync();

  Future<int> run(List<String> args, {FakeLaneLogger? with_}) =>
      DartlaneCommandRunner(
        logger: with_ ?? logger,
        shell: shell,
        workingDirectory: project,
      ).run(args);

  setUp(() {
    project = Directory.systemTemp.createTempSync('dartlane_init_test_');
    File(p.join(project.path, 'pubspec.yaml')).writeAsStringSync(_appPubspec);
    shell = FakeLaneShell();
    logger = FakeLaneLogger();
  });

  tearDown(() => project.deleteSync(recursive: true));

  group('init', () {
    test('creates the nested package files', () async {
      final code = await run(['init']);

      expect(code, ExitCodes.success);
      expect(exists('dartlane/pubspec.yaml'), isTrue);
      expect(exists('dartlane/lanes.dart'), isTrue);
      expect(exists('dartlane/config.dart'), isTrue);
    });

    test('names the package after the app and pins the versions', () async {
      await run(['init']);

      final pubspec = read('dartlane/pubspec.yaml');
      expect(pubspec, contains('name: my_app_dartlane'));
      expect(pubspec, contains('Dartlane lanes for my_app.'));
      expect(pubspec, contains('dartlane_core: ^$dartlaneVersion'));
      expect(pubspec, contains('dartlane_flutter: ^$dartlaneVersion'));
      expect(pubspec, isNot(contains('{{')));
    });

    test('does not hardcode a path to the packages', () async {
      await run(['init']);

      expect(read('dartlane/pubspec.yaml'), isNot(contains('path:')));
      expect(exists('dartlane/pubspec_overrides.yaml'), isFalse);
    });

    test('does not touch the app pubspec.yaml', () async {
      await run(['init']);

      expect(read('pubspec.yaml'), _appPubspec);
    });

    test('generates a lane that builds with FlutterBuild', () async {
      await run(['init']);

      final lanes = read('dartlane/lanes.dart');
      expect(lanes, contains("'build': Lane("));
      expect(lanes, contains('FlutterBuild.apk('));
      expect(lanes, contains('=> dartlane('));
      expect(read('dartlane/config.dart'), contains('class Config'));
    });

    test('runs dart pub get inside the new package', () async {
      await run(['init']);

      final call = shell.calls.single;
      expect(call.commandLine, 'dart pub get');
      expect(p.basename(call.workingDirectory!), 'dartlane');
    });

    test('a failing pub get is reported with its output', () async {
      shell.stub('dart pub get', exitCode: 1, stderr: 'version solving failed');

      final code = await run(['init']);

      expect(code, ExitCodes.failure);
      expect(
        logger.lines,
        contains(contains('version solving failed')),
      );
    });

    test('tells the user how to run the lane', () async {
      await run(['init']);

      expect(
        logger.lines,
        contains(
          'Done. Run your first lane with: dartlane run build',
        ),
      );
    });

    test('needs a pubspec.yaml', () async {
      File(p.join(project.path, 'pubspec.yaml')).deleteSync();

      final code = await run(['init']);

      expect(code, ExitCodes.usage);
      expect(
        logger.lines,
        contains('error: No pubspec.yaml found in this folder.'),
      );
      expect(
        logger.lines,
        contains(contains('Hint: Run `dartlane init` from')),
      );
      expect(Directory(p.join(project.path, 'dartlane')).existsSync(), isFalse);
    });
  });

  group('.gitignore', () {
    test('is created when missing', () async {
      await run(['init']);

      expect(read('.gitignore'), '\n# Dartlane\n.dartlane/\n.env\n');
    });

    test('keeps existing lines and adds only what is missing', () async {
      File(
        p.join(project.path, '.gitignore'),
      ).writeAsStringSync('build/\n.env\n');

      await run(['init']);

      expect(read('.gitignore'), 'build/\n.env\n\n# Dartlane\n.dartlane/\n');
    });

    test('adds a newline when the file does not end with one', () async {
      File(p.join(project.path, '.gitignore')).writeAsStringSync('build/');

      await run(['init']);

      expect(read('.gitignore'), 'build/\n\n# Dartlane\n.dartlane/\n.env\n');
    });

    test('is not changed when it already has both entries', () async {
      File(
        p.join(project.path, '.gitignore'),
      ).writeAsStringSync('.dartlane/\n.env\n');

      await run(['init']);

      expect(read('.gitignore'), '.dartlane/\n.env\n');
      expect(logger.lines, isNot(contains('Updated .gitignore')));
    });

    test('is not duplicated by a second run', () async {
      await run(['init']);
      final first = read('.gitignore');

      await run(['init', '--force']);

      expect(read('.gitignore'), first);
    });
  });

  group('an existing dartlane/ folder', () {
    setUp(() {
      Directory(p.join(project.path, 'dartlane')).createSync();
      File(
        p.join(project.path, 'dartlane/lanes.dart'),
      ).writeAsStringSync('// mine');
      File(
        p.join(project.path, 'dartlane/my_action.dart'),
      ).writeAsStringSync('// keep me');
    });

    test('is not overwritten when it cannot ask', () async {
      final code = await run(['init']);

      expect(code, ExitCodes.usage);
      expect(read('dartlane/lanes.dart'), '// mine');
      expect(
        logger.lines,
        contains('error: A dartlane/ folder already exists.'),
      );
      expect(logger.lines, contains(contains('--force')));
      expect(shell.calls, isEmpty);
    });

    test('is overwritten with --force, keeping other files', () async {
      final code = await run(['init', '--force']);

      expect(code, ExitCodes.success);
      expect(read('dartlane/lanes.dart'), contains('FlutterBuild.apk('));
      expect(read('dartlane/my_action.dart'), '// keep me');
    });

    test('asks first and overwrites when the user agrees', () async {
      final asking = FakeLaneLogger(interactive: true);

      final code = await run(['init'], with_: asking);

      expect(code, ExitCodes.success);
      expect(
        asking.lines,
        contains(
          'confirm: A dartlane/ folder already exists. '
          'Overwrite its generated files?',
        ),
      );
      expect(read('dartlane/lanes.dart'), contains('FlutterBuild.apk('));
    });

    test('changes nothing when the user declines', () async {
      final asking = FakeLaneLogger(interactive: true, confirmAnswer: false);

      final code = await run(['init'], with_: asking);

      expect(code, ExitCodes.success);
      expect(asking.lines, contains('Nothing changed.'));
      expect(read('dartlane/lanes.dart'), '// mine');
      expect(shell.calls, isEmpty);
    });
  });

  group('--local-repo', () {
    late Directory repo;

    setUp(() {
      repo = Directory.systemTemp.createTempSync('dartlane_repo_test_');
      Directory(
        p.join(repo.path, 'packages', 'dartlane_core'),
      ).createSync(recursive: true);
    });

    tearDown(() => repo.deleteSync(recursive: true));

    test('writes path overrides without changing the pubspec', () async {
      await run(['init', '--local-repo', repo.path]);

      final overrides = read('dartlane/pubspec_overrides.yaml');
      expect(
        overrides,
        contains('path: ${p.absolute(repo.path)}/packages/dartlane_core'),
      );
      expect(overrides, contains('packages/dartlane_flutter'));
      expect(read('dartlane/pubspec.yaml'), isNot(contains('path:')));
    });

    test('rejects a folder that is not the repository', () async {
      final code = await run(['init', '--local-repo', project.path]);

      expect(code, ExitCodes.usage);
      expect(logger.lines, contains(contains('is not a Dartlane repository')));
      expect(exists('dartlane/pubspec.yaml'), isFalse);
    });
  });

  group('the command line', () {
    test(
      'an unknown command prints usage and exits with the usage code',
      () async {
        final code = await run(['nope']);

        expect(code, ExitCodes.usage);
        expect(
          logger.lines.first,
          startsWith('error: Could not find a command named "nope"'),
        );
      },
    );
  });
}
