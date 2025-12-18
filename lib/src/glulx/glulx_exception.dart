/// Exceptions specific to Glulx execution.
class GlulxException implements Exception {
  /// The error message.
  final String message;

  /// Creates a new GlulxException.
  GlulxException(this.message);

  @override
  String toString() => 'GlulxException: $message';
}
