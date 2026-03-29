// lib/core/space.dart

import 'musical_element.dart';
import 'duration.dart';

/// Representa um space empty with duração definida, correspwherendo ao
/// elemento `<space>` of the MEI v5.
///
/// Um `<space>` ocupa tempo no measure sem produzir som. É used for
/// alinhar voices ou Createsr paUsess invisíveis in noteção específica.
///
/// ```dart
/// measure.add(Space(duration: const Duration(DurationType.quarter)));
/// ```
class Space extends MusicalElement {
  /// Duração of the space (tempo that ocupa no measure).
  final Duration duration;

  Space({required this.duration});
}

/// Representa um space de medida inteira (measure completo in siReadsncio),
/// correspwherendo ao elemento `<mSpace>` of the MEI v5.
///
/// used for indicar um measure de paUses in partes orquestrais where
/// o instrumento not toca, sem exibir a paUses de semibreve normal.
///
/// ```dart
/// measure.add(MeasureSpace());
/// ```
class MeasureSpace extends MusicalElement {
  /// Number de measures de siReadsncio that this elemento representa.
  /// Default = 1. used for paUsess multi-measures comprimidas.
  final int measureCount;

  MeasureSpace({this.measureCount = 1});
}
