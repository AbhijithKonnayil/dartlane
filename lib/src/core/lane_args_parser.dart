class LaneArgsParser {
  LaneArgsParser(
    this.rawArgs,
  );
  static final RegExp _keyValuePattern = RegExp(r'(\w+):([^,\]]+)');

  List<String> rawArgs;

  Map<String, String> parse() {
    final result = <String, String>{};

    for (final item in rawArgs) {
      final matches = _keyValuePattern.allMatches(item);
      for (final match in matches) {
        final key = match.group(1);
        final value = match.group(2);
        if (key != null && value != null) {
          result[key] = value.trim();
        }
      }
    }

    return result;
  }
}
