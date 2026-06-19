// Convenience bridge from chant notation (GABC / ChantScore) to MIDI playback.
//
// The core mapper [ChantMidiMapper] is pure-Dart and element-based; this layer
// adds the GABC parse step and the clef-flat (soft-B) plumbing, mirroring the
// rendering API so an "edit + play chant" app gets a one-liner.

import '../../midi/chant_midi_mapper.dart';
import '../../midi/midi_models.dart';
import 'chant_score.dart';
import 'gabc_parser.dart';

/// Parses a GABC document and builds a chant [MidiSequence] from it, honouring
/// the clef-flat (soft B-flat) recorded by the parser.
MidiSequence gabcToMidiSequence(
  String gabc, {
  ChantPlaybackOptions options = const ChantPlaybackOptions(),
  String trackName = 'Chant',
}) {
  final result = GabcParser.parse(gabc);
  return ChantMidiMapper.fromChant(
    result.elements,
    options: options,
    softB: result.clef.flat,
    trackName: trackName,
  );
}

/// Builds full chant [ChantPlayback] (sequence + per-note timeline) from GABC,
/// for playback highlighting in an editor.
ChantPlayback gabcToChantPlayback(
  String gabc, {
  ChantPlaybackOptions options = const ChantPlaybackOptions(),
  String trackName = 'Chant',
}) {
  final result = GabcParser.parse(gabc);
  return ChantMidiMapper.build(
    result.elements,
    options: options,
    softB: result.clef.flat,
    trackName: trackName,
  );
}

/// Playback helpers on the [ChantScore] widget, mirroring its render API.
extension ChantScoreMidi on ChantScore {
  /// The chant as a playable/exportable [MidiSequence].
  MidiSequence toMidiSequence({
    ChantPlaybackOptions options = const ChantPlaybackOptions(),
    String trackName = 'Chant',
  }) =>
      ChantMidiMapper.fromChant(
        elements,
        options: options,
        softB: clef.flat,
        trackName: trackName,
      );

  /// The chant as a [ChantPlayback] (sequence + per-note timeline).
  ChantPlayback toChantPlayback({
    ChantPlaybackOptions options = const ChantPlaybackOptions(),
    String trackName = 'Chant',
  }) =>
      ChantMidiMapper.build(
        elements,
        options: options,
        softB: clef.flat,
        trackName: trackName,
      );
}
