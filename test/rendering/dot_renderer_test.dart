import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_notemus/src/rendering/renderers/primitives/dot_renderer.dart';
import 'package:flutter_notemus/src/rendering/staff_coordinate_system.dart';

void main() {
  group('DotRenderer', () {
    test('moves dots on lines to the space above', () {
      expect(DotRenderer.resolveDotStaffPosition(-2), -1);
      expect(DotRenderer.resolveDotStaffPosition(0), 1);
      expect(DotRenderer.resolveDotStaffPosition(4), 5);
    });

    test('keeps dots on notes in spaces in the same space', () {
      expect(DotRenderer.resolveDotStaffPosition(-3), -3);
      expect(DotRenderer.resolveDotStaffPosition(-1), -1);
      expect(DotRenderer.resolveDotStaffPosition(3), 3);
    });

    test(
      'calculates dot y from staff position instead of notehead compensation',
      () {
        final coordinates = StaffCoordinateSystem(
          staffSpace: 10,
          staffBaseline: const Offset(0, 100),
        );

        expect(
          DotRenderer.calculateDotY(
            dotStaffPosition: 1,
            coordinates: coordinates,
          ),
          95,
        );
        expect(
          DotRenderer.calculateDotY(
            dotStaffPosition: -1,
            coordinates: coordinates,
          ),
          105,
        );
      },
    );
  });
}
