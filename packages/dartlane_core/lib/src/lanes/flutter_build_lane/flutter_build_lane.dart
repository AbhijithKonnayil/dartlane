import 'dart:convert';
import 'dart:io';

import 'package:change_case/change_case.dart';
import 'package:dartlane/src/core/enums.dart';
import 'package:dartlane/src/lanes/flutter_build_lane/flutter_build_lane_args.dart';
import 'package:dartlane_core/dartlane_core.dart';

abstract class FlutterBuildLane extends Lane {
  FlutterBuildLane({
    DLogger? logger,
  }) {
    _logger = logger ?? DLogger();
  }

  factory FlutterBuildLane.forExeType({required ExecutableType exeType}) {
    switch (exeType) {
      case ExecutableType.apk:
        return FlutterBuildApkLane();
      // ignore: no_default_cases
      default:
        return FlutterBuildApkLane();
    }
  }
  late final DLogger _logger;
  late final List<String> dynamicArgs;
  List<String> get defaultArgs => <String>[
        'build',
        exeType.name,
      ];
  @override
  String get description => 'Build an executable for flutter';

  @override
  String get name => 'flutterBuild';

  ExecutableType get exeType;

  String get command => 'flutter';

  String get executedCommand =>
      [command, ...defaultArgs, ...dynamicArgs].join(' ');

  @override
  Future<void> execute(Map<String, String> laneArgs) async {
    dynamicArgs = getDynamicArgs(laneArgs);
    _logger.info('Executing `$executedCommand`');
    await executeProcess(defaultArgs, dynamicArgs);
  }

  Future<void> executeProcess(
    List<String> defaultArgs,
    List<String> dynamicArgs,
  ) async {
    try {
      final process = await Process.start(
        command,
        [
          ...defaultArgs,
          ...dynamicArgs,
        ],
        workingDirectory: Directory.current.path,
      );
      process.stdout.transform(utf8.decoder).listen((data) {
        _logger.info(data);
      });

      process.stderr.transform(utf8.decoder).listen((data) {
        _logger.err(data);
      });

      final exitCode = await process.exitCode;
      if (exitCode == 0) {
        _logger.success('$name Lane completed successfully.');
      } else {
        _logger.err('$name Lane failed with exit code $exitCode.');
      }
    } catch (e) {
      _logger.err('Error executing $name Lane: $e');
    }
  }

  List<String> getDynamicArgs(Map<String, String> laneArgs) {
    final dynamicArgs = <String>[];

    /// parse arguments of the form key value
    /// --flavor stgGlobal
    for (final element in [
      'flavor',
      'target',
      'dartDefine',
      'buildNumber',
      'buildName',
    ]) {
      final value = laneArgs[element];
      if (value != null) {
        dynamicArgs.addAll(['--${element.toParamCase()}', value]);
      }
    }

    /// parse arguments of the form key with multiple possible value
    /// --debug | --profile | --release

    for (final element in [
      'exeType',
    ]) {
      final value = laneArgs[element];
      if (value != null) {
        dynamicArgs.add('--$value');
      }
    }
    return dynamicArgs;
  }
}

class FlutterBuildApkLane extends FlutterBuildLane {
  FlutterBuildApkLane({super.logger});

  @override
  String get description => 'Build an Android APK file from your app.';

  @override
  String get name => 'flutterBuildApk';

  /// execute command Type safe
  Future<void> executeT(FlutterBuildLaneArgs laneArgs) async {}

  @override
  ExecutableType get exeType => ExecutableType.apk;
}

class FlutterBuildAppBundleLane extends FlutterBuildLane {
  FlutterBuildAppBundleLane({super.logger});

  @override
  String get description => 'Build an Android APK file from your app.';

  @override
  String get name => 'flutterBuildAppBundle';

  /// execute command Type safe
  Future<void> executeT(FlutterBuildLaneArgs laneArgs) async {}

  @override
  ExecutableType get exeType => ExecutableType.appbundle;
}
