/// Exception thrown when an error occurs during T3 image parsing.
class T3Exception implements Exception {
  /// The error message.
  final String message;

  /// Creates a new T3Exception with the given message.
  T3Exception(this.message);

  @override
  String toString() => 'T3Exception: $message';
}
