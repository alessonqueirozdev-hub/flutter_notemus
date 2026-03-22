/// Testes do Sistema de Espaçamento Inteligente
/// 
/// Valida os modelos matemáticos, compensação óptica e combinação adaptativa.
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_notemus/src/layout/spacing/spacing.dart';

void main() {
  group('SpacingCalculator', () {
    test('Modelo de raiz quadrada aproxima tabela de Gould', () {
      final calculator = SpacingCalculator(
        model: SpacingModel.squareRoot,
        spacingRatio: 1.0,
      );

      // Validar contra tabela de Gould
      final errors = calculator.validateAgainstGould();

      // Todos os erros devem ser < 10%
      errors.forEach((duration, errorPercent) {
        expect(errorPercent, lessThan(10.0),
            reason: 'Duração $duration tem erro de ${errorPercent.toStringAsFixed(2)}%');
      });
    });

    test('Notas de mesma duração têm espaçamento idêntico', () {
      final calculator = SpacingCalculator(
        model: SpacingModel.squareRoot,
        spacingRatio: 1.5,
      );

      final shortestDuration = 0.125; // colcheia
      final quarterDuration = 0.25; // semínima

      // Calcular espaçamento para várias semínimas
      final space1 = calculator.calculateSpace(quarterDuration, shortestDuration);
      final space2 = calculator.calculateSpace(quarterDuration, shortestDuration);
      final space3 = calculator.calculateSpace(quarterDuration, shortestDuration);

      expect(space1, equals(space2));
      expect(space2, equals(space3));
    });

    test('Notas mais longas têm mais espaço', () {
      final calculator = SpacingCalculator(
        model: SpacingModel.squareRoot,
        spacingRatio: 1.5,
      );

      final shortestDuration = 0.125; // colcheia
      final eighthSpace = calculator.calculateSpace(0.125, shortestDuration);
      final quarterSpace = calculator.calculateSpace(0.25, shortestDuration);
      final halfSpace = calculator.calculateSpace(0.5, shortestDuration);
      final wholeSpace = calculator.calculateSpace(1.0, shortestDuration);

      expect(quarterSpace, greaterThan(eighthSpace));
      expect(halfSpace, greaterThan(quarterSpace));
      expect(wholeSpace, greaterThan(halfSpace));
    });

    test('Fator √2 entre durações consecutivas (modelo raiz quadrada)', () {
      final calculator = SpacingCalculator(
        model: SpacingModel.squareRoot,
        spacingRatio: 1.0,
      );

      final shortestDuration = 0.125;
      final eighthSpace = calculator.calculateSpace(0.125, shortestDuration);
      final quarterSpace = calculator.calculateSpace(0.25, shortestDuration);

      // Razão deve ser ≈ √2 ≈ 1.41
      final ratio = quarterSpace / eighthSpace;
      expect(ratio, closeTo(1.41, 0.05));
    });
  });

  group('OpticalCompensator', () {
    late OpticalCompensator compensator;

    setUp(() {
      compensator = OpticalCompensator(
        staffSpace: 12.0,
        enabled: true,
        intensity: 1.0,
      );
    });

    test('Hastes alternadas geram compensação', () {
      final prevContext = OpticalContext.note(
        stemUp: true,
        duration: 0.25,
      );
      final currContext = OpticalContext.note(
        stemUp: false,
        duration: 0.25,
      );

      final compensation = compensator.calculateCompensation(
        prevContext,
        currContext,
      );

      // Haste para cima → haste para baixo: deve afastar
      expect(compensation, greaterThan(0));
    });

    test('Pausa antes de nota com haste para cima gera compensação', () {
      final prevContext = OpticalContext.rest(duration: 0.25);
      final currContext = OpticalContext.note(
        stemUp: true,
        duration: 0.25,
      );

      final compensation = compensator.calculateCompensation(
        prevContext,
        currContext,
      );

      expect(compensation, greaterThan(0));
    });

    test('Acidentes adicionam espaço', () {
      final prevContext = OpticalContext.note(
        stemUp: true,
        duration: 0.25,
      );
      final currContext = OpticalContext.note(
        stemUp: true,
        duration: 0.25,
        hasAccidental: true,
      );

      final compensation = compensator.calculateCompensation(
        prevContext,
        currContext,
      );

      expect(compensation, greaterThan(0));
    });

    test('Compensação pode ser desabilitada', () {
      final disabled = OpticalCompensator(
        staffSpace: 12.0,
        enabled: false,
      );

      final prevContext = OpticalContext.note(
        stemUp: true,
        duration: 0.25,
      );
      final currContext = OpticalContext.note(
        stemUp: false,
        duration: 0.25,
      );

      final compensation = disabled.calculateCompensation(
        prevContext,
        currContext,
      );

      expect(compensation, equals(0));
    });
  });

  group('IntelligentSpacingEngine', () {
    late IntelligentSpacingEngine engine;

    setUp(() {
      engine = IntelligentSpacingEngine(
        preferences: SpacingPreferences.normal,
      );
      engine.initializeOpticalCompensator(12.0);
    });

    test('Espaçamento textual evita colisões', () {
      final symbols = [
        MusicalSymbolInfo(
          index: 0,
          musicalTime: 0.0,
          duration: 0.25,
          glyphWidth: 1.18,
        ),
        MusicalSymbolInfo(
          index: 1,
          musicalTime: 0.25,
          duration: 0.25,
          glyphWidth: 1.18,
        ),
      ];

      final textual = engine.computeTextualSpacing(
        symbols: symbols,
        minGap: 0.25,
        staffSpace: 12.0,
      );

      // Segunda nota deve estar após a primeira
      expect(textual[1].xPosition, greaterThan(textual[0].xPosition));

      // Deve haver gap mínimo
      final gap = textual[1].xPosition - (textual[0].xPosition + textual[0].width);
      expect(gap, greaterThanOrEqualTo(0.25 * 12.0));
    });

    test('Espaçamento duracional é proporcional ao tempo', () {
      final symbols = [
        MusicalSymbolInfo(
          index: 0,
          musicalTime: 0.0,
          duration: 0.25, // semínima
        ),
        MusicalSymbolInfo(
          index: 1,
          musicalTime: 0.25,
          duration: 0.5, // mínima
        ),
      ];

      final durational = engine.computeDurationalSpacing(
        symbols: symbols,
        shortestDuration: 0.125,
        staffSpace: 12.0,
      );

      // Segunda nota (duração mais longa) deve ter mais espaço
      expect(durational[1].width, greaterThan(durational[0].width));
    });

    test('Combinação adaptativa preserva larguras mínimas', () {
      final symbols = List.generate(
        3,
        (i) => MusicalSymbolInfo(
          index: i,
          musicalTime: i * 0.25,
          duration: 0.25,
          glyphWidth: 1.18,
        ),
      );

      final textual = engine.computeTextualSpacing(
        symbols: symbols,
        minGap: 0.25,
        staffSpace: 12.0,
      );

      final durational = engine.computeDurationalSpacing(
        symbols: symbols,
        shortestDuration: 0.125,
        staffSpace: 12.0,
      );

      final combined = engine.combineSpacings(
        textual: textual,
        durational: durational,
        targetWidth: 500.0,
      );

      // Largura final deve ser aproximadamente targetWidth
      final finalWidth = combined.last.xPosition + combined.last.width;
      expect(finalWidth, closeTo(500.0, 10.0));
    });
  });

  group('SpacingPreferences', () {
    test('Presets têm valores válidos', () {
      expect(SpacingPreferences.compact.spacingFactor, lessThan(SpacingPreferences.normal.spacingFactor));
      expect(SpacingPreferences.normal.spacingFactor, lessThan(SpacingPreferences.spacious.spacingFactor));
      expect(SpacingPreferences.spacious.spacingFactor, lessThan(SpacingPreferences.pedagogical.spacingFactor));
    });

    test('copyWith cria nova instância com modificações', () {
      final original = SpacingPreferences.normal;
      final modified = original.copyWith(spacingFactor: 2.0);

      expect(modified.spacingFactor, equals(2.0));
      expect(modified.model, equals(original.model));
      expect(original.spacingFactor, equals(1.5)); // Original não modificado
    });
  });

  group('CollisionDetector', () {
    late CollisionDetector detector;

    setUp(() {
      detector = CollisionDetector(minSafeDistance: 2.0);
    });

    test('Detecta colisão entre retângulos sobrepostos', () {
      final box1 = Rect.fromLTWH(0, 0, 10, 10);
      final box2 = Rect.fromLTWH(5, 0, 10, 10);

      expect(detector.checkCollision(box1, box2), isTrue);
    });

    test('Não detecta colisão entre retângulos separados', () {
      final box1 = Rect.fromLTWH(0, 0, 10, 10);
      final box2 = Rect.fromLTWH(20, 0, 10, 10);

      expect(detector.checkCollision(box1, box2), isFalse);
    });

    test('Calcula separação mínima necessária', () {
      final box1 = Rect.fromLTWH(0, 0, 10, 10);
      final box2 = Rect.fromLTWH(11, 0, 10, 10);

      final separation = detector.calculateMinimumSeparation(box1, box2);

      // Gap atual é 1, min safe distance é 2, então separação necessária é 1
      expect(separation, equals(1.0));
    });
  });
}
