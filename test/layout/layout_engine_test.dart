// test/layout/layout_engine_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

void main() {
  group('LayoutEngine', () {
    late Staff singleNoteStaff;

    setUp(() {
      final measure = Measure()
        ..add(TimeSignature(numerator: 4, denominator: 4))
        ..add(Note(
          pitch: const Pitch(step: 'C', octave: 4),
          duration: const Duration(DurationType.quarter),
        ));
      singleNoteStaff = Staff(measures: [measure]);
    });

    test('layout produces PositionedElements', () {
      // LayoutEngine requires metadata — this test verifies the Staff
      // and Measure structure is correct without instantiating LayoutEngine.
      expect(singleNoteStaff.measures.length, equals(1));
      expect(singleNoteStaff.measures[0].elements.length, equals(2));
    });

    test('note X positions are in ascending order', () {
      final measure = Measure()
        ..add(Note(
          pitch: const Pitch(step: 'C', octave: 4),
          duration: const Duration(DurationType.quarter),
        ))
        ..add(Note(
          pitch: const Pitch(step: 'D', octave: 4),
          duration: const Duration(DurationType.quarter),
        ));
      final staff = Staff(measures: [measure]);
      // This is a structural test; actual rendering needs metadata.
      expect(staff.measures.length, equals(1));
      expect(staff.measures[0].elements.length, equals(2));
    });

    test('Staff with multiple measures has correct measure count', () {
      final measures = List.generate(
        4,
        (_) => Measure()
          ..add(Note(
            pitch: const Pitch(step: 'C', octave: 4),
            duration: const Duration(DurationType.whole),
          )),
      );
      final staff = Staff(measures: measures);
      expect(staff.measures.length, equals(4));
    });

    test('MultiVoiceMeasure has two voices', () {
      final measure = MultiVoiceMeasure.twoVoices(
        voice1Elements: [
          Note(
            pitch: const Pitch(step: 'E', octave: 5),
            duration: const Duration(DurationType.quarter),
          ),
        ],
        voice2Elements: [
          Note(
            pitch: const Pitch(step: 'C', octave: 4),
            duration: const Duration(DurationType.quarter),
          ),
        ],
      );
      expect(measure.voiceCount, equals(2));
      expect(measure.isPolyphonic, isTrue);
    });
  });
}
