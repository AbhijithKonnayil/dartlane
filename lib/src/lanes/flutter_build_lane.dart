import 'dart:io';

import 'package:dartlane/src/core/logger.dart';
import 'package:dartlane/src/lanes/lane.dart';

enum BuildType { debug, release, profile, s }

class FlutterBuildLane extends Lane {
  FlutterBuildLane({DLogger? logger, BuildType? buildType}) {
    _logger = logger ?? DLogger();
    _buildType = buildType ?? BuildType.release;
  }
  late final DLogger _logger;
  late final BuildType _buildType;

  @override
  String get description => 'Build an executable for flutter';

  @override
  Future<void> execute(Map<String, String> laneArgs) {
    throw UnimplementedError();
  }
}

class FlutterBuildApkLane extends FlutterBuildLane {
  FlutterBuildApkLane({super.buildType, super.logger});

  @override
  String get description => 'Build an Android APK file from your app.';

  String get name => 'flutterBuildApk';

  @override
  Future<void> execute(Map<String, String> laneArgs) async {
    _logger.info('Executing $name Lane');
    try {
      final process = await Process.start(
        'flutter',
        [
          'build',
          'apk',
          '--${_buildType.name}', //--release , --debug, --profile
        ],
        workingDirectory: Directory.current.path,
      );
      process.stdout.listen((data) {
        _logger.info(String.fromCharCodes(data));
      });

      process.stderr.listen((data) {
        _logger.err(String.fromCharCodes(data));
      });

      final exitCode = await process.exitCode;
      if (exitCode == 0) {
        _logger.info('$name Lane completed successfully.');
      } else {
        _logger.err('$name Lane failed with exit code $exitCode.');
      }
    } catch (e) {
      _logger.err('Error executing $name Lane: $e');
    }
  }
}
