import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:dartlane/src/run/lanes_launcher.dart';
import 'package:dartlane/src/run/lanes_program.dart';

/// `dartlane list`: prints the lanes in `dartlane/lanes.dart` with their
/// descriptions.
///
/// The lanes only exist inside the user's program, so this starts it with
/// `--list` and lets `dartlane_core` print them. The command exits with the
/// program's exit code.
class ListCommand extends Command<int> {
  /// Creates the command.
  ///
  /// [workingDirectory] is the project root and [launcher] starts the lanes
  /// program.
  ListCommand({required this.launcher, required this.workingDirectory});

  /// Starts the lanes program.
  final LanesLauncher launcher;

  /// The project root.
  final Directory workingDirectory;

  @override
  String get name => 'list';

  @override
  String get description => 'List the lanes in dartlane/lanes.dart.';

  @override
  bool get takesArguments => false;

  @override
  String get invocation => 'dartlane list';

  @override
  Future<int> run() => LanesProgram(
    projectRoot: workingDirectory,
    launcher: launcher,
  ).run(const ['--list']);
}
