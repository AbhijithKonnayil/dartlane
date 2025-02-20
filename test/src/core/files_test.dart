import 'dart:convert';
import 'dart:io';

import 'package:dartlane/src/core/files.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

void main() {
  group('FileSystemUtils', () {
    const testDirPath = 'test_dir';
    const testFilePath = 'test_dir/test_file.txt';
    const testTemplateContent = 'Hello {{name}}!';
    const testData = {'name': 'World'};
    const testNewFilePath = 'test_dir/new_file.txt';

    setUp(() {
      // Ensure the test directory is clean before each test
      if (Directory(testDirPath).existsSync()) {
        Directory(testDirPath).deleteSync(recursive: true);
      }
    });

    tearDown(() {
      // Clean up the test directory after each test
      if (Directory(testDirPath).existsSync()) {
        Directory(testDirPath).deleteSync(recursive: true);
      }
    });

    test('checkAndCreateDirectory creates directory if it does not exist', () {
      bool onDirCreateSuccessCalled = false;

      FileSystemUtils.checkAndCreateDirectory(
        testDirPath,
        onDirCreateSuccess: () => onDirCreateSuccessCalled = true,
      );

      expect(Directory(testDirPath).existsSync(), isTrue);
      expect(onDirCreateSuccessCalled, isTrue);
    });

    test('checkAndCreateDirectory overwrites directory if user confirms', () {
      // Create a directory first
      Directory(testDirPath).createSync();
      bool onDirCreateSuccessCalled = false;

      // Mock stdin using IOOverrides
      IOOverrides.runZoned(
        () {
          FileSystemUtils.checkAndCreateDirectory(
            testDirPath,
            onDirCreateSuccess: () => onDirCreateSuccessCalled = true,
          );
        },
        stdin: StdinMock('yes').getInput,
      );

      expect(Directory(testDirPath).existsSync(), isTrue);
      expect(onDirCreateSuccessCalled, isTrue);
    });

    test('checkAndCreateDirectory skips directory creation if user declines',
        () {
      // Create a directory first
      Directory(testDirPath).createSync();
      bool onDirCreateFailedCalled = false;

      // Mock stdin using IOOverrides
      IOOverrides.runZoned(
        () {
          FileSystemUtils.checkAndCreateDirectory(
            testDirPath,
            onDirCreateFailed: () => onDirCreateFailedCalled = true,
          );
        },
        stdin: StdinMock('no').getInput,
      );

      expect(Directory(testDirPath).existsSync(), isTrue);
      expect(onDirCreateFailedCalled, isTrue);
    });

    test('createFileFromTemplate creates file with replaced placeholders', () {
      Directory(testDirPath).createSync();

      FileSystemUtils.createFileFromTemplate(
        testTemplateContent,
        testNewFilePath,
        testData,
      );

      final file = File(testNewFilePath);
      expect(file.existsSync(), isTrue);
      expect(file.readAsStringSync(), 'Hello World!');
    });

    test('replacePlaceholders replaces all placeholders correctly', () {
      const content = 'Hello {{name}}! Today is {{day}}.';
      const data = {'name': 'Alice', 'day': 'Monday'};

      final result = FileSystemUtils.replacePlaceholders(content, data);

      expect(result, 'Hello Alice! Today is Monday.');
    });
  });

  group('findDartlaneLanesFile', () {
    const projectPath = 'test_project';
    const lanesFilePath = '$projectPath/dartlane/lane.dart';

    setUp(() {
      // Ensure the test directory is clean before each test
      if (Directory(projectPath).existsSync()) {
        Directory(projectPath).deleteSync(recursive: true);
      }
    });

    tearDown(() {
      // Clean up the test directory after each test
      if (Directory(projectPath).existsSync()) {
        Directory(projectPath).deleteSync(recursive: true);
      }
    });

    test('returns null if lane.dart does not exist', () {
      final result = findDartlaneLanesFile(projectPath);
      expect(result, isNull);
    });

    test('returns File if lane.dart exists', () {
      Directory('$projectPath/dartlane').createSync(recursive: true);
      File(lanesFilePath).createSync();

      final result = findDartlaneLanesFile(projectPath);
      expect(result, isNotNull);
      expect(result!.path, lanesFilePath);
    });
  });
}

// Mock class to simulate stdin input
class StdinMock extends Mock implements Stdin {
  final String input;

  StdinMock(this.input);

  StdinMock getInput() {
    return this;
  }

  @override
  String? readLineSync(
      {Encoding encoding = systemEncoding, bool retainNewlines = false}) {
    return input;
  }
}
