// lib/core/space.dart

import 'musical_element.dart';
import 'duration.dart';

/// Representa um espaço vazio com duração definida, correspondendo ao
/// elemento `<space>` do MEI v5.
///
/// Um `<space>` ocupa tempo no compasso sem produzir som. É usado para
/// alinhar vozes ou criar pausas invisíveis em notação específica.
///
/// ```dart
/// measure.add(Space(duration: const Duration(DurationType.quarter)));
/// ```
class Space extends MusicalElement {
  /// Duração do espaço (tempo que ocupa no compasso).
  final Duration duration;

  Space({required this.duration});
}

/// Representa um espaço de medida inteira (compasso completo em silêncio),
/// correspondendo ao elemento `<mSpace>` do MEI v5.
///
/// Usado para indicar um compasso de pausa em partes orquestrais onde
/// o instrumento não toca, sem exibir uma pausa de semibreve normal.
///
/// ```dart
/// measure.add(MeasureSpace());
/// ```
class MeasureSpace extends MusicalElement {
  /// Número de compassos de silêncio que este elemento representa.
  /// Padrão = 1. Usado para pausas multi-compassos comprimidas.
  final int measureCount;

  MeasureSpace({this.measureCount = 1});
}
