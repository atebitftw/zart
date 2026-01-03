import 'dart:typed_data';

import 'package:zart/src/glulx/glulx_header.dart';
import 'package:zart/src/glulx/glulx_op.dart';
import 'package:zart/src/glulx/op_code_info.dart';
import 'package:zart/src/io/glk/glk_gestalt_selectors.dart';
import 'package:zart/src/io/glk/glk_io_selectors.dart';
import 'package:zart/src/logging.dart';

/// The global Zart debugger instance.
final debugger = ZartDebugger();

/// A dedicated debugger for the Zart interpreter.
///
/// When enabled, logs header information, interpreter state, and
/// instruction disassembly to the logging system.
class ZartDebugger {
  /// Maximum size of the flight recorder.
  int flightRecorderSize = 100;

  /// Master switch for debugging output.
  bool enabled = false;

  /// Internal buffer for debug logs to avoid synchronous disk I/O.
  final List<String> _logBuffer = [];

  /// Whether to log the header on load.
  bool showHeader = false;

  /// Whether to show raw bytes being read (opcode, modes, operand data).
  bool showBytes = false;

  /// Whether to show addressing modes for each operand.
  bool showModes = false;

  /// Whether to show PC advancement during instruction execution.
  bool showPCAdvancement = false;

  /// Only emit instructions at or after this step (null = no lower bound).
  int? startStep;

  /// Only emit instructions at or before this step (null = no upper bound).
  int? endStep;

  /// Current step counter (updated by interpreter).
  int step = 0;

  /// Whether to show instructions.
  bool showInstructions = false;

  /// Whether to show the flight recorder.
  bool showFlightRecorder = false;

  /// Whether to log screen output to the flight recorder.
  /// When enabled, text written to screen 0 is logged with 'screen:' prefix.
  bool showScreen = false;

  /// Filter string - if set, only log messages containing this string.
  String? logFilter;

  /// Maximum steps to allow in test scenarios. Do not changes this without permission.
  static const int maxSteps = 3000;

  /// Gets the opcode name for the given opcode.
  static String getOpcodeName(int opcode) {
    return opCodeName[opcode] ?? 'op_0x${opcode.toRadixString(16)}';
  }

  /// Logs the Glulx header information.
  void logGlulxHeader(ByteData memory) {
    if (!enabled || !showHeader) return;

    final magic = memory.getUint32(GlulxHeader.magicNumberOffset, Endian.big);
    final version = memory.getUint32(GlulxHeader.versionOffset, Endian.big);
    final ramStart = memory.getUint32(GlulxHeader.ramStartOffset, Endian.big);
    final extStart = memory.getUint32(GlulxHeader.extStartOffset, Endian.big);
    final endMem = memory.getUint32(GlulxHeader.endMemOffset, Endian.big);
    final stackSize = memory.getUint32(GlulxHeader.stackSizeOffset, Endian.big);
    final startFunc = memory.getUint32(GlulxHeader.startFuncOffset, Endian.big);
    final decodingTbl = memory.getUint32(GlulxHeader.decodingTblOffset, Endian.big);
    final checksum = memory.getUint32(GlulxHeader.checksumOffset, Endian.big);

    // Format version as major.minor.patch
    final major = (version >> 16) & 0xFFFF;
    final minor = (version >> 8) & 0xFF;
    final patch = version & 0xFF;

    bufferedLog('=== Glulx Header ===');
    bufferedLog('Magic:       0x${magic.toRadixString(16).padLeft(8, '0')} (${_magicToString(magic)})');
    bufferedLog('Version:     $major.$minor.$patch');
    bufferedLog('RAMSTART:    0x${ramStart.toRadixString(16).padLeft(8, '0')}');
    bufferedLog('EXTSTART:    0x${extStart.toRadixString(16).padLeft(8, '0')}');
    bufferedLog('ENDMEM:      0x${endMem.toRadixString(16).padLeft(8, '0')}');
    bufferedLog('Stack Size:  0x${stackSize.toRadixString(16).padLeft(8, '0')} ($stackSize bytes)');
    bufferedLog('Start Func:  0x${startFunc.toRadixString(16).padLeft(8, '0')}');
    bufferedLog('Decoding Tbl: 0x${decodingTbl.toRadixString(16).padLeft(8, '0')}');
    bufferedLog('Checksum:    0x${checksum.toRadixString(16).padLeft(8, '0')}');
    bufferedLog('====================');
  }

  /// Converts a magic number to its ASCII string representation.
  String _magicToString(int magic) {
    return String.fromCharCodes([(magic >> 24) & 0xFF, (magic >> 16) & 0xFF, (magic >> 8) & 0xFF, magic & 0xFF]);
  }

  /// Logs the current interpreter state.
  void logState(int pc, int sp, int fp) {
    if (!enabled) {
      return;
    }
    if (!_isInBounds(pc)) {
      bufferedLog('WARNING: PC out of bounds: 0x${pc.toRadixString(16).padLeft(8, '0')}');
      return;
    }

    bufferedLog(
      'PC: 0x${pc.toRadixString(16).padLeft(8, '0')} '
      'SP: 0x${sp.toRadixString(16).padLeft(8, '0')} '
      'FP: 0x${fp.toRadixString(16).padLeft(8, '0')}',
    );
  }

  /// Logs a disassembled instruction.
  ///
  /// [pc] is the address of the instruction.
  /// [opcode] is the decoded opcode value.
  /// [operands] is the list of operand values (already decoded).
  /// [destTypes] is the list of destination types for store operands.
  /// [opInfo] is the opcode info for this instruction.
  /// [operandModes] is the list of addressing modes for each operand.
  void logInstruction(
    int pc,
    int opcode,
    List<int> operands,
    List<int> destTypes,
    OpcodeInfo opInfo,
    List<int> operandModes,
    int step, {
    List<int> rawOperands = const [],
  }) {
    if (!enabled || !showInstructions) {
      return;
    }

    if (!_isInBounds(pc)) {
      bufferedLog('WARNING: PC out of bounds: 0x${pc.toRadixString(16).padLeft(8, '0')}');
      return;
    }

    if (step < (startStep ?? 0) || step > (endStep ?? maxSteps)) {
      return;
    }

    final opName = getOpcodeName(opcode);
    final buffer = StringBuffer();

    // Format: 0x00001234: @opname op1 op2 op3
    buffer.write('(Step: $step) 0x${pc.toRadixString(16).padLeft(8, '0')}: @$opName');

    for (int i = 0; i < operands.length; i++) {
      buffer.write(' ');
      int rawValue = (i < rawOperands.length) ? rawOperands[i] : operands[i];
      buffer.write(
        _formatOperand(
          operands[i],
          operandModes.length > i ? operandModes[i] : 0,
          opInfo.isStore(i),
          rawValue: rawValue,
        ),
      );
    }

    bufferedLog(buffer.toString());
  }

  /// Logs raw bytes being read during instruction decode.
  void logBytes(String label, int startAddr, List<int> bytes) {
    if (!enabled || !showBytes) {
      return;
    }
    if (!_isInBounds(startAddr)) {
      bufferedLog('WARNING: PC out of bounds: 0x${startAddr.toRadixString(16).padLeft(8, '0')}');
      return;
    }

    final hexBytes = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
    bufferedLog('  $label [0x${startAddr.toRadixString(16)}]: $hexBytes');
  }

  /// Logs PC advancement.
  void logPCAdvancement(int oldPC, int newPC, String reason) {
    if (!enabled || !showPCAdvancement) return;
    if (!_isInBounds(oldPC)) return;

    final delta = newPC - oldPC;
    bufferedLog('  PC: 0x${oldPC.toRadixString(16)} -> 0x${newPC.toRadixString(16)} (+$delta bytes) [$reason]');
  }

  /// Logs addressing modes for operands.
  void logModes(List<int> modes) {
    if (!enabled || !showModes) {
      return;
    }

    final modeNames = modes.map((m) => _getModeName(m)).join(', ');
    bufferedLog('  Modes: $modeNames');
  }

  /// Gets the name of an addressing mode.
  String _getModeName(int mode) {
    switch (mode) {
      case 0x0:
        return '0:ConstZero';
      case 0x1:
        return '1:Const1B';
      case 0x2:
        return '2:Const2B';
      case 0x3:
        return '3:Const4B';
      case 0x5:
        return '5:Addr1B';
      case 0x6:
        return '6:Addr2B';
      case 0x7:
        return '7:Addr4B';
      case 0x8:
        return '8:Stack';
      case 0x9:
        return '9:Local1B';
      case 0xA:
        return 'A:Local2B';
      case 0xB:
        return 'B:Local4B';
      case 0xD:
        return 'D:RAM1B';
      case 0xE:
        return 'E:RAM2B';
      case 0xF:
        return 'F:RAM4B';
      default:
        return '$mode:Unknown';
    }
  }

  /// Formats an operand for display.
  String _formatOperand(int value, int mode, bool isStore, {int? rawValue}) {
    // If we have rawValue (offset/index), use it for Locals.
    // For Addresses, rawValue is the address.
    switch (mode) {
      case 0: // Constant zero
        return '0';
      case 1: // Constant (1 byte)
      case 2: // Constant (2 bytes)
      case 3: // Constant (4 bytes)
        // For constants, show the value
        if (value < 0) {
          return value.toString();
        } else if (value < 256) {
          return value.toString();
        } else {
          return '0x${value.toRadixString(16)}';
        }
      case 5: // Contents of address (1 byte addr)
      case 6: // Contents of address (2 bytes addr)
      case 7: // Contents of address (4 bytes addr)
        // If rawValue is available, it is the address.
        if (rawValue != null && !isStore) {
          return '[0x${rawValue.toRadixString(16)}]';
        }
        return isStore ? '*0x${value.toRadixString(16)}' : '[0x${value.toRadixString(16)}]';
      case 8: // Stack push/pop
        return isStore ? '-(sp)' : '(sp)+';
      case 9: // Local (1 byte offset)
      case 0xA: // Local (2 bytes offset)
      case 0xB: // Local (4 bytes offset)
        if (rawValue != null) {
          return 'local$rawValue';
        }
        return 'local$value';
      case 0xD: // RAM address (1 byte)
      case 0xE: // RAM address (2 bytes)
      case 0xF: // RAM address (4 bytes)
        if (rawValue != null && !isStore) {
          return '[ram+0x${rawValue.toRadixString(16)}]';
        }
        return isStore ? '*ram+0x${value.toRadixString(16)}' : '[ram+0x${value.toRadixString(16)}]';
      default:
        // Unknown mode, just show value
        return value.toString();
    }
  }

  /// Checks if the PC is within the configured bounds.
  bool _isInBounds(int pc) {
    // implementing this later
    return true;
  }

  // --- Flight Recorder ---

  final List<String> _flightRecorder = [];

  /// Separate buffer for screen output (not size-limited like flight recorder)
  final List<String> _screenBuffer = [];

  /// Records an event or message to the flight recorder.
  /// Note: Events are ALWAYS recorded regardless of the enabled flag,
  /// to ensure critical diagnostics (e.g. save/restore) are captured.
  void flightRecorderEvent(String message) {
    _flightRecorder.add('[$step] $message');
    if (_flightRecorder.length > flightRecorderSize) {
      _flightRecorder.removeAt(0);
    }
  }

  /// Records screen output to the dedicated screen buffer.
  /// This buffer is NOT size-limited to ensure we capture all screen output.
  void logScreenOutput(String line) {
    if (!enabled || !showScreen) {
      return;
    }
    _screenBuffer.add('[$step] $line');
  }

  /// Dumps the screen output buffer contents.
  void dumpScreenOutput() {
    if (!enabled || !showScreen || _screenBuffer.isEmpty) {
      return;
    }
    bufferedLog('--- Screen Output (All Lines) ---');
    for (final line in _screenBuffer) {
      bufferedLog(line);
    }
    bufferedLog('----------------------------------');
  }

  /// Dumps the flight recorder contents.
  void dumpFlightRecorder() {
    if (!enabled || !showFlightRecorder) {
      return;
    }
    bufferedLog('--- Flight Recorder (Last $flightRecorderSize Instructions) ---');
    for (final line in _flightRecorder) {
      bufferedLog(line);
    }
    bufferedLog('-------------------------------------------');
    _flightRecorder.clear();
  }

  /// Dumps the current debug settings to the log.
  void dumpDebugSettings() {
    bufferedLog('=== Debugger Settings ===');
    bufferedLog('  Enabled: $enabled');
    bufferedLog('  Show Instructions: $showInstructions');
    bufferedLog('  Show Bytes: $showBytes');
    bufferedLog('  Show Modes: $showModes');
    bufferedLog('  Show Flight Recorder: $showFlightRecorder');
    bufferedLog('  Show PC Advancement: $showPCAdvancement');
    bufferedLog('  Start Step: $startStep');
    bufferedLog('  End Step: $endStep');
    bufferedLog('==============================');
  }

  /// Buffers a log message if within the configured step range and matches filter.
  void bufferedLog(String message) {
    if (!enabled) return;
    // Check step bounds - only log if within the configured range
    if (startStep != null && step < startStep!) return;
    if (endStep != null && step > endStep!) return;
    // Check filter - only log if message contains the filter string
    if (logFilter != null && !message.contains(logFilter!)) return;
    _logBuffer.add(message);
  }

  /// Flushes the buffered logs to the logging system.
  void flushLogs() {
    if (showScreen) {
      dumpScreenOutput();
    }

    if (showFlightRecorder) {
      dumpFlightRecorder();
    }

    for (final line in _logBuffer) {
      log.info(line);
    }

    _logBuffer.clear();
  }

  /// Opcode name lookup map.
  static const Map<int, String> opCodeName = {
    GlulxOp.nop: 'nop',
    GlulxOp.add: 'add',
    GlulxOp.sub: 'sub',
    GlulxOp.mul: 'mul',
    GlulxOp.div: 'div',
    GlulxOp.mod: 'mod',
    GlulxOp.neg: 'neg',
    GlulxOp.bitand: 'bitand',
    GlulxOp.bitor: 'bitor',
    GlulxOp.bitxor: 'bitxor',
    GlulxOp.bitnot: 'bitnot',
    GlulxOp.shiftl: 'shiftl',
    GlulxOp.sshiftr: 'sshiftr',
    GlulxOp.ushiftr: 'ushiftr',
    GlulxOp.jump: 'jump',
    GlulxOp.jz: 'jz',
    GlulxOp.jnz: 'jnz',
    GlulxOp.jeq: 'jeq',
    GlulxOp.jne: 'jne',
    GlulxOp.jlt: 'jlt',
    GlulxOp.jge: 'jge',
    GlulxOp.jgt: 'jgt',
    GlulxOp.jle: 'jle',
    GlulxOp.jltu: 'jltu',
    GlulxOp.jgeu: 'jgeu',
    GlulxOp.jgtu: 'jgtu',
    GlulxOp.jleu: 'jleu',
    GlulxOp.call: 'call',
    GlulxOp.ret: 'return',
    GlulxOp.catchEx: 'catch',
    GlulxOp.throwEx: 'throw',
    GlulxOp.tailcall: 'tailcall',
    GlulxOp.copy: 'copy',
    GlulxOp.copys: 'copys',
    GlulxOp.copyb: 'copyb',
    GlulxOp.sexs: 'sexs',
    GlulxOp.sexb: 'sexb',
    GlulxOp.aload: 'aload',
    GlulxOp.aloads: 'aloads',
    GlulxOp.aloadb: 'aloadb',
    GlulxOp.aloadbit: 'aloadbit',
    GlulxOp.astore: 'astore',
    GlulxOp.astores: 'astores',
    GlulxOp.astoreb: 'astoreb',
    GlulxOp.astorebit: 'astorebit',
    GlulxOp.stkcount: 'stkcount',
    GlulxOp.stkpeek: 'stkpeek',
    GlulxOp.stkswap: 'stkswap',
    GlulxOp.stkroll: 'stkroll',
    GlulxOp.stkcopy: 'stkcopy',
    GlulxOp.streamchar: 'streamchar',
    GlulxOp.streamnum: 'streamnum',
    GlulxOp.streamstr: 'streamstr',
    GlulxOp.streamunichar: 'streamunichar',
    GlulxOp.gestalt: 'gestalt',
    GlulxOp.debugtrap: 'debugtrap',
    GlulxOp.getmemsize: 'getmemsize',
    GlulxOp.setmemsize: 'setmemsize',
    GlulxOp.jumpabs: 'jumpabs',
    GlulxOp.random: 'random',
    GlulxOp.setrandom: 'setrandom',
    GlulxOp.quit: 'quit',
    GlulxOp.verify: 'verify',
    GlulxOp.restart: 'restart',
    GlulxOp.save: 'save',
    GlulxOp.restore: 'restore',
    GlulxOp.saveundo: 'saveundo',
    GlulxOp.restoreundo: 'restoreundo',
    GlulxOp.protect: 'protect',
    GlulxOp.hasundo: 'hasundo',
    GlulxOp.discardundo: 'discardundo',
    GlulxOp.glk: 'glk',
    GlulxOp.getstringtbl: 'getstringtbl',
    GlulxOp.setstringtbl: 'setstringtbl',
    GlulxOp.getiosys: 'getiosys',
    GlulxOp.setiosys: 'setiosys',
    GlulxOp.linearsearch: 'linearsearch',
    GlulxOp.binarysearch: 'binarysearch',
    GlulxOp.linkedsearch: 'linkedsearch',
    GlulxOp.callf: 'callf',
    GlulxOp.callfi: 'callfi',
    GlulxOp.callfii: 'callfii',
    GlulxOp.callfiii: 'callfiii',
    GlulxOp.mzero: 'mzero',
    GlulxOp.mcopy: 'mcopy',
    GlulxOp.malloc: 'malloc',
    GlulxOp.mfree: 'mfree',
    GlulxOp.accelfunc: 'accelfunc',
    GlulxOp.accelparam: 'accelparam',
    GlulxOp.numtof: 'numtof',
    GlulxOp.ftonumz: 'ftonumz',
    GlulxOp.ftonumn: 'ftonumn',
    GlulxOp.ceil: 'ceil',
    GlulxOp.floor: 'floor',
    GlulxOp.fadd: 'fadd',
    GlulxOp.fsub: 'fsub',
    GlulxOp.fmul: 'fmul',
    GlulxOp.fdiv: 'fdiv',
    GlulxOp.fmod: 'fmod',
    GlulxOp.sqrt: 'sqrt',
    GlulxOp.exp: 'exp',
    GlulxOp.log: 'log',
    GlulxOp.pow: 'pow',
    GlulxOp.sin: 'sin',
    GlulxOp.cos: 'cos',
    GlulxOp.tan: 'tan',
    GlulxOp.asin: 'asin',
    GlulxOp.acos: 'acos',
    GlulxOp.atan: 'atan',
    GlulxOp.atan2: 'atan2',
    GlulxOp.jfeq: 'jfeq',
    GlulxOp.jfne: 'jfne',
    GlulxOp.jflt: 'jflt',
    GlulxOp.jfle: 'jfle',
    GlulxOp.jfgt: 'jfgt',
    GlulxOp.jfge: 'jfge',
    GlulxOp.jisnan: 'jisnan',
    GlulxOp.jisinf: 'jisinf',
  };

  /// Gestalt selector name lookup map.
  static const Map<int, String> gestaltSelectorNames = {
    GlkGestaltSelectors.version: 'version',
    GlkGestaltSelectors.charInput: 'charInput',
    GlkGestaltSelectors.charOutput: 'charOutput',
    GlkGestaltSelectors.mouseInput: 'mouseInput',
    GlkGestaltSelectors.timer: 'timer',
    GlkGestaltSelectors.graphics: 'graphics',
    GlkGestaltSelectors.drawImage: 'drawImage',
    GlkGestaltSelectors.sound: 'sound',
    GlkGestaltSelectors.soundVolume: 'soundVolume',
    GlkGestaltSelectors.soundNotify: 'soundNotify',
    GlkGestaltSelectors.hyperlinks: 'hyperlinks',
    GlkGestaltSelectors.hyperlinkInput: 'hyperlinkInput',
    GlkGestaltSelectors.soundMusic: 'soundMusic',
    GlkGestaltSelectors.graphicsTransparency: 'graphicsTransparency',
    GlkGestaltSelectors.unicode: 'unicode',
    GlkGestaltSelectors.unicodeNorm: 'unicodeNorm',
    GlkGestaltSelectors.lineInputEcho: 'lineInputEcho',
    GlkGestaltSelectors.lineTerminators: 'lineTerminators',
    GlkGestaltSelectors.lineTerminatorKey: 'lineTerminatorKey',
    GlkGestaltSelectors.dateTime: 'dateTime',
    GlkGestaltSelectors.sound2: 'sound2',
    GlkGestaltSelectors.resourceStream: 'resourceStream',
    GlkGestaltSelectors.graphicsCharInput: 'graphicsCharInput',
    GlkGestaltSelectors.drawImageScale: 'drawImageScale',
  };

  /// GLK selector name lookup map.
  static const Map<int, String> glkSelectorNames = {
    GlkIoSelectors.exit: 'exit',
    GlkIoSelectors.setInterruptHandler: 'setInterruptHandler',
    GlkIoSelectors.tick: 'tick',
    GlkIoSelectors.gestalt: 'gestalt',
    GlkIoSelectors.gestaltExt: 'gestaltExt',
    GlkIoSelectors.windowIterate: 'windowIterate',
    GlkIoSelectors.windowGetRock: 'windowGetRock',
    GlkIoSelectors.windowGetRoot: 'windowGetRoot',
    GlkIoSelectors.windowOpen: 'windowOpen',
    GlkIoSelectors.windowClose: 'windowClose',
    GlkIoSelectors.windowGetSize: 'windowGetSize',
    GlkIoSelectors.windowSetArrangement: 'windowSetArrangement',
    GlkIoSelectors.windowGetArrangement: 'windowGetArrangement',
    GlkIoSelectors.windowGetType: 'windowGetType',
    GlkIoSelectors.windowGetParent: 'windowGetParent',
    GlkIoSelectors.windowClear: 'windowClear',
    GlkIoSelectors.windowMoveCursor: 'windowMoveCursor',
    GlkIoSelectors.windowGetStream: 'windowGetStream',
    GlkIoSelectors.windowSetEchoStream: 'windowSetEchoStream',
    GlkIoSelectors.windowGetEchoStream: 'windowGetEchoStream',
    GlkIoSelectors.setWindow: 'setWindow',
    GlkIoSelectors.windowGetSibling: 'windowGetSibling',
    GlkIoSelectors.streamIterate: 'streamIterate',
    GlkIoSelectors.streamGetRock: 'streamGetRock',
    GlkIoSelectors.streamOpenFile: 'streamOpenFile',
    GlkIoSelectors.streamOpenMemory: 'streamOpenMemory',
    GlkIoSelectors.streamClose: 'streamClose',
    GlkIoSelectors.streamSetPosition: 'streamSetPosition',
    GlkIoSelectors.streamGetPosition: 'streamGetPosition',
    GlkIoSelectors.streamSetCurrent: 'streamSetCurrent',
    GlkIoSelectors.streamGetCurrent: 'streamGetCurrent',
    GlkIoSelectors.streamOpenResource: 'streamOpenResource',
    GlkIoSelectors.filerefCreateTemp: 'filerefCreateTemp',
    GlkIoSelectors.filerefCreateByName: 'filerefCreateByName',
    GlkIoSelectors.filerefCreateByPrompt: 'filerefCreateByPrompt',
    GlkIoSelectors.filerefDestroy: 'filerefDestroy',
    GlkIoSelectors.filerefIterate: 'filerefIterate',
    GlkIoSelectors.filerefGetRock: 'filerefGetRock',
    GlkIoSelectors.filerefDeleteFile: 'filerefDeleteFile',
    GlkIoSelectors.filerefDoesFileExist: 'filerefDoesFileExist',
    GlkIoSelectors.filerefCreateFromFileref: 'filerefCreateFromFileref',
    GlkIoSelectors.putChar: 'putChar',
    GlkIoSelectors.putCharStream: 'putCharStream',
    GlkIoSelectors.putString: 'putString',
    GlkIoSelectors.putStringStream: 'putStringStream',
    GlkIoSelectors.putBuffer: 'putBuffer',
    GlkIoSelectors.putBufferStream: 'putBufferStream',
    GlkIoSelectors.setStyle: 'setStyle',
    GlkIoSelectors.setStyleStream: 'setStyleStream',
    GlkIoSelectors.getCharStream: 'getCharStream',
    GlkIoSelectors.getLineStream: 'getLineStream',
    GlkIoSelectors.getBufferStream: 'getBufferStream',
    GlkIoSelectors.charToLower: 'charToLower',
    GlkIoSelectors.charToUpper: 'charToUpper',
    GlkIoSelectors.stylehintSet: 'stylehintSet',
    GlkIoSelectors.stylehintClear: 'stylehintClear',
    GlkIoSelectors.styleDistinguish: 'styleDistinguish',
    GlkIoSelectors.styleMeasure: 'styleMeasure',
    GlkIoSelectors.select: 'select',
    GlkIoSelectors.selectPoll: 'selectPoll',
    GlkIoSelectors.filerefCreateByFileUni: 'filerefCreateByFileUni',
    GlkIoSelectors.filerefCreateByNameUni: 'filerefCreateByNameUni',
    GlkIoSelectors.filerefCreateByPromptUni: 'filerefCreateByPromptUni',
    GlkIoSelectors.requestLineEvent: 'requestLineEvent',
    GlkIoSelectors.cancelLineEvent: 'cancelLineEvent',
    GlkIoSelectors.requestCharEvent: 'requestCharEvent',
    GlkIoSelectors.cancelCharEvent: 'cancelCharEvent',
    GlkIoSelectors.requestMouseEvent: 'requestMouseEvent',
    GlkIoSelectors.cancelMouseEvent: 'cancelMouseEvent',
    GlkIoSelectors.requestTimerEvents: 'requestTimerEvents',
    GlkIoSelectors.imageGetInfo: 'imageGetInfo',
    GlkIoSelectors.imageDraw: 'imageDraw',
    GlkIoSelectors.imageDrawScaled: 'imageDrawScaled',
    GlkIoSelectors.windowFlowBreak: 'windowFlowBreak',
    GlkIoSelectors.windowEraseRect: 'windowEraseRect',
    GlkIoSelectors.windowFillRect: 'windowFillRect',
    GlkIoSelectors.windowSetBackgroundColor: 'windowSetBackgroundColor',
    GlkIoSelectors.imageDrawScaledExt: 'imageDrawScaledExt',
    GlkIoSelectors.schannelIterate: 'schannelIterate',
    GlkIoSelectors.schannelGetRock: 'schannelGetRock',
    GlkIoSelectors.schannelCreate: 'schannelCreate',
    GlkIoSelectors.schannelDestroy: 'schannelDestroy',
    GlkIoSelectors.schannelCreateExt: 'schannelCreateExt',
    GlkIoSelectors.schannelPlayMulti: 'schannelPlayMulti',
    GlkIoSelectors.schannelPlay: 'schannelPlay',
    GlkIoSelectors.schannelPlayExt: 'schannelPlayExt',
    GlkIoSelectors.schannelStop: 'schannelStop',
    GlkIoSelectors.schannelSetVolume: 'schannelSetVolume',
    GlkIoSelectors.soundLoadHint: 'soundLoadHint',
    GlkIoSelectors.schannelSetVolumeExt: 'schannelSetVolumeExt',
    GlkIoSelectors.schannelPause: 'schannelPause',
    GlkIoSelectors.schannelUnpause: 'schannelUnpause',
    GlkIoSelectors.setHyperlink: 'setHyperlink',
    GlkIoSelectors.setHyperlinkStream: 'setHyperlinkStream',
    GlkIoSelectors.requestHyperlinkEvent: 'requestHyperlinkEvent',
    GlkIoSelectors.cancelHyperlinkEvent: 'cancelHyperlinkEvent',
    GlkIoSelectors.bufferToLowerCaseUni: 'bufferToLowerCaseUni',
    GlkIoSelectors.bufferToUpperCaseUni: 'bufferToUpperCaseUni',
    GlkIoSelectors.bufferToTitleCaseUni: 'bufferToTitleCaseUni',
    GlkIoSelectors.bufferCanonDecomposeUni: 'bufferCanonDecomposeUni',
    GlkIoSelectors.bufferCanonNormalizeUni: 'bufferCanonNormalizeUni',
    GlkIoSelectors.putCharUni: 'putCharUni',
    GlkIoSelectors.putStringUni: 'putStringUni',
    GlkIoSelectors.putBufferUni: 'putBufferUni',
    GlkIoSelectors.putCharStreamUni: 'putCharStreamUni',
    GlkIoSelectors.putStringStreamUni: 'putStringStreamUni',
    GlkIoSelectors.putBufferStreamUni: 'putBufferStreamUni',
    GlkIoSelectors.getCharStreamUni: 'getCharStreamUni',
    GlkIoSelectors.getBufferStreamUni: 'getBufferStreamUni',
    GlkIoSelectors.getLineStreamUni: 'getLineStreamUni',
    GlkIoSelectors.streamOpenFileUni: 'streamOpenFileUni',
    GlkIoSelectors.streamOpenMemoryUni: 'streamOpenMemoryUni',
    GlkIoSelectors.streamOpenResourceUni: 'streamOpenResourceUni',
    GlkIoSelectors.requestCharEventUni: 'requestCharEventUni',
    GlkIoSelectors.requestLineEventUni: 'requestLineEventUni',
    GlkIoSelectors.setEchoLineEvent: 'setEchoLineEvent',
    GlkIoSelectors.setTerminatorsLineEvent: 'setTerminatorsLineEvent',
    GlkIoSelectors.currentTime: 'currentTime',
    GlkIoSelectors.currentSimpleTime: 'currentSimpleTime',
    GlkIoSelectors.timeToDateUtc: 'timeToDateUtc',
    GlkIoSelectors.timeToDateLocal: 'timeToDateLocal',
    GlkIoSelectors.simpleTimeToDateUtc: 'simpleTimeToDateUtc',
    GlkIoSelectors.simpleTimeToDateLocal: 'simpleTimeToDateLocal',
    GlkIoSelectors.dateToTimeUtc: 'dateToTimeUtc',
    GlkIoSelectors.dateToTimeLocal: 'dateToTimeLocal',
    GlkIoSelectors.dateToSimpleTimeUtc: 'dateToSimpleTimeUtc',
    GlkIoSelectors.dateToSimpleTimeLocal: 'dateToSimpleTimeLocal',
  };
}
