// test/core/volta_bracket_test.dart

import 'package:test/test.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

void main() {
  group('VoltaBracket', () {
    test('default displayLabel for number 1 is "1."', () {
      final bracket = VoltaBracket(number: 1, length: 100);
      expect(bracket.displayLabel, equals('1.'));
    });

    test('default displayLabel for number 2 is "2."', () {
      final bracket = VoltaBracket(number: 2, length: 100);
      expect(bracket.displayLabel, equals('2.'));
    });

    test('custom label overrides default', () {
      final bracket = VoltaBracket(number: 1, length: 100, label: '1.-3.');
      expect(bracket.displayLabel, equals('1.-3.'));
    });

    test('hasOpenEnd defaults to false', () {
      final bracket = VoltaBracket(number: 1, length: 100);
      expect(bracket.hasOpenEnd, isFalse);
    });

    test('hasOpenEnd can be set to true', () {
      final bracket = VoltaBracket(number: 2, length: 120, hasOpenEnd: true);
      expect(bracket.hasOpenEnd, isTrue);
    });

    test('number is stored correctly', () {
      final bracket = VoltaBracket(number: 3, length: 80);
      expect(bracket.number, equals(3));
    });

    test('length is stored correctly', () {
      final bracket = VoltaBracket(number: 1, length: 200.0);
      expect(bracket.length, equals(200.0));
    });
  });
}
