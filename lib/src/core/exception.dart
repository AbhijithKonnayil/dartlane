class DException implements Exception {
  DException(this.message, {this.title});
  final String message;
  final String? title;

  @override
  String toString() {
    return '${title != null ? "$title: " : ''}$message';
  }
}
