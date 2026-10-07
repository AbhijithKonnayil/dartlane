// Small actions used by the tests. Each one exists to exercise one behaviour
// of `LaneContext.run` or the runner, and is named after what it does.
import 'package:dartlane_core/dartlane_core.dart';

/// An action with parameters and a custom `describe()`.
///
/// Returns its text in upper case, so `UppercaseAction('hi')` gives `'HI'`.
/// Describes itself as `uppercase <text>`.
class UppercaseAction extends Action<String, String> {
  /// Creates an action that upper-cases its text parameter.
  const UppercaseAction(super.params);

  /// The text to upper-case. Same value as [params].
  String get text => params;

  @override
  Future<String> run(LaneContext ctx) async => text.toUpperCase();

  @override
  String describe() => 'uppercase $text';
}

/// An action that always fails, to test error handling.
///
/// Throws a [StateError] with the message `boom`.
class FailingAction extends Action<void, void> {
  /// Creates an action with no parameters that throws when run.
  const FailingAction() : super(null);

  @override
  Future<void> run(LaneContext ctx) async => throw StateError('boom');
}

/// An action that does not override `describe()`, to test the default.
///
/// Returns `7`. Its `describe()` is the class name,
/// `DefaultDescribeAction`.
class DefaultDescribeAction extends Action<void, int> {
  /// Creates an action with no parameters that returns 7.
  const DefaultDescribeAction() : super(null);

  @override
  Future<int> run(LaneContext ctx) async => 7;
}
