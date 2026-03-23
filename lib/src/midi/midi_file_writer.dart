import 'dart:convert';
import 'dart:typed_data';

import 'midi_models.dart';

class MidiFileWriter {
  static Uint8List write(MidiSequence sequence) {
    final buffer = BytesBuilder();

    final trackCount = sequence.tracks.length;
    final format = trackCount <= 1 ? 0 : 1;

    buffer.add(_ascii('MThd'));
    buffer.add(_u32be(6));
    buffer.add(_u16be(format));
    buffer.add(_u16be(trackCount));
    buffer.add(_u16be(sequence.ticksPerQuarter));

    for (final track in sequence.tracks) {
      final trackData = _buildTrackData(track);
      buffer.add(_ascii('MTrk'));
      buffer.add(_u32be(trackData.length));
      buffer.add(trackData);
    }

    return buffer.toBytes();
  }

  static Uint8List _buildTrackData(MidiTrack track) {
    final events = List<MidiEvent>.from(track.events)
      ..sort((a, b) {
        final tickComparison = a.tick.compareTo(b.tick);
        if (tickComparison != 0) return tickComparison;
        return _eventPriority(a.type).compareTo(_eventPriority(b.type));
      });

    final bytes = BytesBuilder();
    int lastTick = 0;

    for (final event in events) {
      final delta = event.tick - lastTick;
      bytes.add(_vlq(delta < 0 ? 0 : delta));
      bytes.add(_encodeEvent(event));
      lastTick = event.tick;
    }

    bytes.add(const <int>[0x00, 0xFF, 0x2F, 0x00]);
    return bytes.toBytes();
  }

  static List<int> _encodeEvent(MidiEvent event) {
    switch (event.type) {
      case MidiEventType.noteOn:
        return <int>[
          0x90 | (event.channel & 0x0F),
          (event.note ?? 0) & 0x7F,
          (event.velocity ?? 0) & 0x7F,
        ];

      case MidiEventType.noteOff:
        return <int>[
          0x80 | (event.channel & 0x0F),
          (event.note ?? 0) & 0x7F,
          (event.velocity ?? 0) & 0x7F,
        ];

      case MidiEventType.programChange:
        return <int>[
          0xC0 | (event.channel & 0x0F),
          (event.program ?? 0) & 0x7F,
        ];

      case MidiEventType.controlChange:
        return <int>[
          0xB0 | (event.channel & 0x0F),
          (event.controller ?? 0) & 0x7F,
          (event.value ?? 0) & 0x7F,
        ];

      case MidiEventType.tempo:
        final bpm = event.bpm == null || event.bpm! <= 0 ? 120 : event.bpm!;
        final microsPerQuarter = (60000000 / bpm).round().clamp(1, 0xFFFFFF);
        return <int>[
          0xFF,
          0x51,
          0x03,
          (microsPerQuarter >> 16) & 0xFF,
          (microsPerQuarter >> 8) & 0xFF,
          microsPerQuarter & 0xFF,
        ];

      case MidiEventType.timeSignature:
        final numerator = (event.numerator ?? 4).clamp(1, 255);
        final denominator = (event.denominator ?? 4).clamp(1, 255);
        final denominatorPower = _powerOfTwoIndex(denominator);
        return <int>[0xFF, 0x58, 0x04, numerator, denominatorPower, 24, 8];

      case MidiEventType.marker:
        final text = event.markerText ?? '';
        final payload = utf8.encode(text);
        return <int>[0xFF, 0x06, ..._vlq(payload.length), ...payload];
    }
  }
}

int _eventPriority(MidiEventType type) {
  return switch (type) {
    MidiEventType.tempo => 0,
    MidiEventType.timeSignature => 1,
    MidiEventType.marker => 2,
    MidiEventType.programChange => 3,
    MidiEventType.controlChange => 4,
    MidiEventType.noteOff => 5,
    MidiEventType.noteOn => 6,
  };
}

List<int> _ascii(String value) => ascii.encode(value);

List<int> _u16be(int value) {
  return <int>[(value >> 8) & 0xFF, value & 0xFF];
}

List<int> _u32be(int value) {
  return <int>[
    (value >> 24) & 0xFF,
    (value >> 16) & 0xFF,
    (value >> 8) & 0xFF,
    value & 0xFF,
  ];
}

List<int> _vlq(int value) {
  int buffer = value & 0x7F;
  final output = <int>[];

  while ((value >>= 7) > 0) {
    buffer <<= 8;
    buffer |= ((value & 0x7F) | 0x80);
  }

  while (true) {
    output.add(buffer & 0xFF);
    if ((buffer & 0x80) != 0) {
      buffer >>= 8;
    } else {
      break;
    }
  }

  return output;
}

int _powerOfTwoIndex(int denominator) {
  int value = denominator;
  int exponent = 0;
  while (value > 1 && value.isEven) {
    value ~/= 2;
    exponent++;
  }
  if (value != 1) {
    return 2;
  }
  return exponent.clamp(0, 7);
}
