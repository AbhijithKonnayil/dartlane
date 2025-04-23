extension MapUtils on Map<String, String> {
  String getValue(
    String key, {
    String? defaultVale,
  }) {
    assert(
      defaultVale != null || containsKey('key'),
      'Either defaultVale must not be null or params must contain the key.',
    );
    if (containsKey('key')) {
      return this[key]!;
    }
    return defaultVale!;
  }
}
