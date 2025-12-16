/// Glulx Opcode Constants
class GlulxOpcodes {
  static const int nop = 0x00;

  static const int add = 0x10;
  static const int sub = 0x11;
  static const int mul = 0x12;
  static const int div = 0x13;
  static const int mod = 0x14;
  static const int neg = 0x15;

  static const int bitand = 0x18;
  static const int bitor = 0x19;
  static const int bitxor = 0x1A;
  static const int bitnot = 0x1B;

  static const int jump = 0x20;
  static const int jz = 0x22;
  static const int jnz = 0x23;
  static const int jeq = 0x24;
  static const int jne = 0x25;
  static const int jlt = 0x26;
  static const int jge = 0x27;
  static const int jgt = 0x28;
  static const int jle = 0x29;
  static const int jltu = 0x2A;
  static const int jgeu = 0x2B;

  static const int call = 0x30;
  static const int ret = 0x31; // 'return' is a keyword

  static const int copy = 0x40;
  static const int copys = 0x41;
  static const int copyb = 0x42;

  static const int streamchar = 0x70;

  static const int quit = 0x120;
  static const int glk = 0x130;
}
