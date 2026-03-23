import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

void main() {
  group('Treble8vb Staff Position', () {
    test('treble8vb keeps written staff position equal to treble', () {
      final treble = Clef(clefType: ClefType.treble);
      final treble8vb = Clef(clefType: ClefType.treble8vb);
      final pitches = [
        Pitch(step: 'E', octave: 4),
        Pitch(step: 'G', octave: 4),
        Pitch(step: 'C', octave: 5),
      ];

      for (final pitch in pitches) {
        expect(
          StaffPositionCalculator.calculate(pitch, treble8vb),
          StaffPositionCalculator.calculate(pitch, treble),
        );
      }
    });

    test('written E4 in treble8vb stays on first line', () {
      final treble8vb = Clef(clefType: ClefType.treble8vb);
      final writtenE4 = Pitch(step: 'E', octave: 4);

      expect(StaffPositionCalculator.calculate(writtenE4, treble8vb), -4);
    });
  });
}
