import 'package:dartlane_core/testing.dart';
import 'package:test/test.dart';

void main() {
  group('FakeLaneShell', () {
    test('records every call in order', () async {
      final shell = FakeLaneShell();
      await shell.run('flutter', ['pub', 'get'], workingDirectory: 'app');
      await shell.run('flutter', ['build', 'apk']);

      expect(shell.commands, ['flutter pub get', 'flutter build apk']);
      expect(shell.calls.first.workingDirectory, 'app');
    });

    test('answers with a stub and a later stub wins', () async {
      final shell = FakeLaneShell()
        ..stub('git rev-parse HEAD', stdout: 'abc')
        ..stub('git rev-parse HEAD', stdout: 'def');

      final result = await shell.run('git', ['rev-parse', 'HEAD']);

      expect(result.stdout, 'def');
    });

    test('replays the stubbed output line by line when asked', () async {
      final shell = FakeLaneShell()
        ..stub('build', stdout: 'one\ntwo\n', stderr: 'oops\n');
      final lines = <String>[];

      await shell.run('build', [], onOutput: lines.add);

      expect(lines, ['one', 'two', 'oops']);
    });

    test('prints nothing when not asked', () async {
      final shell = FakeLaneShell()..stub('build', stdout: 'one\n');

      final result = await shell.run('build', []);

      expect(result.stdout, 'one\n');
    });

    test('a command with no stub succeeds with empty output', () async {
      final result = await FakeLaneShell().run('anything', []);

      expect(result.ok, isTrue);
      expect(result.stdout, isEmpty);
    });
  });

  group('FakeHttp', () {
    test('records requests and answers with the stub', () async {
      final http = FakeHttp()
        ..stub(
          'POST https://example.com/upload',
          status: 201,
          body: 'created',
          headers: {'x-id': '1'},
        );

      final response = await http.post(
        Uri.parse('https://example.com/upload'),
        body: 'payload',
      );

      expect(response.statusCode, 201);
      expect(response.body, 'created');
      expect(response.headers['x-id'], '1');
      expect(http.requests.single.summary, 'POST https://example.com/upload');
      expect(http.requests.single.body, 'payload');
    });

    test('a request with no stub fails loudly', () async {
      final http = FakeHttp();

      await expectLater(
        http.get(Uri.parse('https://example.com/other')),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('GET https://example.com/other'),
          ),
        ),
      );
      expect(http.requests, hasLength(1));
    });
  });

  group('FakeLaneContext', () {
    test('uses fakes and an empty environment by default', () {
      final ctx = FakeLaneContext();

      expect(ctx.shell, isA<FakeLaneShell>());
      expect(ctx.http, isA<FakeHttp>());
      expect(ctx.logger, isA<FakeLaneLogger>());
      expect(ctx.env, isEmpty);
      expect(ctx.args.raw, isEmpty);
    });

    test('takes args and env', () {
      final ctx = FakeLaneContext(args: ['--flavor=prod'], env: {'A': '1'});

      expect(ctx.args.string('flavor'), 'prod');
      expect(ctx.env, {'A': '1'});
    });
  });
}
