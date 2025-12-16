/// Glulx Opcode Constants
class GlulxOpcodes {
  /// nop
  static const int nop = 0x00; // implemented

  /// add
  static const int add = 0x10; // implemented. unit tested

  /// sub
  static const int sub = 0x11; // implemented. unit tested

  /// mul
  static const int mul = 0x12; // implemented. unit tested

  /// div
  static const int div = 0x13; // implemented. unit tested

  /// mod
  static const int mod = 0x14; // implemented. unit tested

  /// neg
  static const int neg = 0x15; // implemented. unit tested

  /// bitand
  static const int bitand = 0x18; // implemented. unit tested

  /// bitor
  static const int bitor = 0x19; // implemented. unit tested

  /// bitxor
  static const int bitxor = 0x1A; // implemented. unit tested

  /// bitnot
  static const int bitnot = 0x1B; // implemented. unit tested

  /// shiftl
  static const int shiftl = 0x1C; // implemented. unit tested

  /// sshiftr
  static const int sshiftr = 0x1D; // implemented. unit tested

  /// ushiftr
  static const int ushiftr = 0x1E; // implemented. unit tested

  /// jump
  static const int jump = 0x20; // implemented. unit tested

  /// jz
  static const int jz = 0x22; // implemented. unit tested

  /// jnz
  static const int jnz = 0x23; // implemented. unit tested

  /// jeq
  static const int jeq = 0x24; // implemented. unit tested

  /// jne
  static const int jne = 0x25; // implemented. unit tested

  /// jlt
  static const int jlt = 0x26; // implemented. unit tested

  /// jge
  static const int jge = 0x27; // implemented. unit tested

  /// jgt
  static const int jgt = 0x28; // implemented. unit tested

  /// jle
  static const int jle = 0x29; // implemented. unit tested

  /// jltu
  static const int jltu = 0x2A; // implemented. unit tested

  /// jgeu
  static const int jgeu = 0x2B; // implemented. unit tested

  /// call
  static const int call = 0x30;

  /// ret
  static const int ret = 0x31; // 'return' is a keyword

  /// catchEx
  static const int catchEx = 0x32; // 'catch' is a keyword, 'throw' is a keyword

  /// throwEx
  static const int throwEx = 0x33;

  /// tailcall
  static const int tailcall = 0x34;

  /// copy
  static const int copy = 0x40; // implemented. unit tested

  /// copys
  static const int copys = 0x41; // implemented. unit tested

  /// copyb
  static const int copyb = 0x42; // implemented. unit tested

  /// sexs
  static const int sexs = 0x44; // implemented. unit tested

  /// sexb
  static const int sexb = 0x45; // implemented. unit tested

  /// aload
  static const int aload = 0x48; // implemented. unit tested

  /// aloads
  static const int aloads = 0x49; // implemented. unit tested

  /// aloadb
  static const int aloadb = 0x4A; // implemented. unit tested

  /// aloadbit
  static const int aloadbit = 0x4B;

  /// astore
  static const int astore = 0x4C; // implemented. unit tested

  /// astores
  static const int astores = 0x4D; // implemented. unit tested

  /// astoreb
  static const int astoreb = 0x4E; // implemented. unit tested

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
  static const int streamchar = 0x70; // implemented. unit tested

  /// streamnum
  static const int streamnum = 0x71;

  /// streamstr
  static const int streamstr = 0x72;

  /// gestalt
  static const int gestalt = 0x04;

  /// debugtrap
  static const int debugtrap = 0x05;

  /// getmemsize
  static const int getmemsize = 0x08;

  /// setmemsize
  static const int setmemsize = 0x09;

  /// jumpabs
  static const int jumpabs = 0x0A;

  /// random
  static const int random = 0x100;

  /// setrandom
  static const int setrandom = 0x101;

  /// quit
  static const int quit = 0x120; // implemented. unit tested

  /// verify
  static const int verify = 0x128;

  /// restart
  static const int restart = 0x129;

  /// save
  static const int save = 0x12A;

  /// restore
  static const int restore = 0x12B;

  /// saveundo
  static const int saveundo = 0x12C;

  /// restoreundo
  static const int restoreundo = 0x12D;

  /// protect
  static const int protect = 0x12E;

  /// glk
  /// glk
  static const int glk = 0x130; // implemented. unit tested

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

  // Note: 0x160 mzero in main list? Let me cross check with browser text.
  // Browser text said: mzero: 0x160.
  // Let me trust browser "mzero: 0x160".

  /// mzero
  static const int mzero = 0x160;

  /// mcopy
  static const int mcopy = 0x161;

  /// malloc
  static const int malloc = 0x168;

  /// mfree
  static const int mfree = 0x169;

  /// accelfunc
  static const int accelfunc = 0x170;

  /// accelparam
  static const int accelparam = 0x171;

  /// numtof
  static const int numtof = 0x180;

  /// ftonumz
  static const int ftonumz = 0x181;

  /// ftonumn
  static const int ftonumn = 0x182;

  /// ceil
  static const int ceil = 0x188;

  /// floor
  static const int floor = 0x189;

  /// fadd
  static const int fadd = 0x190;

  /// fsub
  static const int fsub = 0x191;

  /// fmul
  static const int fmul = 0x192;

  /// fdiv
  static const int fdiv = 0x193;

  /// fmod
  static const int fmod = 0x194;

  /// sqrt
  static const int sqrt = 0x198;

  /// exp
  static const int exp = 0x199;

  /// log
  static const int log = 0x19A;

  /// pow
  static const int pow = 0x19B;

  /// sin
  static const int sin = 0x1A0;

  /// cos
  static const int cos = 0x1A1;

  /// tan
  static const int tan = 0x1A2;

  /// asin
  static const int asin = 0x1A3;

  /// acos
  static const int acos = 0x1A4;

  /// atan
  static const int atan = 0x1A5;

  /// atan2
  static const int atan2 = 0x1A6;

  /// jfeq
  static const int jfeq = 0x1B0;

  /// jfne
  static const int jfne = 0x1B1;

  /// jflt
  static const int jflt = 0x1B2;

  /// jfle
  static const int jfle = 0x1B3;

  /// jfgt
  static const int jfgt = 0x1B4;

  /// jfge
  static const int jfge = 0x1B5;

  /// jisnan
  static const int jisnan = 0x1B8;

  /// jisinf
  static const int jisinf = 0x1B9;
}
