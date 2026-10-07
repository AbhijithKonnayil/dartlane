import 'dart:io';

import 'package:dartlane/src/init/app_project.dart';
import 'package:dartlane/src/init/gitignore.dart';
import 'package:dartlane/src/init/lane_package.dart';
import 'package:dartlane_core/dartlane_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory dir;

  File file(String relative) => File(p.join(dir.path, relative));

  setUp(() => dir = Directory.systemTemp.createTempSync('dartlane_units_'));
  tearDown(() => dir.deleteSync(recursive: true));

  group('AppProject.read', () {
    test('reads the package name', () {
      file('pubspec.yaml').writeAsStringSync('name: my_app\n');

      final project = AppProject.read(dir);

      expect(project.name, 'my_app');
      expect(project.root.path, dir.path);
      expect(project.gitignore.path, p.join(dir.path, '.gitignore'));
    });

    test('a missing pubspec.yaml is a user error with a hint', () {
      expect(
        () => AppProject.read(dir),
        throwsA(
          isA<UserError>()
              .having((e) => e.message, 'message', contains('No pubspec.yaml'))
              .having((e) => e.hint, 'hint', contains('dartlane init')),
        ),
      );
    });

    test('a pubspec.yaml without a name is a user error', () {
      file('pubspec.yaml').writeAsStringSync('description: nothing\n');

      expect(() => AppProject.read(dir), throwsA(isA<UserError>()));
    });

    test('an empty pubspec.yaml is a user error', () {
      file('pubspec.yaml').writeAsStringSync('');

      expect(() => AppProject.read(dir), throwsA(isA<UserError>()));
    });
  });

  group('LanePackage', () {
    late AppProject project;

    setUp(() => project = AppProject(root: dir, name: 'my_app'));

    test('lives in dartlane/ under the project root', () {
      expect(
        LanePackage.of(project).directory.path,
        p.join(dir.path, 'dartlane'),
      );
    });

    test('exists only once the folder does', () {
      final package = LanePackage.of(project);
      expect(package.exists, isFalse);

      package.write(project: project);

      expect(package.exists, isTrue);
    });

    test('write returns the generated file names and creates them', () {
      final written = LanePackage.of(project).write(project: project);

      expect(written, ['pubspec.yaml', 'lanes.dart', 'config.dart']);
      for (final name in written) {
        expect(file('dartlane/$name').existsSync(), isTrue);
      }
    });

    test('write adds overrides only for a local repo', () {
      final written = LanePackage.of(
        project,
      ).write(project: project, localRepo: '/repo');

      expect(written, contains('pubspec_overrides.yaml'));
      expect(
        file('dartlane/pubspec_overrides.yaml').readAsStringSync(),
        contains('path: /repo/packages/dartlane_core'),
      );
    });

    test('write overwrites generated files and keeps other files', () {
      Directory(p.join(dir.path, 'dartlane')).createSync();
      file('dartlane/lanes.dart').writeAsStringSync('// mine');
      file('dartlane/extra.dart').writeAsStringSync('// keep');

      LanePackage.of(project).write(project: project);

      expect(file('dartlane/lanes.dart').readAsStringSync(), isNot('// mine'));
      expect(file('dartlane/extra.dart').readAsStringSync(), '// keep');
    });
  });

  group('ensureGitignored', () {
    test('creates the file when it is missing', () {
      final changed = ensureGitignored(file('.gitignore'), ['a/', 'b']);

      expect(changed, isTrue);
      expect(file('.gitignore').readAsStringSync(), '\n# Dartlane\na/\nb\n');
    });

    test('adds only the missing entries after the existing lines', () {
      file('.gitignore').writeAsStringSync('build/\nb\n');

      ensureGitignored(file('.gitignore'), ['a/', 'b']);

      expect(
        file('.gitignore').readAsStringSync(),
        'build/\nb\n\n# Dartlane\na/\n',
      );
    });

    test('counts an entry with a leading slash as listed', () {
      file('.gitignore').writeAsStringSync('/a/\n');

      expect(ensureGitignored(file('.gitignore'), ['a/']), isFalse);
    });

    test('does nothing when every entry is listed', () {
      file('.gitignore').writeAsStringSync('a/\nb\n');

      final changed = ensureGitignored(file('.gitignore'), ['a/', 'b']);

      expect(changed, isFalse);
      expect(file('.gitignore').readAsStringSync(), 'a/\nb\n');
    });
  });
}
