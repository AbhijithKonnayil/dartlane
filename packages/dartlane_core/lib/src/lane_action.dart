import 'package:dartlane_core/src/lane_context.dart';

/// One reusable, typed step, for example building an APK or uploading it.
///
/// [R] is the type of the result. An action keeps its parameters as ordinary
/// fields set by its constructor, so a lane reads like
/// `FlutterBuild(target: BuildTarget.apk, flavor: 'prod')`. An action with no
/// result uses `void`.
///
/// Call actions through [LaneContext.run], never [run] directly, so every step
/// is logged and timed the same way.
abstract class LaneAction<R> {
  /// Creates an action.
  const LaneAction();

  /// Does the work and returns the result.
  Future<R> run(LaneContext ctx);

  /// A short, human readable line saying what this action does.
  ///
  /// Used in step logs and, later, in dry-run output. Defaults to the class
  /// name; override it to include the parameters that matter.
  String describe() => runtimeType.toString();
}
