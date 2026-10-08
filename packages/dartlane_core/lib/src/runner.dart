import 'dart:io';

import 'package:dartlane_core/src/doctor.dart';
import 'package:dartlane_core/src/dry_run.dart';
import 'package:dartlane_core/src/exit_codes.dart';
import 'package:dartlane_core/src/lane.dart';
import 'package:dartlane_core/src/lane_context.dart';
import 'package:dartlane_core/src/lane_error.dart';
import 'package:dartlane_core/src/lane_logger.dart';

/// Option that turns on detail logging, such as the commands that are run.
///
/// It is read by the runner anywhere in the arguments and not passed on to
/// the lane.
const _verboseFlag = '--verbose';

/// Option that makes the runner describe the steps of a lane without running
/// them.
///
/// Like `--verbose` it is read anywhere in the arguments and not passed on to
/// the lane, so a lane cannot use `--dry-run` for itself.
const _dryRunFlag = '--dry-run';

/// First word that makes the runner list the lanes instead of running one.
///
/// Only the first word counts, so a lane can still have its own `--list`
/// option. `dartlane list` runs the lanes program with this word.
const _listFlag = '--list';

/// First word that makes the runner run the doctor checks instead of a lane.
///
/// Like `--list`, only the first word counts. `dartlane doctor` runs the lanes
/// program with this word.
const _doctorFlag = '--doctor';

/// Entry point for a project's lanes file.
///
/// ```dart
/// void main(List<String> args) => dartlane(args, lanes: {
///   'beta': Lane('Build and ship', (ctx) async { /* ... */ }),
/// });
/// ```
///
/// The first argument is the lane name and the rest go to the lane, except
/// `--verbose`, which the runner keeps for itself. A first argument of `--list`
/// prints the available lanes with their descriptions and exits with 0, and a
/// first argument of `--doctor` runs [checks]. The process exit code is set
/// from the result of [runLanes].
Future<void> dartlane(
  List<String> args, {
  required Map<String, Lane> lanes,
  List<DoctorCheck> checks = const [],
}) async {
  exitCode = await runLanes(args, lanes: lanes, checks: checks);
}

/// Runs the lane named by the first of [args] and returns an exit code.
///
/// Returns [ExitCodes.success] on success and [ExitCodes.usage] when the lane
/// name is missing or unknown (after printing the available lanes).
///
/// When the lane throws a [LaneError], its message (and a [UserError]'s hint)
/// is printed without a stack trace and the error's own exit code is returned.
/// The stack trace is only logged at detail level, so it shows with verbose
/// logging. Any other exception is reported as unexpected and returns
/// [ExitCodes.failure].
///
/// A first argument of `--list` prints the available lanes and returns
/// [ExitCodes.success] without running anything. A first argument of
/// `--doctor` runs [checks] instead and returns [ExitCodes.success] if every
/// required check passed, otherwise [ExitCodes.failure].
///
/// `--dry-run` anywhere in [args] describes the steps of the lane instead of
/// running them: each action prints its `describe()` line, nothing is run, and
/// the exit code is [ExitCodes.success] unless the lane fails before it
/// reaches a step. It is a best-effort preview. If it reaches something it
/// cannot describe safely, such as an action with a result it cannot make up,
/// it stops there and says so, still with [ExitCodes.success].
///
/// `--verbose` anywhere in [args] turns on detail logging and is not passed to
/// the lane. Without a [logger], one is created from [env] (the process
/// environment by default), so GitHub Actions gets annotations and CI never
/// prompts. Pass [logger] and [env] to control output and environment in
/// tests.
Future<int> runLanes(
  List<String> args, {
  required Map<String, Lane> lanes,
  List<DoctorCheck> checks = const [],
  LaneLogger? logger,
  Map<String, String>? env,
}) async {
  final verbose = args.contains(_verboseFlag);
  final dryRun = args.contains(_dryRunFlag);
  final laneArgs = [
    for (final arg in args)
      if (arg != _verboseFlag && arg != _dryRunFlag) arg,
  ];

  final log = logger ?? LaneLogger.fromEnvironment(env ?? Platform.environment);
  if (verbose) log.verbose = true;

  if (laneArgs.isNotEmpty && laneArgs.first == _listFlag) {
    _printLanes(log, lanes);
    return ExitCodes.success;
  }

  if (laneArgs.isNotEmpty && laneArgs.first == _doctorFlag) {
    final ctx = LaneContext(env: env, logger: log);
    try {
      return await runDoctor(checks, ctx);
    } finally {
      ctx.close();
    }
  }

  if (laneArgs.isEmpty) {
    log.error('No lane given.');
    _printLanes(log, lanes);
    return ExitCodes.usage;
  }

  final name = laneArgs.first;
  final selected = lanes[name];
  if (selected == null) {
    log.error('Unknown lane "$name".');
    _printLanes(log, lanes);
    return ExitCodes.usage;
  }

  final ctx = LaneContext(
    args: laneArgs.sublist(1),
    env: env,
    logger: log,
    dryRun: dryRun,
  );
  if (dryRun) log.info('Dry run: the steps are described, not run.');
  try {
    await selected.run(ctx);
  } on DryRunStopped catch (stop) {
    log.warn('Dry run stopped: ${stop.message}');
    _printDryRunSummary(log, ctx.dryRunSteps.length, stopped: true);
    return ExitCodes.success;
  } on LaneError catch (error, stackTrace) {
    log.error(error.message);
    if (error case UserError(:final hint?)) log.info('Hint: $hint');
    log.detail('$stackTrace');
    return error.exitCode;
  } on Object catch (error, stackTrace) {
    log
      ..error('Lane "$name" failed with an unexpected error: $error')
      ..detail('$stackTrace');
    return ExitCodes.failure;
  } finally {
    ctx.close();
  }
  if (dryRun) {
    _printDryRunSummary(log, ctx.dryRunSteps.length, stopped: false);
  } else {
    log.success('Lane "$name" finished.');
  }
  return ExitCodes.success;
}

void _printDryRunSummary(
  LaneLogger log,
  int steps, {
  required bool stopped,
}) {
  final count = '$steps ${steps == 1 ? 'step' : 'steps'}';
  log.info(
    stopped
        ? 'Dry run stopped after $count. Nothing was changed.'
        : 'Dry run finished: $count would run. Nothing was changed.',
  );
}

void _printLanes(LaneLogger log, Map<String, Lane> lanes) {
  if (lanes.isEmpty) {
    log.info('No lanes are defined.');
    return;
  }
  log.info('Available lanes:');
  final width = lanes.keys.fold(0, (w, k) => k.length > w ? k.length : w);
  for (final entry in lanes.entries) {
    log.info('  ${entry.key.padRight(width)} : ${entry.value.description}');
  }
}
