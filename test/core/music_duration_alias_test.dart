// `MusicDuration` is the canonical name; `Duration` is the legacy alias that
// shadows `dart:core.Duration` for anyone importing the package barrel.
//
// This file is deliberately written the way a CONSUMER has to write it when
// they need both types in one library — `hide Duration` on the package import —
// so the escape hatch documented on `MusicDuration` is executed, not just
// promised. It also pins the alias itself, so removing it in 3.0 is a decision
// somebody makes on purpose rather than a breakage nobody noticed.
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_notemus/flutter_notemus.dart' hide Duration;
import 'package:flutter_notemus/flutter_notemus.dart' as legacy show Duration;

void main() {
  test('MusicDuration is reachable from the public barrel', () {
    const d = MusicDuration(DurationType.quarter);
    expect(d.type, DurationType.quarter);
    expect(d.absoluteValue, 0.25);
    expect(d.dots, 0);
  });

  test('hiding the alias leaves dart:core.Duration usable in the same library',
      () {
    // The whole point of the escape hatch: both types, one library, no prefix.
    const musical = MusicDuration(DurationType.half, dots: 1);
    const elapsed = Duration(milliseconds: 1500); // dart:core, unshadowed

    expect(musical.absoluteValue, 0.75);
    expect(elapsed.inMilliseconds, 1500);
  });

  test('the legacy alias and the canonical name are the same type', () {
    // Imported under a prefix so this library can name both without un-hiding.
    const viaAlias = legacy.Duration(DurationType.eighth, dots: 2);
    const viaCanonical = MusicDuration(DurationType.eighth, dots: 2);

    expect(viaAlias, isA<MusicDuration>());
    expect(viaAlias, viaCanonical);
    expect(viaAlias.hashCode, viaCanonical.hashCode);
    expect(identical(viaAlias.runtimeType, viaCanonical.runtimeType), isTrue);
  });

  test('equality and toString name the canonical type', () {
    const a = MusicDuration(DurationType.quarter);
    const b = MusicDuration(DurationType.quarter);
    const c = MusicDuration(DurationType.quarter, dots: 1);

    expect(a, b);
    expect(a, isNot(c));
    expect(a.toString(), 'MusicDuration(quarter)');
    expect(c.toString(), 'MusicDuration(quarter.)');
  });

  test('a Note built with either name is the same note', () {
    final viaAlias = Note(
      pitch: Pitch(step: 'C', octave: 4),
      duration: const legacy.Duration(DurationType.quarter),
    );
    final viaCanonical = Note(
      pitch: Pitch(step: 'C', octave: 4),
      duration: const MusicDuration(DurationType.quarter),
    );

    expect(viaAlias.duration, viaCanonical.duration);
  });
}
