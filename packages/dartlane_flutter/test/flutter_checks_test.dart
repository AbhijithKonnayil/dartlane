import 'dart:io';

import 'package:dartlane_core/dartlane_core.dart';
import 'package:dartlane_core/testing.dart';
import 'package:dartlane_flutter/dartlane_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late FakeLaneContext ctx;

  setUp(() => ctx = FakeLaneContext());

  group('FlutterSdkCheck', () {
    test('is required and named', () {
      const check = FlutterSdkCheck();

      expect(check.name, 'Flutter SDK');
      expect(check.isRequired, isTrue);
    });

    test('passes with the version Flutter reports', () async {
      ctx.shell.stub(
        'flutter --version',
        stdout:
            'Flutter 3.44.8 • channel stable • https://github.com/flutter/flutter.git\n'
            'Framework • revision abc123\n',
      );

      final result = await const FlutterSdkCheck().run(ctx);

      expect(result.ok, isTrue);
      expect(result.message, 'Flutter 3.44.8 • channel stable');
    });

    test('passes even when the first line has no bullets', () async {
      ctx.shell.stub('flutter --version', stdout: 'Flutter 3.44.8\n');

      expect(
        (await const FlutterSdkCheck().run(ctx)).message,
        'Flutter 3.44.8',
      );
    });

    test('fails with an install hint when flutter is not installed', () async {
      ctx.shell.stubMissing('flutter');

      final result = await const FlutterSdkCheck().run(ctx);

      expect(result.ok, isFalse);
      expect(result.message, 'The flutter command was not found.');
      expect(
        result.fix,
        contains('https://docs.flutter.dev/get-started/install'),
      );
      expect(result.fix, contains('flutter --version'));
    });

    test('fails when flutter exits with an error', () async {
      ctx.shell.stub(
        'flutter --version',
        exitCode: 1,
        stderr: 'Unable to find git in your PATH.\nmore\n',
      );

      final result = await const FlutterSdkCheck().run(ctx);

      expect(result.ok, isFalse);
      expect(
        result.message,
        '`flutter --version` exited with code 1. '
        'Unable to find git in your PATH.',
      );
      expect(result.fix, contains('flutter doctor'));
    });
  });

  group('FlutterFlavorsCheck', () {
    late Directory project;

    setUp(
      () => project = Directory.systemTemp.createTempSync('dartlane_flavors_'),
    );
    tearDown(() => project.deleteSync(recursive: true));

    void writeGradle(String name, String content) {
      File(p.join(project.path, 'android', 'app', name))
        ..createSync(recursive: true)
        ..writeAsStringSync(content);
    }

    FlutterFlavorsCheck check() =>
        FlutterFlavorsCheck(projectDirectory: project.path);

    test('is optional and named', () {
      expect(const FlutterFlavorsCheck().name, 'Flavors');
      expect(const FlutterFlavorsCheck().isRequired, isFalse);
    });

    test('lists the flavors from build.gradle.kts', () async {
      writeGradle(
        'build.gradle.kts',
        'productFlavors { create("dev") { } create("prod") { } }',
      );

      final result = await check().run(ctx);

      expect(result.ok, isTrue);
      expect(result.message, 'dev, prod');
    });

    test('lists the flavors from build.gradle', () async {
      writeGradle('build.gradle', 'productFlavors { staging { } prod { } }');

      expect((await check().run(ctx)).message, 'staging, prod');
    });

    test('prefers build.gradle.kts when both exist', () async {
      writeGradle('build.gradle.kts', 'productFlavors { create("kts") { } }');
      writeGradle('build.gradle', 'productFlavors { groovy { } }');

      expect((await check().run(ctx)).message, 'kts');
    });

    test('a project without flavors passes', () async {
      writeGradle('build.gradle', 'android { compileSdk 34 }');

      final result = await check().run(ctx);

      expect(result.ok, isTrue);
      expect(result.message, 'none (a single build variant)');
    });

    test('a project without an android folder passes', () async {
      final result = await check().run(ctx);

      expect(result.ok, isTrue);
      expect(result.message, contains('nothing to check'));
    });
  });

  group('flutterChecks', () {
    test('gives the SDK check and the flavors check', () {
      final checks = flutterChecks();

      expect(checks, hasLength(2));
      expect(checks[0], isA<FlutterSdkCheck>());
      expect(checks[1], isA<FlutterFlavorsCheck>());
    });

    test('passes the project directory to the flavors check', () {
      final checks = flutterChecks(projectDirectory: 'app');

      expect((checks[1] as FlutterFlavorsCheck).projectDirectory, 'app');
    });

    test('they run together through the doctor', () async {
      ctx.shell.stub(
        'flutter --version',
        stdout: 'Flutter 3.44.8 • channel stable\n',
      );

      final code = await runDoctor(flutterChecks(), ctx);

      expect(code, ExitCodes.success);
      expect(
        ctx.logger.lines.first,
        '✓ Flutter SDK: Flutter 3.44.8 • channel stable',
      );
      expect(ctx.logger.lines.last, 'All required checks passed.');
    });
  });
}
