// Deletes the generated `dartlane/` folder of the example app and creates it
// again with `dartlane init`, so the example always matches the current CLI and
// templates.
//
// Run it with `dart run melos run example:reset`. Pass a folder to reset a
// different project, for example a scratch copy:
//
//     dart run tool/reset_example.dart /tmp/my_app
//
// The folder is git-ignored in the example, so nothing here is committed.
// Anything you added to `dartlane/` there is deleted too.
//
// ignore_for_file: avoid_print
import 'dart:io';

Future<void> main(List<String> args) async {
  final repo = File.fromUri(Platform.script).parent.parent;
  final project = Directory(
    args.isNotEmpty ? args.first : '${repo.path}/example/flutter_app',
  );

  if (!File('${project.path}/pubspec.yaml').existsSync()) {
    stderr.writeln('${project.path} has no pubspec.yaml.');
    exit(2);
  }

  final lanes = Directory('${project.path}/dartlane');
  if (lanes.existsSync()) {
    lanes.deleteSync(recursive: true);
    print('Deleted ${lanes.path}');
  }

  // The CLI from this checkout, so it is always the code you are working on.
  final init = await Process.start(
    Platform.resolvedExecutable,
    [
      'run',
      '${repo.path}/packages/dartlane/bin/dartlane.dart',
      'init',
      '--local-repo',
      repo.path,
    ],
    workingDirectory: project.path,
    mode: ProcessStartMode.inheritStdio,
  );
  exit(await init.exitCode);
}
