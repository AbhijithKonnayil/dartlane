import 'dart:async';

import 'package:dartlane_core/src/lane_context.dart';

/// The body of a lane.
typedef LaneBody = FutureOr<void> Function(LaneContext ctx);

/// A named workflow: a plain Dart function that calls actions in order.
class Lane {
  /// Creates a lane from a [description] and a [body].
  ///
  /// ```dart
  /// Lane('Check the code', (ctx) async {
  ///   await ctx.run(MyAnalyzeAction());
  /// });
  /// ```
  const Lane(this.description, this.body);

  /// One line shown when lanes are listed.
  final String description;

  /// The workflow itself.
  final LaneBody body;

  /// Runs the lane with [ctx].
  Future<void> run(LaneContext ctx) async => body(ctx);
}
