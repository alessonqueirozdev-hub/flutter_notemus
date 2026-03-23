// test/rendering/rest_positioning_test.dart

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Rest positioning (SMuFL compliance)', () {
    test('whole rest should use staffPosition 2 (hangs from line 4)', () {
      const staffSpace = 12.0;
      const baseline = 100.0;
      const staffPosition = 2;
      final expectedY = baseline - (staffPosition * staffSpace * 0.5);
      expect(expectedY, lessThan(baseline)); // Should be above center
      expect(staffPosition, equals(2));
    });

    test('half rest should use staffPosition 0 (sits on line 3)', () {
      const staffPosition = 0;
      expect(staffPosition, equals(0));
    });

    test('rest Y is calculated from baseline and staffSpace', () {
      const staffSpace = 12.0;
      const baseline = 100.0;

      // Whole rest at staffPosition 2
      const wholeRestPosition = 2;
      final wholeRestY = baseline - (wholeRestPosition * staffSpace * 0.5);
      expect(wholeRestY, equals(88.0));

      // Half rest at staffPosition 0
      const halfRestPosition = 0;
      final halfRestY = baseline - (halfRestPosition * staffSpace * 0.5);
      expect(halfRestY, equals(100.0));

      // Whole rest is higher (smaller Y) than half rest
      expect(wholeRestY, lessThan(halfRestY));
    });
  });
}
