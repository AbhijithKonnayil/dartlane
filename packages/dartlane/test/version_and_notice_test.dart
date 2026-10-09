import 'dart:io';

import 'package:dartlane/dartlane.dart';
import 'package:dartlane/src/version.g.dart';
import 'package:dartlane_core/dartlane_core.dart';
import 'package:dartlane_core/testing.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import 'support/fake_lanes_launcher.dart';
import 'support/pub_dev.dart';

const _notice = 'Update available! $dartlaneVersion → 99.0.0';

/// The notice as it is logged: one message, after a blank line.
const _noticeMessage = '\n$_notice\nRun `dartlane update` to install it.';

/// Matches a log that contains the update notice somewhere.
final Matcher _hasNotice = contains(contains('Update available!'));

void main() {
  late Directory project;
  late Directory cache;
  late FakeHttp http;
  late FakeLanesLauncher launcher;

  Future<int> run(
    List<String> args, {
    FakeLaneLogger? logger,
    Map<String, String> environment = const {},
  }) => DartlaneCommandRunner(
    logger: logger ?? FakeLaneLogger(interactive: true),
    launcher: launcher,
    workingDirectory: project,
    httpClientFactory: () => http,
    cacheDirectory: cache,
    environment: environment,
  ).run(args);

  setUp(() {
    project = Directory.systemTemp.createTempSync('dartlane_notice_');
    File(p.join(project.path, 'dartlane', 'lanes.dart'))
      ..createSync(recursive: true)
      ..writeAsStringSync('// lanes');
    cache = Directory.systemTemp.createTempSync('dartlane_notice_cache_');
    http = FakeHttp();
    launcher = FakeLanesLauncher();
  });

  tearDown(() {
    project.deleteSync(recursive: true);
    cache.deleteSync(recursive: true);
  });

  group('--version', () {
    test('prints the version and exits 0', () async {
      final logger = FakeLaneLogger();

      final code = await run(['--version'], logger: logger);

      expect(code, ExitCodes.success);
      expect(logger.lines, [dartlaneVersion]);
    });

    test('is the version in pubspec.yaml', () async {
      final pubspec =
          loadYaml(File('pubspec.yaml').readAsStringSync()) as YamlMap;
      final logger = FakeLaneLogger();

      await run(['--version'], logger: logger);

      expect(logger.lines.single, pubspec['version']);
    });

    test('needs no command and does not ask pub.dev', () async {
      await run(['--version']);

      expect(http.requests, isEmpty);
      expect(launcher.calls, isEmpty);
    });
  });

  group('the generated version file', () {
    test('matches pubspec.yaml', () {
      final pubspec =
          loadYaml(File('pubspec.yaml').readAsStringSync()) as YamlMap;

      expect(dartlaneVersion, pubspec['version']);
      expect(
        (pubspec['environment'] as YamlMap)['sdk'],
        '^$minimumDartVersion',
        reason: 'Run `dart run melos run generate`.',
      );
    });
  });

  group('the update notice', () {
    test('appears after a command when a newer version exists', () async {
      stubLatest(http, '99.0.0');
      final logger = FakeLaneLogger(interactive: true);

      final code = await run(['list'], logger: logger);

      expect(code, ExitCodes.success);
      expect(logger.lines, [_noticeMessage]);
    });

    test('does not change the exit code of the command', () async {
      stubLatest(http, '99.0.0');
      launcher.exitCode = 7;

      expect(await run(['list']), 7);
    });

    test('is left out when the installed version is the latest', () async {
      stubLatest(http, dartlaneVersion);
      final logger = FakeLaneLogger(interactive: true);

      await run(['list'], logger: logger);

      expect(logger.lines, isEmpty);
    });

    test(
      'is not shown, and nothing is asked, when output is not a terminal',
      () async {
        stubLatest(http, '99.0.0');
        final logger = FakeLaneLogger(); // not interactive, like CI or a pipe

        await run(['list'], logger: logger);

        expect(logger.lines, isEmpty);
        expect(http.requests, isEmpty);
      },
    );

    test('can be turned off with $noUpdateCheckVariable', () async {
      stubLatest(http, '99.0.0');
      final logger = FakeLaneLogger(interactive: true);

      await run(
        ['list'],
        logger: logger,
        environment: {noUpdateCheckVariable: '1'},
      );

      expect(logger.lines, isEmpty);
      expect(http.requests, isEmpty);
    });

    test('is not shown after update, which does its own check', () async {
      stubLatest(http, '99.0.0');
      final logger = FakeLaneLogger(interactive: true);

      await DartlaneCommandRunner(
        logger: logger,
        shell: FakeLaneShell(),
        httpClientFactory: () => http,
        cacheDirectory: cache,
        environment: const {},
      ).run(['update']);

      expect(logger.lines, isNot(_hasNotice));
      expect(http.requests, hasLength(1));
    });

    test('is not shown for help or without a command', () async {
      stubLatest(http, '99.0.0');
      final logger = FakeLaneLogger(interactive: true);

      await run(['help'], logger: logger);
      await run([], logger: logger);
      await run(['--help'], logger: logger);

      expect(logger.lines, isEmpty);
      expect(http.requests, isEmpty);
    });

    test('asks pub.dev once a day, however many commands run', () async {
      stubLatest(http, '99.0.0');

      await run(['list']);
      await run(['list']);
      final logger = FakeLaneLogger(interactive: true);
      await run(['list'], logger: logger);

      expect(http.requests, hasLength(1));
      expect(logger.lines, _hasNotice);
    });

    test('a failed check is silent and does not break the command', () async {
      // No stub: pub.dev cannot be reached.
      final logger = FakeLaneLogger(interactive: true);

      final code = await run(['list'], logger: logger);

      expect(code, ExitCodes.success);
      expect(logger.lines, isEmpty);
    });

    test('is shown even when the command fails with a user error', () async {
      stubLatest(http, '99.0.0');
      Directory(p.join(project.path, 'dartlane')).deleteSync(recursive: true);
      final logger = FakeLaneLogger(interactive: true);

      final code = await run(['list'], logger: logger);

      expect(code, ExitCodes.usage);
      expect(logger.lines, isNot(_hasNotice));
    });
  });
}
