import 'dart:core' as core;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_notemus/flutter_notemus.dart';
import 'package:flutter_notemus_example/examples/complete_music_piece.dart';

void main() {
  testWidgets('debug complete piece layout', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CompleteMusicPieceExample()));
    await tester.pump(const core.Duration(milliseconds: 100));

    final musicScore = tester.widget(find.byType(MusicScore).first) as MusicScore;
    final metadata = SmuflMetadata();
    await metadata.load();
    final engine = LayoutEngine(
      musicScore.staff,
      availableWidth: 1400,
      staffSpace: 14,
      metadata: metadata,
    );
    final result = engine.layoutWithSignature();

    var currentSystem = -1;
    for (final element in result.elements) {
      if (element.system != currentSystem) {
        currentSystem = element.system;
        debugPrint('SYSTEM $currentSystem');
      }
      final name = element.element.runtimeType.toString().padRight(18);
      debugPrint('  $name x=${element.position.dx.toStringAsFixed(1)} y=${element.position.dy.toStringAsFixed(1)}');
    }
  });
}
