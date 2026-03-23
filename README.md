# Flutter Notemus

[![pub.dev](https://img.shields.io/pub/v/flutter_notemus.svg)](https://pub.dev/packages/flutter_notemus)
[![Flutter](https://img.shields.io/badge/Flutter-3.0+-blue.svg)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/Dart-3.8.1+-blue.svg)](https://dart.dev/)
[![SMuFL](https://img.shields.io/badge/SMuFL-1.40-green.svg)](https://w3c.github.io/smufl/latest/)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

**Renderização profissional de partituras musicais para Flutter, com suporte completo ao padrão SMuFL e à fonte Bravura.**

Flutter Notemus é um pacote Flutter para exibir notação musical de alta qualidade em aplicativos. Construído sobre a especificação SMuFL (*Standard Music Font Layout*) e a fonte Bravura, ele oferece gravura musical precisa e profissional — diretamente no Canvas do Flutter, sem dependências de bibliotecas nativas externas.

---

## Índice

- [Demonstração visual](#demonstração-visual)
- [Funcionalidades](#funcionalidades)
- [Status no pub.dev e evolução para 2.0.0](#status-no-pubdev-e-evolução-para-200)
- [Novidades pós-first commit](#novidades-pós-first-commit)
- [Instalação](#instalação)
- [Início rápido](#início-rápido)
- [Referência da API](#referência-da-api)
  - [MusicScore — widget principal](#musicscore--widget-principal)
  - [Notas e alturas](#notas-e-alturas)
  - [Durações](#durações)
  - [Pausas](#pausas)
  - [Compassos e Pautas](#compassos-e-pautas)
  - [Claves](#claves)
  - [Armaduras de clave](#armaduras-de-clave)
  - [Fórmulas de compasso](#fórmulas-de-compasso)
  - [Barras de compasso](#barras-de-compasso)
  - [Acordes](#acordes)
  - [Ligaduras de valor e de expressão](#ligaduras-de-valor-e-de-expressão)
  - [Articulações](#articulações)
  - [Dinâmicas](#dinâmicas)
  - [Ornamentos](#ornamentos)
  - [Marcas de tempo](#marcas-de-tempo)
  - [Notas de graça](#notas-de-graça)
  - [Quiálteras (Tuplets)](#quiálteras-tuplets)
  - [Barras de ligação (Beams)](#barras-de-ligação-beams)
  - [Marcações de oitava](#marcações-de-oitava)
  - [Colchetes de volta](#colchetes-de-volta)
  - [Polifonia — múltiplas vozes](#polifonia--múltiplas-vozes)
  - [Repetições](#repetições)
  - [Técnicas instrumentais](#técnicas-instrumentais)
  - [Respiração e césura](#respiração-e-césura)
  - [Importação via JSON, MusicXML e MEI](#importação-via-json-musicxml-e-mei)
  - [MIDI: mapeamento, repetições, metrônomo e export .mid](#midi-mapeamento-repetições-metrônomo-e-export-mid)
  - [Temas e personalização visual](#temas-e-personalização-visual)
- [Formato JSON de referência](#formato-json-de-referência)
- [Arquitetura](#arquitetura)
- [Licença](#licença)

---

## Demonstração visual

<p align="center">
  <img src="assets/readme/Captura%20de%20tela%202025-11-06%20141401.png" alt="Ode à Alegria — partitura completa" width="800">
  <br>
  <em>Ode à Alegria com gravura profissional, dinâmicas e espaçamento proporcional</em>
</p>

<p align="center">
  <img src="assets/readme/Captura%20de%20tela%202025-11-06%20141533.png" alt="Elementos musicais detalhados" width="800">
  <br>
  <em>Notas pontuadas, marcas de respiração e glifos SMuFL com posicionamento preciso</em>
</p>

---

## Funcionalidades

### Notação fundamental
- Notas (semibreve a semifusa, com pontos de aumento)
- Pausas para todas as durações
- Acidentes: sustenido, bemol, natural, dobrado sustenido, dobrado bemol
- Linhas suplementares (acima e abaixo da pauta)

### Claves
- Sol (Treble) e suas variantes: 8va, 8vb, 15ma, 15mb
- Fá (Bass) e suas variantes: 8va, 8vb, 15ma, 15mb, 3ª linha
- Dó: Alto (3ª linha) e Tenor (4ª linha)
- Percussão (duas variantes)
- Tablatura: 6 cordas (guitarra) e 4 cordas (baixo)

### Ritmo e layout
- Beaming automático e manual por compasso, com suporte a anacrusis
- Quiálteras (tercinas, quintinas, sétimas etc.) com bracket e número SMuFL
- Espaçamento rítmico proporcional (modelo √2, conforme *Behind Bars*)
- Justificação horizontal por sistema
- Quebra automática de sistemas conforme a largura disponível
- Linhas suplementares calculadas automaticamente para cada nota

### Dinâmicas
pppp · ppp · pp · p · mp · mf · f · ff · fff · ffff e variantes extremas
sf · sfz · sfp · sfpp · rfz · fp · crescendo · diminuendo · niente

### Articulações
Staccato · Acento · Tenuto · Marcato · Portato · Staccatissimo · Fermatas · Snap pizzicato

### Ornamentos
Trilo (com acidente) · Mordente · Mordente invertido · Grupeto · Acciaccatura · Appoggiatura · Glissando · Vibrato · Tremolo

### Elementos de estrutura
- Armaduras de clave: dó maior (sem acidentes) a 7 sustenidos e 7 bemóis
- Fórmulas de compasso: numerador e denominador livres
- Barras de compasso: simples, dupla, final, repetição (início/fim/ambos), tracejada, grossa
- Colchetes de volta (1ª/2ª vez) com final aberto ou fechado, label personalizado
- Marcações de oitava: 8va, 8vb, 15ma, 15mb, 22da, 22db

### Polifonia e multi-pauta
- Múltiplas vozes numa mesma pauta (`MultiVoiceMeasure`)
- Voz 1 com hastes para cima, Voz 2 com hastes para baixo
- Grand staff: duas pautas independentes empilhadas (piano, coral SATB)

### Ligaduras
- Ligaduras de valor (tie): início, continuação e fim
- Ligaduras de expressão (slur): início, continuação e fim
- Detecção automática de colisão com a pauta (*skyline algorithm*)

### Marcas de tempo e texto
- Marcas de metrônomo (BPM + glifo de figura)
- Texto de andamento (Allegro, Adagio etc.)
- Texto musical livre

### Notas de graça
- Acciaccatura (com barra diagonal)
- Appoggiatura

### Técnicas instrumentais
Pizzicato · Snap pizzicato · Col legno · Sul tasto · Sul ponticello · Martellato · Harmônicos naturais e artificiais · Circular breathing · Flutter tongue · Multifônicos

### Importação de dados
Suporte a JSON, MusicXML (`score-partwise` e `score-timewise`) e MEI, com normalização para a mesma árvore `Staff -> Measure -> MusicalElement` usada pelo renderer.

### MIDI (novo)
- Mapeamento completo de `Staff`/`Score` para eventos MIDI (nota, acorde, pausa, tempo, compasso e marcador)
- Expansão de repetições (`repeatForward`, `repeatBackward`, `repeatBoth`) e finais (`VoltaBracket`) no playback order
- Suporte a tuplets, polifonia (`MultiVoiceMeasure`) e tie-merge durante geração de eventos
- Geração de trilha de metrônomo (canal de percussão) sincronizada com o timeline expandido
- Exportação de arquivo Standard MIDI File (`.mid`) sem dependências externas via `MidiFileWriter`
- Implementação nativa first-party via `MethodChannelMidiNativeAudioBackend` + `MidiNativeSequenceBridge` para envio de tempo/compasso/notas/ties/metrônomo ao backend de áudio
- Configuração de plugin para Android, iOS, macOS, Linux e Windows com canal unificado `flutter_notemus/native_audio`

### Personalização visual
Tema completo com controle individual de cor para cada elemento: pauta, cabeça de nota, haste, clave, barra de compasso, articulação, dinâmica, ligadura, beam, acidente, marcação de oitava, texto e muito mais.

---

## Status no pub.dev e evolução para 2.0.0

A versão publicada no pub.dev hoje é a **`0.1.0`**:
- [flutter_notemus 0.1.0](https://pub.dev/packages/flutter_notemus)

Neste repositório, a versão alvo já está em **`2.0.0`**, com trabalho **além do pacote publicado** (novas features, correções e aperfeiçoamentos).

### O que você ganha nesta branch em relação ao `0.1.0`
- Camada MIDI nativa da biblioteca (`package:flutter_notemus/midi.dart`)
- Mapeamento de notação para timeline MIDI com repetições e volta
- Trilha de metrônomo derivada da partitura
- Writer `.mid` embutido (`MidiFileWriter`)
- Integração nativa pronta para engine própria (MethodChannel + sequence bridge), mantendo o pipeline MIDI first-party da biblioteca
- Configuração nativa em todas as plataformas (Android ativo; iOS/macOS/Linux/Windows com stubs de integração)
- Melhorias contínuas de parser/layout/renderização acumuladas após a publicação

---

## Novidades pós-first commit

Considerando o **first commit** como baseline histórica, a biblioteca evoluiu com adições + correções + aperfeiçoamentos em várias frentes:

- Parser unificado para JSON, MusicXML e MEI
- Polifonia e multi-pauta com `Voice`, `MultiVoiceMeasure`, `Score` e `StaffGroup`
- Suporte avançado de elementos (voltas, respirações, técnicas, marcas de oitava e estrutura expandida)
- Melhorias de layout (beaming, spacing, validação de compasso, colisões)
- Refinamentos de renderização (barlines, rests, chords, tuplets, símbolos e texto)
- Cobertura de testes ampliada em core/layout/rendering/parsers
- Atualizações de documentação, licença e qualidade geral da API

---

## Instalação

Adicione ao `pubspec.yaml` do seu projeto:

```yaml
dependencies:
  flutter_notemus: ^2.0.0
```

Execute:

```bash
flutter pub get
```

### Configuração obrigatória

A fonte Bravura e os metadados SMuFL precisam ser carregados antes de renderizar qualquer partitura. Faça isso no `main()`:

```dart
import 'package:flutter/services.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Carrega a fonte Bravura
  final fontLoader = FontLoader('Bravura');
  fontLoader.addFont(
    rootBundle.load('packages/flutter_notemus/assets/smufl/Bravura.otf'),
  );
  await fontLoader.load();

  // Carrega os metadados SMuFL (posições das âncoras, bounding boxes etc.)
  await SmuflMetadata().load();

  runApp(const MyApp());
}
```

---

## Início rápido

```dart
import 'package:flutter/material.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

class MinhaPartitura extends StatelessWidget {
  const MinhaPartitura({super.key});

  @override
  Widget build(BuildContext context) {
    final staff = Staff();
    final measure = Measure();

    measure.add(Clef(clefType: ClefType.treble));
    measure.add(TimeSignature(numerator: 4, denominator: 4));

    measure.add(Note(
      pitch: const Pitch(step: 'C', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));
    measure.add(Note(
      pitch: const Pitch(step: 'E', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));
    measure.add(Note(
      pitch: const Pitch(step: 'G', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));
    measure.add(Note(
      pitch: const Pitch(step: 'C', octave: 6),
      duration: const Duration(DurationType.quarter),
    ));

    staff.add(measure);

    return Scaffold(
      body: SizedBox(
        height: 160,
        child: MusicScore(staff: staff),
      ),
    );
  }
}
```

---

## Referência da API

### MusicScore — widget principal

```dart
MusicScore(
  staff: staff,           // Staff — obrigatório
  staffSpace: 12.0,       // Tamanho de 1 espaço de pauta em pixels lógicos
  theme: MusicScoreTheme(), // Tema visual (opcional)
)
```

O widget gerencia seu próprio `ScrollController` horizontal e vertical, e carrega os metadados SMuFL automaticamente.

---

### Notas e alturas

```dart
Note(
  pitch: const Pitch(step: 'G', octave: 4),  // step: A B C D E F G
  duration: const Duration(DurationType.quarter),
  articulations: [ArticulationType.staccato],
  tie: TieType.start,     // start | end | inner
  slur: SlurType.start,   // start | end | inner
  beam: BeamType.start,   // start | inner | end
  ornaments: [Ornament(type: OrnamentType.trill)],
  dynamicElement: Dynamic(type: DynamicType.forte),
)
```

**Acidentes** — definidos diretamente na altura:

```dart
Pitch(step: 'F', octave: 5, alter: 1.0)   // Fá sustenido
Pitch(step: 'B', octave: 4, alter: -1.0)  // Si bemol
Pitch(step: 'E', octave: 5, alter: 0.0)   // Mi natural (anula acidente anterior)
Pitch(step: 'C', octave: 5, alter: 2.0)   // Dó dobrado sustenido
Pitch(step: 'D', octave: 4, alter: -2.0)  // Ré dobrado bemol
```

**Pontos de aumento:**

```dart
Duration(DurationType.quarter, dots: 1)  // Semínima pontuada
Duration(DurationType.half, dots: 2)     // Mínima com dois pontos
```

---

### Durações

| Constante | Figura | Valor |
|-----------|--------|-------|
| `DurationType.whole` | Semibreve | 1 |
| `DurationType.half` | Mínima | 1/2 |
| `DurationType.quarter` | Semínima | 1/4 |
| `DurationType.eighth` | Colcheia | 1/8 |
| `DurationType.sixteenth` | Semicolcheia | 1/16 |
| `DurationType.thirtySecond` | Fusa | 1/32 |
| `DurationType.sixtyFourth` | Semifusa | 1/64 |
| `DurationType.oneHundredTwentyEighth` | — | 1/128 |

---

### Pausas

```dart
Rest(duration: const Duration(DurationType.half))
Rest(duration: const Duration(DurationType.whole))
Rest(duration: const Duration(DurationType.eighth, dots: 1))
```

Pausas são posicionadas automaticamente conforme a altura padrão SMuFL (pausa de semibreve na 4ª linha, mínima na 3ª linha).

---

### Compassos e Pautas

```dart
final staff = Staff();
final measure = Measure();

// Adicionar elementos ao compasso
measure.add(Clef(clefType: ClefType.treble));
measure.add(TimeSignature(numerator: 3, denominator: 4));
measure.add(Note(...));

staff.add(measure);

// Múltiplos compassos
final measure2 = Measure();
measure2.add(Note(...));
staff.add(measure2);
```

---

### Claves

```dart
Clef(clefType: ClefType.treble)      // Sol (padrão)
Clef(clefType: ClefType.treble8va)   // Sol 8ª acima
Clef(clefType: ClefType.treble8vb)   // Sol 8ª abaixo
Clef(clefType: ClefType.treble15ma)  // Sol 15ª acima
Clef(clefType: ClefType.treble15mb)  // Sol 15ª abaixo

Clef(clefType: ClefType.bass)           // Fá
Clef(clefType: ClefType.bass8va)        // Fá 8ª acima
Clef(clefType: ClefType.bass8vb)        // Fá 8ª abaixo
Clef(clefType: ClefType.bass15ma)       // Fá 15ª acima
Clef(clefType: ClefType.bass15mb)       // Fá 15ª abaixo
Clef(clefType: ClefType.bassThirdLine)  // Fá na 3ª linha (barítono)

Clef(clefType: ClefType.alto)        // Dó na 3ª linha (viola)
Clef(clefType: ClefType.tenor)       // Dó na 4ª linha (tenor, trombone)

Clef(clefType: ClefType.percussion)  // Percussão
Clef(clefType: ClefType.percussion2) // Percussão variante

Clef(clefType: ClefType.tab6)  // Tablatura 6 cordas
Clef(clefType: ClefType.tab4)  // Tablatura 4 cordas
```

---

### Armaduras de clave

```dart
KeySignature(0)   // Dó maior / Lá menor (sem acidentes)
KeySignature(1)   // Sol maior (1 sustenido)
KeySignature(2)   // Ré maior (2 sustenidos)
KeySignature(3)   // Lá maior (3 sustenidos)
KeySignature(4)   // Mi maior (4 sustenidos)
KeySignature(5)   // Si maior (5 sustenidos)
KeySignature(6)   // Fá# maior (6 sustenidos)
KeySignature(7)   // Dó# maior (7 sustenidos)

KeySignature(-1)  // Fá maior (1 bemol)
KeySignature(-2)  // Si♭ maior (2 bemóis)
KeySignature(-3)  // Mi♭ maior (3 bemóis)
KeySignature(-4)  // Lá♭ maior (4 bemóis)
KeySignature(-5)  // Ré♭ maior (5 bemóis)
KeySignature(-6)  // Sol♭ maior (6 bemóis)
KeySignature(-7)  // Dó♭ maior (7 bemóis)
```

Mudanças de armadura no meio da peça geram automaticamente os símbolos de cancelamento (naturais).

---

### Fórmulas de compasso

```dart
TimeSignature(numerator: 4, denominator: 4)  // 4/4
TimeSignature(numerator: 3, denominator: 4)  // 3/4
TimeSignature(numerator: 6, denominator: 8)  // 6/8
TimeSignature(numerator: 5, denominator: 4)  // 5/4
TimeSignature(numerator: 2, denominator: 2)  // 2/2 (alla breve)
```

---

### Barras de compasso

```dart
Barline(type: BarlineType.single)         // Simples (padrão)
Barline(type: BarlineType.double)         // Dupla
Barline(type: BarlineType.final_)         // Final (fina + grossa)
Barline(type: BarlineType.repeatForward)  // Início de repetição
Barline(type: BarlineType.repeatBackward) // Fim de repetição
Barline(type: BarlineType.repeatBoth)     // Dupla repetição
Barline(type: BarlineType.dashed)         // Tracejada
Barline(type: BarlineType.heavy)          // Grossa
Barline(type: BarlineType.lightLight)     // Dupla leve
Barline(type: BarlineType.lightHeavy)     // Leve + grossa
Barline(type: BarlineType.heavyLight)     // Grossa + leve
Barline(type: BarlineType.heavyHeavy)     // Dupla grossa
```

---

### Acordes

```dart
Chord(
  notes: [
    Note(pitch: const Pitch(step: 'C', octave: 4), duration: const Duration(DurationType.half)),
    Note(pitch: const Pitch(step: 'E', octave: 4), duration: const Duration(DurationType.half)),
    Note(pitch: const Pitch(step: 'G', octave: 4), duration: const Duration(DurationType.half)),
  ],
  duration: const Duration(DurationType.half),
)
```

---

### Ligaduras de valor e de expressão

```dart
// Ligadura de valor (tie) — une duas notas da mesma altura
Note(pitch: Pitch(step: 'C', octave: 5), duration: Duration(DurationType.half), tie: TieType.start),
Note(pitch: Pitch(step: 'C', octave: 5), duration: Duration(DurationType.quarter), tie: TieType.end),

// Ligadura de expressão (slur) — une um grupo de notas
Note(pitch: Pitch(step: 'E', octave: 5), duration: Duration(DurationType.quarter), slur: SlurType.start),
Note(pitch: Pitch(step: 'D', octave: 5), duration: Duration(DurationType.quarter), slur: SlurType.inner),
Note(pitch: Pitch(step: 'C', octave: 5), duration: Duration(DurationType.half),    slur: SlurType.end),
```

---

### Articulações

Articulações são atribuídas diretamente à nota:

```dart
Note(
  pitch: Pitch(step: 'G', octave: 4),
  duration: Duration(DurationType.quarter),
  articulations: [
    ArticulationType.staccato,   // Ponto (staccato)
    ArticulationType.accent,     // Acento (>)
    ArticulationType.tenuto,     // Traço (tenuto)
    ArticulationType.marcato,    // Acento + tenuto (^)
    ArticulationType.portato,    // Staccato + tenuto
    ArticulationType.staccatissimo, // Staccatissimo
  ],
)
```

Fermatas são adicionadas como `Ornament`:

```dart
measure.add(Ornament(type: OrnamentType.fermata));
```

---

### Dinâmicas

```dart
// Atribuída à nota
Note(
  pitch: Pitch(step: 'C', octave: 5),
  duration: Duration(DurationType.quarter),
  dynamicElement: Dynamic(type: DynamicType.forte),
)

// Ou adicionada diretamente ao compasso
measure.add(Dynamic(type: DynamicType.pianissimo));
measure.add(Dynamic(type: DynamicType.crescendo));   // Hairpin crescendo
measure.add(Dynamic(type: DynamicType.diminuendo));  // Hairpin decrescendo
```

| Tipo | Símbolo |
|------|---------|
| `pppp` · `ppp` · `pp` · `p` | pppp · ppp · pp · p |
| `mp` · `mf` | mp · mf |
| `f` · `ff` · `fff` · `ffff` | f · ff · fff · ffff |
| `sforzando` · `sforzandoPiano` | sf / sfz · sfp |
| `rinforzando` · `fortePiano` | rf / rfz · fp |
| `niente` | n |
| `crescendo` · `diminuendo` | hairpin < · > |

---

### Ornamentos

```dart
measure.add(Ornament(type: OrnamentType.trill));           // Trilo (tr~)
measure.add(Ornament(type: OrnamentType.trillSharp));      // Trilo com sustenido
measure.add(Ornament(type: OrnamentType.mordent));         // Mordente inferior
measure.add(Ornament(type: OrnamentType.invertedMordent)); // Mordente superior
measure.add(Ornament(type: OrnamentType.turn));            // Grupeto
measure.add(Ornament(type: OrnamentType.turnInverted));    // Grupeto invertido
measure.add(Ornament(type: OrnamentType.glissando));       // Glissando
```

---

### Marcas de tempo

```dart
// Indicação metronômica
measure.add(TempoMark(
  bpm: 120,
  beatUnit: DurationType.quarter,
  text: 'Allegro',
));

// Apenas texto
measure.add(TempoMark(text: 'Andante moderato'));

// Apenas BPM
measure.add(TempoMark(bpm: 96, beatUnit: DurationType.quarter));
```

---

### Notas de graça

```dart
// Acciaccatura (com barra diagonal — "mordida")
Note(
  pitch: Pitch(step: 'D', octave: 5),
  duration: Duration(DurationType.eighth),
  isGraceNote: true,
  isAcciaccatura: true,
)

// Appoggiatura (sem barra)
Note(
  pitch: Pitch(step: 'D', octave: 5),
  duration: Duration(DurationType.eighth),
  isGraceNote: true,
)
```

---

### Quiálteras (Tuplets)

```dart
// Tercina de semínimas
final tuplet = Tuplet(
  actualNotes: 3,      // 3 notas
  normalNotes: 2,      // no lugar de 2
  elements: [
    Note(pitch: Pitch(step: 'C', octave: 5), duration: Duration(DurationType.quarter)),
    Note(pitch: Pitch(step: 'D', octave: 5), duration: Duration(DurationType.quarter)),
    Note(pitch: Pitch(step: 'E', octave: 5), duration: Duration(DurationType.quarter)),
  ],
);
measure.add(tuplet);

// Tercina de colcheias (beams automáticos)
Tuplet(
  actualNotes: 3,
  normalNotes: 2,
  elements: [
    Note(pitch: Pitch(step: 'E', octave: 5), duration: Duration(DurationType.eighth)),
    Note(pitch: Pitch(step: 'D', octave: 5), duration: Duration(DurationType.eighth)),
    Note(pitch: Pitch(step: 'C', octave: 5), duration: Duration(DurationType.eighth)),
  ],
)
```

Colcheias, semicolcheias e fusas dentro de quiálteras recebem beams automáticos. O bracket e o número são posicionados conforme as âncoras SMuFL.

---

### Barras de ligação (Beams)

**Automático** (por compasso, conforme fórmula de compasso):

```dart
final measure = Measure(); // autoBeaming: true por padrão
measure.add(Note(pitch: Pitch(step: 'E', octave: 5), duration: Duration(DurationType.eighth)));
measure.add(Note(pitch: Pitch(step: 'D', octave: 5), duration: Duration(DurationType.eighth)));
// As duas notas serão automaticamente unidas por uma barra
```

**Manual** (por nota):

```dart
Note(pitch: Pitch(step: 'E', octave: 5), duration: Duration(DurationType.sixteenth), beam: BeamType.start),
Note(pitch: Pitch(step: 'F', octave: 5), duration: Duration(DurationType.sixteenth), beam: BeamType.inner),
Note(pitch: Pitch(step: 'G', octave: 5), duration: Duration(DurationType.sixteenth), beam: BeamType.inner),
Note(pitch: Pitch(step: 'A', octave: 5), duration: Duration(DurationType.sixteenth), beam: BeamType.end),
```

---

### Marcações de oitava

```dart
// 8va — uma oitava acima
measure.add(OctaveMark(
  type: OctaveType.va8,
  startMeasure: 0,
  endMeasure: 0,
  length: 160.0,      // Comprimento da linha em pixels
  showBracket: true,  // Mostrar colchete vertical no fim
));

// 8vb — uma oitava abaixo (aparece sob a pauta)
measure.add(OctaveMark(type: OctaveType.vb8, startMeasure: 0, endMeasure: 0, length: 160.0, showBracket: true));

// 15ma — duas oitavas acima
measure.add(OctaveMark(type: OctaveType.va15, startMeasure: 0, endMeasure: 0, length: 160.0, showBracket: true));

// 15mb — duas oitavas abaixo
measure.add(OctaveMark(type: OctaveType.vb15, startMeasure: 0, endMeasure: 0, length: 160.0, showBracket: true));
```

| Tipo | Descrição |
|------|-----------|
| `OctaveType.va8` | 8va — toca uma oitava acima do escrito |
| `OctaveType.vb8` | 8vb — toca uma oitava abaixo do escrito |
| `OctaveType.va15` | 15ma — toca duas oitavas acima |
| `OctaveType.vb15` | 15mb — toca duas oitavas abaixo |
| `OctaveType.va22` | 22da — toca três oitavas acima |
| `OctaveType.vb22` | 22db — toca três oitavas abaixo |

---

### Colchetes de volta

Indicam finais alternativos para seções repetidas (1ª e 2ª vez):

```dart
// Corpo da seção com repetição
final measure1 = Measure();
measure1.add(Barline(type: BarlineType.repeatForward));
measure1.add(Note(...));

// 1ª volta — final fechado
final measure2 = Measure();
measure2.add(VoltaBracket(number: 1, length: 120.0, hasOpenEnd: false));
measure2.add(Note(...));
measure2.add(Barline(type: BarlineType.repeatBackward));

// 2ª volta — final aberto (sem linha vertical no final)
final measure3 = Measure();
measure3.add(VoltaBracket(number: 2, length: 120.0, hasOpenEnd: true));
measure3.add(Note(...));

// Label personalizado (ex: "1.-3." e "4.")
measure4.add(VoltaBracket(number: 1, length: 130.0, hasOpenEnd: false, label: '1.-3.'));
measure5.add(VoltaBracket(number: 4, length: 130.0, hasOpenEnd: false, label: '4.'));
```

---

### Polifonia — múltiplas vozes

```dart
final staff = Staff();
final measure = MultiVoiceMeasure();

// Voz 1: hastes para cima
final voice1 = Voice.voice1();
voice1.add(Clef(clefType: ClefType.treble));
voice1.add(TimeSignature(numerator: 4, denominator: 4));
voice1.add(Note(pitch: Pitch(step: 'E', octave: 5), duration: Duration(DurationType.quarter)));
voice1.add(Note(pitch: Pitch(step: 'D', octave: 5), duration: Duration(DurationType.quarter)));
voice1.add(Note(pitch: Pitch(step: 'C', octave: 5), duration: Duration(DurationType.half)));

// Voz 2: hastes para baixo
final voice2 = Voice.voice2();
voice2.add(Note(pitch: Pitch(step: 'C', octave: 4), duration: Duration(DurationType.half)));
voice2.add(Note(pitch: Pitch(step: 'G', octave: 3), duration: Duration(DurationType.half)));

measure.addVoice(voice1);
measure.addVoice(voice2);
staff.add(measure);
```

---

### Repetições

```dart
measure.add(Barline(type: BarlineType.repeatForward));   // :||
measure.add(Barline(type: BarlineType.repeatBackward));  // ||:
measure.add(Barline(type: BarlineType.repeatBoth));      // ||:||
```

---

### Técnicas instrumentais

```dart
// Adicionadas à nota via campo techniques
Note(
  pitch: Pitch(step: 'G', octave: 3),
  duration: Duration(DurationType.quarter),
  techniques: [NoteTechnique.naturalHarmonic],
)

// Elemento autônomo de técnica (posicionado no compasso)
measure.add(PlayingTechnique(type: TechniqueType.pizzicato));
measure.add(PlayingTechnique(type: TechniqueType.colLegno));
measure.add(PlayingTechnique(type: TechniqueType.sulTasto));
measure.add(PlayingTechnique(type: TechniqueType.sulPonticello));
```

---

### Respiração e césura

```dart
measure.add(Breath());                             // Vírgula de respiração
measure.add(Breath(type: BreathType.caesura));     // Césura (///)
measure.add(Breath(type: BreathType.shortBreath)); // Respiração curta
```

---

### Importação via JSON, MusicXML e MEI

```dart
import 'package:flutter_notemus/flutter_notemus.dart';

final jsonString = '''
{
  "measures": [
    {
      "clef": "treble",
      "timeSignature": { "numerator": 4, "denominator": 4 },
      "keySignature": 0,
      "elements": [
        { "type": "note", "step": "C", "octave": 5, "duration": "quarter" },
        { "type": "note", "step": "E", "octave": 5, "duration": "quarter" },
        { "type": "note", "step": "G", "octave": 5, "duration": "quarter" },
        { "type": "rest", "duration": "quarter" }
      ]
    }
  ]
}
''';

final musicXmlString = '''
<score-partwise version="4.0">
  <part-list>
    <score-part id="P1"><part-name>Music</part-name></score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <attributes>
        <clef><sign>G</sign><line>2</line></clef>
        <time><beats>4</beats><beat-type>4</beat-type></time>
      </attributes>
      <note>
        <pitch><step>C</step><octave>5</octave></pitch>
        <duration>1</duration>
        <voice>1</voice>
        <type>quarter</type>
      </note>
    </measure>
  </part>
</score-partwise>
''';

final meiString = '''
<mei xmlns="http://www.music-encoding.org/ns/mei">
  <music>
    <body>
      <mdiv>
        <score>
          <section>
            <measure n="1">
              <staff n="1">
                <layer n="1">
                  <note pname="c" oct="5" dur="4"/>
                </layer>
              </staff>
            </measure>
          </section>
        </score>
      </mdiv>
    </body>
  </music>
</mei>
''';

final jsonStaff = JsonMusicParser.parseStaff(jsonString);
final musicXmlStaff = MusicXMLParser.parseMusicXML(musicXmlString);
final meiStaff = MEIParser.parseMEI(meiString);

final autoDetectedStaff = NotationParser.parseStaff(musicXmlString);

final scoreFromJson = MusicScore.fromJson(json: jsonString);
final scoreFromMusicXml = MusicScore.fromMusicXml(musicXml: musicXmlString);
final scoreFromMei = MusicScore.fromMei(mei: meiString);
final scoreFromAnySource = MusicScore.fromSource(source: meiString);
```

Convenções suportadas pelos importadores:

- JSON: cobertura completa da API pública de elementos renderizáveis do pacote.
- MusicXML: `score-partwise` e `score-timewise`, seleção por `partIndex`, importando claves, armaduras, fórmulas de compasso, notas, acordes, pausas, tuplets, dinâmicas, textos, respiração, césura, voltas, repetições e marcas de oitava.
- MEI: seleção por `staffIndex`, importando `layer`, `repeatMark`, `barLine`, `measure@right/@left`, claves, armaduras, compassos, notas, acordes, pausas, tuplets, dinâmicas, textos, respiração, césura, voltas e marcas de oitava.

Observações práticas:

- Use `NotationParser.parseStaff()` ou `MusicScore.fromSource()` quando o banco puder armazenar mais de um formato.
- Use `partIndex` para escolher uma parte específica em MusicXML multipart.
- Use `staffIndex` para escolher uma pauta específica em MEI com múltiplos `<staff>`.
- Os três importadores convertem os dados para a mesma estrutura interna, então o pipeline de layout e renderização é o mesmo após o parse.

---

### MIDI: mapeamento, repetições, metrônomo e export .mid

O módulo MIDI é exposto separadamente para manter a API de renderização limpa:

```dart
import 'package:flutter_notemus/midi.dart';
```

#### 1) Gerar sequência MIDI a partir de uma pauta (`Staff`)

```dart
final sequence = MidiMapper.fromStaff(
  staff,
  options: const MidiGenerationOptions(
    ticksPerQuarter: 960,
    defaultBpm: 120,
    includeMetronome: true,
  ),
);
```

Recursos cobertos pelo mapper:
- Notas, acordes, pausas, tuplets e polifonia
- `TempoMark` e `TimeSignature`
- Repetições com barline (`repeatForward`, `repeatBackward`, `repeatBoth`)
- Finais de repetição com `VoltaBracket`
- Tie merge para notas ligadas

#### 2) Gerar sequência MIDI a partir de uma partitura completa (`Score`)

```dart
final sequence = MidiMapper.fromScore(
  score,
  options: MidiGenerationOptions(
    instrumentsByStaff: {
      0: const MidiInstrumentAssignment(channel: 0, program: 0),   // Piano RH
      1: const MidiInstrumentAssignment(channel: 1, program: 32),  // Piano LH/Bass
    },
    includeMetronome: true,
  ),
);
```

#### 3) Exportar `.mid` (Standard MIDI File)

```dart
final bytes = MidiFileWriter.write(sequence);
// bytes prontos para salvar/enviar como arquivo .mid
```

#### 4) Integração nativa já implementada na biblioteca (v2.0.0)

A biblioteca já inclui implementação first-party para ponte com engine nativa, sem depender de pacote externo para o pipeline de notação -> MIDI:

- `MidiNativeAudioBackend`: contrato para backends nativos
- `MethodChannelMidiNativeAudioBackend`: backend pronto para platform channel (`flutter_notemus/native_audio`)
- `MidiNativeSequenceBridge`: upload da `MidiSequence` para o backend (tempo, compasso, notas, tie-processing e metrônomo)
- `extractScheduledNotes`: conversão de pares note-on/note-off em notas agendadas com duração em ticks
- `setTicksPerQuarter`: sincronização explícita de resolução PPQ entre mapper e sequencer nativo

```dart
final backend = MethodChannelMidiNativeAudioBackend();
final bridge = MidiNativeSequenceBridge(backend);

await backend.initialize(
  primarySoundFontPath: '/data/user/0/app/files/gm.sf2',
  metronomeSoundFontPath: '/data/user/0/app/files/click.sf2',
  sampleRate: 48000,
);

await bridge.uploadAndStart(
  sequence,
  includeMetronome: true,
  countInBeats: 1,
);
```

Status atual por plataforma:
- Android: engine nativo ativo (Kotlin + C++) com clock próprio, sequencer PPQ, metronome e síntese PCM first-party sem dependências externas.
- iOS/macOS/Linux/Windows: plugin registrado com o mesmo canal (`flutter_notemus/native_audio`) e handlers stubs/no-op para manter API estável até a implementação completa do engine nativo em cada alvo.

#### 5) Viabilidade C/C++ para áudio, clock mestre e metrônomo

É viável implementar (ou conectar) um engine próprio em C/C++ no `flutter_notemus` com o desenho abaixo:

- Mapper Dart (`MidiMapper`) gera timeline PPQ determinística
- Bridge nativa (MethodChannel hoje; FFI opcional em evolução) envia eventos para o engine
- Sequencer nativo sample-accurate mantém clock mestre, playback e tie processing
- Synth SoundFont nativo entrega múltiplos timbres e clique de metrônomo

Referência de destino já existente para implementação nativa:
- `C:\Users\Alesson Queiroz\OneDrive\MusiMind\app\src\main\cpp`

Esse desenho mantém a biblioteca independente no nível de API (sem dependências de pacote para mapeamento/export MIDI) e permite evolução progressiva da camada nativa por plataforma.

---

### Temas e personalização visual

```dart
MusicScore(
  staff: staff,
  staffSpace: 14.0, // Aumentar para uma partitura maior
  theme: const MusicScoreTheme(
    staffLineColor: Colors.black,
    noteheadColor: Colors.black,
    stemColor: Colors.black,
    clefColor: Colors.black,
    barlineColor: Colors.black,
    restColor: Colors.black,
    articulationColor: Colors.black,

    // Cores opcionais (null = usa a cor padrão)
    dynamicColor: Colors.black,
    slurColor: Colors.black,
    tieColor: Colors.black,
    beamColor: Colors.black,
    accidentalColor: Colors.black,
    octaveColor: Colors.black,
    tupletColor: Colors.black,
    ornamentColor: Colors.black,
    breathColor: Colors.black,
    repeatColor: Colors.black,
    textColor: Colors.black,
  ),
)
```

---

## Formato JSON de referência

`JsonMusicParser.parseStaff()` aceita o seguinte formato:

```json
{
  "measures": [
    {
      "clef": "treble",
      "timeSignature": { "numerator": 4, "denominator": 4 },
      "keySignature": 2,
      "elements": [
        {
          "type": "note",
          "step": "D",
          "octave": 5,
          "duration": "quarter",
          "dots": 0,
          "alter": 0,
          "articulations": ["staccato"],
          "dynamic": "forte",
          "ornament": "trill",
          "tie": "start",
          "slur": "start",
          "beam": "start"
        },
        {
          "type": "rest",
          "duration": "eighth"
        },
        {
          "type": "chord",
          "duration": "half",
          "notes": [
            { "step": "C", "octave": 4, "duration": "half" },
            { "step": "E", "octave": 4, "duration": "half" },
            { "step": "G", "octave": 4, "duration": "half" }
          ]
        },
        {
          "type": "tuplet",
          "actualNotes": 3,
          "normalNotes": 2,
          "elements": [
            { "type": "note", "step": "C", "octave": 5, "duration": "eighth" },
            { "type": "note", "step": "D", "octave": 5, "duration": "eighth" },
            { "type": "note", "step": "E", "octave": 5, "duration": "eighth" }
          ]
        },
        {
          "type": "barline",
          "barlineType": "final"
        },
        {
          "type": "dynamic",
          "dynamicType": "pianissimo"
        },
        {
          "type": "tempo",
          "bpm": 120,
          "beatUnit": "quarter",
          "text": "Allegro"
        },
        {
          "type": "breath"
        }
      ]
    }
  ]
}
```

**Valores aceitos por campo:**

| Campo | Valores |
|-------|---------|
| `clef` | `treble` · `bass` · `alto` · `tenor` |
| `duration` | `whole` · `half` · `quarter` · `eighth` · `sixteenth` · `thirty_second` · `sixty_fourth` |
| `alter` | `-2` · `-1` · `0` · `1` · `2` (bemol dobrado a sustenido dobrado) |
| `articulations` | `staccato` · `accent` · `tenuto` · `marcato` · `portato` |
| `dynamic` | `pp` · `p` · `mp` · `mf` · `f` · `ff` · `fff` · `sf` · `sfz` · `fp` · `crescendo` · `diminuendo` |
| `ornament` | `trill` · `mordent` · `invertedMordent` · `turn` · `glissando` |
| `tie` / `slur` / `beam` | `start` · `inner` · `end` |
| `barlineType` | `single` · `double` · `final` · `repeatForward` · `repeatBackward` · `dashed` |

---

## Arquitetura

```
flutter_notemus/
├── lib/
│   ├── flutter_notemus.dart        # Ponto de entrada público
│   ├── midi.dart                   # API pública do módulo MIDI
│   ├── core/                       # Modelo de dados musical
│   │   ├── note.dart               # Note, Pitch, ArticulationType
│   │   ├── duration.dart           # Duration, DurationType
│   │   ├── rest.dart               # Rest
│   │   ├── chord.dart              # Chord
│   │   ├── measure.dart            # Measure, autoBeaming
│   │   ├── staff.dart              # Staff
│   │   ├── clef.dart               # Clef, ClefType
│   │   ├── key_signature.dart      # KeySignature
│   │   ├── time_signature.dart     # TimeSignature
│   │   ├── barline.dart            # Barline, BarlineType
│   │   ├── dynamic.dart            # Dynamic, DynamicType
│   │   ├── ornament.dart           # Ornament, OrnamentType
│   │   ├── articulation.dart       # Articulation
│   │   ├── tempo.dart              # TempoMark
│   │   ├── tuplet.dart             # Tuplet
│   │   ├── beam.dart               # BeamType
│   │   ├── slur.dart               # TieType, SlurType
│   │   ├── voice.dart              # Voice, MultiVoiceMeasure
│   │   ├── octave.dart             # OctaveMark, OctaveType
│   │   ├── volta_bracket.dart      # VoltaBracket
│   │   ├── technique.dart          # PlayingTechnique, TechniqueType
│   │   ├── breath.dart             # Breath, BreathType
│   │   └── score.dart              # Score, StaffGroup
│   └── src/
│       ├── midi/
│       │   ├── midi_models.dart                  # Eventos, tracks, sequência e opções
│       │   ├── midi_mapper.dart                  # Notação -> timeline MIDI
│       │   ├── midi_file_writer.dart             # Escrita de arquivo .mid (SMF)
│       │   ├── method_channel_native_backend.dart # Backend MethodChannel para engine nativa
│       │   ├── midi_native_sequence_bridge.dart   # Bridge de sequência para backend nativo
│       │   └── native_audio_contract.dart         # Contrato para backend nativo
│       ├── layout/
│       │   ├── layout_engine.dart          # Posicionamento de elementos
│       │   └── collision_detector.dart     # Detecção de colisão (skyline)
│       ├── beaming/
│       │   └── beam_analyzer.dart          # Análise e geometria dos beams
│       ├── rendering/
│       │   ├── staff_renderer.dart         # Renderer principal da pauta
│       │   ├── staff_coordinate_system.dart # Sistema de coordenadas SMuFL
│       │   └── renderers/                  # Renderers especializados
│       │       ├── note_renderer.dart
│       │       ├── rest_renderer.dart
│       │       ├── chord_renderer.dart
│       │       ├── barline_renderer.dart
│       │       ├── tuplet_renderer.dart
│       │       ├── slur_renderer.dart
│       │       ├── articulation_renderer.dart
│       │       ├── ornament_renderer.dart
│       │       └── symbol_and_text_renderer.dart
│       ├── smufl/
│       │   └── smufl_metadata_loader.dart  # Carregamento de bravura_metadata.json
│       ├── parsers/
│       │   ├── notation_parser.dart        # Auto-detecção de formato
│       │   ├── json_parser.dart            # Importação via JSON
│       │   ├── musicxml_parser.dart        # Importação/exportação MusicXML
│       │   └── mei_parser.dart             # Importação MEI
│       └── theme/
│           └── music_score_theme.dart      # Sistema de temas
├── assets/
│   └── smufl/
│       ├── Bravura.otf             # Fonte SMuFL (SIL OFL 1.1)
│       ├── bravura_metadata.json   # Âncoras, bounding boxes, codepoints
│       └── glyphnames.json         # Mapeamento nome → codepoint Unicode
├── android/                        # Plugin Android (Kotlin + C++ engine)
├── ios/                            # Plugin iOS (Swift bridge)
├── macos/                          # Plugin macOS (Swift bridge)
├── linux/                          # Plugin Linux (C++ bridge)
├── windows/                        # Plugin Windows (C++ bridge)
└── example/                        # App de demonstração com 35 exemplos
```

**Fluxo de renderização:**

```
Staff  →  LayoutEngine  →  List<PositionedElement>  →  StaffRenderer  →  Canvas
                ↓
          BeamAnalyzer (grupos de beams, geometria, ângulo)
                ↓
          CollisionDetector (skyline para slurs e ligaduras)
```

1. O `LayoutEngine` calcula a posição X/Y de cada elemento com espaçamento rítmico proporcional e justificação horizontal.
2. O `BeamAnalyzer` calcula a geometria dos grupos de beams (altura, ângulo, inclinação).
3. O `StaffRenderer` delega a renderização de cada elemento ao seu renderer especializado, que usa âncoras SMuFL para posicionamento sub-pixel preciso.

---

## Licença

Copyright 2025 Alesson Queiroz

Licenciado sob a **Apache License, Version 2.0**. Veja o arquivo [LICENSE](LICENSE) para os termos completos.

```
Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0
```

### Bravura Font

A fonte Bravura incluída neste pacote é licenciada sob a **SIL Open Font License, Version 1.1**.
Copyright (c) 2013–2024 Steinberg Media Technologies GmbH.

### SMuFL

A especificação SMuFL é mantida pelo W3C Music Notation Community Group e está disponível sob o W3C Community Final Specification Agreement.
Mais informações: https://www.w3.org/community/music-notation/
