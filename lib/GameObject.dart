/** Helper class for working with v3 game objects. */
class GameObject
{
  final int id;
  int get PARENT_ADDR() => _address + (Z.version <= 3 ? 4 : 6);
  int get SIBLING_ADDR() => _address + (Z.version <= 3 ? 5 : 8);
  int get CHILD_ADDR() => _address + (Z.version <= 3 ? 6 : 10);
  
  int _address;

  int get parent() => Z.version <= 3 ? Z.machine.mem.loadb(PARENT_ADDR) : Z.machine.mem.loadw(PARENT_ADDR);
  set parent(int oid) => Z.version <= 3 ? Z.machine.mem.storeb(PARENT_ADDR, oid) : Z.machine.mem.storew(PARENT_ADDR, oid);

  int get child() => Z.version <= 3 ? Z.machine.mem.loadb(CHILD_ADDR) : Z.machine.mem.loadw(CHILD_ADDR);
  set child(int oid) => Z.version <= 3 ? Z.machine.mem.storeb(CHILD_ADDR, oid) : Z.machine.mem.storew(CHILD_ADDR, oid);

  int get sibling() => Z.version <= 3 ? Z.machine.mem.loadb(SIBLING_ADDR) : Z.machine.mem.loadw(SIBLING_ADDR);
  set sibling(int oid) => Z.version <= 3 ? Z.machine.mem.storeb(SIBLING_ADDR, oid) : Z.machine.mem.storew(SIBLING_ADDR, oid);

  int flags;

  int get properties() => Z.machine.mem.loadw(_address + (Z.version <= 3 ? 7 : 12));

  int get propertyTableStart() => properties + (Z.machine.mem.loadb(properties) * 2) + 1;

  String shortName;

  GameObject(this.id)
  {
    _address = _getObjectAddress();
    shortName = _getObjectShortName();

    if (id == 0) return;
    _readFlags();
  }

  int getNextProperty(int pnum){

    if (pnum == 0){
      //get first property
      return propertyNumber(propertyTableStart);
    }

    var addr = getPropertyAddress(pnum);

    if (addr == 0) {
      throw new GameException('Attempted to get next property of a property'
        ' that doesn\'t exist ($pnum)');
    }

    var len = propertyLength(addr - 1);
    
    addr += len;

    len = 
        Z.version <= 3 || BinaryHelper.isSet(Z.machine.mem.loadb(addr), 7) 
        ? propertyLength(addr)
        : propertyLength(addr + 1);

    return len == 0 ? len : propertyNumber(addr);
  }


  int getPropertyAddress(int pnum){
    if (pnum == 0) return 0;

    var propNum = 999999;
    int addr = propertyTableStart;

    while(propNum > pnum){
      var len = 
          Z.version <= 3 || BinaryHelper.isSet(Z.machine.mem.loadb(addr), 7) 
          ? propertyLength(addr)
          : propertyLength(addr + 1);
          
      propNum = propertyNumber(addr);

      //not found (ref 12.4.1)
      if (len == 0){
        return 0;
      }

      if (propNum == pnum){
        if (Z.version <= 3){
          return addr + 1;
        }else{
          return addr + (len > 2 ? 2 : 1);
        }
      }

      //skip to the next property
      if (Z.version <= 3){
        addr += (len + 1);
      }else{
        //if property len > 2, account for the second
        //size byte in the header
        addr += (len + ((len > 2) ? 2 : 1));
      }
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
      var len = 
          Z.version <= 3 || BinaryHelper.isSet(Z.machine.mem.loadb(addr), 7) 
          ? propertyLength(addr)
          : propertyLength(addr + 1);
      propNum = propertyNumber(addr);

      //not found (ref 12.4.1)
      if (len == 0){
        return GameObject.getPropertyDefault(pnum);
      }

      if (propNum == pnum){
        //ding ding ding

        if (len > 2){
          throw new GameException('Only property length of 1 or 2 is supported by this function: $len');
        }

        if (len == 1){
          return Z.machine.mem.loadb(addr + 1);
        }else{
          return Z.machine.mem.loadw(addr + 1);
        }
      }

      //skip to the next property
      if (Z.version <= 3){
        addr += (len + 1);
      }else{
        //if property len > 2, account for the second
        //size byte in the header
        addr += (len + ((len > 2) ? 2 : 1));
      }

    }

    //return default property instead (ref 12.4.1)
    return GameObject.getPropertyDefault(pnum);
  }

  static int propertyLength(int address){
    if (address == 0) return 0;   
    
    var fb = Z.machine.mem.loadb(address);
    
    if(Z.version <= 3){
      return ((fb >> 5) & 0x07) + 1;
    }else{
      if(BinaryHelper.isSet(fb, 7)){
        //(ref 12.4.2.1)
        var value = BinaryHelper.bottomBits(fb, 6);
        // (ref 12.4.2.1.1)
        return value > 0 ? value : 64;
      }else{
        //(ref 12.4.2.2)
        return BinaryHelper.isSet(fb, 6) ? 2 : 1;
      }
    }
  }

  static int propertyNumber(int address){
    if (address == 0) return 0;

    if (Z.version <= 3){
      return Z.machine.mem.loadb(address) % 32;
    }else{
      // (ref 12.4.2)
      return BinaryHelper.bottomBits(Z.machine.mem.loadb(address), 6);
    }
  }

  static int getPropertyDefault(int propertyNum){
    propertyNum -= 1;
    propertyNum %= 31;

    if (propertyNum < 0 || propertyNum > 31){
      throw new GameException('property number out of bounds (1-31)');
    }
    return Z.machine.mem.loadw(Z.machine.mem.objectsAddress + (propertyNum * 2));
  }

  void removeFromTree(){
    //already an orphan
    if (parent == 0) return;

    var pgo = new GameObject(parent);

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
      new GameObject(leftSib).sibling = sibling;
    }
    parent = 0;
    sibling = 0;
  }

  int leftSibling(){
    var pgo = new GameObject(parent);
    var theChild = new GameObject(pgo.child);

    while(theChild.sibling != id){
      theChild = new GameObject(theChild.sibling);
      if (theChild.id == 0){
        throw new GameException('Sibling list not well formed.');
      }
    }

    return theChild.id;
  }

  void insertTo(int obj){
    if (parent != 0)
          removeFromTree();

    var p = new GameObject(obj);

    if (p.child > 0){
      //parent already has child, make that child our sibling now
      sibling = p.child;
    }

    p.child = id;
    parent = obj;
  }

  void setFlagBit(int bit){
    flags = BinaryHelper.set(flags, (Z.version <= 3 ? 31 : 47) - bit);

    _writeFlags();
  }

  void unsetFlagBit(int bit){
    flags = BinaryHelper.unset(flags, (Z.version <= 3 ? 31 : 47) - bit);

    _writeFlags();
  }

  bool isFlagBitSet(int bit){
    return BinaryHelper.isSet(flags, (Z.version <= 3 ? 31 : 47) - bit);
  }

  //TODO convert to string return
  void dump(){
    Debugger.debug('Object #: $id, "$shortName"');

    Debugger.debug('parent: ${parent} "${new GameObject(parent).shortName}"');
    Debugger.debug('sibling: ${sibling} "${new GameObject(sibling).shortName}"');
    Debugger.debug('child: ${child} "${new GameObject(child).shortName}"');

    Debugger.debug('Property Address 0x${propertyTableStart.toRadixString(16)}');
    
    var s = new StringBuffer();
    for (int i = 0; i <= (Z.version <= 3 ? 31 : 47); i++){
      if (BinaryHelper.isSet(flags, (Z.version <= 3 ? 31 : 47) - i)){
        s.add('[$i] ');
      }
    }

    Debugger.debug('set flags: $s');
  }

  int _getObjectAddress(){
    // skip header bytes 62 or 126 (ref 12.2)
    var objStart = Z.machine.mem.objectsAddress + (Z.version <= 3 ? 62 : 126);

    // 9 or 14 bytes per object (ref 12.3.1)
    return objStart += (id - 1) * (Z.version <= 3 ? 9 : 14);
  }

  void _readFlags(){
    if (Z.version <= 3){
      flags = (Z.machine.mem.loadb(_address) << 24)
          | (Z.machine.mem.loadb(_address + 1) << 16)
          | (Z.machine.mem.loadb(_address + 2) << 8)
          | Z.machine.mem.loadb(_address + 3);
    }else{
      flags = (Z.machine.mem.loadb(_address) << 40)
          | (Z.machine.mem.loadb(_address + 1) << 32)
          | (Z.machine.mem.loadb(_address + 2) << 24)
          | (Z.machine.mem.loadb(_address + 3) << 16)
          | (Z.machine.mem.loadb(_address + 4) << 8)
          | Z.machine.mem.loadb(_address + 5);
    }
  }

  void _writeFlags(){
    if (Z.version <= 3){
      Z.machine.mem.storeb(_address + 3, BinaryHelper.bottomBits(flags, 8));
      Z.machine.mem.storeb(_address + 2, BinaryHelper.bottomBits(flags >> 8, 8));
      Z.machine.mem.storeb(_address + 1, BinaryHelper.bottomBits(flags >> 16, 8));
      Z.machine.mem.storeb(_address, BinaryHelper.bottomBits(flags >> 24, 8));
    }else{
      Z.machine.mem.storeb(_address + 5, BinaryHelper.bottomBits(flags, 8));
      Z.machine.mem.storeb(_address + 4, BinaryHelper.bottomBits(flags >> 8, 8));
      Z.machine.mem.storeb(_address + 3, BinaryHelper.bottomBits(flags >> 16, 8));
      Z.machine.mem.storeb(_address + 2, BinaryHelper.bottomBits(flags >> 24, 8));
      Z.machine.mem.storeb(_address + 1, BinaryHelper.bottomBits(flags >> 32, 8));
      Z.machine.mem.storeb(_address, BinaryHelper.bottomBits(flags >> 40, 8));
    }
  }

  String _getObjectShortName(){
    if (id == 0 || Z.machine.mem.loadb(properties) == 0) return '';

    var s = ZSCII.readZStringAndPop(properties + 1);

    return s;
  }

}