import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:change_case/change_case.dart';
import 'package:dartlane/src/contents/add_lane_content.dart';
import 'package:dartlane/src/core/files.dart';
import 'package:dartlane/src/core/io.dart';
import 'package:dartlane_core/dartlane_core.dart';

class AddLaneCommand extends Command<int> {
  AddLaneCommand({
    required DLogger logger,
  }) : _logger = logger;

  @override
  final description = 'Initializes a Lane';

  @override
  String get name => 'add-lane';

  final DLogger _logger;

  @override
  Future<int> run() async {
    final laneName = readInput(
      'Enter the lane name',
      defaultValue: 'custom_lane',
    );
    final directory = readInput(
      'Enter the directory name',
      defaultValue: laneName.toSnakeCase(),
    );
    final className = readInput(
      'Enter the class Name',
      defaultValue: laneName.toPascalCase(),
    );
    final argsClassName = readInput(
      'Enter the class Name',
      defaultValue: '${laneName}Args'.toPascalCase(),
    );
    final data = {
      'LANE_CLASSNAME': className,
      'LANE_ARGS_CLASSNAME': argsClassName,
      'LANE_FILENAME': directory,
    };
    FileSystemUtils.checkAndCreateDirectory(
      directory,
      onDirCreateSuccess: () {
        FileSystemUtils.createFileFromTemplate(
          LANE_CONTENT,
          '$directory/${className.toSnakeCase()}.dart',
          data,
        );
        FileSystemUtils.createFileFromTemplate(
          LANE_ARGS_CONTENT,
          '$directory/${className.toSnakeCase()}_args.dart',
          data,
        );
      },
    );
    final root = findProjectRoot();
    final process = await Process.start(
      'dart',
      ['run', 'build_runner', 'build'],
      workingDirectory: root,
    );
    process.stdout.transform(utf8.decoder).listen(_logger.info);

    process.stderr.transform(utf8.decoder).listen(_logger.err);

    final exitCode = await process.exitCode;
    return exitCode;
  }
}
