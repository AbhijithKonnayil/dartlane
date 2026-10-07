import 'dart:io';

import 'package:dartlane/src/render_template.dart';
import 'package:dartlane/src/templates.g.dart';
import 'package:dartlane/src/version.dart';
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

  test('the generated pubspec has no placeholders left once rendered', () {
    final rendered = renderTemplate(Templates.pubspec, {
      'package_name': 'x_dartlane',
      'app_name': 'x',
      'version': dartlaneVersion,
    });
    expect(rendered, isNot(contains('{{')));
    final yaml = loadYaml(rendered) as YamlMap;
    expect(yaml['name'], 'x_dartlane');
  });

  test('dartlaneVersion matches the version in pubspec.yaml', () {
    final pubspec =
        loadYaml(File('pubspec.yaml').readAsStringSync()) as YamlMap;
    expect(dartlaneVersion, pubspec['version']);
  });
}
