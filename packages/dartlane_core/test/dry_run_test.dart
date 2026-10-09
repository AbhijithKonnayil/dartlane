import 'package:dartlane_core/dartlane_core.dart';
import 'package:dartlane_core/testing.dart';
import 'package:http/http.dart';
import 'package:test/test.dart';

import 'support/sample_actions.dart';

void main() {
  late FakeLaneContext real;
  late FakeLaneContext dry;

  setUp(() {
    real = FakeLaneContext();
    dry = FakeLaneContext(dryRun: true);
  });

  test('a context is not a dry run by default', () {
    expect(real.dryRun, isFalse);
    expect(real.dryRunSteps, isEmpty);
  });

  group('ctx.run in a dry run', () {
    test('prints the step and does not run the action', () async {
      final action = RecordingAction();

      await dry.run(action);

      expect(action.ran, isFalse);
      expect(dry.logger.lines, ['Would run: record that it ran']);
    });

    test('runs the action when it is not a dry run', () async {
      final action = RecordingAction();

      await real.run(action);

      expect(action.ran, isTrue);
      expect(real.logger.lines.first, '> record that it ran');
    });

    test('prints no timing and records each step in order', () async {
      await dry.run(RecordingAction());
      await dry.run(const PlaceholderAction());

      expect(dry.logger.lines, [
        'Would run: record that it ran',
        'Would run: make a thing',
      ]);
      expect(dry.dryRunSteps, ['record that it ran', 'make a thing']);
    });

    test('an action that would fail is not run, so it does not fail', () async {
      await expectLater(dry.run(const FailingAction()), completes);
      expect(dry.logger.lines, ['Would run: FailingAction']);
    });
  });

  group('dryRunResult', () {
    test('a placeholder flows to the next step', () async {
      final result = await dry.run(const PlaceholderAction());

      expect(result, 'placeholder');
      expect(await real.run(const PlaceholderAction()), 'real');
    });

    test('an action with no result returns null', () async {
      await expectLater(dry.run(RecordingAction()), completion(isNull));
    });

    test('an action with a nullable result returns null', () async {
      expect(await dry.run(const NullableResultAction()), isNull);
    });

    test('a result that cannot be made up stops the dry run', () async {
      await expectLater(
        dry.run(const UppercaseAction('hi')),
        throwsA(
          isA<DryRunStopped>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('uppercase hi returns a result that a dry run cannot'),
              contains('Override dryRunResult'),
            ),
          ),
        ),
      );
      // The step was still described before it stopped.
      expect(dry.logger.lines, ['Would run: uppercase hi']);
    });

    test('an int result cannot be made up either', () async {
      await expectLater(
        dry.run(const DefaultDescribeAction()),
        throwsA(isA<DryRunStopped>()),
      );
    });
  });

  group('ctx.sh in a dry run', () {
    test('describes the command and runs nothing', () async {
      final result = await dry.sh('flutter', ['build', 'apk']);

      expect(dry.shell.calls, isEmpty);
      expect(dry.logger.lines, ['Would run: flutter build apk']);
      expect(dry.dryRunSteps, ['flutter build apk']);
      expect(result.ok, isTrue);
      expect(result.stdout, isEmpty);
    });

    test('does not fail even when the command would', () async {
      dry.shell.stub('flutter build apk', exitCode: 1);

      expect((await dry.sh('flutter', ['build', 'apk'])).ok, isTrue);
    });

    test('runs the command when it is not a dry run', () async {
      await real.sh('flutter', ['build', 'apk']);

      expect(real.shell.commands, ['flutter build apk']);
      expect(real.dryRunSteps, isEmpty);
    });
  });

  group('ctx.http in a dry run', () {
    const url = 'https://example.com/data';

    test('lets requests that only read through', () async {
      dry.http.stub('GET $url', body: 'hello');
      dry.http.stub('HEAD $url');

      expect((await dry.http.get(Uri.parse(url))).body, 'hello');
      expect((await dry.http.head(Uri.parse(url))).statusCode, 200);
    });

    test(
      'stops the dry run before a request that would change something',
      () async {
        for (final send in <Future<Response> Function(Client)>[
          (c) => c.post(Uri.parse(url)),
          (c) => c.put(Uri.parse(url)),
          (c) => c.patch(Uri.parse(url)),
          (c) => c.delete(Uri.parse(url)),
        ]) {
          await expectLater(
            send(_clientOf(dry)),
            throwsA(
              isA<DryRunStopped>().having(
                (e) => e.message,
                'message',
                contains('a dry run does not send'),
              ),
            ),
          );
        }
        expect(dry.http.requests, isEmpty, reason: 'nothing was sent');
      },
    );

    test('the real context guards the client it was given', () async {
      final inner = FakeHttp()..stub('GET $url', body: 'hello');
      final context = LaneContext(dryRun: true, http: inner);

      expect((await context.http.get(Uri.parse(url))).body, 'hello');
      await expectLater(
        context.http.post(Uri.parse(url)),
        throwsA(isA<DryRunStopped>()),
      );
      expect(inner.requests.map((r) => r.method), ['GET']);
    });

    test(
      'the real context leaves the client alone when it is not a dry run',
      () async {
        final inner = FakeHttp()..stub('POST $url', status: 201);
        final context = LaneContext(http: inner);

        expect(context.http, same(inner));
        expect((await context.http.post(Uri.parse(url))).statusCode, 201);
      },
    );

    test('is not restricted when it is not a dry run', () async {
      real.http.stub('POST $url', status: 201);

      expect((await real.http.post(Uri.parse(url))).statusCode, 201);
    });
  });

  group('DryRunStopped', () {
    test('toString is the message', () {
      expect('${const DryRunStopped('why')}', 'why');
    });
  });
}

/// The context's client, as the lane sees it.
Client _clientOf(LaneContext context) => context.http;
