import 'package:flutter/cupertino.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

import '../widgets/showcase_shell.dart';

/// MEI import, including the three attributes that used to be dropped.
///
/// MEI is import-only here — there is no exporter, and the README has never
/// claimed one (tracked as issue #31). What this page shows is what the
/// importer actually reads, with the emphasis on the attributes that changed
/// the SOUND and the PITCH and were previously ignored without a word.
class MeiInteropExample extends StatelessWidget {
  const MeiInteropExample({super.key});

  static const _accent = Color(0xFF6D28D9);

  @override
  Widget build(BuildContext context) {
    final plain = MEIParser.parseMEI(_plain);
    final octaveClef = MEIParser.parseMEI(_octaveClef);
    final transposing = MEIParser.parseMEI(_transposing);

    String describe(Staff staff) {
      final clef = staff.measures.first.elements.whereType<Clef>().firstOrNull;
      final t = staff.transposition;
      return [
        'clef        ${clef?.clefType.name ?? '(none)'}',
        'octaveShift ${clef?.octaveShift ?? 0}',
        'transpose   ${t == null ? '(none)' : 'diatonic ${t.diatonic}, '
            'chromatic ${t.chromatic}, octave ${t.octaveChange}'}',
      ].join('\n');
    }

    return ExampleShowcasePage(
      title: 'MEI Import',
      subtitle:
          'Common Music Notation from MEI v5, including the octave clef and '
          'the transposing part — two things this importer used to read past '
          'in silence.',
      accentColor: _accent,
      children: [
        const ShowcaseInfoBanner(
          title: 'Import only, and the reason is written down',
          description:
              'MEI goes in; nothing comes back out. There is no MEI serializer '
              'in this package and grep for toMei returns nothing, which is why '
              'the compatibility table says import rather than round trip. An '
              'exporter is tracked as issue #31. Several advanced MEI modules '
              '(figured bass, mensural, <neume>) exist in the data model but '
              'are not imported or rendered — issue #32.',
          accentColor: _accent,
        ),
        ExampleSectionCard(
          title: 'A plain CMN staff',
          description:
              'staffDef with clef.shape, clef.line, key.sig and meter.count / '
              'meter.unit, then a layer of notes carrying @pname, @oct and '
              '@accid.',
          accentColor: _accent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ScorePreviewFrame(
                staff: plain,
                accentColor: _accent,
                minHeight: 200,
                staffSpace: 15,
              ),
              const SizedBox(height: 12),
              ShowcaseCodeBlock(text: describe(plain)),
            ],
          ),
        ),
        ExampleSectionCard(
          title: 'clef.dis and clef.dis.place — the tenor G clef',
          description:
              'An octave-transposing clef used to import as a plain treble, so '
              'a tenor part was engraved an octave off. The parser now reads '
              'clef.dis="8" with clef.dis.place="below" into a treble8vb with '
              'octaveShift -1. Per ADR-003 the Pitch stays the SOUNDING pitch — '
              'the clef changes where it is drawn, not what it means.',
          accentColor: _accent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ScorePreviewFrame(
                staff: octaveClef,
                accentColor: _accent,
                minHeight: 200,
                staffSpace: 15,
              ),
              const SizedBox(height: 12),
              ShowcaseCodeBlock(text: describe(octaveClef)),
            ],
          ),
        ),
        ExampleSectionCard(
          title: 'trans.semi and trans.diat — a B-flat clarinet',
          description:
              'A transposing part declares how far its written pitch sits from '
              'its sounding pitch. Both attributes were ignored, so playback of '
              'an imported clarinet part was a whole tone out. They now reach '
              'Staff.transposition, and from there the MIDI mapper.',
          accentColor: _accent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ScorePreviewFrame(
                staff: transposing,
                accentColor: _accent,
                minHeight: 200,
                staffSpace: 15,
              ),
              const SizedBox(height: 12),
              ShowcaseCodeBlock(text: describe(transposing)),
            ],
          ),
        ),
        ExampleSectionCard(
          title: 'A note with no @oct is refused, not dropped',
          description:
              'MEI used to discard an unreadable note and carry on, so a '
              'document could import as an empty staff with no error at all. A '
              'CMN note missing @oct or @pname now raises a FormatException '
              'naming the attribute. A tablature note is still tolerated, '
              'because there @oct is genuinely optional.',
          accentColor: _accent,
          child: ShowcaseCodeBlock(text: _octlessOutcome()),
        ),
        ExampleSectionCard(
          title: 'The source',
          description: 'The transposing example, in full.',
          accentColor: _accent,
          child: ShowcaseCodeBlock(text: _transposing.trim(), maxHeight: 280),
        ),
      ],
    );
  }

  static String _octlessOutcome() {
    try {
      final staff = MEIParser.parseMEI(_octless);
      final notes = staff.measures
          .expand((m) => m.elements)
          .whereType<Note>()
          .length;
      return 'No exception. Imported $notes note(s) — this is the old '
          'behaviour and should not happen.';
    } on FormatException catch (e) {
      return 'FormatException\n\n${e.message}';
    }
  }
}

const String _plain = '''
<mei xmlns="http://www.music-encoding.org/ns/mei">
 <music>
 <body><mdiv><score>
  <scoreDef><staffGrp>
   <staffDef n="1" lines="5" clef.shape="G" clef.line="2" key.sig="1s"
             meter.count="4" meter.unit="4"/>
  </staffGrp></scoreDef>
  <section><measure n="1"><staff n="1"><layer n="1">
   <note pname="c" oct="5" dur="4"/>
   <note pname="d" oct="5" dur="4"/>
   <note pname="e" oct="5" dur="4" accid="f"/>
   <note pname="f" oct="5" dur="4"/>
  </layer></staff></measure></section>
 </score></mdiv></body>
 </music>
</mei>
''';

const String _octaveClef = '''
<mei xmlns="http://www.music-encoding.org/ns/mei">
 <music>
 <body><mdiv><score>
  <scoreDef><staffGrp>
   <staffDef n="1" lines="5" clef.shape="G" clef.line="2"
             clef.dis="8" clef.dis.place="below"
             meter.count="4" meter.unit="4"/>
  </staffGrp></scoreDef>
  <section><measure n="1"><staff n="1"><layer n="1">
   <note pname="c" oct="4" dur="4"/>
   <note pname="e" oct="4" dur="4"/>
   <note pname="g" oct="4" dur="4"/>
   <note pname="c" oct="5" dur="4"/>
  </layer></staff></measure></section>
 </score></mdiv></body>
 </music>
</mei>
''';

const String _transposing = '''
<mei xmlns="http://www.music-encoding.org/ns/mei">
 <music>
 <body><mdiv><score>
  <scoreDef><staffGrp>
   <staffDef n="1" lines="5" clef.shape="G" clef.line="2"
             label="Clarinet in B-flat" label.abbr="Cl."
             trans.semi="-2" trans.diat="-1"
             meter.count="4" meter.unit="4"/>
  </staffGrp></scoreDef>
  <section><measure n="1"><staff n="1"><layer n="1">
   <note pname="c" oct="5" dur="4"/>
   <note pname="d" oct="5" dur="4"/>
   <note pname="e" oct="5" dur="2"/>
  </layer></staff></measure></section>
 </score></mdiv></body>
 </music>
</mei>
''';

const String _octless = '''
<mei xmlns="http://www.music-encoding.org/ns/mei">
 <music>
 <body><mdiv><score>
  <scoreDef><staffGrp>
   <staffDef n="1" lines="5" clef.shape="G" clef.line="2"/>
  </staffGrp></scoreDef>
  <section><measure n="1"><staff n="1"><layer n="1">
   <note pname="c" dur="4"/>
  </layer></staff></measure></section>
 </score></mdiv></body>
 </music>
</mei>
''';
