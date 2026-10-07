import 'dart:io';

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

/// First word that makes the runner list the lanes instead of running one.
///
/// Only the first word counts, so a lane can still have its own `--list`
/// option. `dartlane list` runs the lanes program with this word.
const _listFlag = '--list';

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
/// prints the available lanes with their descriptions and exits with 0. The
/// process exit code is set from the result of [runLanes].
Future<void> dartlane(
  List<String> args, {
  required Map<String, Lane> lanes,
}) async {
  exitCode = await runLanes(args, lanes: lanes);
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
/// [ExitCodes.success] without running anything.
///
/// `--verbose` anywhere in [args] turns on detail logging and is not passed to
/// the lane. Without a [logger], one is created from [env] (the process
/// environment by default), so GitHub Actions gets annotations and CI never
/// prompts. Pass [logger] and [env] to control output and environment in
/// tests.
Future<int> runLanes(
  List<String> args, {
  required Map<String, Lane> lanes,
  LaneLogger? logger,
  Map<String, String>? env,
}) async {
  final verbose = args.contains(_verboseFlag);
  final laneArgs = [
    for (final arg in args)
      if (arg != _verboseFlag) arg,
  ];

  final log = logger ?? LaneLogger.fromEnvironment(env ?? Platform.environment);
  if (verbose) log.verbose = true;

  if (laneArgs.isNotEmpty && laneArgs.first == _listFlag) {
    _printLanes(log, lanes);
    return ExitCodes.success;
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

  final ctx = LaneContext(args: laneArgs.sublist(1), env: env, logger: log);
  try {
    await selected.run(ctx);
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
  log.success('Lane "$name" finished.');
  return ExitCodes.success;
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
