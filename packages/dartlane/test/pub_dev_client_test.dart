import 'package:dartlane/src/update/pub_dev_client.dart';
import 'package:dartlane_core/testing.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

import 'support/pub_dev.dart';

void main() {
  late FakeHttp http;

  setUp(() => http = FakeHttp());

  Future<Version?> latest() => PubDevClient(http).latestVersion('dartlane');

  test('reads the latest version', () async {
    stubLatest(http, '0.2.0');

    expect(await latest(), Version(0, 2, 0));
    expect(http.requests.single.summary, 'GET $dartlaneUrl');
  });

  test('reads a pre-release version', () async {
    stubLatest(http, '1.0.0-dev.3');

    expect(await latest(), Version.parse('1.0.0-dev.3'));
  });

  test('a package pub.dev does not know gives null', () async {
    http.stub('GET $dartlaneUrl', status: 404);

    expect(await latest(), isNull);
  });

  test('another status is an error that says which', () async {
    http.stub('GET $dartlaneUrl', status: 503);

    await expectLater(
      latest(),
      throwsA(
        isA<UpdateCheckException>().having(
          (e) => e.message,
          'message',
          'pub.dev answered with status 503.',
        ),
      ),
    );
  });

  test('an answer that cannot be read is an error', () async {
    for (final body in [
      'not json',
      '{}',
      '{"latest":{}}',
      '{"latest":{"version":"x"}}',
    ]) {
      http.stub('GET $dartlaneUrl', body: body);

      await expectLater(
        latest(),
        throwsA(
          isA<UpdateCheckException>().having(
            (e) => e.message,
            'message',
            'pub.dev sent an answer that could not be read.',
          ),
        ),
        reason: body,
      );
    }
  });

  test('a request that cannot be made is an error', () async {
    // No stub: FakeHttp fails the request.
    await expectLater(
      latest(),
      throwsA(
        isA<UpdateCheckException>().having(
          (e) => e.message,
          'message',
          'Could not reach pub.dev.',
        ),
      ),
    );
  });

  test('a request that takes too long is an error', () async {
    final client = PubDevClient(
      HangingClient(),
      timeout: const Duration(milliseconds: 20),
    );

    await expectLater(
      client.latestVersion('dartlane'),
      throwsA(
        isA<UpdateCheckException>().having(
          (e) => e.message,
          'message',
          'Could not reach pub.dev (it took too long).',
        ),
      ),
    );
  });
}
