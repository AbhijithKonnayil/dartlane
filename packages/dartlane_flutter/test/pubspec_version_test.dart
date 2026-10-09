import 'dart:io';

import 'package:dartlane_core/dartlane_core.dart';
import 'package:dartlane_core/testing.dart';
import 'package:dartlane_flutter/dartlane_flutter.dart';
import 'package:test/test.dart';

const _pubspec = '''
# App
name: app
version: 1.2.3+45 # release
description: x

dependencies:
  # keep me
  path: ^1.9.1
''';

void main() {
  group('PubspecVersion', () {
    test('parses and prints', () {
      expect(PubspecVersion.parse('1.2.3').toString(), '1.2.3');
      expect(PubspecVersion.parse('1.2.3+45').build, 45);
      expect(PubspecVersion.parse('1.2.3-beta.1+4').name, '1.2.3-beta.1');
      expect(() => PubspecVersion.parse('1.2'), throwsFormatException);
    });

    test('bumps each part', () {
      final v = PubspecVersion.parse('1.2.3+45');
      expect(v.bump(VersionBump.major).toString(), '2.0.0+45');
      expect(v.bump(VersionBump.minor).toString(), '1.3.0+45');
      expect(v.bump(VersionBump.patch).toString(), '1.2.4+45');
      expect(v.bump(VersionBump.build).toString(), '1.2.3+46');
      expect(
        PubspecVersion.parse('1.0.0').bump(VersionBump.build).toString(),
        '1.0.0+1',
      );
    });
  });

  group('actions', () {
    late Directory dir;
    late FakeLaneContext ctx;
    late File file;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('pubspec');
      file = File('${dir.path}/pubspec.yaml')..writeAsStringSync(_pubspec);
      ctx = FakeLaneContext();
    });
    tearDown(() => dir.deleteSync(recursive: true));

    test('read returns the version', () async {
      final v = await ctx.run(ReadPubspecVersion(workingDirectory: dir.path));
      expect(v.toString(), '1.2.3+45');
    });

    test('bump rewrites only the version and keeps the rest', () async {
      final v = await ctx.run(
        BumpPubspecVersion(VersionBump.minor, workingDirectory: dir.path),
      );
      expect(v.toString(), '1.3.0+45');
      expect(
        file.readAsStringSync(),
        _pubspec.replaceFirst('1.2.3+45', '1.3.0+45'),
      );
    });

    test('dry run returns the new version and writes nothing', () async {
      final dry = FakeLaneContext(dryRun: true);
      final v = await dry.run(
        BumpPubspecVersion(VersionBump.build, workingDirectory: dir.path),
      );
      expect(v.toString(), '1.2.3+46');
      expect(file.readAsStringSync(), _pubspec);
    });

    test('missing file or version is a UserError', () {
      expect(
        ctx.run(ReadPubspecVersion(workingDirectory: '${dir.path}/none')),
        throwsA(isA<UserError>()),
      );
      file.writeAsStringSync('name: x\n');
      expect(
        ctx.run(ReadPubspecVersion(workingDirectory: dir.path)),
        throwsA(isA<UserError>()),
      );
    });
  });
}
