// Renders the templates into a real package and checks that it is valid.
//
// This is what catches a syntax error in a template, or a template that no
// longer matches the API of dartlane_core or dartlane_flutter. It runs
// `dart pub get`, so it needs network access the first time.
import 'dart:io';

import 'package:dartlane/src/init/app_project.dart';
import 'package:dartlane/src/init/lane_package.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory project;
  late Directory repo;

  setUpAll(() {
    // `dart test` runs from the package folder: <repo>/packages/dartlane.
    repo = Directory(p.normalize(p.join(Directory.current.path, '..', '..')));
    expect(
      Directory(p.join(repo.path, 'packages', 'dartlane_core')).existsSync(),
      isTrue,
      reason: 'Run this test from packages/dartlane in the Dartlane repo.',
    );
    project = Directory.systemTemp.createTempSync('dartlane_valid_');
  });

  tearDownAll(() => project.deleteSync(recursive: true));

  ProcessResult dart(List<String> args, Directory workingDirectory) =>
      Process.runSync(
        Platform.resolvedExecutable,
        args,
        workingDirectory: workingDirectory.path,
      );

  test(
    'the generated package resolves and analyzes without problems',
    () {
      final appProject = AppProject(root: project, name: 'sample_app');
      final package = LanePackage.of(appProject)
        ..write(project: appProject, localRepo: repo.path);

      final pubGet = dart(['pub', 'get'], package.directory);
      expect(
        pubGet.exitCode,
        0,
        reason: 'dart pub get failed:\n${pubGet.stdout}\n${pubGet.stderr}',
      );

      final analyze = dart(['analyze'], package.directory);
      expect(
        analyze.exitCode,
        0,
        reason:
            'dart analyze found problems in the templates:\n'
            '${analyze.stdout}\n${analyze.stderr}',
      );
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
