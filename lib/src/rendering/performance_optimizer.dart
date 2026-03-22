// lib/src/rendering/performance_optimizer.dart
// VERSÃO CORRIGIDA: Gestão de cache melhorada

import 'package:flutter/material.dart';
import '../layout/layout_engine.dart';

class PerformanceOptimizer {
  static final Map<String, Path> _pathCache = {};
  static final Map<String, TextPainter> _textCache = {};
  static final Map<String, Offset> _positionCache = {};

  // CORREÇÃO #8: Limite de tamanho de cache
  static const int maxCacheSize = 500;

  static List<PositionedElement> optimizeRenderOrder(
    List<PositionedElement> elements,
  ) {
    // Ordena elementos para renderizar de baixo para cima
    final sorted = List<PositionedElement>.from(elements);
    sorted.sort((a, b) {
      // Primeiro por sistema
      final systemComp = a.system.compareTo(b.system);
      if (systemComp != 0) return systemComp;

      // Depois por posição Y
      return a.position.dy.compareTo(b.position.dy);
    });
    return sorted;
  }

  static Path getStaffLinesPath(double width, double staffSpace, double y) {
    final key = 'staff_${width}_${staffSpace}_$y';
    if (_pathCache.containsKey(key)) {
      return _pathCache[key]!;
    }

    final path = Path();
    for (int i = 0; i < 5; i++) {
      final lineY = y + (i * staffSpace);
      path.moveTo(0, lineY);
      path.lineTo(width, lineY);
    }

    _pathCache[key] = path;
    _checkCacheSize();
    return path;
  }

  static Paint getPaint(Color color, double strokeWidth) {
    return Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
  }

  static void returnPaint(Paint paint) {
    // Método mantido para compatibilidade, mas não faz nada
    // pois não estamos fazendo pooling de Paint objects
  }

  static void drawOptimizedSmuflText({
    required Canvas canvas,
    required String character,
    required Offset position,
    required double size,
    required Color color,
  }) {
    final key = '${character}_${size}_${color.toARGB32()}';

    TextPainter? textPainter = _textCache[key];

    if (textPainter == null) {
      textPainter = TextPainter(
        text: TextSpan(
          text: character,
          style: TextStyle(
            fontFamily: 'Bravura',
            fontSize: size,
            color: color,
            height: 1.0,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      _textCache[key] = textPainter;
      _checkCacheSize();
    }

    textPainter.paint(canvas, position);
  }

  static void _checkCacheSize() {
    if (_pathCache.length > maxCacheSize) {
      // Remove 20% mais antigos
      final toRemove = (maxCacheSize * 0.2).round();
      final keys = _pathCache.keys.take(toRemove).toList();
      for (final key in keys) {
        _pathCache.remove(key);
      }
    }

    if (_textCache.length > maxCacheSize) {
      final toRemove = (maxCacheSize * 0.2).round();
      final keys = _textCache.keys.take(toRemove).toList();
      for (final key in keys) {
        _textCache.remove(key);
      }
    }

    if (_positionCache.length > maxCacheSize) {
      final toRemove = (maxCacheSize * 0.2).round();
      final keys = _positionCache.keys.take(toRemove).toList();
      for (final key in keys) {
        _positionCache.remove(key);
      }
    }
  }

  static void clearCaches() {
    _pathCache.clear();
    _textCache.clear();
    _positionCache.clear();
  }
}
