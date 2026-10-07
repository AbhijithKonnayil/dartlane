// Small actions used by the tests. Each one exists to exercise one behaviour
// of `LaneContext.run` or the runner, and is named after what it does.
import 'package:dartlane_core/dartlane_core.dart';

/// An action with parameters and a custom `describe()`.
///
/// Returns its text in upper case, so `UppercaseAction('hi')` gives `'HI'`.
/// Describes itself as `uppercase <text>`.
class UppercaseAction extends LaneAction<String> {
  /// Creates an action that upper-cases [text].
  const UppercaseAction(this.text);

  /// The text to upper-case.
  final String text;

  @override
  Future<String> run(LaneContext ctx) async => text.toUpperCase();

  @override
  String describe() => 'uppercase $text';
}

/// An action that always fails, to test error handling.
///
/// Throws a [StateError] with the message `boom`.
class FailingAction extends LaneAction<void> {
  /// Creates an action with no parameters that throws when run.
  const FailingAction();

  @override
  Future<void> run(LaneContext ctx) async => throw StateError('boom');
}

/// An action that does not override `describe()`, to test the default.
///
/// Returns `7`. Its `describe()` is the class name,
/// `DefaultDescribeAction`.
class DefaultDescribeAction extends LaneAction<int> {
  /// Creates an action with no parameters that returns 7.
  const DefaultDescribeAction();

  @override
  Future<int> run(LaneContext ctx) async => 7;
}

/// An action that fails because of something the user must fix.
///
/// Throws a [UserError] with the message `Missing credentials` and the hint
/// `Set FIREBASE_TOKEN`.
class MisconfiguredAction extends LaneAction<void> {
  /// Creates an action with no parameters that throws a user error.
  const MisconfiguredAction();

  @override
  Future<void> run(LaneContext ctx) async => throw const UserError(
    'Missing credentials',
    hint: 'Set FIREBASE_TOKEN',
  );
}

/// An action that ran and failed.
///
/// Throws an [ActionFailed] with the message `Upload rejected with status 500`.
class RejectedAction extends LaneAction<void> {
  /// Creates an action with no parameters that throws an action failure.
  const RejectedAction();

  @override
  Future<void> run(LaneContext ctx) async =>
      throw const ActionFailed('Upload rejected with status 500');
}
