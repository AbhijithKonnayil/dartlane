import 'dart:io';

import 'package:dartlane/src/update/pub_dev_client.dart';
import 'package:dartlane/src/update/update_cache.dart';
import 'package:dartlane/src/update/update_checker.dart';
import 'package:dartlane_core/testing.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

import 'support/pub_dev.dart';

void main() {
  late FakeHttp http;
  late Directory dir;
  late DateTime now;

  UpdateChecker checker({String current = '0.1.0', bool cached = true}) =>
      UpdateChecker(
        currentVersion: Version.parse(current),
        clientFactory: () => http,
        cache: cached ? UpdateCache(dir) : null,
        now: () => now,
      );

  setUp(() {
    http = FakeHttp();
    dir = Directory.systemTemp.createTempSync('dartlane_checker_');
    now = DateTime.utc(2026, 10, 7, 12);
  });

  tearDown(() => dir.deleteSync(recursive: true));

  group('newerVersion', () {
    test('is the published version when it is newer', () async {
      stubLatest(http, '0.2.0');

      expect(await checker().newerVersion(), Version(0, 2, 0));
    });

    test('is null when the installed version is the latest', () async {
      stubLatest(http, '0.1.0');

      expect(await checker().newerVersion(), isNull);
    });

    test(
      'is null when the installed version is newer than the published one',
      () async {
        stubLatest(http, '0.1.0');

        expect(await checker(current: '0.2.0').newerVersion(), isNull);
      },
    );

    test('a pre-release is older than its release', () async {
      stubLatest(http, '0.1.0');

      expect(
        await checker(current: '0.1.0-dev.1').newerVersion(),
        Version(0, 1, 0),
      );
      expect(await checker(current: '0.1.1-dev.1').newerVersion(), isNull);
    });

    test('is null when the package is not on pub.dev', () async {
      http.stub('GET $dartlaneUrl', status: 404);

      expect(await checker().newerVersion(), isNull);
    });

    test('never throws, even when pub.dev cannot be reached', () async {
      // No stub: the request fails.
      expect(await checker().newerVersion(), isNull);
    });
  });

  group('the cache', () {
    test('a recent result is used without asking pub.dev', () async {
      stubLatest(http, '0.2.0');
      final first = checker();
      await first.newerVersion();

      now = now.add(const Duration(hours: 23));
      final again = await checker().newerVersion();

      expect(again, Version(0, 2, 0));
      expect(http.requests, hasLength(1));
    });

    test('an old result is replaced by asking again', () async {
      stubLatest(http, '0.2.0');
      await checker().newerVersion();

      now = now.add(const Duration(days: 1, minutes: 1));
      stubLatest(http, '0.3.0');
      final again = await checker().newerVersion();

      expect(again, Version(0, 3, 0));
      expect(http.requests, hasLength(2));
    });

    test(
      'a failed check is remembered, so an offline computer does not retry',
      () async {
        await checker().newerVersion();
        await checker().newerVersion();

        expect(http.requests, hasLength(1));
      },
    );

    test('an unpublished package is remembered too', () async {
      http.stub('GET $dartlaneUrl', status: 404);
      await checker().newerVersion();
      await checker().newerVersion();

      expect(http.requests, hasLength(1));
    });

    test(
      'a cached version is compared with the installed one, not stored as news',
      () async {
        stubLatest(http, '0.2.0');
        await checker().newerVersion();

        // Installed since: the cached 0.2.0 is no longer newer.
        expect(await checker(current: '0.2.0').newerVersion(), isNull);
      },
    );

    test('without a cache every check asks pub.dev', () async {
      stubLatest(http, '0.2.0');

      await checker(cached: false).newerVersion();
      await checker(cached: false).newerVersion();

      expect(http.requests, hasLength(2));
    });
  });

  group('latestVersion', () {
    test('always asks pub.dev, whatever is cached', () async {
      stubLatest(http, '0.2.0');
      await checker().newerVersion();

      stubLatest(http, '0.3.0');

      expect(await checker().latestVersion(), Version(0, 3, 0));
      expect(http.requests, hasLength(2));
    });

    test('throws when pub.dev cannot be reached', () async {
      await expectLater(
        checker().latestVersion(),
        throwsA(isA<UpdateCheckException>()),
      );
    });
  });

  group('notice', () {
    test('says what is available and how to get it', () async {
      stubLatest(http, '0.2.0');

      expect(
        await checker().notice(),
        'Update available! 0.1.0 → 0.2.0\n'
        'Run `dartlane update` to install it.',
      );
    });

    test('is null when there is nothing newer', () async {
      stubLatest(http, '0.1.0');

      expect(await checker().notice(), isNull);
    });
  });
}
