import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:dartlane/src/core/files.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:resource_portable/resource.dart';

import '../core/core.dart';

class InitCommand extends Command<int> {
  InitCommand({
    required DLogger logger,
  }) : _logger = logger;

  @override
  final description = 'Initializes the project with dartlane';

  @override
  String get name => 'init';

  final DLogger _logger;

  @override
  Future<int> run() async {
    // FileSystemUtils.checkAndCreateDirectory("dartlane");
    final process = await Process.start(
        'flutter',
        [
          'pub',
          'add',
          'dartlane',
          '--path=../',
        ],
        runInShell: true);

    // Listen to stdout and stderr streams
    process.stdout.listen((data) {
      _logger.info(String.fromCharCodes(data).trim());
    });

    process.stderr.listen((data) {
      _logger.err(String.fromCharCodes(data).trim());
    });

    // Wait for the process to complete
    final exitCode = await process.exitCode;
    final templateUri =
        Resource('package:dartlane/src/contents/lane_content.dart');
    final content = await templateUri.readAsString();
    FileSystemUtils.createFileFromTemplate(content, "Dartlane.dart", {});
    return ExitCode.success.code;
  }
}
