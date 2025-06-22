abstract class LaneArgs {
  Map<String, dynamic> toJson();

  Map<String, String> toStringJson() {
    return Map<String, String>.fromEntries(
      toJson().entries
          .where((entry) => entry.value != null)
          .map((entry) => MapEntry(entry.key, entry.value.toString())),
    );
  }
}
