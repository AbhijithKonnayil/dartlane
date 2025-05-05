import 'dart:io';

import 'package:dartlane/src/core/enums.dart';
import 'package:dartlane/src/core/exception.dart';
import 'package:dartlane/src/lanes/firebase_app_distribution/constants.dart';
import 'package:path/path.dart' as path;

class FirebaseAppDistributionHelper {
  /// Determines the binary type based on the file extension.
  ExecutableType binaryTypeFromPath(String binaryPath) {
    final extension = path.extension(binaryPath).toLowerCase();
    switch (extension) {
      case '.apk':
        return ExecutableType.apk;
      case '.aab':
        return ExecutableType.appbundle;
      case '.ipa':
        return ExecutableType.ipa;
      default:
        throw DException(Messages.UNSUPPORTED_FILE_FORMAT);
    }
  }

  /// Reads a value from a file if the value is null or empty.
  String? getValueFromValueOrFile({String? value, String? filePath}) {
    if ((value == null || value.isEmpty) && filePath != null) {
      try {
        return File(filePath).readAsStringSync();
      } catch (e) {
        throw DException(filePath, title: 'Invalid path');
      }
    }
    return value;
  }

  String? appIdFromParams(
    Map<String, String> params,
  ) {
    try {
      if (params['app'] != null) {
        return params['app'];
      }
      throw DException(Messages.APP_ID_NOT_FOUND);
    } catch (e) {
      rethrow;
    }
  }

  /// Extracts the project number from the app ID.
  String projectNumberFromAppId(String appId) {
    return appId.split(':')[1];
  }

  /// Constructs the app name from the app ID.
  String appNameFromAppId(String appId) {
    final projectNumber = projectNumberFromAppId(appId);
    return '${projectName(projectNumber)}/apps/$appId';
  }

  /// Constructs the project namegetAuthorization from the project number.
  String projectName(String projectNumber) {
    return 'projects/$projectNumber';
  }

  /// Constructs the group name from the project number and group alias.
  String groupName(String projectNumber, String groupAlias) {
    return '${projectName(projectNumber)}/groups/$groupAlias';
  }

  String? getIosAppIdFromArchivePlist(
    String xcodeArchivePath,
    String plistPath,
  ) {
    return null;

    // TODO(abhijithkonnayil): impement this function for ios
    // this will be used to get the app id from the archive plist , will be used in `appIdFromParams()`
  }
  FlutterPlatform platformFromAppId(String appId) {
    try {
      if (appId.contains(':ios:')) {
        return FlutterPlatform.ios;
      } else if (appId.contains(':android:')) {
        return FlutterPlatform.android;
      } else {
        throw DException('Unknown Platform');
      }
    } catch (e) {
      rethrow;
    }
  }
}
