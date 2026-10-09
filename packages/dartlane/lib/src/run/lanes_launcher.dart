import 'dart:io';

import 'package:dartlane/src/init/lane_package.dart';
import 'package:dartlane_core/dartlane_core.dart';
import 'package:path/path.dart' as p;

/// Starts the user's lanes program and waits for it to finish.
///
/// The CLI does not run lanes itself. The lanes live in the project's own
/// `dartlane/lanes.dart`, which calls `dartlane()` from `dartlane_core`. This
/// only launches that program, so tests can replace it with a fake.
// An interface rather than a function type so the real launcher and the fake
// can be named and documented.
// ignore: one_member_abstracts
abstract interface class LanesLauncher {
  /// Runs `dartlane/lanes.dart` of the project in [projectRoot] with
  /// [arguments], and returns its exit code.
  Future<int> launch({
    required Directory projectRoot,
    required List<String> arguments,
  });
}

/// The real [LanesLauncher]: runs `dart run dartlane/lanes.dart <arguments>`.
///
/// By default the program shares this process's terminal, so its output
/// appears live and it can still tell that a person is there. It runs in the
/// project root, which is where lanes such as a Flutter build expect to run.
///
/// With `inheritStdio: false` the program's output is captured and discarded
/// instead, which keeps tests quiet.
class ProcessLanesLauncher implements LanesLauncher {
  /// Creates a launcher that starts real processes.
  const ProcessLanesLauncher({this.inheritStdio = true});

  /// Whether the program shares this process's terminal.
  final bool inheritStdio;

  @override
  Future<int> launch({
    required Directory projectRoot,
    required List<String> arguments,
  }) async {
    // The Dart that is running the CLI, not whichever `dart` is first on PATH.
    final executable = Platform.resolvedExecutable;
    final command = [
      'run',
      p.join(LanePackage.folderName, LanePackage.lanesFileName),
      ...arguments,
    ];

    final int code;
    if (inheritStdio) {
      final process = await Process.start(
        executable,
        command,
        workingDirectory: projectRoot.path,
        mode: ProcessStartMode.inheritStdio,
      );
      code = await process.exitCode;
    } else {
      final result = await Process.run(
        executable,
        command,
        workingDirectory: projectRoot.path,
      );
      code = result.exitCode;
    }
    // A negative code means the program was stopped by a signal.
    return code < 0 ? ExitCodes.failure : code;
  }
}
