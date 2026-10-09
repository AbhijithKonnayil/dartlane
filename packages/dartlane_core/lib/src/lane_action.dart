import 'package:dartlane_core/src/dry_run.dart';
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
  /// Used in step logs and in dry-run output, where it is the step's line.
  /// Defaults to the class name; override it to include the parameters that
  /// matter.
  String describe() => runtimeType.toString();

  /// What [LaneContext.run] returns in a dry run, in place of running [run].
  ///
  /// A dry run never calls [run], so the next step still needs something to
  /// work with. Override this to return a believable placeholder, for example a
  /// build result with the path the artifact would have. It must have no side
  /// effects, and it is the place to check the action's own options, so a dry
  /// run catches mistakes too.
  ///
  /// The default returns null, which suits an action with no result (`void` or
  /// a nullable type). For any other result type there is nothing to return, so
  /// it throws a [DryRunStopped] and the dry run ends at this step.
  R dryRunResult(LaneContext ctx) {
    // True for `void` and for nullable result types.
    if (null is R) return null as R;
    throw DryRunStopped(
      '${describe()} returns a result that a dry run cannot make up. '
      'Override dryRunResult in the action to let a dry run continue past it.',
    );
  }
}
