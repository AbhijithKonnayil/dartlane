import 'package:dartlane_core/dartlane_core.dart';
import 'package:dartlane_core/testing.dart';
import 'package:test/test.dart';

import 'support/sample_actions.dart';

void main() {
  late FakeLaneLogger logger;

  setUp(() => logger = FakeLaneLogger());

  group('runLanes', () {
    test('runs a plain function lane that calls actions', () async {
      String? result;
      final code = await runLanes(
        ['beta'],
        lanes: {
          'beta': Lane('Beta', (ctx) async {
            result = await ctx.run(const UppercaseAction('x'));
          }),
        },
        logger: logger,
      );
      expect(code, ExitCodes.success);
      expect(result, 'X');
    });

    test('accepts a synchronous lane body', () async {
      var ran = false;
      final code = await runLanes(
        ['sync'],
        lanes: {'sync': Lane('Sync', (ctx) => ran = true)},
        logger: logger,
      );
      expect(code, ExitCodes.success);
      expect(ran, isTrue);
    });

    test('passes remaining args and env to the lane', () async {
      LaneContext? seen;
      await runLanes(
        ['beta', '--flavor=prod', 'x'],
        lanes: {'beta': Lane('Beta', (ctx) => seen = ctx)},
        env: {'A': '1'},
        logger: logger,
      );
      expect(seen!.args, ['--flavor=prod', 'x']);
      expect(seen!.env, {'A': '1'});
    });

    test('unknown lane lists the available lanes and fails', () async {
      final code = await runLanes(
        ['nope'],
        lanes: {
          'beta': Lane('Ship to QA', (ctx) {}),
          'alpha': Lane('Ship to devs', (ctx) {}),
        },
        logger: logger,
      );
      expect(code, ExitCodes.usage);
      expect(logger.lines, contains('error: Unknown lane "nope".'));
      expect(logger.lines, contains('Available lanes:'));
      expect(logger.lines, contains('  beta   Ship to QA'));
      expect(logger.lines, contains('  alpha  Ship to devs'));
    });

    test('missing lane name lists the available lanes and fails', () async {
      final code = await runLanes(
        [],
        lanes: {'beta': Lane('Ship to QA', (ctx) {})},
        logger: logger,
      );
      expect(code, ExitCodes.usage);
      expect(logger.lines, contains('error: No lane given.'));
      expect(logger.lines, contains('  beta  Ship to QA'));
    });

    test('an unexpected error exits non-zero and says so', () async {
      final code = await runLanes(
        ['bad'],
        lanes: {'bad': Lane('Bad', (ctx) => ctx.run(const FailingAction()))},
        logger: logger,
      );
      expect(code, ExitCodes.failure);
      expect(
        logger.lines,
        contains(
          'error: Lane "bad" failed with an unexpected error: '
          'Bad state: boom',
        ),
      );
    });
  });

  group('runLanes errors', () {
    Future<int> runWith(Action<void, void> action, LaneLogger logger) =>
        runLanes(
          ['go'],
          lanes: {'go': Lane('Go', (ctx) => ctx.run(action))},
          logger: logger,
        );

    test('a user error exits with the usage code and shows its hint', () async {
      final code = await runWith(const MisconfiguredAction(), logger);

      expect(code, ExitCodes.usage);
      expect(logger.lines, contains('error: Missing credentials'));
      expect(logger.lines, contains('Hint: Set FIREBASE_TOKEN'));
    });

    test('a failed action exits with the failure code', () async {
      final code = await runWith(const RejectedAction(), logger);

      expect(code, ExitCodes.failure);
      expect(
        logger.lines,
        contains('error: Upload rejected with status 500'),
      );
    });

    test(
      'a failed command exits with the failure code and shows why',
      () async {
        final code = await runLanes(
          ['build'],
          lanes: {
            'build': Lane('Build', (ctx) {
              throw ShellException(
                commandLine: 'flutter build apk',
                result: const ShellResult(exitCode: 1, stderr: 'no pubspec'),
              );
            }),
          },
          logger: logger,
        );

        expect(code, ExitCodes.failure);
        expect(
          logger.lines,
          contains(
            'error: `flutter build apk` exited with code 1.\nno pubspec',
          ),
        );
      },
    );

    test('a stack trace is hidden unless logging is verbose', () async {
      await runWith(const MisconfiguredAction(), logger);
      expect(logger.lines.any((l) => l.contains('.dart:')), isFalse);

      final verbose = FakeLaneLogger(verbose: true);
      await runWith(const MisconfiguredAction(), verbose);
      expect(verbose.lines.any((l) => l.contains('.dart:')), isTrue);
    });
  });
}
