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

  /// frem
  static const int frem = 0x1A5;

  /// ceil (C reference: 0x198)
  static const int ceil = 0x198;

  /// floor (C reference: 0x199)
  static const int floor = 0x199;

  /// sqrt (C reference: 0x1A8)
  static const int sqrt = 0x1A8;

  /// exp (C reference: 0x1A9)
  static const int exp = 0x1A9;

  /// log (C reference: 0x1AA)
  static const int log = 0x1AA;

  /// pow (C reference: 0x1AB)
  static const int pow = 0x1AB;

  /// sin (C reference: 0x1B0)
  static const int sin = 0x1B0;

  /// cos (C reference: 0x1B1)
  static const int cos = 0x1B1;

  /// tan (C reference: 0x1B2)
  static const int tan = 0x1B2;

  /// asin (C reference: 0x1B3)
  static const int asin = 0x1B3;

  /// acos (C reference: 0x1B4)
  static const int acos = 0x1B4;

  /// atan (C reference: 0x1B5)
  static const int atan = 0x1B5;

  /// atan2 (C reference: 0x1B6)
  static const int atan2 = 0x1B6;

  /// jfeq (C reference: 0x1C0)
  static const int jfeq = 0x1C0;

  /// jfne (C reference: 0x1C1)
  static const int jfne = 0x1C1;

  /// jflt (C reference: 0x1C2)
  static const int jflt = 0x1C2;

  /// jfle (C reference: 0x1C3)
  static const int jfle = 0x1C3;

  /// jfgt (C reference: 0x1C4)
  static const int jfgt = 0x1C4;

  /// jfge (C reference: 0x1C5)
  static const int jfge = 0x1C5;

  /// jisnan (C reference: 0x1C8)
  static const int jisnan = 0x1C8;

  /// jisinf (C reference: 0x1C9)
  static const int jisinf = 0x1C9;

  // Double-Precision Opcodes (Spec Section 2.13.1)

  /// numtod (C reference: 0x200)
  static const int numtod = 0x200;

  /// dtonumz (C reference: 0x201)
  static const int dtonumz = 0x201;

  /// dtonumn (C reference: 0x202)
  static const int dtonumn = 0x202;

  /// ftod (C reference: 0x203)
  static const int ftod = 0x203;

  /// dtof (C reference: 0x204)
  static const int dtof = 0x204;

  /// dceil (C reference: 0x208)
  static const int dceil = 0x208;

  /// dfloor (C reference: 0x209)
  static const int dfloor = 0x209;

  /// dadd (C reference: 0x210)
  static const int dadd = 0x210;

  /// dsub (C reference: 0x211)
  static const int dsub = 0x211;

  /// dmul (C reference: 0x212)
  static const int dmul = 0x212;

  /// ddiv (C reference: 0x213)
  static const int ddiv = 0x213;

  /// dmodr (C reference: 0x214)
  static const int dmodr = 0x214;

  /// dmodq (C reference: 0x215)
  static const int dmodq = 0x215;

  /// dsqrt (C reference: 0x218)
  static const int dsqrt = 0x218;

  /// dexp (C reference: 0x219)
  static const int dexp = 0x219;

  /// dlog (C reference: 0x21A)
  static const int dlog = 0x21A;

  /// dpow (C reference: 0x21B)
  static const int dpow = 0x21B;

  /// dsin (C reference: 0x220)
  static const int dsin = 0x220;

  /// dcos (C reference: 0x221)
  static const int dcos = 0x221;

  /// dtan (C reference: 0x222)
  static const int dtan = 0x222;

  /// dasin (C reference: 0x223)
  static const int dasin = 0x223;

  /// dacos (C reference: 0x224)
  static const int dacos = 0x224;

  /// datan (C reference: 0x225)
  static const int datan = 0x225;

  /// datan2 (C reference: 0x226)
  static const int datan2 = 0x226;

  /// jdeq (C reference: 0x230)
  static const int jdeq = 0x230;

  /// jdne (C reference: 0x231)
  static const int jdne = 0x231;

  /// jdlt (C reference: 0x232)
  static const int jdlt = 0x232;

  /// jdle (C reference: 0x233)
  static const int jdle = 0x233;

  /// jdgt (C reference: 0x234)
  static const int jdgt = 0x234;

  /// jdge (C reference: 0x235)
  static const int jdge = 0x235;

  /// jdisnan (C reference: 0x238)
  static const int jdisnan = 0x238;

  /// jdisinf (C reference: 0x239)
  static const int jdisinf = 0x239;
}
