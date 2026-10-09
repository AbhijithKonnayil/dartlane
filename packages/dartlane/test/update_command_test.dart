import 'dart:io';

import 'package:dartlane/dartlane.dart';
import 'package:dartlane/src/version.g.dart';
import 'package:dartlane_core/dartlane_core.dart';
import 'package:dartlane_core/testing.dart';
import 'package:test/test.dart';

import 'support/pub_dev.dart';

const _activateFailed =
    'error: `dart pub global activate dartlane 99.0.0` exited with code 65.';
const _notPublished =
    'error: dartlane is not on pub.dev, so there is nothing to update to.';

void main() {
  late Directory cache;
  late FakeHttp http;
  late FakeLaneShell shell;
  late FakeLaneLogger logger;

  Future<int> run(List<String> args) => DartlaneCommandRunner(
    logger: logger,
    shell: shell,
    httpClientFactory: () => http,
    cacheDirectory: cache,
    environment: const {},
  ).run(args);

  setUp(() {
    cache = Directory.systemTemp.createTempSync('dartlane_update_');
    http = FakeHttp();
    shell = FakeLaneShell();
    logger = FakeLaneLogger();
  });

  tearDown(() => cache.deleteSync(recursive: true));

  group('update', () {
    test(
      'says so and does nothing when already on the latest version',
      () async {
        stubLatest(http, dartlaneVersion);

        final code = await run(['update']);

        expect(code, ExitCodes.success);
        expect(logger.lines, [
          'Checking for updates...',
          'dartlane $dartlaneVersion is already the latest version.',
        ]);
        expect(shell.calls, isEmpty);
      },
    );

    test('installs a newer version with pub global activate', () async {
      stubLatest(http, '99.0.0');
      shell.stub(
        'dart pub global activate dartlane 99.0.0',
        stdout: 'Activated dartlane 99.0.0.\n',
      );

      final code = await run(['update']);

      expect(code, ExitCodes.success);
      expect(shell.commands, ['dart pub global activate dartlane 99.0.0']);
      expect(logger.lines, [
        'Checking for updates...',
        'Updating dartlane $dartlaneVersion → 99.0.0',
        'Activated dartlane 99.0.0.',
        'Updated dartlane to 99.0.0.',
      ]);
    });

    test('does nothing when the published version is older', () async {
      stubLatest(http, '0.0.0');

      expect(await run(['update']), ExitCodes.success);
      expect(shell.calls, isEmpty);
    });

    test('fails and shows why when the install fails', () async {
      stubLatest(http, '99.0.0');
      shell.stub(
        'dart pub global activate dartlane 99.0.0',
        exitCode: 65,
        stderr: 'version solving failed',
      );

      final code = await run(['update']);

      expect(code, ExitCodes.failure);
      expect(
        logger.lines,
        containsAllInOrder([
          'version solving failed',
          _activateFailed,
        ]),
      );
    });

    test('fails when the package is not on pub.dev', () async {
      http.stub('GET $dartlaneUrl', status: 404);

      final code = await run(['update']);

      expect(code, ExitCodes.failure);
      expect(
        logger.lines,
        contains(_notPublished),
      );
      expect(shell.calls, isEmpty);
    });

    test('fails when pub.dev cannot be reached', () async {
      final code = await run(['update']);

      expect(code, ExitCodes.failure);
      expect(logger.lines, contains('error: Could not reach pub.dev.'));
    });

    test('always asks pub.dev, even when a recent check is cached', () async {
      stubLatest(http, '0.0.0');
      await run(['list']); // fills the cache (not interactive: no check)
      stubLatest(http, '99.0.0');

      await run(['update']);

      expect(http.requests.map((r) => r.summary), ['GET $dartlaneUrl']);
      expect(shell.commands, ['dart pub global activate dartlane 99.0.0']);
    });

    test('takes no arguments', () async {
      final code = await run(['update', 'extra']);

      expect(code, ExitCodes.usage);
      expect(http.requests, isEmpty);
    });
  });
}
