/// The names of the product flavors declared in an Android Gradle file.
///
/// Reads the `productFlavors { ... }` block of `build.gradle` (Groovy, where a
/// flavor looks like `dev { ... }`) or `build.gradle.kts` (Kotlin, where it
/// looks like `create("dev") { ... }`). Comments are ignored. Returns an empty
/// list if there is no such block.
///
/// This is a reading aid for `dartlane doctor`, not a Gradle parser. A build
/// file that builds its flavors in some other way will report none.
List<String> parseAndroidFlavors(String gradle) {
  final text = _withoutComments(gradle);
  final start = RegExp(r'productFlavors\s*\{').firstMatch(text);
  if (start == null) return const [];

  final flavors = <String>[];
  final header = StringBuffer();
  var depth = 1;
  for (var i = start.end; i < text.length && depth > 0; i++) {
    final character = text[i];
    if (character == '{') {
      // At depth 1 the text before a brace is the flavor's declaration.
      if (depth == 1) {
        final name = _flavorName(header.toString());
        if (name != null) flavors.add(name);
        header.clear();
      }
      depth++;
    } else if (character == '}') {
      depth--;
      if (depth == 1) header.clear();
    } else if (depth == 1) {
      header.write(character);
    }
  }
  return flavors;
}

String _withoutComments(String text) => text
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .replaceAll(RegExp(r'//[^\n]*'), '');

/// `dev` or `create("dev")` or `register('dev')` give `dev`.
String? _flavorName(String declaration) {
  final quoted = RegExp('["\']([^"\']+)["\']').firstMatch(declaration);
  if (quoted != null) return quoted.group(1);
  final words = RegExp(r'\w+').allMatches(declaration).toList();
  return words.isEmpty ? null : words.last.group(0);
}
