import 'package:dartlane_core/src/lane_context.dart';

/// One reusable, typed step, for example building an APK or uploading it.
///
/// [P] is the type of the parameters the action was created with and [R] is
/// the type of its result. An action with no parameters uses `void` for [P]
/// and passes `null` to the constructor.
///
/// Call actions through [LaneContext.run], never [run] directly, so every step
/// is logged and timed the same way.
abstract class Action<P, R> {
  /// Creates an action with its [params].
  const Action(this.params);

  /// The parameters this action was created with.
  final P params;

  /// Does the work and returns the result.
  Future<R> run(LaneContext ctx);

  /// A short, human readable line saying what this action does.
  ///
  /// Used in step logs and, later, in dry-run output. Defaults to the class
  /// name; override it to include the parameters that matter.
  String describe() => runtimeType.toString();
}
