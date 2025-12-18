import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:zart/src/glulx/glulx_locals_descriptor.dart';

void main() {
  group('GlulxLocalsDescriptor', () {
    test('empty format', () {
      final format = Uint8List.fromList([0, 0]);
      final descriptor = GlulxLocalsDescriptor.parse(format);
      expect(descriptor.locals, isEmpty);
      expect(descriptor.localsSize, 0);
      expect(descriptor.totalSizeWithPadding, 0);
    });

    test('simple 8-bit locals', () {
      final format = Uint8List.fromList([1, 4, 0, 0]);
      final descriptor = GlulxLocalsDescriptor.parse(format);
      expect(descriptor.locals.length, 4);
      expect(descriptor.locals[0].offset, 0);
      expect(descriptor.locals[1].offset, 1);
      expect(descriptor.locals[2].offset, 2);
      expect(descriptor.locals[3].offset, 3);
      expect(descriptor.localsSize, 4);
      expect(descriptor.totalSizeWithPadding, 4);
    });

    test('mixed locals with alignment padding (Spec example)', () {
      // Spec Example: "if a function has three 8-bit locals followed by six 16-bit locals, the format segment would contain eight bytes: (1, 3, 2, 6, 0, 0, 0, 0). The locals segment would then be 16 bytes long, with a padding byte after the third local." (L102)
      final format = Uint8List.fromList([1, 3, 2, 6, 0, 0]);
      final descriptor = GlulxLocalsDescriptor.parse(format);

      expect(descriptor.locals.length, 9);

      // 8-bit locals: 0, 1, 2
      expect(descriptor.locals[0].offset, 0);
      expect(descriptor.locals[1].offset, 1);
      expect(descriptor.locals[2].offset, 2);

      // 16-bit locals: should start at offset 4 (padding after 2)
      expect(descriptor.locals[3].offset, 4);
      expect(descriptor.locals[4].offset, 6);
      expect(descriptor.locals[5].offset, 8);
      expect(descriptor.locals[6].offset, 10);
      expect(descriptor.locals[7].offset, 12);
      expect(descriptor.locals[8].offset, 14);

      expect(descriptor.localsSize, 16);
      expect(descriptor.totalSizeWithPadding, 16);
    });

    test('alignment for 32-bit locals', () {
      // Spec: "padding is inserted wherever necessary to bring a value to its natural alignment (16-bit values at even addresses, 32-bit values at multiples of four)." (L91)
      final format = Uint8List.fromList([1, 1, 4, 1, 0, 0]);
      final descriptor = GlulxLocalsDescriptor.parse(format);

      expect(descriptor.locals.length, 2);
      expect(descriptor.locals[0].offset, 0);
      expect(descriptor.locals[1].offset, 4); // Padding 1, 2, 3
      expect(descriptor.localsSize, 8);
    });

    test('trailing padding to 4-byte boundary', () {
      // Spec: "Another pair of zeroes is added if necessary to reach a four-byte boundary." (L100)
      final format = Uint8List.fromList([1, 1, 0, 0]);
      final descriptor = GlulxLocalsDescriptor.parse(format);
      expect(descriptor.localsSize, 1);
      expect(descriptor.totalSizeWithPadding, 4);
    });

    test('multiple pairs', () {
      final format = Uint8List.fromList([4, 1, 2, 1, 1, 1, 0, 0]);
      final descriptor = GlulxLocalsDescriptor.parse(format);
      expect(descriptor.locals.length, 3);
      expect(descriptor.locals[0].offset, 0); // 4-byte
      expect(descriptor.locals[1].offset, 4); // 2-byte
      expect(descriptor.locals[2].offset, 6); // 1-byte
      expect(descriptor.localsSize, 7);
      expect(descriptor.totalSizeWithPadding, 8);
    });
  });
}
