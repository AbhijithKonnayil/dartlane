import 'dart:io';

import 'package:dartlane_core/dartlane_core.dart';
import 'package:dartlane_core/testing.dart';
import 'package:test/test.dart';

import 'support/sample_checks.dart';

/// The fix that `OptionalFailingCheck` suggests.
const _flavorsFix =
    'Add productFlavors to android/app/build.gradle if you need them.';

void main() {
  late FakeLaneContext ctx;

  setUp(() => ctx = FakeLaneContext());

  group('runDoctorChecks', () {
    test('a passing check prints a tick, its name and what it found', () async {
      await runDoctorChecks([const PassingCheck()], ctx);

      expect(ctx.logger.lines, ['✓ Dart SDK: 3.12.2']);
    });

    test('a passing check with no message prints just its name', () async {
      await runDoctorChecks([const PassingCheck(message: '')], ctx);

      expect(ctx.logger.lines, ['✓ Dart SDK']);
    });

    test('a failing required check prints the problem and the fix', () async {
      await runDoctorChecks([const FailingCheck()], ctx);

      expect(ctx.logger.lines, [
        'error: ✗ Flutter SDK: flutter was not found',
        '    Fix: Install Flutter and add it to your PATH.',
      ]);
    });

    test('a failing optional check is a warning with a fix', () async {
      await runDoctorChecks([const OptionalFailingCheck()], ctx);

      expect(ctx.logger.lines, [
        'warning: Flavors: none found',
        '    Fix: $_flavorsFix',
      ]);
    });

    test('runs the checks in order', () async {
      await runDoctorChecks([
        const PassingCheck(),
        const FailingCheck(),
        const OptionalFailingCheck(),
      ], ctx);

      expect(ctx.logger.lines.map((l) => l.split(':').first), [
        '✓ Dart SDK',
        'error',
        '    Fix',
        'warning',
        '    Fix',
      ]);
    });

    test('a check that throws fails without stopping the others', () async {
      final report = await runDoctorChecks([
        const ThrowingCheck(),
        const PassingCheck(),
      ], ctx);

      expect(ctx.logger.lines, [
        'error: ✗ Credentials: Bad state: could not read the key file',
        '    Fix: Run again with --verbose to see the details.',
        '✓ Dart SDK: 3.12.2',
      ]);
      expect(report.failed, 1);
      expect(report.passed, 1);
    });

    test('counts passes, failures and warnings', () async {
      final report = await runDoctorChecks([
        const PassingCheck(),
        const PassingCheck(),
        const FailingCheck(),
        const OptionalFailingCheck(),
      ], ctx);

      expect(report.passed, 2);
      expect(report.failed, 1);
      expect(report.warnings, 1);
      expect(report.ok, isFalse);
      expect(report.exitCode, ExitCodes.failure);
    });

    test('a warning alone is still ok', () async {
      final report = await runDoctorChecks([
        const OptionalFailingCheck(),
      ], ctx);

      expect(report.ok, isTrue);
      expect(report.exitCode, ExitCodes.success);
    });

    test('no checks is ok', () async {
      final report = await runDoctorChecks(const [], ctx);

      expect(report.ok, isTrue);
      expect(ctx.logger.lines, isEmpty);
    });
  });

  group('printDoctorSummary', () {
    String summary(DoctorReport report) {
      final logger = FakeLaneLogger();
      printDoctorSummary(report, logger);
      return logger.lines.single;
    }

    test('all passed', () {
      expect(
        summary(const DoctorReport(passed: 3)),
        'All required checks passed.',
      );
    });

    test('all passed with warnings', () {
      expect(
        summary(const DoctorReport(passed: 3, warnings: 1)),
        'All required checks passed (1 warning).',
      );
      expect(
        summary(const DoctorReport(passed: 3, warnings: 2)),
        'All required checks passed (2 warnings).',
      );
    });

    test('failures', () {
      expect(
        summary(const DoctorReport(failed: 1)),
        'error: 1 required check failed.',
      );
      expect(
        summary(const DoctorReport(failed: 2, warnings: 1)),
        'error: 2 required checks failed (1 warning).',
      );
    });
  });

  group('runDoctor', () {
    test(
      'prints the results and a summary and exits 0 when all pass',
      () async {
        final code = await runDoctor([const PassingCheck()], ctx);

        expect(code, ExitCodes.success);
        expect(ctx.logger.lines, [
          '✓ Dart SDK: 3.12.2',
          'All required checks passed.',
        ]);
      },
    );

    test('exits non-zero when a required check fails', () async {
      final code = await runDoctor([
        const PassingCheck(),
        const FailingCheck(),
      ], ctx);

      expect(code, ExitCodes.failure);
      expect(ctx.logger.lines.last, 'error: 1 required check failed.');
    });
  });

  group('runLanes --doctor', () {
    late FakeLaneLogger logger;

    setUp(() => logger = FakeLaneLogger());

    test('runs the checks instead of a lane', () async {
      var ran = false;

      final code = await runLanes(
        ['--doctor'],
        lanes: {'go': Lane('Go', (ctx) => ran = true)},
        checks: [const PassingCheck(), const OptionalFailingCheck()],
        logger: logger,
      );

      expect(code, ExitCodes.success);
      expect(ran, isFalse);
      expect(logger.lines, [
        '✓ Dart SDK: 3.12.2',
        'warning: Flavors: none found',
        '    Fix: $_flavorsFix',
        'All required checks passed (1 warning).',
      ]);
    });

    test('exits non-zero when a required check fails', () async {
      final code = await runLanes(
        ['--doctor'],
        lanes: {},
        checks: [const FailingCheck()],
        logger: logger,
      );

      expect(code, ExitCodes.failure);
      expect(logger.lines.last, 'error: 1 required check failed.');
    });

    test('with no checks it still passes', () async {
      final code = await runLanes(['--doctor'], lanes: {}, logger: logger);

      expect(code, ExitCodes.success);
      expect(logger.lines, ['All required checks passed.']);
    });

    test(
      'only counts as the first word, so a lane can have a --doctor option',
      () async {
        bool? flag;

        final code = await runLanes(
          ['go', '--doctor'],
          lanes: {'go': Lane('Go', (ctx) => flag = ctx.args.flag('doctor'))},
          checks: [const FailingCheck()],
          logger: logger,
        );

        expect(code, ExitCodes.success);
        expect(flag, isTrue);
      },
    );

    test('works together with --verbose', () async {
      final code = await runLanes(
        ['--verbose', '--doctor'],
        lanes: {},
        checks: [const PassingCheck()],
        logger: logger,
      );

      expect(code, ExitCodes.success);
      expect(logger.lines, contains('✓ Dart SDK: 3.12.2'));
    });
  });

  group('FakeLaneShell.stubMissing', () {
    test('throws like a command that is not installed', () {
      final shell = FakeLaneShell()..stubMissing('flutter');

      expect(
        () => shell.run('flutter', ['--version']),
        throwsA(isA<ProcessException>()),
      );
      expect(shell.commands, ['flutter --version']);
    });

    test('leaves other commands alone', () async {
      final shell = FakeLaneShell()..stubMissing('flutter');

      expect((await shell.run('dart', ['--version'])).ok, isTrue);
    });
  });
}
