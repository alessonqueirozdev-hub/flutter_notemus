// lib/core/note.dart

import 'musical_element.dart';
import 'pitch.dart';
import 'duration.dart';
import 'ornament.dart';
import 'dynamic.dart';
import 'technique.dart';
import '../src/music_model/bounding_box_support.dart';

/// Define os tipos de articulações que uma nota pode ter.
enum ArticulationType {
  staccato,         // Ponto
  staccatissimo,    // Ponto triangular
  accent,           // Acento
  strongAccent,     // Acento forte
  tenuto,           // Traço
  marcato,          // Combinação de acento e tenuto
  legato,           // Ligado (normalmente como slur)
  portato,          // Combinação de staccato e tenuto
  upBow,            // Arco para cima (cordas)
  downBow,          // Arco para baixo (cordas)
  harmonics,        // Harmônicos
  pizzicato,        // Pizzicato
  snap,             // Snap pizzicato
  thumb,            // Dedilhado com polegar
  stopped,          // Notas abafadas (metal)
  open,             // Notas abertas (metal)
  halfStopped,      // Meio abafado (metal)
}

/// Representa uma nota musical com altura e duração.
class Note extends MusicalElement with BoundingBoxSupport {
  final Pitch pitch;
  final Duration duration;

  final BeamType? beam;
  final List<ArticulationType> articulations;
  final TieType? tie;

  /// Opcional: Define se esta nota inicia ou termina uma ligadura de expressão.
  final SlurType? slur;

  /// Lista de ornamentos aplicados à nota
  final List<Ornament> ornaments;

  /// Dinâmica específica da nota
  final Dynamic? dynamicElement;

  /// Técnicas especiais da nota
  final List<PlayingTechnique> techniques;

  /// Número da voz para notação polifônica (1 = soprano, 2 = contralto, etc.)
  /// null = voz única (padrão)
  final int? voice;

  Note({
    required this.pitch,
    required this.duration,
    this.beam,
    this.articulations = const [],
    this.tie,
    this.slur,
    this.ornaments = const [],
    this.dynamicElement,
    this.techniques = const [],
    this.voice,
  });
}
