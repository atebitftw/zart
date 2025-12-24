/// Represents a store operand in a Glulx instruction.
class StoreOperand {
  /// Addressing mode (e.g., direct, indirect, etc).
  final int mode;

  /// Address of the operand.
  final int addr;

  /// Creates a new store operand.
  StoreOperand(this.mode, this.addr);

  @override
  String toString() {
    return 'Store(mode: $mode, addr: $addr)';
  }
}
