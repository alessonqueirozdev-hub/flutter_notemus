// example/lib/examples/multi_staff_example.dart

import 'package:flutter/material.dart';
import 'package:flutter_notemus/core/core.dart';

/// Example demonstrating multi-staff notation
///
/// Shows:
/// 1. Piano (grand staff with brace)
/// 2. Choir SATB (with bracket)
/// 3. Orchestral score (multiple groups)
class MultiStaffExample {
  /// Create a simple piano score (grand staff)
  static Score createPianoScore() {
    // Treble staff (right hand)
    final trebleStaff = Staff();
    final trebleMeasure = Measure();

    trebleMeasure.add(Clef(type: 'treble'));
    trebleMeasure.add(KeySignature(0)); // C major
    trebleMeasure.add(TimeSignature(numerator: 4, denominator: 4));

    // Right hand melody: C D E F (quarter notes)
    trebleMeasure.add(Note(
      pitch: const Pitch(step: 'C', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));
    trebleMeasure.add(Note(
      pitch: const Pitch(step: 'D', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));
    trebleMeasure.add(Note(
      pitch: const Pitch(step: 'E', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));
    trebleMeasure.add(Note(
      pitch: const Pitch(step: 'F', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));

    trebleStaff.add(trebleMeasure);

    // Bass staff (left hand)
    final bassStaff = Staff();
    final bassMeasure = Measure();

    bassMeasure.add(Clef(type: 'bass'));
    bassMeasure.add(KeySignature(0)); // C major
    bassMeasure.add(TimeSignature(numerator: 4, denominator: 4));

    // Left hand accompaniment: C chord (whole note)
    bassMeasure.add(Chord(
      notes: [
        Note(
          pitch: const Pitch(step: 'C', octave: 3),
          duration: const Duration(DurationType.whole),
        ),
        Note(
          pitch: const Pitch(step: 'E', octave: 3),
          duration: const Duration(DurationType.whole),
        ),
        Note(
          pitch: const Pitch(step: 'G', octave: 3),
          duration: const Duration(DurationType.whole),
        ),
      ],
      duration: const Duration(DurationType.whole),
    ));

    bassStaff.add(bassMeasure);

    // Create piano score with grand staff
    return Score.grandStaff(
      trebleStaff,
      bassStaff,
      title: 'Piano Example',
      composer: 'Flutter Notemus',
    );
  }

  /// Create a choir SATB score
  static Score createChoirScore() {
    // Soprano staff
    final soprano = _createVoiceStaff('treble', 5, 'Soprano');

    // Alto staff
    final alto = _createVoiceStaff('treble', 4, 'Alto');

    // Tenor staff (treble clef, sounds octave lower)
    final tenor = _createVoiceStaff('treble', 4, 'Tenor');

    // Bass staff
    final bass = _createVoiceStaff('bass', 3, 'Bass');

    return Score.choir(
      soprano,
      alto,
      tenor,
      bass,
      title: 'Ave Maria',
      composer: 'Various',
    );
  }

  /// Create an orchestral score with multiple groups
  static Score createOrchestralScore() {
    // Woodwind section
    final flute = _createInstrumentStaff('Flute', 'treble', 5);
    final clarinet = _createInstrumentStaff('Clarinet', 'treble', 5);
    final woodwindGroup = StaffGroup.woodwinds([flute, clarinet]);

    // Brass section
    final trumpet = _createInstrumentStaff('Trumpet', 'treble', 5);
    final trombone = _createInstrumentStaff('Trombone', 'bass', 3);
    final brassGroup = StaffGroup.brass([trumpet, trombone]);

    // String section
    final violin1 = _createInstrumentStaff('Violin I', 'treble', 5);
    final violin2 = _createInstrumentStaff('Violin II', 'treble', 5);
    final viola = _createInstrumentStaff('Viola', 'alto', 4);
    final cello = _createInstrumentStaff('Cello', 'bass', 3);
    final stringsGroup = StaffGroup.strings([violin1, violin2, viola, cello]);

    return Score.orchestral(
      title: 'Symphony No. 1',
      composer: 'Example Composer',
      groups: [woodwindGroup, brassGroup, stringsGroup],
    );
  }

  /// Helper: Create a voice staff for choir
  static Staff _createVoiceStaff(String clefType, int octave, String voice) {
    final staff = Staff();
    final measure = Measure();

    measure.add(Clef(type: clefType));
    measure.add(KeySignature(0));
    measure.add(TimeSignature(numerator: 4, denominator: 4));

    // Simple quarter notes
    for (int i = 0; i < 4; i++) {
      final steps = ['C', 'D', 'E', 'F'];
      measure.add(Note(
        pitch: Pitch(step: steps[i], octave: octave),
        duration: const Duration(DurationType.quarter),
      ));
    }

    staff.add(measure);
    return staff;
  }

  /// Helper: Create an instrument staff
  static Staff _createInstrumentStaff(
    String name,
    String clefType,
    int octave,
  ) {
    final staff = Staff();
    final measure = Measure();

    measure.add(Clef(type: clefType));
    measure.add(KeySignature(0));
    measure.add(TimeSignature(numerator: 4, denominator: 4));

    // Whole note
    measure.add(Note(
      pitch: Pitch(step: 'C', octave: octave),
      duration: const Duration(DurationType.whole),
    ));

    staff.add(measure);
    return staff;
  }
}

/// Flutter widget to display multi-staff examples
class MultiStaffExampleWidget extends StatelessWidget {
  final Score score;

  const MultiStaffExampleWidget({
    super.key,
    required this.score,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(score.title ?? 'Multi-Staff Example'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Score metadata
            if (score.title != null)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  score.title!,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            if (score.composer != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  score.composer!,
                  style: const TextStyle(
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),

            // TODO: Render score using MultiStaffRenderer
            // For now, show staff groups info
            ...score.staffGroups.asMap().entries.map((entry) {
              final index = entry.key;
              final group = entry.value;
              return Card(
                margin: const EdgeInsets.all(16.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Group ${index + 1}: ${group.name ?? 'Unnamed'}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Bracket Type: ${group.bracket.name}'),
                      Text('Staff Count: ${group.staffCount}'),
                      Text('Connect Barlines: ${group.connectBarlines}'),
                      if (group.abbreviation != null)
                        Text('Abbreviation: ${group.abbreviation}'),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

/// Demo app showing all multi-staff examples
class MultiStaffDemoApp extends StatelessWidget {
  const MultiStaffDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Multi-Staff Examples',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Multi-Staff Examples'),
          ),
          body: ListView(
            children: [
              ListTile(
                leading: const Icon(Icons.piano),
                title: const Text('Piano (Grand Staff)'),
                subtitle: const Text('Treble + Bass with brace'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MultiStaffExampleWidget(
                        score: MultiStaffExample.createPianoScore(),
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.groups),
                title: const Text('Choir (SATB)'),
                subtitle: const Text('Soprano, Alto, Tenor, Bass with bracket'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MultiStaffExampleWidget(
                        score: MultiStaffExample.createChoirScore(),
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.music_note),
                title: const Text('Orchestral Score'),
                subtitle: const Text('Multiple instrument groups'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MultiStaffExampleWidget(
                        score: MultiStaffExample.createOrchestralScore(),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
