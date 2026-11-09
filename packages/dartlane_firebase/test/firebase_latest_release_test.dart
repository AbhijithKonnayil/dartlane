import 'dart:convert';

import 'package:dartlane_core/dartlane_core.dart';
import 'package:dartlane_core/testing.dart';
import 'package:dartlane_firebase/dartlane_firebase.dart';
import 'package:test/test.dart';

const _app = '1:123456:android:abc';
const _host = 'https://firebaseappdistribution.googleapis.com';
const _list = 'GET $_host/v1/projects/123456/apps/$_app/releases?pageSize=1';

void main() {
  late FakeLaneContext ctx;

  setUp(() => ctx = FakeLaneContext());

  FirebaseGetLatestRelease action({String app = _app}) =>
      FirebaseGetLatestRelease(app: app, client: ctx.http);

  test('returns the newest release', () async {
    ctx.http.stub(
      _list,
      body: jsonEncode({
        'releases': [
          {
            'name': 'projects/123456/apps/$_app/releases/r9',
            'displayVersion': '1.2.3',
            'buildVersion': '45',
            'createTime': '2026-11-01T10:00:00Z',
            'firebaseConsoleUri': 'https://console',
            'testingUri': 'https://t',
            'releaseNotes': {'text': 'Fixes'},
          },
        ],
      }),
    );
    final release = await ctx.run(action());
    expect(release, isNotNull);
    expect(release!.name, endsWith('/releases/r9'));
    expect(release.displayVersion, '1.2.3');
    expect(release.buildVersion, '45');
    expect(release.createTime, DateTime.utc(2026, 11, 1, 10));
    expect(release.testingUri, 'https://t');
    expect(release.releaseNotes, 'Fixes');
  });

  test('no releases yet is null, not an error', () async {
    ctx.http.stub(_list, body: '{}');
    expect(await ctx.run(action()), isNull);
    expect(ctx.logger.lines, contains(contains('no releases yet')));
  });

  test('a refused request fails the lane', () {
    ctx.http.stub(
      _list,
      status: 403,
      body: jsonEncode({
        'error': {'message': 'caller lacks permission'},
      }),
    );
    expect(
      ctx.run(action()),
      throwsA(
        isA<ActionFailed>().having(
          (e) => e.message,
          'message',
          allOf(contains('HTTP 403'), contains('caller lacks permission')),
        ),
      ),
    );
  });

  test('a bad app id is a UserError and nothing is sent', () {
    expect(ctx.run(action(app: 'nope')), throwsA(isA<UserError>()));
    expect(ctx.http.requests, isEmpty);
  });

  test('dry run sends nothing and returns a placeholder', () async {
    final dry = FakeLaneContext(dryRun: true);
    final release = await dry.run(
      FirebaseGetLatestRelease(app: _app, client: dry.http),
    );
    expect(dry.http.requests, isEmpty);
    expect(release, isNotNull);
    expect(release!.buildVersion, '0');
    expect(dry.dryRunSteps.single, contains(_app));
  });
}
