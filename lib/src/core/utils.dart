import 'dart:io';

import 'package:dartlane/src/core/exception.dart';

class Utils {
  static String getEnvironmentVariable(String key) {
    try {
      final envVarValue = Platform.environment[key];
      if (envVarValue == null) {
        throw DException('Environment variable $key not found');
      }
      return envVarValue;
    } catch (e) {
      rethrow;
    }
  }
}
