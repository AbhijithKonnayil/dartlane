import 'dart:convert';
import 'dart:io';

import 'package:dartlane_core/dartlane_core.dart';
import 'package:dartlane_core/testing.dart';
import 'package:dartlane_firebase/dartlane_firebase.dart';
import 'package:http/http.dart';
import 'package:test/test.dart';

const _app = '1:123456:android:abc';
const _name = 'projects/123456/apps/$_app';
const _host = 'https://firebaseappdistribution.googleapis.com';
const _upload = 'POST $_host/upload/v1/$_name/releases:upload';
const _op = '$_name/releases/-/operations/op1';
const _release = '$_name/releases/r1';

String _done({String result = 'RELEASE_CREATED'}) => jsonEncode({
  'done': true,
  'response': {
    'result': result,
    'release': {
      'name': _release,
      'displayVersion': '1.2.3',
      'buildVersion': '45',
      'testingUri': 'https://t',
    },
  },
});

void main() {
  late Directory dir;
  late String apk;
  late FakeLaneContext ctx;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('fb');
    apk = '${dir.path}/app-release.apk';
    File(apk).writeAsStringSync('binary');
    ctx = FakeLaneContext();
    ctx.http
      ..stub(_upload, body: jsonEncode({'name': _op}))
      ..stub('GET $_host/v1/$_op', body: _done())
      ..stub(
        'PATCH $_host/v1/$_release?updateMask=release_notes.text',
        body: '{}',
      )
      ..stub('POST $_host/v1/$_release:distribute', body: '{}');
  });
  tearDown(() => dir.deleteSync(recursive: true));

  FirebaseDistribute action({
    List<String> groups = const [],
    List<String> testers = const [],
    String? notes,
    Duration timeout = const Duration(minutes: 5),
  }) => FirebaseDistribute(
    apk,
    app: _app,
    groups: groups,
    testers: testers,
    releaseNotes: notes,
    uploadTimeout: timeout,
    pollInterval: Duration.zero,
    client: ctx.http,
  );

  test('uploads, sets notes and distributes', () async {
    final result = await ctx.run(
      action(groups: ['qa'], testers: ['a@b.c'], notes: 'Fixes'),
    );

    expect(result.releaseName, _release);
    expect(result.outcome, ReleaseOutcome.created);
    expect(result.distributed, isTrue);
    expect(result.displayVersion, '1.2.3');
    expect(result.buildVersion, '45');
    expect(result.testingUri, 'https://t');

    final requests = ctx.http.requests;
    expect(requests.first.body, 'binary');
    expect(requests.first.headers['X-Goog-Upload-Protocol'], 'raw');
    expect(
      requests.first.headers['X-Goog-Upload-File-Name'],
      'app-release.apk',
    );
    expect(jsonDecode(requests[2].body), {
      'releaseNotes': {'text': 'Fixes'},
    });
    expect(jsonDecode(requests[3].body), {
      'testerEmails': ['a@b.c'],
      'groupAliases': ['qa'],
    });
  });

  test('no testers or groups: uploaded, warned, not an error', () async {
    final result = await ctx.run(action());

    expect(result.distributed, isFalse);
    expect(ctx.http.requests.map((r) => r.method), ['POST', 'GET']);
    expect(
      ctx.logger.lines,
      contains(startsWith('warning: Uploaded, but no testers or groups')),
    );
  });

  test('reports an unmodified release', () async {
    ctx.http.stub(
      'GET $_host/v1/$_op',
      body: _done(result: 'RELEASE_UNMODIFIED'),
    );
    final result = await ctx.run(action());
    expect(result.outcome, ReleaseOutcome.unmodified);
  });

  test('polls until the operation is done', () async {
    var calls = 0;
    ctx.http.stub('GET $_host/v1/$_op', body: '{"done":false}');
    // Swap the answer after two checks by wrapping via a custom client.
    final result = await ctx.run(
      FirebaseDistribute(
        apk,
        app: _app,
        pollInterval: Duration.zero,
        client: _Flipping(ctx.http, () => ++calls >= 3, _done()),
      ),
    );
    expect(result.releaseName, _release);
    expect(calls, 3);
  });

  test('a rejected upload fails the lane', () {
    ctx.http.stub(
      _upload,
      status: 403,
      body: '{"error":{"message":"denied"}}',
    );
    expect(
      ctx.run(action()),
      throwsA(
        isA<ActionFailed>().having(
          (e) => e.message,
          'message',
          contains('denied'),
        ),
      ),
    );
  });

  test('an operation that ends in an error fails the lane', () {
    ctx.http.stub(
      'GET $_host/v1/$_op',
      body: '{"done":true,"error":{"message":"bad apk"}}',
    );
    expect(
      ctx.run(action()),
      throwsA(
        isA<ActionFailed>().having(
          (e) => e.message,
          'message',
          contains('bad apk'),
        ),
      ),
    );
  });

  test('a failing distribute fails the lane', () {
    ctx.http.stub('POST $_host/v1/$_release:distribute', status: 500);
    expect(ctx.run(action(groups: ['qa'])), throwsA(isA<ActionFailed>()));
  });

  test('processing that never finishes honours the timeout', () {
    ctx.http.stub('GET $_host/v1/$_op', body: '{"done":false}');
    expect(
      ctx.run(action(timeout: const Duration(milliseconds: 20))),
      throwsA(isA<ActionFailed>()),
    );
  });

  group('from files', () {
    FirebaseDistribute fromFiles({
      String? notes,
      String? notesFile,
      String? testersFile,
      String? groupsFile,
      List<String> testers = const [],
    }) => FirebaseDistribute(
      apk,
      app: _app,
      releaseNotes: notes,
      releaseNotesFile: notesFile,
      testersFile: testersFile,
      groupsFile: groupsFile,
      testers: testers,
      pollInterval: Duration.zero,
      client: ctx.http,
    );

    String write(String name, String text) {
      final path = '${dir.path}/$name';
      File(path).writeAsStringSync(text);
      return path;
    }

    test('reads notes, testers and groups from files', () async {
      final result = await ctx.run(
        fromFiles(
          notesFile: write('notes.md', '\n# 1.2.3\n- fix\n\n'),
          testersFile: write(
            'testers.txt',
            '# qa team\na@b.c, d@e.f\n\ng@h.i\r\n',
          ),
          groupsFile: write('groups.txt', 'qa\ndevs\n'),
        ),
      );

      expect(result.distributed, isTrue);
      final requests = ctx.http.requests;
      expect(jsonDecode(requests[2].body), {
        'releaseNotes': {'text': '# 1.2.3\n- fix'},
      });
      expect(jsonDecode(requests[3].body), {
        'testerEmails': ['a@b.c', 'd@e.f', 'g@h.i'],
        'groupAliases': ['qa', 'devs'],
      });
    });

    test('inline testers and a file are merged without duplicates', () async {
      await ctx.run(
        fromFiles(
          testers: ['a@b.c', 'x@y.z'],
          testersFile: write('t.txt', 'a@b.c\nn@m.o'),
        ),
      );
      expect(jsonDecode(ctx.http.requests.last.body), {
        'testerEmails': ['a@b.c', 'x@y.z', 'n@m.o'],
      });
    });

    test('inline notes still work', () async {
      await ctx.run(fromFiles(notes: 'hi', testers: ['a@b.c']));
      expect(jsonDecode(ctx.http.requests[2].body), {
        'releaseNotes': {'text': 'hi'},
      });
    });

    test('bad inputs fail before anything is sent', () async {
      for (final action in [
        fromFiles(notes: 'a', notesFile: write('n.txt', 'b')),
        fromFiles(notesFile: '${dir.path}/none.md'),
        fromFiles(testersFile: '${dir.path}/none.txt'),
        fromFiles(testersFile: write('bad.txt', 'not-an-email')),
      ]) {
        await expectLater(ctx.run(action), throwsA(isA<UserError>()));
      }
      expect(ctx.http.requests, isEmpty);
    });

    test('dry run does not need the files yet', () async {
      final dry = FakeLaneContext(dryRun: true);
      final result = await dry.run(
        fromFiles(
          notesFile: '${dir.path}/later.md',
          testersFile: '${dir.path}/later.txt',
        ),
      );
      expect(result.distributed, isTrue);
    });
  });

  test('missing file and bad app id are UserErrors', () {
    expect(
      ctx.run(FirebaseDistribute('${dir.path}/none.apk', app: _app)),
      throwsA(isA<UserError>()),
    );
    expect(
      ctx.run(FirebaseDistribute(apk, app: 'nope')),
      throwsA(isA<UserError>()),
    );
  });

  test('dry run uploads nothing and returns a placeholder', () async {
    final dry = FakeLaneContext(dryRun: true);
    final result = await dry.run(
      FirebaseDistribute(
        '${dir.path}/not-built-yet.apk',
        app: _app,
        groups: ['qa'],
      ),
    );
    expect(dry.http.requests, isEmpty);
    expect(result.distributed, isTrue);
    expect(dry.dryRunSteps.single, contains('Firebase app $_app'));
  });
}

/// Answers GETs with [done] once [ready] returns true, else not done.
class _Flipping extends FakeHttp {
  _Flipping(this._inner, this.ready, this.done);

  final FakeHttp _inner;
  final bool Function() ready;
  final String done;

  @override
  Future<StreamedResponse> send(BaseRequest request) {
    if (request.method == 'GET') {
      _inner.stub(
        'GET ${request.url}',
        body: ready() ? done : '{"done":false}',
      );
    }
    return _inner.send(request);
  }
}
