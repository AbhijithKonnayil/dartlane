import 'dart:io';

import 'package:dartlane_core/src/exit_codes.dart';
import 'package:dartlane_core/src/lane.dart';
import 'package:dartlane_core/src/lane_context.dart';
import 'package:dartlane_core/src/lane_error.dart';
import 'package:dartlane_core/src/lane_logger.dart';

/// Entry point for a project's lanes file.
///
/// ```dart
/// void main(List<String> args) => dartlane(args, lanes: {
///   'beta': Lane('Build and ship', (ctx) async { /* ... */ }),
/// });
/// ```
///
/// The first argument is the lane name and the rest go to the lane. The
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
/// [ExitCodes.failure]. Pass [logger] and [env] to control output and
/// environment in tests.
Future<int> runLanes(
  List<String> args, {
  required Map<String, Lane> lanes,
  LaneLogger? logger,
  Map<String, String>? env,
}) async {
  final log = logger ?? LaneLogger();

  if (args.isEmpty) {
    log.error('No lane given.');
    _printLanes(log, lanes);
    return ExitCodes.usage;
  }

  final name = args.first;
  final selected = lanes[name];
  if (selected == null) {
    log.error('Unknown lane "$name".');
    _printLanes(log, lanes);
    return ExitCodes.usage;
  }

  final ctx = LaneContext(args: args.sublist(1), env: env, logger: log);
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
    log.info('  ${entry.key.padRight(width)}  ${entry.value.description}');
  }
}
