import 'dart:io';

import 'package:dartlane_core/dartlane_core.dart';

/// Reads the text file at [path]; [what] names it in the error.
///
/// Throws a [UserError] if the file does not exist.
String readInputFile(String path, String what) {
  final file = File(path);
  if (!file.existsSync()) {
    throw UserError(
      'The $what file $path does not exist.',
      hint: 'Check the path, or write the file in an earlier step.',
    );
  }
  return file.readAsStringSync();
}

/// Reads a list from the file at [path]: one item per line or separated by
/// commas. Blank lines and lines starting with `#` are ignored.
List<String> readInputList(String path, String what) => [
  for (final line in readInputFile(path, what).split(RegExp(r'\r?\n')))
    if (!line.trim().startsWith('#'))
      for (final item in line.split(','))
        if (item.trim().isNotEmpty) item.trim(),
];

/// Throws a [UserError] if any of [emails], read from [source], is not an
/// email address.
void requireEmails(Iterable<String> emails, String source) {
  for (final email in emails) {
    if (!email.contains('@')) {
      throw UserError(
        '$source has "$email", which is not an email address.',
        hint: 'List one tester email per line.',
      );
    }
  }
}
