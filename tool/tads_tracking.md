# TADS 3 Porting Tracker

## Platform & Base Utilities
Supporting libraries and encoding/decoding.

- [x] `t3std.h` - Standard definitions and macros <!-- id: 502 -->
- [x] `os.h` - OS abstraction layer definitions (not needed - Dart provides cross-platform APIs) <!-- id: 503 -->
- [x] `utf8.cpp` / `utf8.h` - UTF-8 handling (not needed - Dart has built-in UTF-8 support via dart:convert) <!-- id: 401 -->
- [x] `charmap.cpp` / `charmap.h` - Character mapping and translation (not needed - Dart has UTF-8/UTF-16 support via dart:convert) <!-- id: 400 -->
- [x] `uni_case.cpp` - Unicode case folding (not needed - code generator tool, Dart has built-in case conversion) <!-- id: 402 -->

## VM Core Infrastructure
Essential for the basic execution of the T3 VM.

- [x] `vmtype.cpp` / `vmtype.h` - Data type definitions <!-- id: 112 -->
- [x] `vmerr.cpp` / `vmerr.h` - Error handling and exceptions <!-- id: 108 -->
- [x] `vmerrmsg.cpp` - Error message strings <!-- id: 109 -->
- [x] `vmstack.cpp` / `vmstack.h` - VM stack implementation <!-- id: 106 -->
- [x] `vmpool.cpp` / `vmpool.h` - Constant and code pool management <!-- id: 107 -->
- [x] `vmglob.cpp` / `vmglob.h` / `vmglobv.h` - Global variable management <!-- id: 111 -->

## Object System Core
Root classes for the T3 object system.

- [x] `vmobj.cpp` / `vmobj.h` - Root T3 object class <!-- id: 104 -->
- [x] `vmcoll.cpp` / `vmcoll.h` - Collection base class <!-- id: 204 -->
- [x] `vmtobj.cpp` / `vmtobj.h` - TadsObject metaclass <!-- id: 214 -->

## Interpreter & Execution Engine
Core execution loop and dispatch.

- [x] `vmop.cpp` / `vmop.h` - Opcode definitions and helpers <!-- id: 113 -->
- [x] `vmfunc.cpp` / `vmfunc.h` - Function and method handling <!-- id: 105 -->
- [x] `vmbif.cpp` / `vmbif.h` - Core BIF handling <!-- id: 302 -->
- [/] `vmrun.cpp` / `vmrun.h` - Main execution loop (Phase 2: arithmetic) <!-- id: 102 -->

## Essential Metaclasses
Commonly used TADS 3 data types.

- [ ] `vmstr.cpp` / `vmstr.h` - String metaclass <!-- id: 202 -->
- [ ] `vmlst.cpp` / `vmlst.h` - List metaclass <!-- id: 200 -->
- [ ] `vmvec.cpp` / `vmvec.h` - Vector metaclass <!-- id: 201 -->
- [ ] `vmanonfn.cpp` / `vmanonfn.h` - Anonymous function metaclass <!-- id: 218 -->
- [ ] `vmiter.cpp` / `vmiter.h` - Iterator metaclass <!-- id: 217 -->

## Advanced Metaclasses
Complex built-in TADS 3 objects.

- [ ] `vmstrbuf.cpp` / `vmstrbuf.h` - StringBuffer metaclass <!-- id: 213 -->
- [ ] `vmlookup.cpp` / `vmlookup.h` - LookupTable metaclass <!-- id: 211 -->
- [ ] `vmdict.cpp` / `vmdict.h` - Dictionary metaclass <!-- id: 203 -->
- [ ] `vmregex.cpp` / `vmregex.h` - RexGroup metaclass <!-- id: 212 -->
- [ ] `vmbignum.cpp` / `vmbignum.h` - BigNumber metaclass <!-- id: 205 -->
- [ ] `vmdate.cpp` / `vmdate.h` - Date metaclass <!-- id: 207 -->
- [ ] `vmfile.cpp` / `vmfile.h` - File metaclass <!-- id: 209 -->
- [ ] `vmbytarr.cpp` / `vmbytarr.h` - ByteArray metaclass <!-- id: 206 -->
- [ ] `vmtz.cpp` / `vmtz.h` - TimeZone and TimeZoneData metaclasses <!-- id: 215 -->
- [ ] `vmgram.cpp` / `vmgram.h` - GrammarProd metaclass <!-- id: 210 -->
- [ ] `vmdynfunc.cpp` / `vmdynfunc.h` - DynamicFunc metaclass <!-- id: 208 -->
- [ ] `vmundo.cpp` / `vmundo.h` - Undo mechanism <!-- id: 216 -->

## Built-in Function Sets (BIFs)
Function sets provided by the VM.

- [ ] `vmbift3.cpp` / `vmbift3.h` - T3 system intrinsics <!-- id: 303 -->
- [ ] `vmbiftad.cpp` / `vmbiftad.h` - TADS-specific intrinsics <!-- id: 300 -->
- [ ] `vmbiftio.cpp` / `vmbiftio.h` - TADS I/O intrinsics <!-- id: 301 -->
- [ ] `vmbiftix.cpp` / `vmbiftix.h` - TADS indexing intrinsics <!-- id: 304 -->

## VM Management & Entrypoint
VM initialization and host integration.

- [ ] `vminit.cpp` / `vminit.h` - VM initialization and termination <!-- id: 110 -->
- [ ] `vmcore.cpp` / `vmcore.h` - Core VM definitions <!-- id: 100 -->
- [ ] `vmmain.cpp` / `vmmain.h` - Interpreter main entrypoint <!-- id: 101 -->
- [ ] `vmhost.h` - Host application interface <!-- id: 501 -->
- [ ] `os_stdio.cpp` - Standard I/O interface <!-- id: 500 -->

## Support Libraries
Low-level algorithm implementations.

- [ ] `vmisaac.cpp` / `vmisaac.h` - ISAAC random number generator <!-- id: 406 -->
- [ ] `sha2.cpp` / `sha2.h` - SHA-256 implementation <!-- id: 403 -->
- [ ] `md5.cpp` / `md5.h` - MD5 implementation <!-- id: 404 -->
- [ ] `vmcrc.cpp` / `vmcrc.h` - CRC-32 implementation <!-- id: 405 -->

## TADS 3 Compiler (TC)
Files related to the TADS 3 compiler (low priority for interpreter port).

- [ ] `tcmain.cpp` / `tcmain.h` - Compiler entry point <!-- id: 600 -->
- [ ] `tcprs.cpp` / `tcprs.h` - Parser implementation <!-- id: 601 -->
- [ ] `tctok.cpp` / `tctok.h` - Tokenizer implementation <!-- id: 602 -->
- [ ] `tct3.cpp` / `tct3.h` - T3 code generator <!-- id: 603 -->

## Resource Handling
Resource compiler tools (low priority).

- [ ] `rcmain.cpp` / `rcmain.h` - Resource compiler entry point <!-- id: 700 -->
