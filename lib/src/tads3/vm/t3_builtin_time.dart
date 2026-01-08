import 'package:zart/src/loaders/tads/t3_exception.dart';
import 'package:zart/src/tads3/vm/t3_interpreter.dart';
import 'package:zart/src/tads3/vm/t3_value.dart';

/// Time-related built-in functions for TADS 3.
class T3BuiltinTime {
  static int? _timeZero;

  /// gettime(type?) - Get current date/time information.
  /// Ref: vmbiftad.cpp line 2315
  /// Type 1 (default): return list [year, month, day, weekday, yearday, hour, min, sec, timestamp]
  /// Type 2: return high-precision millisecond timer
  static void gettime(T3Interpreter interp, int argc) {
    final type = argc >= 1 ? interp.stack.pop().numToInt() : 1;
    if (argc > 1) interp.stack.discard(argc - 1);

    switch (type) {
      case 1:
        // Return full date/time list (9 elements)
        final now = DateTime.now();
        final timestamp = now.millisecondsSinceEpoch ~/ 1000;
        final list = [
          T3Value.fromInt(now.year),
          T3Value.fromInt(now.month),
          T3Value.fromInt(now.day),
          T3Value.fromInt(
            now.weekday == 7 ? 1 : now.weekday + 1,
          ), // TADS weekday: 1=Sunday..7=Saturday. Convert 1=Mon..7=Sun.
          T3Value.fromInt(_dayOfYear(now)),
          T3Value.fromInt(now.hour),
          T3Value.fromInt(now.minute),
          T3Value.fromInt(now.second),
          T3Value.fromInt(timestamp),
        ];
        final offset = interp.addDynamicList(list);
        interp.registers.r0 = T3Value.fromList(offset);
        break;

      case 2:
        // Return millisecond ticks
        final now = DateTime.now().millisecondsSinceEpoch;
        _timeZero ??= now;
        final elapsed = (now - _timeZero!) & 0x7FFFFFFF;
        interp.registers.r0 = T3Value.fromInt(elapsed);
        break;

      case 3:
        // Return parser date/time list [year, day-of-year, ms-from-midnight]
        final now = DateTime.now();
        final msFromMidnight =
            (now.hour * 3600 + now.minute * 60 + now.second) * 1000 +
            now.millisecond;
        final list = [
          T3Value.fromInt(now.year),
          T3Value.fromInt(_dayOfYear(now)),
          T3Value.fromInt(msFromMidnight),
        ];
        final offset = interp.addDynamicList(list);
        interp.registers.r0 = T3Value.fromList(offset);
        break;

      default:
        throw T3Exception('gettime() invalid type: $type');
    }
  }

  /// Calculate day of year (1-366)
  static int _dayOfYear(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    return date.difference(firstDayOfYear).inDays + 1;
  }
}
