// Writes `lib/src/version.g.dart` from `pubspec.yaml`, so the version the CLI
// reports and the minimum Dart it checks for are never typed by hand.
//
// Run it with `dart run melos run generate`, for example after `melos
// version` has changed the version. It needs only dart:io, so it works from any
// directory.
//
// ignore_for_file: avoid_print
import 'dart:io';

void main() {
  final root = File.fromUri(Platform.script).parent.parent;
  final pubspec = File('${root.path}/pubspec.yaml').readAsStringSync();

  final version = _match(pubspec, r'^version:\s*(\S+)\s*$');
  final minimumDart = _match(pubspec, r'^\s+sdk:\s*\^?(\d+\.\d+\.\d+)\s*$');

  final target = File('${root.path}/lib/src/version.g.dart')
    ..writeAsStringSync('''
// GENERATED CODE - DO NOT MODIFY BY HAND.
// Edit pubspec.yaml and run `dart run melos run generate`.

/// The version of the Dartlane packages: the `version` in `pubspec.yaml`.
///
/// It is the version `dartlane --version` prints and the version the generated
/// `dartlane/` package depends on.
const dartlaneVersion = '$version';

/// The oldest Dart SDK that can run Dartlane: the lower bound of the `sdk`
/// constraint in `pubspec.yaml`.
///
/// `dartlane doctor` checks for it and the generated `dartlane/` package asks
/// for it.
const minimumDartVersion = '$minimumDart';
''');
  Process.runSync(Platform.resolvedExecutable, ['format', target.path]);
  print('Wrote ${target.path} (version $version, Dart $minimumDart)');
}

/// The first capture group of [pattern] in [text], or an error naming it.
String _match(String text, String pattern) {
  final match = RegExp(pattern, multiLine: true).firstMatch(text);
  if (match == null) {
    stderr.writeln('pubspec.yaml has nothing matching $pattern');
    exit(1);
  }
  return match.group(1)!;
}
