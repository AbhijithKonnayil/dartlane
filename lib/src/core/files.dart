import 'dart:io';

import 'package:dartlane/src/core/logger.dart';

class FileSystemUtils {
  static final DLogger _logger = DLogger();

  static void checkAndCreateDirectory(
    String path, {
    void Function()? onDirCreateSuccess,
    void Function()? onDirCreateFailed,
  }) {
    final directory = Directory(path);

    if (directory.existsSync()) {
      _logger.err('Directory already exists: ${directory.path}');
      stdout.write('Do you want to overwrite it? (yes/no): ');
      final response = stdin.readLineSync()?.toLowerCase();

      if (response == 'yes') {
        // Delete the existing directory and create a new one
        directory
          ..deleteSync(recursive: true)
          ..createSync(recursive: true);
        _logger.info('Directory overwritten: ${directory.path}');
        onDirCreateSuccess?.call();
      } else {
        _logger.info('Directory creation skipped.');
        onDirCreateFailed?.call();
      }
    } else {
      directory.createSync(recursive: true);
      _logger.info('Directory created: ${directory.path}');
      onDirCreateSuccess?.call();
    }
  }

  static void createFileFromTemplate(
    String content,
    String newFilePath,
    Map<String, String> data,
  ) {
    try {
      // Read the template file
      final templateContent = content;

      // Replace placeholders with actual data
      final newContent = replacePlaceholders(templateContent, data);

      // Write the new file
      File(newFilePath).writeAsStringSync(newContent);

      _logger.info('File created successfully: $newFilePath');
    } catch (e) {
      _logger.err('Error: $e');
    }
  }

  static String replacePlaceholders(String content, Map<String, String> data) {
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
