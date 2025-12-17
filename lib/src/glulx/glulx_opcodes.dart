/// Glulx Opcode Constants
class GlulxOpcodes {
  /// nop
  static const int nop = 0x00; // implemented. unit tested

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

  /// jgtu
  static const int jgtu = 0x2C; // implemented. unit tested

  /// jleu
  static const int jleu = 0x2D; // implemented. unit tested

  /// call
  static const int call = 0x30; // implemented. unit tested

  /// ret
  static const int ret = 0x31; // implemented. unit tested

  /// catchEx
  static const int catchEx = 0x32; // implemented. unit tested

  /// throwEx
  static const int throwEx = 0x33; // implemented. unit tested

  /// tailcall
  static const int tailcall = 0x34; // implemented. unit tested

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
  static const int aloadbit = 0x4B; // implemented. unit tested

  /// astore
  static const int astore = 0x4C; // implemented. unit tested

  /// astores
  static const int astores = 0x4D; // implemented. unit tested

  /// astoreb
  static const int astoreb = 0x4E; // implemented. unit tested

  /// astorebit
  static const int astorebit = 0x4F; // implemented. unit tested

  /// stkcount
  static const int stkcount = 0x50; // implemented. unit tested

  /// stkpeek
  static const int stkpeek = 0x51; // implemented. unit tested

  /// stkswap
  static const int stkswap = 0x52; // implemented. unit tested

  /// stkroll
  static const int stkroll = 0x53; // implemented. unit tested

  /// stkcopy
  static const int stkcopy = 0x54; // implemented. unit tested

  /// streamchar
  static const int streamchar = 0x70; // implemented. unit tested

  /// streamnum
  static const int streamnum = 0x71; // implemented. unit tested

  /// streamstr
  static const int streamstr = 0x72; // implemented. unit tested

  /// streamunichar
  static const int streamunichar = 0x73; // implemented. unit tested

  /// gestalt
  static const int gestalt = 0x100; // implemented. unit tested

  /// debugtrap
  static const int debugtrap = 0x101; // implemented. unit tested

  /// getmemsize
  static const int getmemsize = 0x102; // implemented. unit tested

  /// setmemsize
  static const int setmemsize = 0x103; // implemented. unit tested

  /// jumpabs
  static const int jumpabs = 0x104; // implemented. unit tested

  /// random
  static const int random = 0x110; // implemented. unit tested

  /// setrandom
  static const int setrandom = 0x111; // implemented. unit tested

  /// quit
  static const int quit = 0x120; // implemented. unit tested

  /// verify
  static const int verify = 0x121; // implemented (stub). unit tested

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
  /// glk
  static const int glk = 0x130; // implemented. unit tested

  /// getstringtbl
  static const int getstringtbl = 0x140;

  /// setstringtbl
  static const int setstringtbl = 0x141;

  /// getiosys
  static const int getiosys = 0x148; // implemented. unit tested

  /// setiosys
  static const int setiosys = 0x149; // implemented. unit tested

  /// linearsearch
  static const int linearsearch = 0x150;

  /// binarysearch
  static const int binarysearch = 0x151;

  /// linkedsearch
  static const int linkedsearch = 0x152;

  /// callf
  static const int callf = 0x160; // implemented. unit tested

  /// callfi
  static const int callfi = 0x161; // implemented. unit tested

  /// callfii
  static const int callfii = 0x162; // implemented. unit tested

  /// callfiii
  static const int callfiii = 0x163; // implemented. unit tested

  // Note: 0x160 mzero in main list? Let me cross check with browser text.
  // Browser text said: mzero: 0x160.
  // Let me trust browser "mzero: 0x160".

  /// mzero
  static const int mzero = 0x170; // implemented. unit tested

  /// mcopy
  static const int mcopy = 0x171; // implemented. unit tested

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
