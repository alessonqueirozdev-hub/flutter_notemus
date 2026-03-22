// test/core/key_signature_cancellation_test.dart

import 'package:test/test.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

void main() {
  group('KeySignature cancellations', () {
    test('KeySignature accepts previousCount', () {
      final ks = KeySignature(0, previousCount: 2);
      expect(ks.count, equals(0));
      expect(ks.previousCount, equals(2));
    });

    test('KeySignature without previousCount defaults to null', () {
      final ks = KeySignature(2);
      expect(ks.previousCount, isNull);
    });

    test('KeySignature with sharps', () {
      final ks = KeySignature(3); // A major / F# minor
      expect(ks.count, equals(3));
      expect(ks.previousCount, isNull);
    });

    test('KeySignature with flats', () {
      final ks = KeySignature(-2); // Bb major / G minor
      expect(ks.count, equals(-2));
    });

    test('KeySignature C major has zero accidentals', () {
      final ks = KeySignature(0);
      expect(ks.count, equals(0));
    });

    test('KeySignature transitioning from sharps to flats', () {
      final ks = KeySignature(-3, previousCount: 4);
      expect(ks.count, equals(-3));
      expect(ks.previousCount, equals(4));
    });
  });
}
