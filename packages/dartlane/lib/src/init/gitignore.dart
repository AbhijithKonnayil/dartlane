import 'dart:io';

/// Adds each of [entries] to [gitignore] unless it is already listed.
///
/// Creates the file if it does not exist. An entry counts as listed when a
/// line equals it, with or without a leading `/`. Existing lines are kept and
/// the new ones go under a `# Dartlane` comment at the end.
///
/// Returns whether the file changed.
bool ensureGitignored(File gitignore, List<String> entries) {
  final content = gitignore.existsSync() ? gitignore.readAsStringSync() : '';
  final lines = content.split('\n').map((l) => l.trim()).toSet();
  final missing = [
    for (final entry in entries)
      if (!lines.contains(entry) && !lines.contains('/$entry')) entry,
  ];
  if (missing.isEmpty) return false;

  final separator = content.isEmpty || content.endsWith('\n') ? '' : '\n';
  gitignore.writeAsStringSync(
    '$content$separator\n# Dartlane\n${missing.join('\n')}\n',
  );
  return true;
}
