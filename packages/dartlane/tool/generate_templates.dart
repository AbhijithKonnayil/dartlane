// Embeds the files in `templates/` into `lib/src/templates.g.dart`.
//
// Run it with `dart run melos run generate` after editing a template. It needs
// only dart:io, so it works from any directory.
//
// ignore_for_file: avoid_print
import 'dart:io';

/// Constant name, template file, and the doc comment for the constant.
const List<({String doc, String file, String name})> _templates = [
  (
    name: 'pubspec',
    file: 'pubspec.yaml.tmpl',
    doc:
        '`dartlane/pubspec.yaml`. Placeholders: `package_name`, `app_name`, '
        '`version`.',
  ),
  (name: 'lanes', file: 'lanes.dart', doc: '`dartlane/lanes.dart`.'),
  (name: 'config', file: 'config.dart', doc: '`dartlane/config.dart`.'),
  (
    name: 'overrides',
    file: 'pubspec_overrides.yaml.tmpl',
    doc:
        '`dartlane/pubspec_overrides.yaml`, only for developing Dartlane '
        'itself. Placeholder: `repo`.',
  ),
];

void main() {
  final root = File.fromUri(Platform.script).parent.parent;
  final out = StringBuffer()
    ..writeln('// GENERATED CODE - DO NOT MODIFY BY HAND.')
    ..writeln(
      '// Edit the files in templates/ and run `dart run melos run '
      'generate`.',
    )
    ..writeln()
    ..writeln(
      '/// The files `dartlane init` creates, as Dart string constants.',
    )
    ..writeln('///')
    ..writeln('/// Generated from the files in `templates/`.')
    ..writeln('abstract final class Templates {');

  for (final template in _templates) {
    final content = File(
      '${root.path}/templates/${template.file}',
    ).readAsStringSync();
    if (content.contains("'''")) {
      stderr.writeln("${template.file} contains ''' and cannot be embedded.");
      exit(1);
    }
    out
      ..writeln('  /// ${template.doc}')
      // A leading newline after the opening quotes is not part of the string.
      ..writeln("  static const ${template.name} = r'''")
      ..write(content)
      ..writeln("''';")
      ..writeln();
  }
  // Drop the blank line after the last constant.
  final text = '${out.toString().trimRight()}\n}\n';

  final target = File('${root.path}/lib/src/templates.g.dart')
    ..writeAsStringSync(text);
  Process.runSync(Platform.resolvedExecutable, ['format', target.path]);
  print('Wrote ${target.path}');
}
