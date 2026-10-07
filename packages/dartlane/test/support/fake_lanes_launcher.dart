import 'dart:io';

import 'package:dartlane/src/run/lanes_launcher.dart';

/// A [LanesLauncher] that starts nothing. It records each launch and answers
/// with [exitCode].
class FakeLanesLauncher implements LanesLauncher {
  /// Creates a launcher whose launches finish with [exitCode].
  FakeLanesLauncher({this.exitCode = 0});

  /// What every launch returns.
  int exitCode;

  /// Every launch so far, in order.
  final calls = <({Directory projectRoot, List<String> arguments})>[];

  @override
  Future<int> launch({
    required Directory projectRoot,
    required List<String> arguments,
  }) async {
    calls.add((projectRoot: projectRoot, arguments: arguments));
    return exitCode;
  }
}
