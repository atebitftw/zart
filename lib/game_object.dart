import 'package:zart/binary_helper.dart';
import 'package:zart/debugger.dart';
import 'package:zart/game_exception.dart';
import 'package:zart/z_machine.dart';
import 'package:zart/zscii.dart';

/// Helper class for working with v3 game objects.
class GameObject {
  int? id;

  int get parentAddr =>
      _address! + ((ZMachine.verToInt(Z.engine.version) <= 3 ? 4 : 6));
  int get siblingAddr =>
      _address! + ((ZMachine.verToInt(Z.engine.version) <= 3 ? 5 : 8));
  int get childAddr =>
      _address! + ((ZMachine.verToInt(Z.engine.version) <= 3 ? 6 : 10));

  int? _address;

  int get parent => (ZMachine.verToInt(Z.engine.version) <= 3)
      ? Z.engine.mem.loadb(parentAddr)
      : Z.engine.mem.loadw(parentAddr);
  set parent(int? oid) => ZMachine.verToInt(Z.engine.version) <= 3
      ? Z.engine.mem.storeb(parentAddr, oid!)
      : Z.engine.mem.storew(parentAddr, oid!);

  int get child => ZMachine.verToInt(Z.engine.version) <= 3
      ? Z.engine.mem.loadb(childAddr)
      : Z.engine.mem.loadw(childAddr);
  set child(int? oid) => ZMachine.verToInt(Z.engine.version) <= 3
      ? Z.engine.mem.storeb(childAddr, oid!)
      : Z.engine.mem.storew(childAddr, oid!);

  int get sibling => ZMachine.verToInt(Z.engine.version) <= 3
      ? Z.engine.mem.loadb(siblingAddr)
      : Z.engine.mem.loadw(siblingAddr);
  set sibling(int oid) => ZMachine.verToInt(Z.engine.version) <= 3
      ? Z.engine.mem.storeb(siblingAddr, oid)
      : Z.engine.mem.storew(siblingAddr, oid);

  late int flags;

  int get properties => Z.engine.mem
      .loadw(_address! + (ZMachine.verToInt(Z.engine.version) <= 3 ? 7 : 12));

  int get propertyTableStart =>
      properties + (Z.engine.mem.loadb(properties) * 2) + 1;

  String? shortName;

  GameObject(this.id) {
    _address = _getObjectAddress();

    shortName = _address != 0 ? _getObjectShortName() : '';

    if (id == 0) return;
    _readFlags();
  }

  int getNextProperty(int? pnum) {
    if (pnum == 0) {
      //get first property
      return propertyNumber(propertyTableStart);
    }

    var addr = getPropertyAddress(pnum);

    if (addr == 0) {
      throw GameException('Attempted to get next property of a property'
          ' that doesn\'t exist ($pnum)');
    }

    var len = propertyLength(addr - 1);

    addr += len;

    len = ZMachine.verToInt(Z.engine.version) <= 3 ||
            !BinaryHelper.isSet(Z.engine.mem.loadb(addr), 7)
        ? propertyLength(addr)
        : propertyLength(addr + 1);

    return len == 0 ? len : propertyNumber(addr);
  }

  int getPropertyAddress(int? pnum) {
    if (pnum == 0) return 0;

    var propNum = 999999;
    int addr = propertyTableStart;

    while (propNum > pnum!) {
      var len = ZMachine.verToInt(Z.engine.version) <= 3 ||
              !BinaryHelper.isSet(Z.engine.mem.loadb(addr), 7)
          ? propertyLength(addr)
          : propertyLength(addr + 1);

      propNum = propertyNumber(addr);

      //not found (ref 12.4.1)
      if (len == 0) {
        return 0;
      }

      if (propNum == pnum) {
        if (ZMachine.verToInt(Z.engine.version) <= 3) {
          return addr + 1;
        } else {
          return addr + (len > 2 ? 2 : 1);
        }
      }

      //skip to the next property
      if (ZMachine.verToInt(Z.engine.version) <= 3) {
        addr += (len + 1);
      } else {
        //if property len > 2, account for the second
        //size byte in the header
        addr += (len + ((len > 2) ? 2 : 1));
      }
    }

    //return 0 if not found
    return 0;
  }

  void setPropertyValue(int? pnum, int? value) {
    var addr = getPropertyAddress(pnum);
    var len = propertyLength(addr - 1);

    if (addr == 0) {
      throw GameException('Property not found.');
    }

    if (len < 1 || len > 2) {
      throw GameException('Cannot set property on properties > 2 bytes.');
    }

    if (len == 1) {
      if (value! < 0) {
        Debugger.todo('length is 1 & value < 0');
      }
      value &= 0xff;
      Z.engine.mem.storeb(addr, value);
    } else if (len == 2) {
      Z.engine.mem.storew(addr, value!);
    }
  }

  //gets a byte or word value from a given [propertyNumber].
  int getPropertyValue(int pnum) {
    var propNum = 999999;
    int addr = propertyTableStart;

    while (propNum > pnum) {
      propNum = propertyNumber(addr);

      var len = ZMachine.verToInt(Z.engine.version) <= 3 ||
              !BinaryHelper.isSet(Z.engine.mem.loadb(addr), 7)
          ? propertyLength(addr)
          : propertyLength(addr + 1);

      //not found (ref 12.4.1)
      if (len == 0) {
        return GameObject.getPropertyDefault(pnum);
      }

      if (propNum == pnum) {
        //ding ding ding

        if (len > 2) {
          throw GameException(
              'Only property length of 1 or 2 is supported by this function: $len');
        }

        if (len == 1) {
          return Z.engine.mem.loadb(addr + 1);
        } else {
          return Z.engine.mem.loadw(addr + 1);
        }
      }

      //skip to the next property
      if (ZMachine.verToInt(Z.engine.version) <= 3) {
        addr += (len + 1);
      } else {
        //if property len > 2, account for the second
        //size byte in the header
        addr += (len + ((len > 2) ? 2 : 1));
      }
    }

    //return default property instead (ref 12.4.1)
    return GameObject.getPropertyDefault(pnum);
  }

  static int propertyLength(int address) {
    if (address == 0) return 0;

    var fb = Z.engine.mem.loadb(address);

    if (ZMachine.verToInt(Z.engine.version) <= 3) {
      return ((fb >> 5) & 0x07) + 1;
    } else {
      if (BinaryHelper.isSet(fb, 7)) {
        //(ref 12.4.2.1)
        var value = BinaryHelper.bottomBits(fb, 6);
        // (ref 12.4.2.1.1)
        return value > 0 ? value : 64;
      } else {
        //(ref 12.4.2.2)
        return BinaryHelper.isSet(fb, 6) ? 2 : 1;
      }
    }
  }

  static int propertyNumber(int address) {
    if (address == 0) return 0;

    if (ZMachine.verToInt(Z.engine.version) <= 3) {
      return Z.engine.mem.loadb(address) % 32;
    } else {
      // (ref 12.4.2)
      return BinaryHelper.bottomBits(Z.engine.mem.loadb(address), 6);
    }
  }

  static int getPropertyDefault(int propertyNum) {
    propertyNum -= 1;
    propertyNum %= 31;

    if (propertyNum < 0 || propertyNum > 31) {
      throw GameException('property number out of bounds (1-31)');
    }
    return Z.engine.mem
        .loadw(Z.engine.mem.objectsAddress + (propertyNum * 2));
  }

  void removeFromTree() {
    //already an orphan
    if (parent == 0) return;

    var pgo = GameObject(parent);

    if (pgo.child == id) {
      //we are the parent's child so...
      pgo.child = 0;
      if (sibling != 0) {
        //move sibling to parent's child
        pgo.child = sibling;
      }
    } else {
      //find the sibling to the left of us...
      var leftSib = leftSibling();

      // now set that sibling's sibling to our sibling
      // effectively removing us from the list.
      GameObject(leftSib).sibling = sibling;
    }
    parent = 0;
    sibling = 0;
  }

  int? leftSibling() {
    var pgo = GameObject(parent);
    var theChild = GameObject(pgo.child);

    while (theChild.sibling != id) {
      theChild = GameObject(theChild.sibling);

      if (theChild.id == 0) {
        throw GameException('Sibling list not well formed.');
      }
    }

    return theChild.id;
  }

  void insertTo(int? obj) {
    if (parent != 0) {
      removeFromTree();
    }

    var p = GameObject(obj);

    if (p.child > 0) {
      //parent already has child, make that child our sibling now
      sibling = p.child;
    }

    p.child = id;
    parent = obj;
  }

  void setFlagBit(int bit) {
    flags = BinaryHelper.set(
        flags, (ZMachine.verToInt(Z.engine.version) <= 3 ? 31 : 47) - bit);

    _writeFlags();
  }

  void unsetFlagBit(int bit) {
    flags = BinaryHelper.unset(
        flags, (ZMachine.verToInt(Z.engine.version) <= 3 ? 31 : 47) - bit);

    _writeFlags();
  }

  bool isFlagBitSet(int bit) {
    return BinaryHelper.isSet(
        flags, (ZMachine.verToInt(Z.engine.version) <= 3 ? 31 : 47) - bit);
  }

  @override
  String toString() {
    final s = StringBuffer();
    for (int i = 0;
        i <= (ZMachine.verToInt(Z.engine.version) <= 3 ? 31 : 47);
        i++) {
      if (BinaryHelper.isSet(
          flags, (ZMachine.verToInt(Z.engine.version) <= 3 ? 31 : 47) - i)) {
        s.write('[$i] ');
      }
    }

    final ret = '''
Object #:$id, "$shortName" (Address: 0x${_address!.toRadixString(16)})
parent: $parent "${GameObject(parent).shortName}"
sibling: $sibling "${GameObject(sibling).shortName}"
child: $child "${GameObject(child).shortName}"
Property Address 0x${propertyTableStart.toRadixString(16)}
flags: $s
''';

    return ret;
  }

  int _getObjectAddress() {
    // skip header bytes 62 or 126 (ref 12.2)
    var objStart = Z.engine.mem.objectsAddress +
        (ZMachine.verToInt(Z.engine.version) <= 3 ? 62 : 126);

    // 9 or 14 bytes per object (ref 12.3.1)
    objStart += (id! - 1) * (ZMachine.verToInt(Z.engine.version) <= 3 ? 9 : 14);

    //TODO find a better check (this doesn't work in minizork)
    //if (objStart > Z.machine.mem.loadw(Header.GLOBAL_VARS_TABLE_ADDR)) return 0;

    return objStart;
  }

  void _readFlags() {
    if (ZMachine.verToInt(Z.engine.version) <= 3) {
      flags = (Z.engine.mem.loadb(_address!) << 24) |
          (Z.engine.mem.loadb(_address! + 1) << 16) |
          (Z.engine.mem.loadb(_address! + 2) << 8) |
          Z.engine.mem.loadb(_address! + 3);
    } else {
      flags = (Z.engine.mem.loadb(_address!) << 40) |
          (Z.engine.mem.loadb(_address! + 1) << 32) |
          (Z.engine.mem.loadb(_address! + 2) << 24) |
          (Z.engine.mem.loadb(_address! + 3) << 16) |
          (Z.engine.mem.loadb(_address! + 4) << 8) |
          Z.engine.mem.loadb(_address! + 5);
    }
  }

  void _writeFlags() {
    if (ZMachine.verToInt(Z.engine.version) <= 3) {
      Z.engine.mem.storeb(_address! + 3, BinaryHelper.bottomBits(flags, 8));
      Z.engine.mem
          .storeb(_address! + 2, BinaryHelper.bottomBits(flags >> 8, 8));
      Z.engine.mem
          .storeb(_address! + 1, BinaryHelper.bottomBits(flags >> 16, 8));
      Z.engine.mem.storeb(_address!, BinaryHelper.bottomBits(flags >> 24, 8));
    } else {
      Z.engine.mem.storeb(_address! + 5, BinaryHelper.bottomBits(flags, 8));
      Z.engine.mem
          .storeb(_address! + 4, BinaryHelper.bottomBits(flags >> 8, 8));
      Z.engine.mem
          .storeb(_address! + 3, BinaryHelper.bottomBits(flags >> 16, 8));
      Z.engine.mem
          .storeb(_address! + 2, BinaryHelper.bottomBits(flags >> 24, 8));
      Z.engine.mem
          .storeb(_address! + 1, BinaryHelper.bottomBits(flags >> 32, 8));
      Z.engine.mem.storeb(_address!, BinaryHelper.bottomBits(flags >> 40, 8));
    }
  }

  String _getObjectShortName() {
    if (id == 0 || Z.engine.mem.loadb(properties) == 0) return '';

    return ZSCII.readZStringAndPop(properties + 1);
  }
}
