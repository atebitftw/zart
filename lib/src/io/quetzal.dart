import 'dart:collection';
import 'dart:io';
import 'package:zart/src/io/iff.dart';
import 'package:zart/src/binary_helper.dart';
import 'package:zart/src/header.dart';
import 'package:zart/src/engines/engine.dart';
import 'package:zart/src/memory_map.dart';
import 'package:zart/src/z_machine.dart';

/// Quetzal IFF Standard load/save implementation.
///
/// Ref: http://www.inform-fiction.org/zmachine/standards/quetzal/
///
/// Note that while the format of the standard is followed, and
/// files saved with this class should interchange with other interpreters
/// that conform to Quetzal, this implementation does not support all
/// standards on file restore (compression, etc), therefore it is not
/// guaranteed to successfully load Quetzal save files that are not
/// explicitly saved with it.
class Quetzal {
  /// Generates a stream of save bytes in the Quetzal format.
  static List<int?> save(int pcAddr) {
    List<int> saveData = <int>[];

    IFF.writeChunk(saveData, Chunk.form);
    IFF.writeChunk(saveData, Chunk.ifzs);

    //associated story file
    IFF.writeChunk(saveData, Chunk.ifhd);
    IFF.write4Byte(saveData, 13);
    IFF.write2Byte(saveData, Z.engine.mem.loadw(Header.release));
    IFF.write2Byte(saveData, Z.engine.mem.loadw(Header.serialNumber));
    IFF.write2Byte(saveData, Z.engine.mem.loadw(Header.serialNumber + 2));
    IFF.write2Byte(saveData, Z.engine.mem.loadw(Header.serialNumber + 4));
    IFF.write2Byte(saveData, Z.engine.mem.loadw(Header.checkSumOfFile));
    //pc
    IFF.write3Byte(saveData, pcAddr); //varies depending on version.
    saveData.add(0); //pad byte

    //compressed memory
    IFF.writeChunk(saveData, Chunk.cmem);

    var compressedParams = _compressMem(
      Z.engine.mem.memList,
      Z.rawBytes,
      Z.engine.mem.memList.length,
    );

    IFF.write4Byte(saveData, compressedParams.length);
    saveData.addAll(compressedParams);

    if (compressedParams.length % 2 != 0) {
      saveData.add(0); //pad byte
    }

    //stacks, oldest first
    IFF.writeChunk(saveData, Chunk.stks);

    var stackData = Queue<StackFrame>();

    stackData.addFirst(StackFrame(0, 0));

    while (stackData.first.nextCallStackIndex != null) {
      stackData.addFirst(
        StackFrame(
          stackData.first.nextCallStackIndex!,
          stackData.first.nextEvalStackIndex!,
        ),
      );
    }

    var totalStackBytes = 0;
    for (final sd in stackData) {
      totalStackBytes += sd.computedByteSize;
    }

    IFF.write4Byte(saveData, totalStackBytes);

    for (StackFrame sd in stackData) {
      IFF.write3Byte(saveData, sd.returnAddr);

      //flags byte
      var flagByte = 0;

      //set the call_xN bit if this stack frame is supposed to discard returns
      if (sd.returnVar == Engine.stackMarker) {
        flagByte = BinaryHelper.set(flagByte, 4);
      }

      //using the first 4 bits, we set the number of locals... (not standard, but permissible)
      flagByte |= sd.locals.length;

      saveData.add(flagByte);

      // return variable number
      // (ref 4.6)
      saveData.add(sd.returnVar != Engine.stackMarker ? sd.returnVar : 0);

      //total args passed (4.3.4)
      saveData.add(BinaryHelper.setBottomBits(sd.totalArgsPassed));

      IFF.write2Byte(saveData, sd.evals.length);

      for (int? l in sd.locals) {
        IFF.write2Byte(saveData, l!);
      }

      for (int? e in sd.evals) {
        IFF.write2Byte(saveData, e!);
      }
    }

    if (totalStackBytes % 2 != 0) {
      saveData.add(0);
    } //pad byte

    return saveData;
  }

  /// Restores current machine state with the given stream of file bytes.
  static bool restore(List<int> rawBytes) {
    var fileBytes = List.from(rawBytes);
    //List<int> restoreData = List<int>();

    Chunk? nextChunk = IFF.readChunk(fileBytes);
    if (!assertChunk(Chunk.form, nextChunk)) return false;

    nextChunk = IFF.readChunk(fileBytes);
    if (!assertChunk(Chunk.ifzs, nextChunk)) return false;

    var gotStacks = false;
    var gotMem = false;
    var gotHeader = false;
    late int pc;
    var memBytes = [];
    final stackList = <StackFrame>[];

    nextChunk = IFF.readChunk(fileBytes);
    if (nextChunk == null) return false;

    while (nextChunk != null) {
      switch (nextChunk) {
        case Chunk.ifhd:
          // here we are validating that this file is compatible
          // with the game currently loaded into the machine.

          IFF.read4Byte(fileBytes); //size (always 13)
          if (Z.engine.mem.loadw(Header.release) != IFF.read2Byte(fileBytes)) {
            return false;
          }
          if (Z.engine.mem.loadw(Header.serialNumber) !=
              IFF.read2Byte(fileBytes)) {
            return false;
          }
          if (Z.engine.mem.loadw(Header.serialNumber + 2) !=
              IFF.read2Byte(fileBytes)) {
            return false;
          }
          if (Z.engine.mem.loadw(Header.serialNumber + 4) !=
              IFF.read2Byte(fileBytes)) {
            return false;
          }
          if (Z.engine.mem.loadw(Header.checkSumOfFile) !=
              IFF.read2Byte(fileBytes)) {
            return false;
          }
          pc = IFF.read3Byte(fileBytes); //PC
          IFF.nextByte(fileBytes); //pad
          gotHeader = true;
          break;
        case Chunk.stks:
          var stacksLen = IFF.read4Byte(fileBytes);

          StackFrame getNextStackFrame() {
            var sf = StackFrame.empty();

            sf.returnAddr = IFF.read3Byte(fileBytes);

            var flagByte = IFF.nextByte(fileBytes)!;

            var returnVar = IFF.nextByte(fileBytes);

            sf.returnVar = BinaryHelper.isSet(flagByte, 4)
                ? Engine.stackMarker
                : returnVar!;

            var numLocals = BinaryHelper.bottomBits(flagByte, 4);

            var argsPassed = IFF.nextByte(fileBytes)!;

            var args = 0;
            while (BinaryHelper.isSet(argsPassed, 0)) {
              args++;
              argsPassed = argsPassed >> 1;
            }
            sf.totalArgsPassed = args;

            var numEvals = IFF.read2Byte(fileBytes);

            for (int i = 0; i < numLocals; i++) {
              sf.locals.add(IFF.read2Byte(fileBytes));
            }

            for (int i = 0; i < numEvals; i++) {
              sf.evals.add(IFF.read2Byte(fileBytes));
            }
            return sf;
          }

          while (stacksLen > 0) {
            if (stacksLen == 1) {
              //pad byte
              IFF.nextByte(fileBytes);
              continue;
            }

            stackList.add(getNextStackFrame());
            stacksLen -= stackList.last.computedByteSize;
          }

          gotStacks = true;
          break;
        case Chunk.umem:
          var numBytes = IFF.read4Byte(fileBytes);

          //memory length mismatch
          if (numBytes != Z.engine.mem.memList.length) {
            return false;
          }

          memBytes = fileBytes.getRange(0, numBytes) as List<dynamic>;
          fileBytes.removeRange(0, numBytes);

          //IFF.read pad byte if present
          if (numBytes % 2 != 0) {
            IFF.nextByte(fileBytes);
          }
          gotMem = true;
          break;
        case Chunk.cmem:
          var numBytes = IFF.read4Byte(fileBytes);
          var cmemBytes = fileBytes.getRange(0, numBytes).cast<int>().toList();
          fileBytes.removeRange(0, numBytes);
          if (numBytes % 2 != 0) {
            IFF.nextByte(fileBytes);
          }

          try {
            memBytes = _decompressMem(cmemBytes, Z.rawBytes);
          } catch (e) {
            print('Quetzal Restore Error: $e');
            return false; // Decompression failed
          }

          gotMem = true;
          break;
        default:
          if (!gotStacks || !gotMem || !gotHeader) {
            if (nextChunk == Chunk.form || nextChunk == Chunk.ifzs) {
              return false; //something went horribly wrong in the file format
            }

            //attempt to skip the chunk
            var sizeOfChunk = IFF.read4Byte(fileBytes);
            fileBytes.removeRange(0, sizeOfChunk);
          }
      }

      if (gotStacks && gotMem && gotHeader) break;
      nextChunk = IFF.readChunk(fileBytes);
    }

    if (!gotStacks || !gotMem || !gotHeader) return false;

    //now that we have all the data structures, do the restore...

    //memory
    Z.engine.mem = MemoryMap(memBytes as List<int>);
    Z.engine.visitHeader();

    Z.engine.callStack.clear();
    Z.engine.stack.clear();

    //stacks
    for (StackFrame sf in stackList) {
      //callstack first
      stdout.writeln(sf);

      //locals
      Z.engine.callStack.push(sf.locals.length);

      for (final local in sf.locals) {
        Z.engine.callStack.push(local!);
      }

      //total locals
      Z.engine.callStack.push(sf.locals.length);

      //returnTo variable
      Z.engine.callStack.push(sf.returnVar);

      //return addr
      Z.engine.callStack.push(sf.returnAddr);

      //eval stack
      Z.engine.stack.push(Engine.stackMarker);
      for (final eval in sf.evals) {
        Z.engine.stack.push(eval!);
      }
    }

    Z.engine.programCounter = pc;

    return true;
  }

  /// Asserts that the given chunk is the expected chunk.
  static bool assertChunk(Chunk expect, Chunk? value) {
    return (expect == value);
  }

  /// Compresses the given memory.
  static List<int> _compressMem(
    List<int> currentMem,
    List<int> originalMem,
    int length,
  ) {
    var result = <int>[];
    var xorMem = <int>[];

    // XOR Map
    for (var i = 0; i < length; i++) {
      xorMem.add(currentMem[i] ^ originalMem[i]);
    }

    // RLE Compression
    var i = 0;
    while (i < length) {
      if (xorMem[i] == 0) {
        var zeroCount = 0;
        while (i < length && xorMem[i] == 0 && zeroCount < 256) {
          zeroCount++;
          i++;
        }
        result.add(0);
        result.add(zeroCount - 1);
      } else {
        result.add(xorMem[i]);
        i++;
      }
    }
    return result;
  }

  static List<int> _decompressMem(
    List<int> compressedBytes,
    List<int> originalMem,
  ) {
    var result = <int>[];
    var i = 0;
    while (i < compressedBytes.length) {
      var byte = compressedBytes[i++];
      if (byte == 0) {
        if (i >= compressedBytes.length) {
          // Should not happen in valid CMem, 0 must be followed by count
          break;
        }
        var count = compressedBytes[i++] + 1;
        for (var k = 0; k < count; k++) {
          result.add(0);
        }
      } else {
        result.add(byte);
      }
    }

    // XOR back
    // The result length depends on how much was compressed, but it should generally
    // match the dynamic memory region. For safety, we match the reconstructed length.
    var decompressed = <int>[];
    for (var j = 0; j < result.length && j < originalMem.length; j++) {
      decompressed.add(result[j] ^ originalMem[j]);
    }

    // If original memory is larger (e.g. static memory not fully covered by dynamic changes if we only saved dynamic),
    // we might need to fill rest from original.
    // BUT Quetzal says CMem is XOR of dynamic memory. Usually dynamic memory is the *entire* memory
    // map that is mutable or just up to a point?
    // Standard 5.3: "The CMem chunk contains the dynamic memory... exclusive-ORed..."
    // Dynamic memory usually implies addresses 0 to header[static_mem_base] - 1?
    // Or does it mean the whole story file capability?
    // Usually save files restore the *entire* RAM contents up to the size of the story file RAM.
    // Z-Machine RAM is up to 64KB or more.
    // We should ensure the output matches the expected memory size.
    // If the compressed data ended early (e.g. trailing zeros omitted? No, RLE encodes them),
    // it should match exactly.

    // In strict Quetzal, CMem covers the *dynamic memory* range.
    // Let's assume the result should match the original memory length we care about.
    // For now we just return what we have reconstructed.

    return decompressed;
  }
}

/// Quetzal Stack Frame
class StackFrame {
  /// Return address
  late int returnAddr;

  /// Return variable
  late int returnVar;

  /// Locals
  final Queue<int?> locals;

  /// Evaluation stack
  final Queue<int?> evals;

  /// Next call stack index
  int? nextCallStackIndex;

  /// Next evaluation stack index
  int? nextEvalStackIndex;

  /// Total arguments passed
  late int totalArgsPassed;

  /// Instantiates an empty [StackFrame].
  StackFrame.empty() : locals = Queue<int>(), evals = Queue<int>();

  /// Instantiates a [StackFrame] from the current call stack and evaluation stack.
  StackFrame(int callIndex, int evalIndex)
    : locals = Queue<int>(),
      evals = Queue<int>() {
    returnAddr = Z.engine.callStack[callIndex];
    returnVar = Z.engine.callStack[++callIndex];

    var totalLocals = Z.engine.callStack[++callIndex];

    for (int i = 0; i < totalLocals; i++) {
      locals.addFirst(Z.engine.callStack[++callIndex]);
    }

    totalArgsPassed = Z.engine.callStack[++callIndex];

    nextCallStackIndex = callIndex + 1;

    if (nextCallStackIndex! >= Z.engine.callStack.length) {
      nextCallStackIndex = null;
    }

    if (evalIndex < Z.engine.stack.length) {
      var eStack = Z.engine.stack[evalIndex];

      while (eStack != Engine.stackMarker) {
        evals.addFirst(eStack);
        // safe check before increment
        if (++evalIndex >= Z.engine.stack.length) break;
        eStack = Z.engine.stack[evalIndex];
      }
    }

    if (nextCallStackIndex != null) {
      nextEvalStackIndex = evalIndex + 1;
    }
  }

  /// Returns the computed byte size of the [StackFrame].
  int get computedByteSize => 8 + (locals.length * 2) + (evals.length * 2);

  @override
  String toString() {
    var s = StringBuffer();
    s.write('return addr: 0x${returnAddr.toRadixString(16)}\n');
    s.write('return var: 0x${returnVar.toRadixString(16)}\n');
    s.write('args passed: $totalArgsPassed');
    s.write('locals: $locals \n');
    s.write('evals: $evals \n');
    s.write('nextCallStackIndex: $nextCallStackIndex \n');
    s.write('nextEvalStackIndex: $nextEvalStackIndex\n\n');
    return s.toString();
  }
}
