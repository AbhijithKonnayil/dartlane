import 'package:dartlane_core/dartlane_core.dart';
import 'package:dartlane_core/testing.dart';
import 'package:http/http.dart';
import 'package:test/test.dart';

import 'support/sample_actions.dart';

/// A client that remembers whether it was closed.
class _SpyClient extends BaseClient {
  bool closed = false;

  @override
  Future<StreamedResponse> send(BaseRequest request) =>
      throw UnimplementedError();

  @override
  void close() => closed = true;
}

void main() {
  late FakeLaneContext ctx;

  setUp(() => ctx = FakeLaneContext());

  group('LaneContext.run', () {
    test('returns the action result', () async {
      expect(await ctx.run(const UppercaseAction('hi')), 'HI');
    });

    test('logs the step with timing', () async {
      await ctx.run(const UppercaseAction('hi'));
      expect(ctx.logger.lines.first, '> uppercase hi');
      expect(ctx.logger.lines.last, matches(RegExp(r'^  done \(\d+ms\)$')));
    });

    test('describe defaults to the class name', () async {
      await ctx.run(const DefaultDescribeAction());
      expect(ctx.logger.lines.first, '> DefaultDescribeAction');
    });

    test('logs a failure and rethrows it', () async {
      await expectLater(ctx.run(const FailingAction()), throwsStateError);
      expect(
        ctx.logger.lines.last,
        matches(RegExp(r'^error: FailingAction failed \(\d+ms\)$')),
      );
    });
  });

  group('LaneContext.sh', () {
    test('runs the command through the shell and returns the result', () async {
      ctx.shell.stub('flutter --version', stdout: 'Flutter 3');

      final result = await ctx.sh('flutter', ['--version']);

      expect(result.stdout, 'Flutter 3');
      expect(ctx.shell.commands, ['flutter --version']);
    });

    test('passes the working directory and environment', () async {
      await ctx.sh(
        'flutter',
        ['build', 'apk'],
        workingDirectory: 'app',
        environment: {'A': '1'},
      );

      final call = ctx.shell.calls.single;
      expect(call.workingDirectory, 'app');
      expect(call.environment, {'A': '1'});
    });

    test('logs the command at detail level', () async {
      final verbose = FakeLaneContext(verbose: true);
      await verbose.sh('flutter', ['build', 'apk']);
      expect(verbose.logger.lines, [r'$ flutter build apk']);

      await ctx.sh('flutter', ['build', 'apk']);
      expect(ctx.logger.lines, isEmpty);
    });

    test('throws on a non-zero exit code', () async {
      ctx.shell.stub('flutter build apk', exitCode: 1, stderr: 'no pubspec');

      await expectLater(
        ctx.sh('flutter', ['build', 'apk']),
        throwsA(
          isA<ShellException>()
              .having((e) => e.result.exitCode, 'exitCode', 1)
              .having((e) => e.commandLine, 'commandLine', 'flutter build apk')
              .having((e) => '$e', 'message', contains('no pubspec')),
        ),
      );
    });
  });

  group('LaneContext.http and close', () {
    test('http is the injected client', () {
      final fake = FakeHttp();
      expect(LaneContext(http: fake).http, same(fake));
    });

    test('close does not close an injected client', () {
      final spy = _SpyClient();
      LaneContext(http: spy).close();
      expect(spy.closed, isFalse);
    });

    test('a default client is created on first use', () {
      final context = LaneContext();
      expect(context.http, isA<Client>());
      expect(context.http, same(context.http));
      context.close();
    });
  });
}
