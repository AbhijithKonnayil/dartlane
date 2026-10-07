import 'dart:io';

import 'package:dartlane/src/render_template.dart';
import 'package:dartlane/src/templates.g.dart';
import 'package:dartlane/src/version.g.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  group('renderTemplate', () {
    test('replaces every occurrence of each placeholder', () {
      expect(
        renderTemplate('{{a}} and {{a}} and {{b}}', {'a': '1', 'b': '2'}),
        '1 and 1 and 2',
      );
    });

    test('leaves unknown placeholders alone', () {
      expect(renderTemplate('{{a}} {{c}}', {'a': '1'}), '1 {{c}}');
    });
  });

  group('templates.g.dart is up to date with templates/', () {
    // If one of these fails, run `dart run melos run generate`.
    const embedded = {
      'pubspec.yaml.tmpl': Templates.pubspec,
      'lanes.dart': Templates.lanes,
      'config.dart': Templates.config,
      'pubspec_overrides.yaml.tmpl': Templates.overrides,
    };

    for (final MapEntry(:key, :value) in embedded.entries) {
      test(key, () {
        expect(
          File('templates/$key').readAsStringSync(),
          value,
          reason: 'Run `dart run melos run generate`.',
        );
      });
    }
  });

  group('the generated pubspec', () {
    final rendered = renderTemplate(Templates.pubspec, {
      'package_name': 'x_dartlane',
      'app_name': 'x',
      'version': dartlaneVersion,
      'minimum_dart': minimumDartVersion,
    });

    test('has no placeholders left once rendered', () {
      expect(rendered, isNot(contains('{{')));
      expect((loadYaml(rendered) as YamlMap)['name'], 'x_dartlane');
    });

    test('asks for the minimum Dart that doctor checks', () {
      expect(rendered, contains('sdk: ^$minimumDartVersion'));
    });

    test('depends on the packages at this version', () {
      expect(rendered, contains('dartlane_core: ^$dartlaneVersion'));
      expect(rendered, contains('dartlane_flutter: ^$dartlaneVersion'));
    });
  });

  test('minimumDartVersion matches the sdk constraint in pubspec.yaml', () {
    final pubspec =
        loadYaml(File('pubspec.yaml').readAsStringSync()) as YamlMap;
    expect((pubspec['environment'] as YamlMap)['sdk'], '^$minimumDartVersion');
  });

  test('dartlaneVersion matches the version in pubspec.yaml', () {
    final pubspec =
        loadYaml(File('pubspec.yaml').readAsStringSync()) as YamlMap;
    expect(dartlaneVersion, pubspec['version']);
  });
}
