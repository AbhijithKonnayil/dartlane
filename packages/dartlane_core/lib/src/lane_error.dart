import 'package:dartlane_core/src/exit_codes.dart';

/// A failure that the runner understands.
///
/// Throw a [UserError] when the person running the lane can fix the problem,
/// and an [ActionFailed] when a step ran and failed. The runner prints
/// [message] without a stack trace and exits with [exitCode]. Any other
/// exception is treated as an unexpected bug.
abstract class LaneError implements Exception {
  /// Creates an error with a [message] for the person running the lane.
  const LaneError(this.message);

  /// What went wrong, in a form that is clear on its own.
  final String message;

  /// The process exit code the runner uses for this error.
  int get exitCode;

  @override
  String toString() => message;
}

/// The person running the lane gave something wrong or left something out, for
/// example a missing credential or an invalid argument value.
class UserError extends LaneError {
  /// Creates an error. Pass a [hint] saying how to fix it.
  const UserError(super.message, {this.hint});

  /// How to fix the problem, shown after the message.
  final String? hint;

  @override
  int get exitCode => ExitCodes.usage;
}

/// A step ran and failed, for example a build that exited with an error or an
/// upload that was rejected.
class ActionFailed extends LaneError {
  /// Creates an error describing what failed.
  const ActionFailed(super.message);

  @override
  int get exitCode => ExitCodes.failure;
}
