import 'dart:io';

import 'package:dartlane/src/doctor/dart_sdk_check.dart';
import 'package:dartlane/src/doctor/project_checks.dart';
import 'package:dartlane/src/version.g.dart';
import 'package:dartlane_core/testing.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late FakeLaneContext ctx;

  setUp(() => ctx = FakeLaneContext());

  group('DartSdkCheck', () {
    Future<(bool, String, String?)> check(String version) async {
      final result = await DartSdkCheck(version: version).run(ctx);
      return (result.ok, result.message, result.fix);
    }

    test('is required and named', () {
      expect(DartSdkCheck().name, 'Dart SDK');
      expect(DartSdkCheck().isRequired, isTrue);
    });

    test('passes with the version the SDK reports', () async {
      final (ok, message, _) = await check(
        '3.12.2 (stable) (Tue Jun 9 01:11:39 2026 -0700) on "macos_arm64"',
      );

      expect(ok, isTrue);
      expect(message, '3.12.2');
    });

    test('passes with exactly the minimum', () async {
      expect((await check(minimumDartVersion)).$1, isTrue);
    });

    test('passes with a newer major version', () async {
      expect((await check('4.0.0')).$1, isTrue);
    });

    test('fails with an older one and says what to do', () async {
      for (final old in ['3.9.9', '3.0.0', '2.19.6']) {
        final (ok, message, fix) = await check(old);

        expect(ok, isFalse, reason: old);
        expect(
          message,
          '$old is older than the $minimumDartVersion that Dartlane needs.',
        );
        expect(fix, contains('flutter upgrade'));
      }
    });

    test('fails when the version cannot be read', () async {
      final (ok, message, fix) = await check('unknown');

      expect(ok, isFalse);
      expect(message, 'Could not read the Dart version from "unknown".');
      expect(fix, contains('dart.dev/get-dart'));
    });

    test('defaults to the Dart that is running', () async {
      final result = await DartSdkCheck().run(ctx);

      expect(result.ok, isTrue);
      expect(Platform.version, startsWith(result.message));
    });
  });

  group('project checks', () {
    late Directory project;

    setUp(() => project = Directory.systemTemp.createTempSync('dartlane_doc_'));
    tearDown(() => project.deleteSync(recursive: true));

    void write(String relative, [String content = '']) =>
        File(p.join(project.path, relative))
          ..createSync(recursive: true)
          ..writeAsStringSync(content);

    group('ProjectCheck', () {
      test('passes with the package name', () async {
        write('pubspec.yaml', 'name: my_app\n');

        final result = await ProjectCheck(project).run(ctx);

        expect(result.ok, isTrue);
        expect(result.message, 'my_app');
      });

      test('fails without a pubspec.yaml, with the hint from init', () async {
        final result = await ProjectCheck(project).run(ctx);

        expect(result.ok, isFalse);
        expect(result.message, 'No pubspec.yaml found in this folder.');
        expect(result.fix, contains('root of your Flutter or Dart project'));
      });

      test('fails when the pubspec has no name', () async {
        write('pubspec.yaml', 'description: nothing\n');

        final result = await ProjectCheck(project).run(ctx);

        expect(result.ok, isFalse);
        expect(result.message, 'pubspec.yaml has no package name.');
        expect(result.fix, isNotEmpty);
      });
    });

    group('LanesFileCheck', () {
      test('passes when dartlane/lanes.dart exists', () async {
        write('dartlane/lanes.dart');

        final result = await LanesFileCheck(project).run(ctx);

        expect(result.ok, isTrue);
        expect(result.message, 'dartlane/lanes.dart found');
      });

      test('fails with no dartlane/ folder and points to init', () async {
        final result = await LanesFileCheck(project).run(ctx);

        expect(result.ok, isFalse);
        expect(result.message, 'No dartlane/ folder found in this folder.');
        expect(result.fix, 'Run `dartlane init` to create it.');
      });

      test('fails when the folder has no lanes.dart', () async {
        write('dartlane/pubspec.yaml');

        final result = await LanesFileCheck(project).run(ctx);

        expect(result.ok, isFalse);
        expect(result.message, 'dartlane/lanes.dart was not found.');
      });
    });

    group('LanesDependenciesCheck', () {
      test('passes when the packages are installed', () async {
        write('dartlane/.dart_tool/package_config.json', '{}');

        final result = await LanesDependenciesCheck(project).run(ctx);

        expect(result.ok, isTrue);
        expect(result.message, 'installed');
      });

      test('fails when they are not, and says to run pub get', () async {
        write('dartlane/lanes.dart');

        final result = await LanesDependenciesCheck(project).run(ctx);

        expect(result.ok, isFalse);
        expect(
          result.message,
          'The packages in dartlane/ have not been installed.',
        );
        expect(result.fix, 'Run `dart pub get` in the dartlane/ folder.');
      });
    });
  });
}
