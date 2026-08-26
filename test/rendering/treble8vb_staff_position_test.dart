import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

/// Octave-transposing clefs, under the ADR-003 convention that [Pitch] is the
/// SOUNDING pitch — the same thing MusicXML `<pitch>`, MEI `@pname`/`@oct` and
/// MIDI mean by it.
///
/// This file used to assert the opposite ("treble8vb keeps written staff
/// position equal to treble", "written E4 in treble8vb stays on first line"),
/// which is precisely the defect N-15 reports: a tenor part imported from
/// MusicXML was drawn an octave low AND played an octave low, because the
/// importer stored the sounding pitch while the renderer read it as written
/// and `MidiMapper` shifted it a second time.
///
/// It was also never true of the whole clef family: `c8vb` baked the shift into
/// its own `ClefReference`, so it alone already behaved the sounding way.
void main() {
  group('octave-transposing clefs place a SOUNDING pitch', () {
    final treble = Clef(clefType: ClefType.treble);

    test('an 8vb clef prints a sounding pitch one octave HIGHER', () {
      final treble8vb = Clef(clefType: ClefType.treble8vb);
      for (final pitch in [
        Pitch(step: 'E', octave: 4),
        Pitch(step: 'G', octave: 4),
        Pitch(step: 'C', octave: 5),
      ]) {
        expect(
          StaffPositionCalculator.calculate(pitch, treble8vb),
          StaffPositionCalculator.calculate(pitch, treble) + 7,
          reason: 'a clef that SOUNDS an octave lower must PRINT a given '
              'sounding pitch an octave higher (7 half-space positions)',
        );
      }
    });

    test('an 8va clef prints a sounding pitch one octave LOWER', () {
      final treble8va = Clef(clefType: ClefType.treble8va);
      for (final pitch in [
        Pitch(step: 'E', octave: 5),
        Pitch(step: 'C', octave: 6),
      ]) {
        expect(
          StaffPositionCalculator.calculate(pitch, treble8va),
          StaffPositionCalculator.calculate(pitch, treble) - 7,
        );
      }
    });

    test('15ma / 15mb shift by two octaves', () {
      expect(
        StaffPositionCalculator.calculate(
            Pitch(step: 'C', octave: 5), Clef(clefType: ClefType.treble15mb)),
        StaffPositionCalculator.calculate(
                Pitch(step: 'C', octave: 5), treble) +
            14,
      );
      expect(
        StaffPositionCalculator.calculate(
            Pitch(step: 'C', octave: 5), Clef(clefType: ClefType.treble15ma)),
        StaffPositionCalculator.calculate(
                Pitch(step: 'C', octave: 5), treble) -
            14,
      );
    });

    test('sounding E4 on a treble-8vb staff sits where E5 sits on treble', () {
      final treble8vb = Clef(clefType: ClefType.treble8vb);
      expect(
        StaffPositionCalculator.calculate(
            Pitch(step: 'E', octave: 4), treble8vb),
        StaffPositionCalculator.calculate(Pitch(step: 'E', octave: 5), treble),
      );
      // E4 is the bottom line on a plain treble staff; an octave up is +7.
      expect(
        StaffPositionCalculator.calculate(
            Pitch(step: 'E', octave: 4), treble8vb),
        3,
      );
    });

    test('c8vb is shifted ONCE, not twice', () {
      // Regression guard: `c8vb` used to carry the octave inside its own
      // ClefReference (`baseOctave: 3`). With the shift applied uniformly in
      // `calculate`, leaving it there would have moved c8vb two octaves.
      final c8vb = Clef(clefType: ClefType.c8vb);
      final tenor = Clef(clefType: ClefType.tenor);
      expect(
        StaffPositionCalculator.calculate(Pitch(step: 'C', octave: 3), c8vb),
        2,
        reason: 'sounding C3 on a c8vb clef keeps the position it always had',
      );
      expect(
        StaffPositionCalculator.calculate(Pitch(step: 'C', octave: 3), c8vb),
        StaffPositionCalculator.calculate(Pitch(step: 'C', octave: 4), tenor),
        reason: 'c8vb sounds an octave below the tenor C clef it shares a line '
            'with',
      );
    });

    test('a clef with no octave shift is unchanged', () {
      for (final type in [
        ClefType.treble,
        ClefType.bass,
        ClefType.alto,
        ClefType.tenor,
        ClefType.percussion,
      ]) {
        final clef = Clef(clefType: type);
        expect(clef.octaveShift, 0);
      }
    });
  });

  group('playback does not shift a second time', () {
    test('a sounding C4 plays as MIDI 60 under every octave clef', () {
      for (final type in [
        ClefType.treble,
        ClefType.treble8vb,
        ClefType.treble8va,
        ClefType.treble15mb,
        ClefType.bass8vb,
      ]) {
        final measure = Measure()
          ..elements.addAll([
            Clef(clefType: type),
            Note(
              pitch: Pitch(step: 'C', octave: 4),
              duration: Duration(DurationType.whole),
            ),
          ]);
        final notes = MidiMapper.fromStaff(Staff(measures: [measure]))
            .tracks
            .expand((t) => t.events)
            .where((e) => e.type == MidiEventType.noteOn)
            .map((e) => e.note)
            .toList();
        expect(notes, [60], reason: 'clef $type must not re-transpose');
      }
    });
  });
}
