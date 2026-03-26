import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_notemus/flutter_notemus.dart';
import 'package:flutter_notemus/src/rendering/renderers/symbol_and_text_renderer.dart';

void main() {
  group('SymbolAndTextRenderer.calculateHairpinGeometry', () {
    test('opens crescendo to the right', () {
      final geometry = SymbolAndTextRenderer.calculateHairpinGeometry(
        DynamicType.crescendo,
        const Offset(10, 0),
        40,
        20,
        6,
      );

      expect(geometry.upperStart, const Offset(10, 20));
      expect(geometry.lowerStart, const Offset(10, 20));
      expect(geometry.upperEnd, const Offset(50, 14));
      expect(geometry.lowerEnd, const Offset(50, 26));
    });

    test('closes diminuendo to the right', () {
      final geometry = SymbolAndTextRenderer.calculateHairpinGeometry(
        DynamicType.diminuendo,
        const Offset(10, 0),
        40,
        20,
        6,
      );

      expect(geometry.upperStart, const Offset(10, 14));
      expect(geometry.lowerStart, const Offset(10, 26));
      expect(geometry.upperEnd, const Offset(50, 20));
      expect(geometry.lowerEnd, const Offset(50, 20));
    });
  });

  group('SymbolAndTextRenderer.calculateTextPaintOrigin', () {
    test('keeps left-aligned text anchored at the reserved x position', () {
      final origin = SymbolAndTextRenderer.calculateTextPaintOrigin(
        const Offset(100, 40),
        const Size(36, 12),
        centerHorizontally: false,
      );

      expect(origin.dx, 100);
      expect(origin.dy, 34);
    });

    test('centers text when horizontal centering is requested', () {
      final origin = SymbolAndTextRenderer.calculateTextPaintOrigin(
        const Offset(100, 40),
        const Size(36, 12),
      );

      expect(origin.dx, 82);
      expect(origin.dy, 34);
    });
  });
}
