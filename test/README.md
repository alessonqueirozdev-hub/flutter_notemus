# Flutter Notemus Test Suite

Comprehensive test coverage for the Flutter Notemus music notation library.

## 📊 Test Coverage Summary

### Core Models (`test/core/`)
Complete coverage of fundamental music notation models:

- **`pitch_test.dart`** (60+ tests)
  - Construction, MIDI numbers, accidentals
  - Enharmonic equivalents, SMuFL glyphs
  - Musical intervals and staff position integration

- **`duration_test.dart`** (50+ tests)
  - All duration types, dotted values
  - SMuFL glyphs for notes and rests
  - Musical theory relationships

- **`note_test.dart`** (50+ tests)
  - Basic construction, beaming, ties, slurs
  - Articulations, ornaments, dynamics
  - Voice support, complex combinations

- **`chord_test.dart`** (40+ tests)
  - Multi-note construction, common chords
  - Highest/lowest note detection
  - Accidentals, beaming, voices

- **`voice_test.dart`** (40+ tests)
  - Voice construction, stem directions
  - Horizontal offsets, element management
  - MultiVoiceMeasure, polyphonic scenarios

- **`rest_test.dart`** (45+ tests)
  - All rest types, SMuFL glyphs
  - Dotted rests, measure validation
  - Musical context, visual representation

- **`clef_test.dart`** (50+ tests)
  - All clef types, octave transpositions
  - Staff position calculations
  - Instrument associations, reading ranges

- **`time_signature_test.dart`** (55+ tests)
  - Common and irregular meters
  - Simple vs compound classification
  - Beat counting, musical styles

### Rendering (`test/rendering/`)
- **`smufl_positioning_engine_test.dart`** (40+ tests)
  - Stem and flag anchor calculations
  - Stem length calculations for notes and chords
  - Beam thickness, fallback values

### Existing Tests
- **`staff_position_calculator_test.dart`** - Staff positioning validation
- **`spacing_test.dart`** - Intelligent spacing system
- **`utils/lru_cache_test.dart`** - LRU cache implementation

## 📈 Test Statistics

- **Total Test Files**: 12
- **Total Tests**: 440+ comprehensive tests
- **Core Models Coverage**: ~95%
- **Overall Coverage**: ~55-60% (estimated)

## 🎯 Test Categories

### 1. **Musical Theory Validation**
Tests verify correct implementation of music theory:
- Intervals (major third = 4 semitones, perfect fifth = 7 semitones)
- Duration relationships (2 halves = 1 whole, 4 quarters = 1 whole)
- Clef transpositions and pitch readings
- Time signature capacity and beat counting

### 2. **SMuFL Compliance**
Tests ensure Standard Music Font Layout compliance:
- Glyph name mappings (noteheadBlack, restQuarter, accidentalSharp)
- Anchor point calculations (stem up/down, flag positioning)
- Bounding boxes and optical corrections
- Engraving defaults (beam thickness, stem length)

### 3. **Edge Cases**
Comprehensive edge case testing:
- Extreme pitch ranges (C0 to C8)
- Multiple dots (triple-dotted notes)
- Irregular time signatures (5/4, 7/8, 11/8)
- Wide chord spreads, dense clusters
- Polyphonic voices (3+)

### 4. **Integration**
Tests verify components work together:
- Pitch + Clef → Staff Position
- Duration + Dots → Absolute Value
- Note + Voice → Stem Direction + Offset
- TimeSignature + Elements → Measure Validation

## 🚀 Running Tests

### Run All Tests
```bash
flutter test
```

### Run Specific Test Suite
```bash
flutter test test/core/pitch_test.dart
flutter test test/core/duration_test.dart
```

### Run Core Model Tests
```bash
flutter test test/core/
```

### Run with Coverage
```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

## 📝 Test Naming Conventions

Tests follow a clear naming pattern:

```dart
group('Component - Feature', () {
  test('Specific behavior or requirement', () {
    // Arrange
    final object = Component(...);

    // Act
    final result = object.method();

    // Assert
    expect(result, equals(expected));
  });
});
```

## 🎵 Musical Accuracy

All tests validate against professional music engraving standards:
- **Behind Bars** (Elaine Gould) - music notation reference
- **SMuFL Specification** - music font layout standard
- **MIDI Standard** - pitch numbering (middle C = 60, A4 = 69)
- **Music Theory** - intervals, durations, time signatures

## 🔍 Test Quality Standards

Each test suite includes:
- ✅ Basic construction tests
- ✅ Property validation tests
- ✅ Edge case tests
- ✅ Musical theory validation
- ✅ SMuFL compliance checks
- ✅ Integration tests
- ✅ Clear documentation

## 📚 Future Test Coverage

Planned test expansion:
- [ ] Complete rendering component tests (NoteRenderer, ChordRenderer)
- [ ] Layout engine tests (positioning, spacing)
- [ ] Theme system tests
- [ ] PDF export tests
- [ ] Performance benchmarks
- [ ] Visual regression tests

## 🤝 Contributing

When adding new tests:
1. Follow existing naming conventions
2. Include musical theory validation
3. Test edge cases thoroughly
4. Document expected behavior
5. Ensure SMuFL compliance
6. Add integration tests where applicable

## 📖 References

- [SMuFL Specification](https://w3c.github.io/smufl/latest/)
- [Behind Bars](https://www.faber.co.uk/product/behind-bars/) - Elaine Gould
- [MIDI Specification](https://www.midi.org/specifications)
- [Music Theory Fundamentals](https://en.wikipedia.org/wiki/Music_theory)

---

**Current Status**: Core model testing complete (440+ tests). Rendering and layout tests in progress.

**Target**: 85%+ code coverage with comprehensive edge case validation.
