import 'package:dartlane_core/src/exit_codes.dart';
import 'package:dartlane_core/src/lane_context.dart';
import 'package:dartlane_core/src/lane_logger.dart';

/// The outcome of one [DoctorCheck].
class DoctorResult {
  const DoctorResult._({required this.ok, required this.message, this.fix});

  /// The check passed. [message] says what was found, for example a version.
  const DoctorResult.pass([String message = ''])
    : this._(ok: true, message: message);

  /// The check failed. [message] says what is wrong and [fix] says what to do
  /// about it.
  const DoctorResult.fail(String message, {required String fix})
    : this._(ok: false, message: message, fix: fix);

  /// Whether the check passed.
  final bool ok;

  /// What was found, or what is wrong.
  final String message;

  /// What to do about a failure. Null for a pass.
  final String? fix;
}

/// One thing `dartlane doctor` looks at, for example "is Flutter installed".
///
/// Packages with actions contribute their own checks, for example a check that
/// credentials exist, and pass them to `dartlane(args, lanes: ..., checks:
/// ...)`. A check should only look and report. It must not change anything.
abstract class DoctorCheck {
  /// Creates a check.
  const DoctorCheck();

  /// A short label, such as `Flutter SDK`.
  String get name;

  /// Whether a failure makes `doctor` fail.
  ///
  /// When false, a failure is shown as a warning and the exit code stays 0.
  bool get isRequired => true;

  /// Looks and reports. Throwing is treated as a failure.
  Future<DoctorResult> run(LaneContext ctx);
}

/// What a run of checks found.
class DoctorReport {
  /// Creates a report.
  const DoctorReport({
    this.passed = 0,
    this.failed = 0,
    this.warnings = 0,
  });

  /// How many checks passed.
  final int passed;

  /// How many required checks failed.
  final int failed;

  /// How many optional checks failed.
  final int warnings;

  /// Whether every required check passed.
  bool get ok => failed == 0;

  /// The exit code for this report.
  int get exitCode => ok ? ExitCodes.success : ExitCodes.failure;
}

/// Runs [checks] one after the other and prints each result with [ctx]'s
/// logger.
///
/// A passing check prints a line starting with `✓`, a failing required check a
/// line starting with `✗` followed by its fix, and a failing optional check a
/// warning. A check that throws counts as failed; it never stops the others.
Future<DoctorReport> runDoctorChecks(
  Iterable<DoctorCheck> checks,
  LaneContext ctx,
) async {
  final log = ctx.logger;
  var passed = 0;
  var failed = 0;
  var warnings = 0;

  for (final check in checks) {
    DoctorResult result;
    try {
      result = await check.run(ctx);
    } on Object catch (error, stackTrace) {
      log.detail('$stackTrace');
      result = DoctorResult.fail(
        '$error',
        fix: 'Run again with --verbose to see the details.',
      );
    }

    final detail = result.message.isEmpty ? '' : ': ${result.message}';
    if (result.ok) {
      passed++;
      log.success('✓ ${check.name}$detail');
    } else if (check.isRequired) {
      failed++;
      log
        ..error('✗ ${check.name}$detail')
        ..info('    Fix: ${result.fix}');
    } else {
      warnings++;
      log
        ..warn('${check.name}$detail')
        ..info('    Fix: ${result.fix}');
    }
  }

  return DoctorReport(passed: passed, failed: failed, warnings: warnings);
}

/// Prints one line saying whether every required check passed.
void printDoctorSummary(DoctorReport report, LaneLogger log) {
  final warnings = switch (report.warnings) {
    0 => '',
    1 => ' (1 warning)',
    final count => ' ($count warnings)',
  };
  if (report.ok) {
    log.success('All required checks passed$warnings.');
  } else {
    final count = report.failed;
    log.error(
      '$count required ${count == 1 ? 'check' : 'checks'} failed$warnings.',
    );
  }
}

/// Runs [checks], prints the results and a summary, and returns the exit code:
/// [ExitCodes.success] if every required check passed, otherwise
/// [ExitCodes.failure].
Future<int> runDoctor(Iterable<DoctorCheck> checks, LaneContext ctx) async {
  final report = await runDoctorChecks(checks, ctx);
  printDoctorSummary(report, ctx.logger);
  return report.exitCode;
}
