import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:dartlane/src/doctor/dart_sdk_check.dart';
import 'package:dartlane/src/doctor/project_checks.dart';
import 'package:dartlane/src/run/lanes_launcher.dart';
import 'package:dartlane/src/run/lanes_program.dart';
import 'package:dartlane_core/dartlane_core.dart';

/// `dartlane doctor`: checks that the setup is ready to run lanes.
///
/// It first checks what the CLI can see by itself: the Dart SDK, the project,
/// and `dartlane/`. If those pass, it starts the lanes program with `--doctor`
/// so the checks that action packages contribute, such as the Flutter SDK and
/// credentials, run too. If a basic check fails the lanes program cannot start,
/// so it is skipped.
///
/// The exit code is non-zero if any required check fails.
class DoctorCommand extends Command<int> {
  /// Creates the command.
  ///
  /// [workingDirectory] is the project root and [launcher] starts the lanes
  /// program. [logger] prints the results.
  DoctorCommand({
    required this.logger,
    required this.launcher,
    required this.workingDirectory,
    DoctorCheck? dartSdkCheck,
  }) : _dartSdkCheck = dartSdkCheck ?? DartSdkCheck();

  /// Where results are printed.
  final LaneLogger logger;

  /// Starts the lanes program.
  final LanesLauncher launcher;

  /// The project root.
  final Directory workingDirectory;

  final DoctorCheck _dartSdkCheck;

  @override
  String get name => 'doctor';

  @override
  String get description =>
      'Check that Dart, Flutter and the project are ready to run lanes.';

  @override
  bool get takesArguments => false;

  @override
  String get invocation => 'dartlane doctor';

  @override
  Future<int> run() async {
    final ctx = LaneContext(logger: logger);
    try {
      final report = await runDoctorChecks([
        _dartSdkCheck,
        ProjectCheck(workingDirectory),
        LanesFileCheck(workingDirectory),
        LanesDependenciesCheck(workingDirectory),
      ], ctx);

      if (!report.ok) {
        // The lanes program cannot start, so its checks are skipped.
        printDoctorSummary(report, logger);
        return report.exitCode;
      }

      // The program prints its own results and the summary, and its exit code
      // says whether a required check failed.
      return await LanesProgram(
        projectRoot: workingDirectory,
        launcher: launcher,
      ).run(const ['--doctor']);
    } finally {
      ctx.close();
    }
  }
}
