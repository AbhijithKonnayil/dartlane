import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:dartlane/src/core/files.dart';
import 'package:dartlane/src/core/logger.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:resource_portable/resource.dart';

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
      runInShell: true,
    );

    // Listen to stdout and stderr streams
    process.stdout.listen((data) {
      _logger.detail(String.fromCharCodes(data).trim());
    });

    process.stderr.listen((data) {
      _logger.err(String.fromCharCodes(data).trim());
    });

    // Wait for the process to complete
    await process.exitCode;
    const templateUri =
        Resource('package:dartlane/src/contents/lane_content.dart');
    final content = await templateUri.readAsString();
    FileSystemUtils.checkAndCreateDirectory(
      'dartlane',
      onDirCreateSuccess: () {
        FileSystemUtils.createFileFromTemplate(
          content,
          'dartlane/lane.dart',
          {},
        );
        _logger.success('Dartlane initializated successfully !!');
      },
      onDirCreateFailed: () {
        _logger.err('Dartlane initialization canceled !!');
      },
    );
    return ExitCode.success.code;
  }
}
