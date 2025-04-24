extension MapUtils on Map<String, String> {
  String getValue(
    String key, {
    String? defaultVale,
  }) {
    assert(
      defaultVale != null || containsKey(key),
      'Either defaultVale must not be null or params must contain the key.',
    );
    if (containsKey(key)) {
      return this[key]!;
    }
    return defaultVale!;
  }
}

extension DynamicUtils on dynamic {
  bool isBlank() {
    if (this == null) return true;
    if (this is String) {
      return (this as String).trim().isEmpty;
    }
    if (this is Iterable) {
      return (this as Iterable).isEmpty;
    }
    if (this is Map) {
      return (this as Map).isEmpty;
    }
    return false;
  }

  bool isPresent() {
    return !isBlank();
  }
}

extension StringUtils on String? {
  /// Converts a string into an array by splitting it using a delimiter.
  List<String> stringToArray({String delimiter = ','}) {
    if (this == null || this!.isEmpty) {
      return [];
    }
    return this!.split(RegExp(delimiter)).map((e) => e.trim()).toList();
  }
}
