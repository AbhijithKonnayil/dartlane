import 'dart:convert';
import 'dart:io';

import 'package:dartlane_core/dartlane_core.dart';
import 'package:dartlane_core/testing.dart';
import 'package:dartlane_firebase/dartlane_firebase.dart';
import 'package:test/test.dart';

const _host = 'https://firebaseappdistribution.googleapis.com';
const _add = 'POST $_host/v1/projects/123456/testers:batchAdd';
const _remove = 'POST $_host/v1/projects/123456/testers:batchRemove';

void main() {
  late Directory dir;
  late FakeLaneContext ctx;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('testers');
    ctx = FakeLaneContext();
  });
  tearDown(() => dir.deleteSync(recursive: true));

  FirebaseAddTesters add({
    String project = '123456',
    List<String> emails = const [],
    String? file,
  }) => FirebaseAddTesters(
    project: project,
    emails: emails,
    emailsFile: file,
    client: ctx.http,
  );

  FirebaseRemoveTesters remove({
    List<String> emails = const [],
    String? file,
  }) => FirebaseRemoveTesters(
    project: '123456',
    emails: emails,
    emailsFile: file,
    client: ctx.http,
  );

  String writeFile(String content) {
    final path = '${dir.path}/testers.txt';
    File(path).writeAsStringSync(content);
    return path;
  }

  Map<String, dynamic> sentBody(String key) {
    final request = ctx.http.requests.firstWhere((r) => r.summary == key);
    return jsonDecode(request.body) as Map<String, dynamic>;
  }

  group('FirebaseAddTesters', () {
    test('adds inline and file emails, without duplicates', () async {
      ctx.http.stub(
        _add,
        body: jsonEncode({
          'testers': [
            {'name': 'projects/123456/testers/a@b.c'},
            {'name': 'projects/123456/testers/d@e.f'},
          ],
        }),
      );
      final added = await ctx.run(
        add(
          emails: ['a@b.c'],
          file: writeFile('# qa\nd@e.f, a@b.c\n\n'),
        ),
      );
      expect(added, ['a@b.c', 'd@e.f']);
      expect(ctx.http.requests, hasLength(1));
    });

    test('a bad inline email fails before anything is sent', () {
      expect(
        ctx.run(add(emails: ['nope'])),
        throwsA(isA<UserError>()),
      );
      expect(ctx.http.requests, isEmpty);
    });

    test('a bad email in the file names the file', () {
      final path = writeFile('ok@b.c\nbroken\n');
      expect(
        ctx.run(add(file: path)),
        throwsA(
          isA<UserError>().having((e) => e.message, 'message', contains(path)),
        ),
      );
      expect(ctx.http.requests, isEmpty);
    });

    test('no emails at all is a UserError', () {
      expect(ctx.run(add()), throwsA(isA<UserError>()));
      expect(ctx.http.requests, isEmpty);
    });

    test('a missing file and a bad project are UserErrors', () {
      expect(
        ctx.run(add(file: '${dir.path}/missing.txt')),
        throwsA(isA<UserError>()),
      );
      expect(
        ctx.run(add(project: 'abc', emails: ['a@b.c'])),
        throwsA(isA<UserError>()),
      );
      expect(ctx.http.requests, isEmpty);
    });

    test('a refused request fails the lane', () {
      ctx.http.stub(
        _add,
        status: 403,
        body: jsonEncode({
          'error': {'message': 'caller lacks permission'},
        }),
      );
      expect(
        ctx.run(add(emails: ['a@b.c'])),
        throwsA(
          isA<ActionFailed>().having(
            (e) => e.message,
            'message',
            allOf(contains('add the testers'), contains('HTTP 403')),
          ),
        ),
      );
    });

    test('more than 1000 emails are sent in batches', () async {
      ctx.http.stub(_add, body: '{}');
      final emails = [for (var i = 0; i < 1001; i++) 'u$i@b.c'];
      final added = await ctx.run(add(emails: emails));
      expect(ctx.http.requests, hasLength(2));
      expect(added, hasLength(1001));
    });

    test('the request body carries the emails', () async {
      ctx.http.stub(_add, body: '{}');
      await ctx.run(add(emails: ['a@b.c']));
      expect(sentBody('POST $_host/v1/projects/123456/testers:batchAdd'), {
        'emails': ['a@b.c'],
      });
    });

    test('dry run sends nothing and returns the emails', () async {
      final dry = FakeLaneContext(dryRun: true);
      final emails = await dry.run(
        FirebaseAddTesters(
          project: '123456',
          emails: ['a@b.c'],
          client: dry.http,
        ),
      );
      expect(emails, ['a@b.c']);
      expect(dry.http.requests, isEmpty);
      expect(dry.dryRunSteps.single, contains('123456'));
    });

    test('dry run does not need the file yet', () async {
      final dry = FakeLaneContext(dryRun: true);
      final emails = await dry.run(
        FirebaseAddTesters(
          project: '123456',
          emailsFile: '${dir.path}/later.txt',
          client: dry.http,
        ),
      );
      expect(emails, isEmpty);
    });
  });

  group('FirebaseRemoveTesters', () {
    test('removes testers and returns what Firebase removed', () async {
      ctx.http.stub(
        _remove,
        body: jsonEncode({
          'emails': ['a@b.c'],
        }),
      );
      final removed = await ctx.run(remove(emails: ['a@b.c', 'x@y.z']));
      expect(removed, ['a@b.c']);
      expect(sentBody('POST $_host/v1/projects/123456/testers:batchRemove'), {
        'emails': ['a@b.c', 'x@y.z'],
      });
    });

    test('reads emails from a file', () async {
      ctx.http.stub(_remove, body: '{}');
      final removed = await ctx.run(remove(file: writeFile('a@b.c\nd@e.f')));
      expect(removed, ['a@b.c', 'd@e.f']);
    });

    test('a bad email fails before anything is sent', () {
      expect(ctx.run(remove(emails: ['nope'])), throwsA(isA<UserError>()));
      expect(ctx.http.requests, isEmpty);
    });

    test('a refused request fails the lane', () {
      ctx.http.stub(_remove, status: 500, body: '{}');
      expect(
        ctx.run(remove(emails: ['a@b.c'])),
        throwsA(isA<ActionFailed>()),
      );
    });

    test('dry run sends nothing', () async {
      final dry = FakeLaneContext(dryRun: true);
      final emails = await dry.run(
        FirebaseRemoveTesters(
          project: '123456',
          emails: ['a@b.c'],
          client: dry.http,
        ),
      );
      expect(emails, ['a@b.c']);
      expect(dry.http.requests, isEmpty);
    });
  });
}
