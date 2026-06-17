// Regression for R1: SmuflMetadata.getEngravingDefault must be null-safe.
// Previously it did an unchecked `as num` on a possibly-missing section/key
// and threw; now it returns the fallback instead.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SmuflMetadata.getEngravingDefault null-safety (R1)', () {
    test('returns fallback (no throw) before metadata is loaded', () {
      // Fresh singletons in some run orders may be loaded already; assert the
      // contract holds regardless: a missing key never throws.
      expect(
        () => SmuflMetadata().getEngravingDefault('definitelyMissingKey'),
        returnsNormally,
      );
    });

    test('returns provided fallback for a missing key after load', () async {
      await SmuflMetadata().load();
      expect(
        SmuflMetadata().getEngravingDefault('definitelyMissingKey', 1.5),
        1.5,
      );
    });

    test('returns the real value for a present key after load', () async {
      await SmuflMetadata().load();
      final stem = SmuflMetadata().getEngravingDefault('stemThickness');
      // Bravura's stemThickness is a small positive value (~0.12 staff spaces).
      expect(stem, greaterThan(0.0));
      expect(stem, lessThan(1.0));
    });
  });
}
