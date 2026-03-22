// lib/core/slur.dart

import 'musical_element.dart';

/// Direção de uma ligadura
enum SlurDirection { up, down, auto }

/// Representa uma ligadura de expressão avançada
class AdvancedSlur extends MusicalElement {
  final SlurType type;
  final SlurDirection direction;
  final int? voiceNumber;
  final String? id;

  AdvancedSlur({
    required this.type,
    this.direction = SlurDirection.auto,
    this.voiceNumber,
    this.id,
  });
}
