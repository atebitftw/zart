/// Glulx Opcode Constants.  DO NOT CHANGE
class GlulxOp {
  /// nop
  static const int nop = 0x00;

  /// add
  static const int add = 0x10;

  /// sub
  static const int sub = 0x11;

  /// mul
  static const int mul = 0x12;

  /// div
  static const int div = 0x13;

  /// mod
  static const int mod = 0x14;

  /// neg
  static const int neg = 0x15;

  /// bitand
  static const int bitand = 0x18;

  /// bitor
  static const int bitor = 0x19;

  /// bitxor
  static const int bitxor = 0x1A;

  /// bitnot
  static const int bitnot = 0x1B;

  /// shiftl
  static const int shiftl = 0x1C;

  /// sshiftr
  static const int sshiftr = 0x1D;

  /// ushiftr
  static const int ushiftr = 0x1E;

  /// jump
  static const int jump = 0x20;

  /// jz
  static const int jz = 0x22;

  /// jnz
  static const int jnz = 0x23;

  /// jeq
  static const int jeq = 0x24;

  /// jne
  static const int jne = 0x25;

  /// jlt
  static const int jlt = 0x26;

  /// jge
  static const int jge = 0x27;

  /// jgt
  static const int jgt = 0x28;

  /// jle
  static const int jle = 0x29;

  /// jltu
  static const int jltu = 0x2A;

  /// jgeu
  static const int jgeu = 0x2B;

  /// jgtu
  static const int jgtu = 0x2C;

  /// jleu
  static const int jleu = 0x2D;

  /// call
  static const int call = 0x30;

  /// ret
  static const int ret = 0x31;

  /// catchEx
  static const int catchEx = 0x32;

  /// throwEx
  static const int throwEx = 0x33;

  /// tailcall
  static const int tailcall = 0x34;

  /// copy
  static const int copy = 0x40;

  /// copys
  static const int copys = 0x41;

  /// copyb
  static const int copyb = 0x42;

  /// sexs
  static const int sexs = 0x44;

  /// sexb
  static const int sexb = 0x45;

  /// aload
  static const int aload = 0x48;

  /// aloads
  static const int aloads = 0x49;

  /// aloadb
  static const int aloadb = 0x4A;

  /// aloadbit
  static const int aloadbit = 0x4B;

  /// astore
  static const int astore = 0x4C;

  /// astores
  static const int astores = 0x4D;

  /// astoreb
  static const int astoreb = 0x4E;

  /// astorebit
  static const int astorebit = 0x4F;

  /// stkcount
  static const int stkcount = 0x50;

  /// stkpeek
  static const int stkpeek = 0x51;

  /// stkswap
  static const int stkswap = 0x52;

  /// stkroll
  static const int stkroll = 0x53;

  /// stkcopy
  static const int stkcopy = 0x54;

  /// streamchar
  static const int streamchar = 0x70;

  /// streamnum
  static const int streamnum = 0x71;

  /// streamstr
  static const int streamstr = 0x72;

  /// streamunichar
  static const int streamunichar = 0x73;

  /// gestalt
  static const int gestalt = 0x100;

  /// debugtrap
  static const int debugtrap = 0x101;

  /// getmemsize
  static const int getmemsize = 0x102;

  /// setmemsize
  static const int setmemsize = 0x103;

  /// jumpabs
  static const int jumpabs = 0x104;

  /// random
  static const int random = 0x110;

  /// setrandom
  static const int setrandom = 0x111;

  /// quit
  static const int quit = 0x120;

  /// verify
  static const int verify = 0x121;

  /// restart
  static const int restart = 0x122;

  /// save
  static const int save = 0x123;

  /// restore
  static const int restore = 0x124;

  /// saveundo
  static const int saveundo = 0x125;

  /// restoreundo
  static const int restoreundo = 0x126;

  /// protect
  static const int protect = 0x127;

  /// hasundo
  static const int hasundo = 0x128;

  /// discardundo
  static const int discardundo = 0x129;

  /// glk
  static const int glk = 0x130;

  /// getstringtbl
  static const int getstringtbl = 0x140;

  /// setstringtbl
  static const int setstringtbl = 0x141;

  /// getiosys
  static const int getiosys = 0x148;

  /// setiosys
  static const int setiosys = 0x149;

  /// linearsearch
  static const int linearsearch = 0x150;

  /// binarysearch
  static const int binarysearch = 0x151;

  /// linkedsearch
  static const int linkedsearch = 0x152;

  /// callf
  static const int callf = 0x160;

  /// callfi
  static const int callfi = 0x161;

  /// callfii
  static const int callfii = 0x162;

  /// callfiii
  static const int callfiii = 0x163;

  /// mzero
  static const int mzero = 0x170;

  /// mcopy
  static const int mcopy = 0x171;

  /// malloc
  static const int malloc = 0x178;

  /// mfree
  static const int mfree = 0x179;

  /// accelfunc
  static const int accelfunc = 0x180;

  /// accelparam
  static const int accelparam = 0x181;

  /// numtof
  static const int numtof = 0x190;

  /// ftonumz
  static const int ftonumz = 0x191;

  /// ftonumn
  static const int ftonumn = 0x192;

  /// ceil
  static const int ceil = 0x198;

  /// floor
  static const int floor = 0x199;

  /// fadd
  static const int fadd = 0x1A0;

  /// fsub
  static const int fsub = 0x1A1;

  /// fmul
  static const int fmul = 0x1A2;

  /// fdiv
  static const int fdiv = 0x1A3;

  /// fmod
  static const int fmod = 0x1A4;

  /// sqrt
  static const int sqrt = 0x1A8;

  /// exp
  static const int exp = 0x1A9;

  /// log
  static const int log = 0x1AA;

  /// pow
  static const int pow = 0x1AB;

  /// sin
  static const int sin = 0x1B0;

  /// cos
  static const int cos = 0x1B1;

  /// tan
  static const int tan = 0x1B2;

  /// asin
  static const int asin = 0x1B3;

  /// acos
  static const int acos = 0x1B4;

  /// atan
  static const int atan = 0x1B5;

  /// atan2
  static const int atan2 = 0x1B6;

  /// jfeq
  static const int jfeq = 0x1C0;

  /// jfne
  static const int jfne = 0x1C1;

  /// jflt
  static const int jflt = 0x1C2;

  /// jfle
  static const int jfle = 0x1C3;

  /// jfgt
  static const int jfgt = 0x1C4;

  /// jfge
  static const int jfge = 0x1C5;

  /// jisnan
  static const int jisnan = 0x1C8;

  /// jisinf
  static const int jisinf = 0x1C9;
}
