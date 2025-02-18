import 'dart:io';

import 'package:dartlane/src/core/logger.dart';

class FileSystemUtils {
  static final DLogger _logger = DLogger();

  static void checkAndCreateDirectory(String path) {
    final directory = Directory(path);

    if (directory.existsSync()) {
      _logger.err('Directory already exists: ${directory.path}');
    } else {
      directory.createSync(recursive: true);
      _logger.info('Directory created: ${directory.path}');
    }
  }

  static void createFileFromTemplate(
      String content, String newFilePath, Map<String, String> data) {
    try {
      // Read the template file
      final templateContent = content;

      // Replace placeholders with actual data
      final newContent = _replacePlaceholders(templateContent, data);

      // Write the new file
      final newFile = File(newFilePath);
      newFile.writeAsStringSync(newContent);

      print('File created successfully: $newFilePath');
    } catch (e) {
      print('Error: $e');
    }
  }

  static String _replacePlaceholders(String content, Map<String, String> data) {
    var newContent = content;
    data.forEach((key, value) {
      newContent = newContent.replaceAll('{{$key}}', value);
    });
    return newContent;
  }
}

File? findDartlaneLanesFile(String projectPath) {
  final file = File('$projectPath/dartlane/lane.dart');
  if (file.existsSync()) {
    return file;
  }
  return null;
}
