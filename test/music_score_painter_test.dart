import 'package:flutter/material.dart';
import 'package:flutter_notemus/flutter_notemus.dart' as nm;
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PositionedElement.computeSignature', () {
    test('is stable for equivalent positioned content', () {
      final note = nm.Note(
        pitch: const nm.Pitch(step: 'C', octave: 4),
        duration: const nm.Duration(nm.DurationType.quarter),
      );

      final original = <nm.PositionedElement>[
        nm.PositionedElement(
          note,
          const Offset(10, 20),
          system: 0,
          voiceNumber: 1,
        ),
      ];
      final equivalent = <nm.PositionedElement>[
        nm.PositionedElement(
          note,
          const Offset(10, 20),
          system: 0,
          voiceNumber: 1,
        ),
      ];

      expect(
        nm.PositionedElement.computeSignature(original),
        equals(nm.PositionedElement.computeSignature(equivalent)),
      );
    });

    test('changes when visual placement changes', () {
      final note = nm.Note(
        pitch: const nm.Pitch(step: 'C', octave: 4),
        duration: const nm.Duration(nm.DurationType.quarter),
      );

      final original = <nm.PositionedElement>[
        nm.PositionedElement(
          note,
          const Offset(10, 20),
          system: 0,
          voiceNumber: 1,
        ),
      ];
      final moved = <nm.PositionedElement>[
        nm.PositionedElement(
          note,
          const Offset(11, 20),
          system: 0,
          voiceNumber: 1,
        ),
      ];

      expect(
        nm.PositionedElement.computeSignature(moved),
        isNot(equals(nm.PositionedElement.computeSignature(original))),
      );
    });
  });

  group('MusicScorePainter.shouldRepaint', () {
    late ScrollController horizontalController;
    late ScrollController verticalController;

    setUp(() {
      horizontalController = ScrollController();
      verticalController = ScrollController();
    });

    tearDown(() {
      horizontalController.dispose();
      verticalController.dispose();
    });

    nm.MusicScorePainter buildPainter({
      required List<nm.PositionedElement> elements,
      Size viewportSize = const Size(800, 400),
      nm.MusicScoreTheme theme = const nm.MusicScoreTheme(),
      double staffSpace = 12.0,
      int? signature,
    }) {
      return nm.MusicScorePainter(
        positionedElements: elements,
        positionedElementsSignature: signature,
        metadata: nm.SmuflMetadata(),
        theme: theme,
        staffSpace: staffSpace,
        viewportSize: viewportSize,
        horizontalController: horizontalController,
        verticalController: verticalController,
      );
    }

    test('returns false when signature and configuration are unchanged', () {
      final note = nm.Note(
        pitch: const nm.Pitch(step: 'C', octave: 4),
        duration: const nm.Duration(nm.DurationType.quarter),
      );
      final rest = nm.Rest(
        duration: const nm.Duration(nm.DurationType.quarter),
      );

      final baseElements = <nm.PositionedElement>[
        nm.PositionedElement(
          note,
          const Offset(10, 20),
          system: 0,
          voiceNumber: 1,
        ),
        nm.PositionedElement(
          rest,
          const Offset(30, 20),
          system: 0,
          voiceNumber: 1,
        ),
      ];
      final oldPainter = buildPainter(elements: baseElements);

      final equivalentElements = <nm.PositionedElement>[
        nm.PositionedElement(
          baseElements[0].element,
          baseElements[0].position,
          system: baseElements[0].system,
          voiceNumber: baseElements[0].voiceNumber,
        ),
        nm.PositionedElement(
          baseElements[1].element,
          baseElements[1].position,
          system: baseElements[1].system,
          voiceNumber: baseElements[1].voiceNumber,
        ),
      ];
      final newPainter = buildPainter(elements: equivalentElements);

      expect(newPainter.shouldRepaint(oldPainter), isFalse);
    });

    test('returns true when positioned signature changes', () {
      final note = nm.Note(
        pitch: const nm.Pitch(step: 'C', octave: 4),
        duration: const nm.Duration(nm.DurationType.quarter),
      );

      final original = <nm.PositionedElement>[
        nm.PositionedElement(
          note,
          const Offset(10, 20),
          system: 0,
          voiceNumber: 1,
        ),
      ];
      final moved = <nm.PositionedElement>[
        nm.PositionedElement(
          note,
          const Offset(20, 20),
          system: 0,
          voiceNumber: 1,
        ),
      ];

      final oldPainter = buildPainter(elements: original);
      final newPainter = buildPainter(elements: moved);

      expect(newPainter.shouldRepaint(oldPainter), isTrue);
    });

    test('returns true when viewport changes', () {
      final note = nm.Note(
        pitch: const nm.Pitch(step: 'C', octave: 4),
        duration: const nm.Duration(nm.DurationType.quarter),
      );

      final elements = <nm.PositionedElement>[
        nm.PositionedElement(
          note,
          const Offset(10, 20),
          system: 0,
          voiceNumber: 1,
        ),
      ];

      final oldPainter = buildPainter(
        elements: elements,
        viewportSize: const Size(800, 400),
      );
      final newPainter = buildPainter(
        elements: elements,
        viewportSize: const Size(780, 400),
      );

      expect(newPainter.shouldRepaint(oldPainter), isTrue);
    });
  });
}
