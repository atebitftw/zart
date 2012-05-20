/** Helper class for working with v3 game objects. */
class GameObjectV3
{
  final int id;
  int CHILD_ADDR;
  int SIBLING_ADDR;
  int PARENT_ADDR;

  int _address;

  int get parent () => Z._machine.mem.loadb(PARENT_ADDR);
  int get child () => Z._machine.mem.loadb(CHILD_ADDR);
  int get sibling () => Z._machine.mem.loadb(SIBLING_ADDR);
  set parent(int oid) => Z._machine.mem.storeb(PARENT_ADDR, oid);
  set sibling(int oid) => Z._machine.mem.storeb(SIBLING_ADDR, oid);
  set child(int oid) => Z._machine.mem.storeb(CHILD_ADDR, oid);

  int flags;

  int get properties() => Z._machine.mem.loadw(_address + 7);

  int get propertyTableStart() => properties + (Z._machine.mem.loadb(properties) * 2) + 1;

  String shortName;

  GameObjectV3(this.id)
  {
    _address = _getObjectAddress();
    shortName = _getObjectShortName();
    PARENT_ADDR = _address + 4;
    SIBLING_ADDR = _address + 5;
    CHILD_ADDR = _address + 6;

    if (id == 0) return;
    _readFlags();
  }

  int getNextProperty(int pnum){

    if (pnum == 0){
      //get first property

      int addr = propertyTableStart;
      return propertyNumber(addr);
    }

    var addr = getPropertyAddress(pnum);

    if (addr == 0) {
      throw new GameException('Attempted to get next property of a property'
        ' that doesn\'t exist ($pnum)');
    }

    var len = propertyLength(addr - 1);
    addr += len;

    len = propertyLength(addr);

    return len == 0 ? len : propertyNumber(addr);
  }


  int getPropertyAddress(int pnum){
    if (pnum == 0) return 0;

    var propNum = 999999;
    int addr = propertyTableStart;

    while(propNum > pnum){
      var len = propertyLength(addr);
      propNum = propertyNumber(addr);

      //not found (ref 12.4.1)
      if (len == 0){
        return 0;
      }

      if (propNum == pnum){
        return addr + 1;
      }

      //skip to the next property
      addr += (len + 1);
    }

    //return 0 if not found
    return 0;
  }

  void setPropertyValue(int pnum, int value){
    var addr = getPropertyAddress(pnum);
    var len = propertyLength(addr - 1);

    if (addr == 0){
      throw new GameException('Property not found.');
    }

    if (len < 1 || len > 2){
      throw new GameException('Cannot set property on properties > 2 bytes.');
    }

    if (len == 1){
      if (value < 0)
        Debugger.todo('length is 1 & value < 0');
      value &= 0xff;
      Z.machine.mem.storeb(addr, value);
    }else if (len == 2){
      Z.machine.mem.storew(addr, value);
    }
  }

  //gets a byte or word value from a given [propertyNumber].
  int getPropertyValue(int pnum)
  {
    var propNum = 999999;
    int addr = propertyTableStart;

    while(propNum > pnum){
      var len = propertyLength(addr);
      propNum = propertyNumber(addr);

      //not found (ref 12.4.1)
      if (len == 0){
        return GameObjectV3.getPropertyDefault(pnum);
      }

      if (propNum == pnum){
        //ding ding ding

        if (len > 2){
          throw new GameException('Only property length of 1 or 2 is supported by this function: $len');
        }

        if (len == 1){
          return Z._machine.mem.loadb(addr + 1);
        }else{
          return Z._machine.mem.loadw(addr + 1);
        }
      }

      //skip to the next property
      addr += (len + 1);
    }

    //return default property instead (ref 12.4.1)
    return GameObjectV3.getPropertyDefault(pnum);
  }

  static int propertyLength(int address){
    if (address == 0) return 0;

    var propNum = propertyNumber(address);

    return ((Z._machine.mem.loadb(address) >> 5) & 0x07) + 1;
  }

  static int propertyNumber(int address){
    if (address == 0) return 0;

    return Z._machine.mem.loadb(address) % 32;
  }

  static int getPropertyDefault(int propertyNum){
    propertyNum -= 1;
    propertyNum %= 31;

    if (propertyNum < 0 || propertyNum > 31){
      throw new GameException('property number out of bounds (1-31)');
    }
    return Z._machine.mem.loadw(Z._machine.mem.objectsAddress + (propertyNum * 2));
  }

  void removeFromTree(){
    //already an orphan
    if (parent == 0) return;

    var pgo = new GameObjectV3(parent);

    if (pgo.child == id){
      //we are the parent's child so...
      pgo.child = 0;
      if (sibling != 0){
        //move sibling to parent's child
        pgo.child = sibling;
      }
    }else{
      //find the sibling to the left of us...
      var leftSib = leftSibling();


      // now set that sibling's sibling to our sibling
      // effectively removing us from the list.
      new GameObjectV3(leftSib).sibling = sibling;
    }
    parent = 0;
    sibling = 0;
  }

  int leftSibling(){
    var pgo = new GameObjectV3(parent);
    var theChild = new GameObjectV3(pgo.child);

    while(theChild.sibling != id){
      theChild = new GameObjectV3(theChild.sibling);
      if (theChild.id == 0){
        throw new GameException('Sibling list not well formed.');
      }
    }

    return theChild.id;
  }

  void insertTo(int obj){
    if (parent != 0)
          removeFromTree();

    var p = new GameObjectV3(obj);

    if (p.child > 0){
      //parent already has child, make that child our sibling now
      sibling = p.child;
    }

    p.child = id;
    parent = obj;
  }

  void setFlagBit(int bit){
    flags = BinaryHelper.set(flags, 31 - bit);

    _writeFlags();
  }

  void unsetFlagBit(int bit){
    flags = BinaryHelper.unset(flags, 31 - bit);

    _writeFlags();
  }

  bool isFlagBitSet(int bit){
    return BinaryHelper.isSet(flags, 31 - bit);
  }

  //TODO convert to string return
  void dump(){
    print('Object #: $id, "$shortName"');

    print('parent: ${parent} "${new GameObjectV3(parent).shortName}"');
    print('sibling: ${sibling} "${new GameObjectV3(sibling).shortName}"');
    print('child: ${child} "${new GameObjectV3(child).shortName}"');

    var s = new StringBuffer();
    for (int i = 0; i <= 31; i++){
      if (BinaryHelper.isSet(flags, 31 - i)){
        s.add('[$i] ');
      }
    }

    print('set flags: $s');
  }

  int _getObjectAddress(){
    // skip header bytes (ref 12.2)
    var objStart = Z._machine.mem.objectsAddress + 62;

    // 9 bytes per object (ref 12.3.1)
    return objStart += (id - 1) * 9;
  }

  void _readFlags(){
    flags = (Z._machine.mem.loadb(_address) << 24)
        | (Z._machine.mem.loadb(_address + 1) << 16)
        | (Z._machine.mem.loadb(_address + 2) << 8)
        | Z._machine.mem.loadb(_address + 3);
  }

  void _writeFlags(){
    Z._machine.mem.storeb(_address + 3, BinaryHelper.bottomBits(flags, 8));
    Z._machine.mem.storeb(_address + 2, BinaryHelper.bottomBits(flags >> 8, 8));
    Z._machine.mem.storeb(_address + 1, BinaryHelper.bottomBits(flags >> 16, 8));
    Z._machine.mem.storeb(_address, BinaryHelper.bottomBits(flags >> 24, 8));
  }

  String _getObjectShortName(){
    if (id == 0 || Z._machine.mem.loadb(properties) == 0) return '';

    var s = ZSCII.readZStringAndPop(properties + 1);

    return s;
  }

}