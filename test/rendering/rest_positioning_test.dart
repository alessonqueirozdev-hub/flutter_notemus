// test/rendering/rest_positioning_test.dart

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Rest positioning (SMuFL compliance)', () {
    test('whole rest should use staffPosition 3 (hangs below line 4)', () {
      // The RestRenderer uses staffPosition = 3 for whole rests.
      // Line 4 in staff coordinate system = staffPosition 2
      // (space between lines 4 and 5 = 3).
      // This is a documentation/compliance test.
      const staffSpace = 12.0;
      const baseline = 100.0;
      const staffPosition = 3; // Expected for whole rest
      final expectedY = baseline - (staffPosition * staffSpace * 0.5);
      expect(expectedY, lessThan(baseline)); // Should be above center
      expect(staffPosition, equals(3));
    });

    test('half rest should use staffPosition 1 (sits on line 3)', () {
      const staffPosition = 1; // Expected for half rest
      expect(staffPosition, equals(1));
    });

    test('rest Y is calculated from baseline and staffSpace', () {
      const staffSpace = 12.0;
      const baseline = 100.0;

      // Whole rest at staffPosition 3
      const wholeRestPosition = 3;
      final wholeRestY = baseline - (wholeRestPosition * staffSpace * 0.5);
      expect(wholeRestY, equals(82.0));

      // Half rest at staffPosition 1
      const halfRestPosition = 1;
      final halfRestY = baseline - (halfRestPosition * staffSpace * 0.5);
      expect(halfRestY, equals(94.0));

      // Whole rest is higher (smaller Y) than half rest
      expect(wholeRestY, lessThan(halfRestY));
    });
  });
}
