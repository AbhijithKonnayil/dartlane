import 'dart:io';

import 'package:dartlane/src/core/exception.dart';
import 'package:dartlane_core/dartlane_core.dart';
import 'package:yaml_edit/yaml_edit.dart';

enum VersionComponent { versionName, versionCode, patch, major, minor }

class Versioner extends Lane {
  Versioner({
    DLogger? logger,
  }) {
    _logger = logger ?? DLogger();
  }

  @override
  String get name => 'versioner';

  @override
  String get description => 'updates the version in pubspec.yaml';
  late final DLogger _logger;

  @override
  Future<LaneResponse> executeLogic(Map<String, String> laneArgs) async {
    /* 
    ```
    pubspecFile
    versionComponent

    ```
     */
    final pubspecFile = laneArgs['pubspecFile'] ?? 'pubspec.yaml';
    final file = File(pubspecFile);
    if (!file.existsSync()) {
      throw Exception("Pubspec doesn't exist");
    }
    final content = await file.readAsString();
    final yamlEditor = YamlEditor(content);
    final currentVersion = yamlEditor.parseAt(['version']).value as String;
    final versionRegExp = RegExp(r'^\d+\.\d+\.\d+\+\d+$');
    if (!versionRegExp.hasMatch(currentVersion)) {
      throw DException(
        'Current version($currentVersion) is not in valid pattern',
      );
    }

    _logger.info('Current Version : $currentVersion');
    //TODO
    //current version regex check
    final newVersion = getVersion(
      laneArgs: laneArgs,
      currentVersion: currentVersion,
    );
    yamlEditor.update(['version'], newVersion);
    file.writeAsStringSync(yamlEditor.toString());
    _logger.info('Updated Version : $newVersion');
    return LaneResponse.success();
  }

  String getVersion({
    required Map<String, String> laneArgs,
    required String currentVersion,
  }) {
    var versionName = getVersionName(currentVersion);
    var versionCode = getVersionCode(currentVersion);
    final versionComponentFromArgs = laneArgs['versionComponent'];
    final versionComponent = getVersionComponent(
      versionComponentFromArgs,
    );
    final nameParts = versionName.split('.').map(int.parse).toList();
    final value = laneArgs['value'];

    switch (versionComponent) {
      case VersionComponent.versionName:
        versionName = value ?? getVersionName(currentVersion);
        return '$versionName+$versionCode';
      case VersionComponent.versionCode:
        versionCode = value ?? '${int.parse(versionCode) + 1}';
        return '$versionName+$versionCode';
      case VersionComponent.patch:
        nameParts[2] = value != null ? int.parse(value) : nameParts[2] + 1;
      case VersionComponent.minor:
        nameParts[1] = value != null ? int.parse(value) : nameParts[1] + 1;
        nameParts[2] = 0;
      case VersionComponent.major:
        nameParts[0] = value != null ? int.parse(value) : nameParts[0] + 1;
        nameParts[1] = 0;
        nameParts[2] = 0;
    }
    return '${nameParts.join('.')}+$versionCode';
  }

  VersionComponent getVersionComponent(String? versionComponentFromArgs) {
    try {
      if (versionComponentFromArgs == null) {
        throw Exception('Invalid Version Component');
      }
      return VersionComponent.values.byName(versionComponentFromArgs);
    } catch (e) {
      throw Exception('Invalid Version Component');
    }
  }

  String getVersionCode(String version) => version.split('+').last;

  String getVersionName(String version) => version.split('+').first;
}
