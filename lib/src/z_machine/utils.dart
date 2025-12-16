import 'dart:math';

import 'package:zart/src/z_machine/game_object.dart';
import 'package:zart/zart.dart';

/// Returns a string containing a pretty-print visual tree of game objects.
/// This function crawls the tree structure until all objects have been found
/// although there is the possibility that some orphaned objects may not be
/// found if they are above the highest "found" object number and are not
/// referenced as a sibling/child/parent of any other object.
///
/// This function requires that a story file is alread loaded into the [Z] machine
/// and will throw an exception if no file is loaded.
///
/// Provide an optional [objectNum] to begin the tree construction at a known point.
/// **Override the default value at your own risk**, as the function does not check
/// if the provided [objectNum] is valid.
String generateObjectTree([int objectNum = 1]) {
  if (!Z.isLoaded) {
    throw "Z-machine must be loaded with a story file before calling this function (use Z.load(storybytes)).";
  }

  if (objectNum < 1) {
    throw "objectNum argument must be greater than 0.  Found: $objectNum.";
  }

  _resetObjectState();
  _updateObjectState(objectNum);

  final sb = StringBuffer();

  //first find root parent, which we assume is 0...
  final rootObject = GameObject(objectNum);

  void doTree(GameObject currentObject) {
    while (currentObject.parent != 0) {
      currentObject = GameObject(currentObject.parent);
    }

    sb.writeln(
      "${currentObject.shortName}(${currentObject.id}) child: ${currentObject.child}, sib: ${currentObject.sibling}",
    );

    if (currentObject.child != 0) {
      _updateObjectState(currentObject.child);
      sb.write(_writeChildren(currentObject.child, 3));
    }

    if (currentObject.sibling != 0) {
      _updateObjectState(currentObject.sibling);
      sb.write(_writeChildren(currentObject.sibling, 0));
    }
  }

  doTree(rootObject);

  while (_highestObject > _objects.length) {
    final nextObjectId = _getNextAvailableObject();
    if (nextObjectId < 1) break;
    _updateObjectState(nextObjectId);
    final next = GameObject(nextObjectId);
    doTree(next);
  }

  sb.writeln("");
  sb.writeln("Total Objects Found: ${_objects.length}");
  sb.writeln(
    "Highest Object: ${GameObject(_highestObject).shortName}($_highestObject)",
  );
  return sb.toString();
}

Set<int> _objects = <int>{};
var _highestObject = 0;

void _resetObjectState() {
  _highestObject = 0;
  _objects.clear();
}

String _whitespace(int amount, [String kind = ' ']) {
  final sb = StringBuffer();
  for (var i = 0; i < amount; i++) {
    sb.write(kind);
  }

  return sb.toString();
}

String _writeChildren(int objectNum, int indent) {
  final sb = StringBuffer();
  final obj = GameObject(objectNum);
  final child = obj.child != 0 ? GameObject(obj.child).shortName : "";
  final sibling = obj.sibling != 0 ? GameObject(obj.sibling).shortName : "";
  sb.writeln(
    "${_whitespace(indent, '.')}${obj.shortName}(${obj.id}), child: $child(${obj.child}), sib: $sibling(${obj.sibling})",
  );

  if (obj.child != 0) {
    _updateObjectState(obj.child);
    sb.write(_writeChildren(obj.child, indent + 3));
  }

  if (obj.sibling != 0) {
    _updateObjectState(obj.sibling);
    sb.write(_writeChildren(obj.sibling, indent));
  }

  return sb.toString();
}

void _updateObjectState(int objectNum) {
  _highestObject = max<int>(objectNum, _highestObject);
  _objects.add(objectNum);
}

int _getNextAvailableObject() {
  int i = _highestObject;

  while (i > 0) {
    if (_objects.contains(i)) {
      i--;
      continue;
    }

    return i;
  }

  return -1;
}
