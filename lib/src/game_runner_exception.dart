/// Exception thrown by GameRunner.
class GameRunnerException implements Exception {
  /// The error message.
  final String message;

  /// Creates a new GameRunnerException.
  GameRunnerException(this.message);

  @override
  String toString() => 'GameRunnerException: $message';
}
