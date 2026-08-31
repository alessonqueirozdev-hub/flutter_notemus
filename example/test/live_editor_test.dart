// The Live Editor ships three seed documents — JSON, MusicXML and MEI — and a
// seed that does not parse would make the page look broken on arrival. The
// smoke suite only proves the widget builds; `_parse` catches everything, so a
// dead seed would build perfectly and render nothing.
//
// This checks the thing that matters: each format arrives with a rendered
// staff and no error panel.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// `hide Duration`: the package exports the rhythmic duration type under the
// legacy alias `Duration`, which shadows `dart:core.Duration` — so
// `tester.pump(const Duration(milliseconds: 300))` does not compile without
// this. It is the exact trap `MusicDuration` exists to let a consumer avoid,
// and it caught this file on the first run.
import 'package:flutter_notemus/flutter_notemus.dart' hide Duration;
import 'package:flutter_notemus_example/examples/live_editor_example.dart';
import 'package:flutter_notemus_example/showcase_bootstrap.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await ensureShowcaseAssetsLoaded();
  });

  Future<void> pumpEditor(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: LiveEditorExample()));
    await tester.pump();
  }

  testWidgets('the JSON seed renders a staff, with no refusal', (tester) async {
    await pumpEditor(tester);
    expect(tester.takeException(), isNull);
    expect(find.byType(MusicScore), findsWidgets,
        reason: 'the seed document must produce a rendered staff');
    expect(find.text('Refused'), findsNothing);
    expect(find.textContaining('warnings  (none)'), findsWidgets,
        reason: 'the seed should parse cleanly, with nothing to warn about');
  });

  for (final format in const ['MusicXML', 'MEI']) {
    testWidgets('the $format seed renders a staff, with no refusal',
        (tester) async {
      await pumpEditor(tester);
      await tester.tap(find.text(format));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(find.text('Refused'), findsNothing,
          reason: 'the $format seed was rejected by its own parser');
      expect(find.byType(MusicScore), findsWidgets,
          reason: 'the $format seed must produce a rendered staff');
    });
  }
}
