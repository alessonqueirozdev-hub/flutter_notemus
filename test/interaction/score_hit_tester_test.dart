// Selection / hit-testing.
//
// The forensic audit scored "readiness for a professional editor" at 2/10 and
// named the blocker precisely: the layout replaced the caller's `Note` objects
// with clones, so there was no stable identity to select. With that fixed,
// these tests pin the contract the editor layer depends on — above all that a
// hit returns THE SAME OBJECT the caller put into the model.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SmuflMetadata metadata;
  setUpAll(() async {
    metadata = SmuflMetadata();
    await metadata.load();
  });

  ({LayoutEngine engine, List<PositionedElement> elements, List<Note> notes})
      build() {
    final notes = <Note>[
      for (var i = 0; i < 8; i++)
        Note(
          pitch: Pitch(step: 'CDEFGAB'[i % 7], octave: 4),
          duration: const Duration(DurationType.quarter),
          voice: i < 4 ? 1 : 2,
        ),
    ];
    final m1 = Measure();
    m1.elements.add(Clef(clefType: ClefType.treble));
    m1.elements.add(TimeSignature(numerator: 4, denominator: 4));
    for (var i = 0; i < 4; i++) {
      m1.elements.add(notes[i]);
    }
    final m2 = Measure();
    for (var i = 4; i < 8; i++) {
      m2.elements.add(notes[i]);
    }
    final engine = LayoutEngine(
      Staff(measures: [m1, m2]),
      availableWidth: 900,
      staffSpace: 12,
      metadata: metadata,
    );
    return (engine: engine, elements: engine.layout(), notes: notes);
  }

  test('a hit returns the caller own object, not a copy', () {
    final b = build();
    final tester = ScoreHitTester(
      elements: b.elements,
      staffSpace: 12,
      engine: b.engine,
    );

    final target = b.notes[2];
    final x = b.engine.noteXPositions[target];
    final y = b.engine.noteYPositions[target];
    expect(x, isNotNull, reason: 'identity must survive the layout');
    expect(y, isNotNull);

    final hit = tester.hitTest(Offset(x! + 2, y!));
    expect(hit, isNotNull);
    expect(identical(hit!.element, target), isTrue,
        reason: 'the engine used to hand back cloned notes, which made every '
            'form of selection and editing impossible.');
  });

  test('a hit carries bar, voice and musical time', () {
    final b = build();
    final tester = ScoreHitTester(
      elements: b.elements,
      staffSpace: 12,
      engine: b.engine,
    );
    final target = b.notes[5]; // second bar, voice 2, beat 2
    final hit = tester.hitTest(Offset(
      b.engine.noteXPositions[target]!,
      b.engine.noteYPositions[target]!,
    ));
    expect(hit, isNotNull);
    expect(hit!.measureIndex, 1);
    expect(hit.onset, closeTo(1.25, 1e-9));
  });

  test('nothing is picked far away from the music', () {
    final b = build();
    final tester = ScoreHitTester(
      elements: b.elements,
      staffSpace: 12,
      engine: b.engine,
    );
    expect(tester.hitTest(const Offset(5000, 5000)), isNull);
  });

  test('selection by measure, by system and by voice', () {
    final b = build();
    final tester = ScoreHitTester(
      elements: b.elements,
      staffSpace: 12,
      engine: b.engine,
    );

    final bar0 = tester.selectMeasure(0);
    expect(bar0.where((h) => h.element is Note).length, 4);
    expect(bar0.any((h) => h.element is Clef), isTrue);

    final bar1Notes =
        tester.selectMeasure(1).where((h) => h.element is Note).toList();
    expect(bar1Notes, hasLength(4));
    expect(identical(bar1Notes.first.element, b.notes[4]), isTrue);

    expect(tester.selectSystem(0), isNotEmpty);

    final voice2 = tester.selectVoice(2).where((h) => h.element is Note);
    expect(voice2, hasLength(4));
  });

  test('marquee selection yields a playable time range', () {
    final b = build();
    final tester = ScoreHitTester(
      elements: b.elements,
      staffSpace: 12,
      engine: b.engine,
    );
    final firstX = b.engine.noteXPositions[b.notes.first]!;
    final lastX = b.engine.noteXPositions[b.notes[3]]!;

    final selection = tester.selectionFromRect(
      Rect.fromLTRB(firstX - 4, 0, lastX + 12, 400),
    );
    expect(selection.isEmpty, isFalse);
    expect(selection.firstMeasure, 0);
    expect(selection.startOnset, closeTo(0.0, 1e-9));
    expect(selection.endOnset, closeTo(0.75, 1e-9));
    expect(selection.soundingElements, isNotEmpty);
  });

  test('a time range selects exactly the events inside it', () {
    final b = build();
    final tester = ScoreHitTester(
      elements: b.elements,
      staffSpace: 12,
      engine: b.engine,
    );
    // Beats 2 and 3 of the first bar.
    final hits = tester
        .selectTimeRange(0.25, 0.75)
        .where((h) => h.element is Note)
        .toList();
    expect(hits, hasLength(2));
    expect(identical(hits[0].element, b.notes[1]), isTrue);
    expect(identical(hits[1].element, b.notes[2]), isTrue);
  });

  test('timeAt places a caret from a pointer position', () {
    final b = build();
    final tester = ScoreHitTester(
      elements: b.elements,
      staffSpace: 12,
      engine: b.engine,
    );
    final target = b.notes[6];
    final where = tester.timeAt(Offset(
      b.engine.noteXPositions[target]!,
      b.engine.noteYPositions[target]!,
    ));
    expect(where, isNotNull);
    expect(where!.measureIndex, 1);
    expect(where.onset, closeTo(1.5, 1e-9));
  });
}
