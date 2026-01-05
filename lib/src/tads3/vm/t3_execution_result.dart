/// Execution result from a single instruction.
enum T3ExecutionResult {
  /// Continue to next instruction.
  continue_,

  /// Program has exited.
  quit,

  /// Waiting for input.
  waitingForInput,

  /// Error occurred.
  error,
}
