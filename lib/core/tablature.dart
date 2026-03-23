// lib/core/tablature.dart

import 'musical_element.dart';
import 'duration.dart';

/// Representa a afinação de uma corda em notação de tablatura.
///
/// Corresponde às informações de afinação em `<staffDef>` no MEI v5.
class TabString {
  /// Número da corda (1 = mais aguda / primeira corda).
  final int number;

  /// Nome da nota da corda solta (ex.: 'E', 'A', 'D', 'G', 'B').
  final String pitchName;

  /// Oitava da corda solta.
  final int octave;

  const TabString({
    required this.number,
    required this.pitchName,
    required this.octave,
  });
}

/// Afinação de instrumento para tablatura.
///
/// Inclui afinações pré-definidas para violão, baixo e outros instrumentos.
class TabTuning {
  /// Nome da afinação (ex.: 'Standard', 'Drop D', 'Open G').
  final String name;

  /// Cordas da afinação, ordenadas da mais aguda (1) para a mais grave.
  final List<TabString> strings;

  const TabTuning({required this.name, required this.strings});

  /// Afinação padrão de violão (E2-A2-D3-G3-B3-E4).
  static const TabTuning guitarStandard = TabTuning(
    name: 'Standard',
    strings: [
      TabString(number: 1, pitchName: 'E', octave: 4),
      TabString(number: 2, pitchName: 'B', octave: 3),
      TabString(number: 3, pitchName: 'G', octave: 3),
      TabString(number: 4, pitchName: 'D', octave: 3),
      TabString(number: 5, pitchName: 'A', octave: 2),
      TabString(number: 6, pitchName: 'E', octave: 2),
    ],
  );

  /// Afinação Drop D de violão (D2-A2-D3-G3-B3-E4).
  static const TabTuning guitarDropD = TabTuning(
    name: 'Drop D',
    strings: [
      TabString(number: 1, pitchName: 'E', octave: 4),
      TabString(number: 2, pitchName: 'B', octave: 3),
      TabString(number: 3, pitchName: 'G', octave: 3),
      TabString(number: 4, pitchName: 'D', octave: 3),
      TabString(number: 5, pitchName: 'A', octave: 2),
      TabString(number: 6, pitchName: 'D', octave: 2),
    ],
  );

  /// Afinação padrão de baixo de 4 cordas (E1-A1-D2-G2).
  static const TabTuning bassStandard = TabTuning(
    name: 'Bass Standard',
    strings: [
      TabString(number: 1, pitchName: 'G', octave: 2),
      TabString(number: 2, pitchName: 'D', octave: 2),
      TabString(number: 3, pitchName: 'A', octave: 1),
      TabString(number: 4, pitchName: 'E', octave: 1),
    ],
  );

  /// Afinação padrão de alaúde renascentista em Sol (G2-C3-F3-A3-D4-G4).
  static const TabTuning luteStandard = TabTuning(
    name: 'Lute (Renaissance G)',
    strings: [
      TabString(number: 1, pitchName: 'G', octave: 4),
      TabString(number: 2, pitchName: 'D', octave: 4),
      TabString(number: 3, pitchName: 'A', octave: 3),
      TabString(number: 4, pitchName: 'F', octave: 3),
      TabString(number: 5, pitchName: 'C', octave: 3),
      TabString(number: 6, pitchName: 'G', octave: 2),
    ],
  );
}

/// Símbolo de duração em tablatura (MEI `<tabDurSym>`).
///
/// Em tablatura, a duração pode ser indicada por um símbolo separado
/// acima ou abaixo dos números de casa. Corresponde ao elemento
/// `<tabDurSym>` do MEI v5.
class TabDurSym extends MusicalElement {
  /// Duração representada por este símbolo.
  final Duration duration;

  /// Indica se o símbolo é exibido acima (padrão) ou abaixo das cordas.
  final bool above;

  TabDurSym({required this.duration, this.above = true});
}

/// Representa uma nota em tablatura, correspondendo ao elemento `<note>`
/// com atributos `@tab.fret` e `@tab.string` no MEI v5.
///
/// ```dart
/// TabNote(string: 1, fret: 0)   // primeira corda solta
/// TabNote(string: 3, fret: 2)   // terceira corda, 2ª casa
/// TabNote(string: 6, fret: 5)   // sexta corda, 5ª casa
/// ```
class TabNote extends MusicalElement {
  /// Número da corda (1 = mais aguda). MEI `@tab.string`.
  final int string;

  /// Casa (fret). 0 = corda solta. MEI `@tab.fret`.
  final int fret;

  /// Duração da nota de tablatura.
  final Duration? duration;

  /// Indica se esta nota é harmonics (toque levemente a corda).
  final bool isHarmonic;

  /// Indica se há mudo (x) nesta corda.
  final bool isMuted;

  TabNote({
    required this.string,
    required this.fret,
    this.duration,
    this.isHarmonic = false,
    this.isMuted = false,
  });
}

/// Grupo de notas simultâneas em tablatura (MEI `<tabGrp>`).
///
/// Equivale a um acorde em notação convencional, mas representado como
/// números de casa em múltiplas cordas simultaneamente.
///
/// ```dart
/// TabGrp(
///   notes: [
///     TabNote(string: 1, fret: 0),
///     TabNote(string: 2, fret: 1),
///     TabNote(string: 3, fret: 2),
///   ],
///   duration: Duration(DurationType.quarter),
/// )
/// ```
class TabGrp extends MusicalElement {
  /// Notas do grupo (uma por corda).
  final List<TabNote> notes;

  /// Duração do grupo.
  final Duration duration;

  TabGrp({required this.notes, required this.duration});
}
