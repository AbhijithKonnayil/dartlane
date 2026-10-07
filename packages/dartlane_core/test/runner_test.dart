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
      expect(seen!.args.raw, ['--flavor=prod', 'x']);
      expect(seen!.args.string('flavor'), 'prod');
      expect(seen!.args.positional, ['x']);
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
      expect(logger.lines, contains('  beta  : Ship to QA'));
      expect(logger.lines, contains('  alpha : Ship to devs'));
    });

    test('missing lane name lists the available lanes and fails', () async {
      final code = await runLanes(
        [],
        lanes: {'beta': Lane('Ship to QA', (ctx) {})},
        logger: logger,
      );
      expect(code, ExitCodes.usage);
      expect(logger.lines, contains('error: No lane given.'));
      expect(logger.lines, contains('  beta : Ship to QA'));
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

  group('runLanes logging', () {
    final lane = Lane('Log', (ctx) {
      ctx.logger.detail('a detail');
      ctx.logger.info('args: ${ctx.args.raw}');
    });

    test('detail output is hidden by default', () async {
      await runLanes(['go'], lanes: {'go': lane}, logger: logger);

      expect(logger.lines, contains('args: []'));
      expect(logger.lines, isNot(contains('a detail')));
    });

    test('--verbose shows detail output', () async {
      await runLanes(['go', '--verbose'], lanes: {'go': lane}, logger: logger);

      expect(logger.lines, contains('a detail'));
    });

    test('--verbose can come before the lane name', () async {
      await runLanes(['--verbose', 'go'], lanes: {'go': lane}, logger: logger);

      expect(logger.lines, contains('a detail'));
    });

    test('--verbose is not passed on to the lane', () async {
      await runLanes(
        ['go', '--flavor=prod', '--verbose'],
        lanes: {'go': lane},
        logger: logger,
      );

      expect(logger.lines, contains('args: [--flavor=prod]'));
    });

    test('a failure is annotated on GitHub Actions', () async {
      final github = FakeLaneLogger(githubActions: true);

      final code = await runLanes(
        ['go'],
        lanes: {'go': Lane('Go', (ctx) => ctx.run(const RejectedAction()))},
        logger: github,
      );

      expect(code, ExitCodes.failure);
      expect(
        github.lines,
        contains('::error::Upload rejected with status 500'),
      );
    });
  });

  group('runLanes --list', () {
    test('prints the lanes with their descriptions and exits 0', () async {
      var ran = false;

      final code = await runLanes(
        ['--list'],
        lanes: {
          'build': Lane('Build a release APK', (ctx) => ran = true),
          'distribute': Lane('Send it to testers', (ctx) => ran = true),
        },
        logger: logger,
      );

      expect(code, ExitCodes.success);
      expect(logger.lines, [
        'Available lanes:',
        '  build      : Build a release APK',
        '  distribute : Send it to testers',
      ]);
      expect(ran, isFalse);
    });

    test('says so when there are no lanes, and still exits 0', () async {
      final code = await runLanes(['--list'], lanes: {}, logger: logger);

      expect(code, ExitCodes.success);
      expect(logger.lines, ['No lanes are defined.']);
    });

    test(
      'only counts as the first word, so a lane can have a --list option',
      () async {
        bool? listed;

        final code = await runLanes(
          ['go', '--list'],
          lanes: {'go': Lane('Go', (ctx) => listed = ctx.args.flag('list'))},
          logger: logger,
        );

        expect(code, ExitCodes.success);
        expect(listed, isTrue);
        expect(logger.lines, isNot(contains('Available lanes:')));
      },
    );

    test('works together with --verbose', () async {
      final code = await runLanes(
        ['--verbose', '--list'],
        lanes: {'go': Lane('Go', (ctx) {})},
        logger: logger,
      );

      expect(code, ExitCodes.success);
      expect(logger.lines, contains('  go : Go'));
    });
  });

  group('runLanes arguments', () {
    test('typed options reach the lane', () async {
      String? flavor;
      bool? notify;
      List<String>? testers;

      final code = await runLanes(
        [
          'go',
          '--flavor=prod',
          '--no-notify',
          '--testers=a@x.com,b@y.com',
        ],
        lanes: {
          'go': Lane('Go', (ctx) {
            flavor = ctx.args.string('flavor');
            notify = ctx.args.flag('notify', defaultValue: true);
            testers = ctx.args.list('testers');
          }),
        },
        logger: logger,
      );

      expect(code, ExitCodes.success);
      expect(flavor, 'prod');
      expect(notify, isFalse);
      expect(testers, ['a@x.com', 'b@y.com']);
    });

    test(
      'a missing required option exits with the usage code and a hint',
      () async {
        final code = await runLanes(
          ['go'],
          lanes: {'go': Lane('Go', (ctx) => ctx.args.requireString('app'))},
          logger: logger,
        );

        expect(code, ExitCodes.usage);
        expect(logger.lines, contains('error: Missing required option --app.'));
        expect(logger.lines, contains('Hint: Pass --app=<value>.'));
      },
    );

    test('a value of the wrong type is a user error', () async {
      final code = await runLanes(
        ['go', '--retries=many'],
        lanes: {'go': Lane('Go', (ctx) => ctx.args.integer('retries'))},
        logger: logger,
      );

      expect(code, ExitCodes.usage);
      expect(
        logger.lines,
        contains('error: --retries must be a whole number, but got "many".'),
      );
    });
  });

  group('runLanes errors', () {
    Future<int> runWith(LaneAction<void> action, LaneLogger logger) => runLanes(
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
