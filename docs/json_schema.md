# Flutter Notemus JSON Format Reference

This document describes the JSON format accepted by `JsonParser` and `SimpleJsonParser`.

## Top-Level Staff Object

```json
{
  "name": "My Score",
  "measures": []
}
```

## Measure Object

```json
{
  "elements": []
}
```

## Element Types

### Note

```json
{
  "type": "note",
  "pitch": { "step": "C", "octave": 4, "alter": 0 },
  "duration": { "type": "quarter", "dots": 0 },
  "voice": 1,
  "beam": "begin|continue|end",
  "tie": "start|stop",
  "slur": "start|stop",
  "tremoloStrokes": 0,
  "articulations": ["staccato", "accent", "tenuto", "marcato"],
  "ornaments": [{ "type": "trill" }]
}
```

### Rest

```json
{
  "type": "rest",
  "duration": { "type": "quarter", "dots": 0 }
}
```

### Chord

```json
{
  "type": "chord",
  "notes": [
    { "pitch": { "step": "C", "octave": 4 }, "duration": { "type": "quarter" } },
    { "pitch": { "step": "E", "octave": 4 }, "duration": { "type": "quarter" } }
  ]
}
```

### Clef

```json
{
  "type": "clef",
  "clefType": "treble|bass|alto|tenor|percussion|tab"
}
```

### Key Signature

```json
{
  "type": "keySignature",
  "count": 2,
  "previousCount": 0
}
```

`count` > 0 = sharps, `count` < 0 = flats, `count` = 0 = C major / A minor.
`previousCount` (optional): when set, natural signs are shown before the new key.

### Time Signature

```json
{
  "type": "timeSignature",
  "numerator": 4,
  "denominator": 4
}
```

### Barline

```json
{
  "type": "barline",
  "barlineType": "single|double|final|repeatForward|repeatBackward|repeatBoth"
}
```

### Dynamic

```json
{
  "type": "dynamic",
  "dynamicType": "ppp|pp|p|mp|mf|f|ff|fff|sfz|fp|crescendo|diminuendo",
  "isHairpin": false,
  "length": 80.0,
  "customText": "cresc. molto"
}
```

### Ottava Mark (8va, 8vb)

```json
{
  "type": "octaveMark",
  "octaveType": "va8|vb8|va15|vb15",
  "length": 120.0,
  "showBracket": true
}
```

### Volta Bracket (1st/2nd Ending)

```json
{
  "type": "voltaBracket",
  "number": 1,
  "length": 150.0,
  "hasOpenEnd": false,
  "label": "1."
}
```

### Tuplet

```json
{
  "type": "tuplet",
  "ratio": 3,
  "in": 2,
  "notes": []
}
```

## Duration Types

| JSON value | Note value |
|-----------|------------|
| `"whole"` | Whole note |
| `"half"` | Half note |
| `"quarter"` | Quarter note |
| `"eighth"` | Eighth note |
| `"sixteenth"` | Sixteenth note |
| `"thirtySecond"` | 32nd note |
| `"sixtyFourth"` | 64th note |
| `"oneHundredTwentyEighth"` | 128th note |

## Pitch Steps and Accidentals

Steps: `"C"`, `"D"`, `"E"`, `"F"`, `"G"`, `"A"`, `"B"`

Alter (semitones): `-2` = double flat, `-1` = flat, `0` = natural, `1` = sharp, `2` = double sharp

## Articulation Types

`staccato`, `staccatissimo`, `accent`, `strongAccent`, `tenuto`, `marcato`, `portato`,
`fermata`, `fermataBelow`, `snappizzicato`, `leftHandPizzicato`, `bowUpBowing`, `bowDownBowing`,
`openString`, `harmonic`, `upBow`, `downBow`

## Ornament Types

`trill`, `trillSharp`, `trillFlat`, `trillNatural`, `mordent`, `invertedMordent`,
`turn`, `turnInverted`, `acciaccatura`, `appoggiaturaUp`, `appoggiaturaDown`,
`fermata`, `fermataBelow`, `arpeggio`, `glissando`
