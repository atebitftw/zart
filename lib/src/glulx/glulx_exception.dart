/// Exceptions specific to Glulx execution.
class GlulxException implements Exception {
  final String message;
  GlulxException(this.message);
  @override
  String toString() => 'GlulxException: $message';
}
