import 'dart:io';

String readInputWithDefault(String prompt, String defaultValue) {
  stdout.write('$prompt [$defaultValue]: ');
  final input = stdin.readLineSync();
  return (input == null || input.trim().isEmpty) ? defaultValue : input.trim();
}

String readInput(String prompt, {String? defaultValue}) {
  final displayPrompt =
      defaultValue != null ? '$prompt [$defaultValue]' : prompt;
  stdout.write('$displayPrompt: ');
  final input = stdin.readLineSync();

  if (input == null || input.trim().isEmpty) {
    return defaultValue ?? ''; // may be null
  }
  return input.trim();
}

String? findProjectRoot([Directory? start]) {
  var dir = start ?? Directory.current;

  while (true) {
    if (File('${dir.path}/pubspec.yaml').existsSync()) {
      return dir.path;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break; // reached root
    dir = parent;
  }

  return null; // not found
}
