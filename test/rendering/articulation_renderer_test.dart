import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_notemus/flutter_notemus.dart';
import 'package:flutter_notemus/src/rendering/renderers/articulation_renderer.dart';

void main() {
  group('ArticulationRenderer.getArticulationClearanceSS', () {
    test('keeps accented articulations farther from the notehead', () {
      expect(
        ArticulationRenderer.getArticulationClearanceSS(ArticulationType.accent),
        greaterThan(
          ArticulationRenderer.getArticulationClearanceSS(
            ArticulationType.staccato,
          ),
        ),
      );
      expect(
        ArticulationRenderer.getArticulationClearanceSS(
          ArticulationType.marcato,
        ),
        greaterThanOrEqualTo(
          ArticulationRenderer.getArticulationClearanceSS(
            ArticulationType.accent,
          ),
        ),
      );
    });

    test('keeps tenuto farther than staccato for readability', () {
      expect(
        ArticulationRenderer.getArticulationClearanceSS(ArticulationType.tenuto),
        greaterThan(
          ArticulationRenderer.getArticulationClearanceSS(
            ArticulationType.staccato,
          ),
        ),
      );
    });
  });
}
