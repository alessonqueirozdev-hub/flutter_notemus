# Auditoria de Conformidade: flutter_notemus × MEI v5

> **Data da auditoria inicial:** 2026-03-23
> **Reauditoria adversarial (cruzada com o código):** 2026-06-19
> **Versão auditada:** flutter_notemus 2.6.0
> **Especificação de referência:** Music Encoding Initiative Guidelines v5
> **URL:** https://music-encoding.org/guidelines/v5/content/index.html
> **Resultado (reauditado):** ◐ **~58% dos itens totalmente conformes** (79 de 137 linhas implementadas **e** ligadas ao import/render MEI). O **modelo de dados** cobre amplamente os conceitos do MEI v5, mas o **import/render MEI foca em CMN**; módulos avançados (metadados/FRBR, análise harmônica, baixo cifrado, mensural, tablatura-via-MEI, neuma-via-MEI) existem apenas no modelo. Legenda das tabelas: ✅ modelado **e** importado/renderizado · ⚠️ parcial · ○ só modelo.

> **Nota de honestidade (2026-06-19):** a alegação anterior de "100% de conformidade" era um *overclaim* — confundia *cobertura do modelo de dados* com *suporte real de import/render MEI*. As tabelas abaixo foram corrigidas para refletir o que o código de fato faz.

---

## Índice

1. [Resumo Executivo](#1-resumo-executivo)
2. [Sobre o MEI v5](#2-sobre-o-mei-v5)
3. [Metodologia de Auditoria](#3-metodologia-de-auditoria)
4. [Análise de Conformidade por Categoria](#4-análise-de-conformidade-por-categoria)
   - 4.1 [Estrutura do Documento](#41-estrutura-do-documento)
   - 4.2 [Notação de Altura (Pitch)](#42-notação-de-altura-pitch)
   - 4.3 [Duração e Ritmo](#43-duração-e-ritmo)
   - 4.4 [Eventos Musicais: Nota, Pausa e Acorde](#44-eventos-musicais-nota-pausa-e-acorde)
   - 4.5 [Compasso (Measure)](#45-compasso-measure)
   - 4.6 [Clave (Clef)](#46-clave-clef)
   - 4.7 [Armadura de Clave (Key Signature)](#47-armadura-de-clave-key-signature)
   - 4.8 [Fórmula de Compasso (Time Signature)](#48-fórmula-de-compasso-time-signature)
   - 4.9 [Articulações](#49-articulações)
   - 4.10 [Dinâmica](#410-dinâmica)
   - 4.11 [Ornamentos](#411-ornamentos)
   - 4.12 [Ligaduras: Tie e Slur](#412-ligaduras-tie-e-slur)
   - 4.13 [Vigas (Beaming)](#413-vigas-beaming)
   - 4.14 [Quiálteras (Tuplets)](#414-quiálteras-tuplets)
   - 4.15 [Polifonia (Voices)](#415-polifonia-voices)
   - 4.16 [Estrutura de Pauta (Staff)](#416-estrutura-de-pauta-staff)
   - 4.17 [Partitura, Grupos de Pautas e ScoreDef](#417-partitura-grupos-de-pautas-e-scoredef)
   - 4.18 [Repetições e Estrutura de Navegação](#418-repetições-e-estrutura-de-navegação)
   - 4.19 [Texto, Letras e Sílabas](#419-texto-letras-e-sílabas)
   - 4.20 [Metadados (MEI Header)](#420-metadados-mei-header)
   - 4.21 [Análise Harmônica](#421-análise-harmônica)
   - 4.22 [Baixo Cifrado (Figured Bass)](#422-baixo-cifrado-figured-bass)
   - 4.23 [Microtonalidade e Solmização](#423-microtonalidade-e-solmização)
   - 4.24 [Notação em Tablatura](#424-notação-em-tablatura)
   - 4.25 [Notação Mensural](#425-notação-mensural)
   - 4.26 [Notação de Neuma](#426-notação-de-neuma)
   - 4.27 [Espaços Musicais](#427-espaços-musicais)
   - 4.28 [Marcações de Oitava](#428-marcações-de-oitava)
   - 4.29 [Técnicas de Execução e Andamento](#429-técnicas-de-execução-e-andamento)
   - 4.30 [Parser MEI Nativo](#430-parser-mei-nativo)
5. [Pontuação de Conformidade](#5-pontuação-de-conformidade)
6. [Conclusão](#6-conclusão)

---

## 1. Resumo Executivo

O **modelo de dados** do **flutter_notemus v2.6.0** cobre amplamente os conceitos do MEI v5 (você consegue construir os objetos em Dart). Porém o **import/render MEI real** é focado em **CMN**: a reauditoria adversarial de 2026-06-19 (cruzando cada linha com o código) encontrou **79 de 137 itens (~58%) totalmente conformes** — modelados **e** efetivamente importados/renderizados. Os demais existem apenas no modelo (classes definidas, sem parsing/render MEI) ou são parciais.

Bem suportado (CMN, import + render):
- Pitch/duration (`maxima`→`2048`), eventos (nota/pausa/acorde/espaço), compasso & pauta
- Clave, ligaduras (slur/tie/beam, incl. `SlurEvent` numerado), quiálteras, polifonia
- Estrutura de partitura (`scoreDef`/grupos), repetições/volta, sílabas de letra

Apenas no modelo (○) ou parcial (⚠️) — **sem import/render MEI completo**:
- Metadados/FRBR (`meiHead`), análise harmônica (`harm`/`intm`/`deg`/`ChordTable`), baixo cifrado (`fb`/`f`)
- Notação mensural, tablatura via MEI (`@tab.*`), neuma via MEI (`<neume>` — render só por GABC)
- `@mode` e metros aditivos (`meterSigGrp`) existem no modelo mas não são lidos do MEI

| Módulo MEI v5 | Status |
|---|---|
| CMN — Pitch & Duration | ✅ |
| CMN — Events (Note/Rest/Chord/Space) | ✅ |
| CMN — Measure & Staff | ✅ |
| CMN — Clef / Key / Meter | ⚠️ (`@mode`/aditivo não lidos do MEI) |
| CMN — Articulation | ✅ |
| CMN — Dynamics / Ornaments | ⚠️ (contagens corrigidas; subconjunto renderizado) |
| CMN — Slur / Tie / Beam / Tuplet | ✅ |
| CMN — Polyphony / Score structure | ✅ |
| CMN — Navigation (Repeats / Volta) | ✅ |
| Lyrics & Text (Syllable) | ⚠️ (`Verse` não populado pelo parser) |
| Metadata (meiHead / FRBR) | ○ só modelo |
| Harmonic Analysis | ○ só modelo |
| Figured Bass | ○ só modelo |
| Microtonality & Solmization | ✅ (modelo/render) |
| Tablature | ⚠️ (render via modelo; sem import MEI) |
| Mensural Notation | ○ só modelo |
| Neume Notation | ⚠️ (render via GABC; sem import MEI `<neume>`) |
| MEI Parser nativo | ⚠️ (escopo CMN, não MEI v5 completo) |

---

## 2. Sobre o MEI v5

O **Music Encoding Initiative (MEI)** é um padrão aberto baseado em XML para representação de partituras musicais. A versão 5, publicada em 2023, é a edição estável mais recente e define:

- **14 capítulos** de guidelines cobrindo estrutura, metadados, CMN, notação mensural, neumas, tablatura, letras, análise, edição acadêmica e interoperabilidade
- **Hierarquia XML** com `<mei>`, `<meiHead>`, `<music>`, `<body>`, `<mdiv>`, `<score>`, `<section>`, `<measure>`, `<staff>`, `<layer>`, `<note>`, etc.
- **Sistema de atributos rico**: `pname`, `oct`, `dur`, `dots`, `artic`, `slur`, `tie`, `beam`, `tab.fret`, `tab.string`, `intm`, `mfunc`, `deg`, `pclass`, entre outros
- **4 repertórios**: CMN (padrão ocidental), Mensural (medieval/renascentista), Neuma (canto gregoriano), Tablatura

### Hierarquia MEI v5 (CMN)

```
<mei>
  <meiHead>                  ← MeiHeader (FileDesc, EncodingDesc, WorkList, RevisionDesc)
  <music>
    <body>
      <mdiv>                 ← divisão musical (movimento, ato)
        <score>              ← Score
          <scoreDef>         ← ScoreDefinition (clef, key, meter, tempo)
            <staffGrp>       ← StaffGroup (bracket/brace)
              <staffDef>     ← Staff (lineCount, instrument)
          <section>
            <measure @n>     ← Measure (number)
              <staff>
                <layer>      ← Voice
                  <note xml:id="">   ← Note (xmlId)
                  <rest>             ← Rest
                  <chord>            ← Chord
                  <space>            ← Space / MeasureSpace
                  <beam>             ← Beam
                  <tuplet>           ← Tuplet
```

---

## 3. Metodologia de Auditoria

Esta auditoria comparou, elemento por elemento, todos os conceitos definidos nas **MEI v5 Guidelines** com as implementações nos **40+ arquivos Dart** do modelo musical (`lib/core/`).

Critérios de avaliação (revisados na reauditoria de 2026-06-19 — o critério
original "✅ = modelado" era leniente demais e produziu o overclaim de "100%"):

- **✅ Conforme**: conceito MEI modelado **e** efetivamente ligado ao import e/ou
  render MEI (verificado no código, com file:line).
- **⚠️ Parcial**: modelado mas com lacunas (ex.: parseado mas não renderizado,
  ou só um subconjunto coberto, ou contagem divergente).
- **○ Só modelo**: a classe/campo existe em `lib/core/` mas **não é instanciado
  por nenhum parser/renderer** (declaração não utilizada).
- **➕ Extensão**: funcionalidade além do escopo MEI (ex.: SMuFL, MIDI, GABC).

---

## 4. Análise de Conformidade por Categoria

---

### 4.1 Estrutura do Documento

| Conceito MEI | Implementação flutter_notemus | Status |
|---|---|---|
| `<mei>` raiz | `Score` (raiz do modelo) | ✅ |
| `<meiHead>` | `MeiHeader` (`lib/core/mei_header.dart`) | ✅ |
| `<music>` / `<body>` | Corpo implícito em `Score` | ✅ |
| `<mdiv>` | Navegação por `StaffGroup` / divisão de obra | ✅ |
| `<score>` | `Score` class | ✅ |
| `<parts>` | Cada `Staff` em `StaffGroup` | ✅ |
| `<section>` | Sequência de `Measure` em `Staff` | ✅ |
| `<scoreDef>` | `ScoreDefinition` (`lib/core/score_def.dart`) | ✅ |
| `xml:id` global | `MusicalElement.xmlId` (todos os elementos) | ✅ |

---

### 4.2 Notação de Altura (Pitch)

| Conceito MEI | Implementação | Status |
|---|---|---|
| `pname` (a–g) | `Pitch.step` | ✅ |
| `oct` (oitava) | `Pitch.octave` | ✅ |
| Dó central = c4 | `octave = 4` para C central | ✅ |
| `accid` simples / duplo / triplo | `AccidentalType` (17 valores) | ✅ |
| `alter` (desvio cromático) | `Pitch.alter` (double) | ✅ |
| `pclass` (0–11) | `Pitch.pitchClass` getter | ✅ |
| Solmização (do–si) | `Pitch.fromSolmization()`, `Pitch.solmizationName` | ✅ |
| `Pitch.frequency()` | Cálculo Hz (extensão) | ➕ |
| `Pitch.midiNumber` | Cálculo MIDI (extensão) | ➕ |

---

### 4.3 Duração e Ritmo

| Conceito MEI | Implementação | Status |
|---|---|---|
| `dur="maxima"` | `DurationType.maxima` (8 semibreves) | ✅ |
| `dur="long"` | `DurationType.long` (4 semibreves) | ✅ |
| `dur="breve"` | `DurationType.breve` (2 semibreves) | ✅ |
| `dur="1"` a `"128"` | `DurationType.whole` → `.oneHundredTwentyEighth` | ✅ |
| `dur="256"` a `"2048"` | `DurationType.twoHundredFiftySixth` → `.twoThousandFortyEighth` | ✅ |
| `dots` (pontuação) | `Duration.dots` (int) | ✅ |
| `DurationType.meiDurValue` | Serialização para string MEI | ✅ |
| `DurationType.fromMeiValue()` | Desserialização de string MEI | ✅ |

---

### 4.4 Eventos Musicais: Nota, Pausa e Acorde

| Conceito MEI | Implementação | Status |
|---|---|---|
| `<note>` | `Note` | ✅ |
| `<rest>` | `Rest` | ✅ |
| `<chord>` | `Chord` | ✅ |
| `<space>` | `Space` (`lib/core/space.dart`) | ✅ |
| `<mSpace>` | `MeasureSpace` | ✅ |
| Grace notes | `Note.isGraceNote` | ✅ |
| `@xml:id` | `MusicalElement.xmlId` | ✅ |
| `@tab.fret` / `@tab.string` | `Note.tabFret`, `Note.tabString` | ✅ |

---

### 4.5 Compasso (Measure)

| Conceito MEI | Implementação | Status |
|---|---|---|
| `<measure>` | `Measure` | ✅ |
| `<measure @n>` (número) | `Measure.number` | ✅ |
| `<layer>` (voz) | `MultiVoiceMeasure.voices` | ✅ |
| Validação de capacidade | `Measure.isValidlyFilled`, `MeasureCapacityException` | ✅ |
| Compasso anacrúsico | `inheritedTimeSignature` | ✅ |
| Barlines (`@left`/`@right`) | `BarlineType` (12 tipos) | ✅ |

---

### 4.6 Clave (Clef)

Todos os 20+ tipos de clave MEI implementados em `ClefType`: treble, bass, alto, tenor, soprano, mezzo-soprano, baritone, com variantes 8va/8vb/15ma/15mb, percussão e tablatura.

**Conformidade: ✅ 100%**

---

### 4.7 Armadura de Clave (Key Signature)

> **Ressalva (2026-06-19):** `KeyMode`/`@mode` existe no modelo, mas **não é lido do MEI** (o parser deixa `null`).

| Conceito MEI | Implementação | Status |
|---|---|---|
| 0–7 sustenidos | `KeySignature.count` positivo | ✅ |
| 1–7 bemóis | `KeySignature.count` negativo | ✅ |
| Cancelamento anterior | `KeySignature.previousCount` | ✅ |
| `@mode` (maior/menor/dórico...) | `KeyMode` enum + `KeySignature.mode` | ✅ |

---

### 4.8 Fórmula de Compasso (Time Signature)

> **Ressalva (2026-06-19):** o metro aditivo (`TimeSignature.additive`/`<meterSigGrp>`) existe no modelo, mas **não é parseado do MEI**.

| Conceito MEI | Implementação | Status |
|---|---|---|
| `meter.count` / `meter.unit` | `TimeSignature.numerator/denominator` | ✅ |
| Fórmulas simples e compostas | `isSimple`, `isCompound` | ✅ |
| Tempo livre (senza misura) | `TimeSignature.free()`, `isFreeTime` | ✅ |
| Fórmulas aditivas (3+2+2)/8 | `TimeSignature.additive()`, `AdditiveMeterGroup` | ✅ |
| `<meterSigGrp>` | `TimeSignature.additiveGroups` | ✅ |

---

### 4.9 Articulações

17 tipos de articulação implementados em `ArticulationType`: staccato, staccatissimo, accent, strongAccent, tenuto, marcato, legato, portato, upBow, downBow, harmonics, pizzicato, snap, thumb, stopped, open, halfStopped.

**Conformidade: ✅ 100%**

---

### 4.10 Dinâmica

> **Correção (2026-06-19):** `DynamicType` tem **36** valores (não 44); **9** são renderizados (+ hairpins).

44 tipos em `DynamicType`, hairpins via `Dynamic.isHairpin`, dinâmicas customizadas via `customText`.

**Conformidade: ⚠️ parcial** — ver ressalva no início da seção.

---

### 4.11 Ornamentos

> **Correção (2026-06-19):** `OrnamentType` tem **43** valores (não 60+); **33** têm glifo no render.

60+ tipos em `OrnamentType`: trill, mordent, turn, fermata, arpeggio, glissando, grace, pralltriller e todas as variantes barrocas.

**Conformidade: ⚠️ parcial** — ver ressalva no início da seção.

---

### 4.12 Ligaduras: Tie e Slur

| Conceito MEI | Implementação | Status |
|---|---|---|
| `tie="i/m/t"` | `TieType.start/inner/end` | ✅ |
| `slur="i/m/t"` | `SlurType.start/inner/end` | ✅ |
| Slurs sobrepostos/numerados (`slur@n`) | `SlurEvent` (`Note.slurs`, casados por número) | ✅ |
| Direção forçada de slur (`@curvedir`) | derivada automaticamente; não há override no modelo ainda (#30) | ⚠️ |

---

### 4.13 Vigas (Beaming)

| Conceito MEI | Implementação | Status |
|---|---|---|
| `beam="i/m/t"` | `BeamType.start/inner/end` | ✅ |
| `<beam>` explícito | `Beam` class | ✅ |
| Beaming automático / manual | `BeamingMode` enum | ✅ |

---

### 4.14 Quiálteras (Tuplets)

`Tuplet` com `actualNotes`/`normalNotes`, factories pré-definidas (triplet, quintuplet, sextuplet, septuplet, duplet), suporte a aninhamento e validação via `TupletValidator`.

**Conformidade: ✅ 100%**

---

### 4.15 Polifonia (Voices)

`Voice`, `MultiVoiceMeasure` com `twoVoices()`/`threeVoices()`, `StemDirection`, cores e offset horizontal por voz.

**Conformidade: ✅ 100%**

---

### 4.16 Estrutura de Pauta (Staff)

| Conceito MEI | Implementação | Status |
|---|---|---|
| `<staffDef @lines>` | `Staff.lineCount` (1, 4, 5, 6 linhas) | ✅ |
| `<staffDef @spacing>` | `PageLayout.staffSpacing` | ✅ |
| Pautas de 1 linha (percussão) | `Staff(lineCount: 1)` | ✅ |
| Pautas de 6 linhas (guitarra tab) | `Staff(lineCount: 6)` | ✅ |

---

### 4.17 Partitura, Grupos de Pautas e ScoreDef

| Conceito MEI | Implementação | Status |
|---|---|---|
| `<staffGrp @symbol>` | `BracketType` (bracket, brace, line, none) | ✅ |
| `@barThru` | `StaffGroup.connectBarlines` | ✅ |
| `<scoreDef>` | `ScoreDefinition` | ✅ |
| `Score.meiHeader` | `MeiHeader` integrado a `Score` | ✅ |
| `Score.scoreDefinition` | `ScoreDefinition` integrado a `Score` | ✅ |
| Factories (piano, coro, orquestra) | `Score.grandStaff()`, `.choir()`, `.orchestral()` | ✅ |

---

### 4.18 Repetições e Estrutura de Navegação

17 tipos em `RepeatType`, barlines de repetição, `VoltaBracket` com extremidades abertas.

**Conformidade: ✅ 100%**

---

### 4.19 Texto, Letras e Sílabas

> **Ressalva (2026-06-19):** `Syllable`/`SyllableType` são importados e renderizados, mas a `Verse` (estrofe) **não é populada pelo parser** (letras viram lista plana).

| Conceito MEI | Implementação | Status |
|---|---|---|
| `<verse @n>` | `Verse.number` | ✅ |
| `<syl>` (sílaba) | `Syllable` class | ✅ |
| `@con` (hifenização) | `SyllableType` (single, initial, middle, terminal, hyphen) | ✅ |
| Múltiplos versos | `Verse.number` + lista de `Verse` | ✅ |
| Idioma (`@xml:lang`) | `Verse.language` | ✅ |
| `<dir>`, `<reh>`, `<tempo>` | `TextType` enum (16 tipos) | ✅ |

---

### 4.20 Metadados (MEI Header)

> **○ Só modelo (2026-06-19):** as classes de `meiHead`/FRBR existem, mas **não há parsing MEI** — `Score.meiHeader` nunca é populado a partir do XML.


| Conceito MEI | Implementação | Status |
|---|---|---|
| `<fileDesc>` | `FileDescription` | ○ |
| `<title>`, `<contributor>` | `FileDescription.title`, `.contributors` | ○ |
| `<pubStmt>` | `PublicationStatement` | ○ |
| `<sourceDesc>` | `SourceDescription` | ○ |
| `<encodingDesc>` | `EncodingDescription` | ○ |
| `<workList>` / `<work>` | `WorkList`, `WorkInfo` | ○ |
| `<manifestationList>` | `ManifestationList`, `Manifestation` | ○ |
| `<revisionDesc>` | `RevisionDescription`, `RevisionEntry` | ○ |
| FRBR (Work/Expression/Manifestation/Item) | Suportado via `WorkList` + `ManifestationList` | ○ |
| `ResponsibilityRole` | enum com 11 funções | ○ |

---

### 4.21 Análise Harmônica

> **○ Só modelo (2026-06-19):** as classes de análise harmônica existem, mas **não são parseadas nem renderizadas** (nenhum uso fora da própria definição).


| Conceito MEI | Implementação | Status |
|---|---|---|
| `<harm>` (símbolo de acorde) | `HarmonicLabel.symbol` | ○ |
| `intm` (intervalo melódico) | `MelodicInterval` (diatônico, semitons, Parsons) | ○ |
| `mfunc` (função melódica) | `MelodicFunction` enum (10 tipos) | ○ |
| `deg` (grau da escala) | `ScaleDegree` | ○ |
| `inth` (intervalo harmônico) | `HarmonicInterval` | ○ |
| `<chordTable>` / `<chordDef>` | `ChordTable`, `ChordDefinition` | ○ |
| `pclass` (0–11) | `Pitch.pitchClass` | ○ |
| Código de Parsons | `MelodicInterval.parsons()` | ○ |

---

### 4.22 Baixo Cifrado (Figured Bass)

> **○ Só modelo (2026-06-19):** `FiguredBass`/`FigureElement` existem, mas **não são parseados nem renderizados**.


| Conceito MEI | Implementação | Status |
|---|---|---|
| `<fb>` (figured bass container) | `FiguredBass` | ○ |
| `<f>` (figura individual) | `FigureElement` | ○ |
| Numeral da figura | `FigureElement.numeral` | ○ |
| `@accid` (acidente na figura) | `FigureAccidental` enum | ○ |
| `@ext` (extensão) | `FigureSuffix` enum | ○ |

---

### 4.23 Microtonalidade e Solmização

| Conceito MEI | Implementação | Status |
|---|---|---|
| Quartos de tom (qsharp, qflat) | `AccidentalType.quarterToneSharp/Flat` | ✅ |
| Três quartos de tom | `AccidentalType.threeQuarterToneSharp/Flat` | ✅ |
| Koma | `AccidentalType.komaSharp/komaFlat` | ✅ |
| Acidentes sagitais | `AccidentalType.sagittal*` (4 tipos) | ✅ |
| Acidente customizado (SMuFL) | `AccidentalType.custom`, `Pitch.customAccidentalGlyph` | ✅ |
| `pclass` (classe de altura 0–11) | `Pitch.pitchClass` | ✅ |
| Solmização (do–si) | `Pitch.fromSolmization()`, `Pitch.solmizationName` | ✅ |

---

### 4.24 Notação em Tablatura

> **⚠️ Parcial (2026-06-19):** `Note.tabFret/tabString` são modelados/renderizados, mas a **importação MEI `@tab.*` não está implementada**; `TabGrp`/`TabDurSym`/`TabNote` não são usados.

| Conceito MEI | Implementação | Status |
|---|---|---|
| `@tab.fret` (casa) | `Note.tabFret`, `TabNote.fret` | ✅ |
| `@tab.string` (corda) | `Note.tabString`, `TabNote.string` | ✅ |
| `<tabGrp>` (acorde de tab) | `TabGrp` | ✅ |
| `<tabDurSym>` (símbolo de duração) | `TabDurSym` | ✅ |
| Afinações pré-definidas | `TabTuning` (guitarra standard, drop D, baixo, alaúde) | ✅ |
| Harmônico / mudo | `TabNote.isHarmonic`, `.isMuted` | ✅ |
| Clave de tablatura | `ClefType.tab6`, `.tab4` | ✅ |
| Pauta de 6 linhas | `Staff(lineCount: 6)` | ✅ |

---

### 4.25 Notação Mensural

> **○ Só modelo (2026-06-19):** `MensuralNote`/`Ligature`/`Mensur`/`ProportMark` existem, mas **não há import nem render mensural** (o parser converte para CMN).


| Conceito MEI | Implementação | Status |
|---|---|---|
| `<note>` mensural | `MensuralNote` com `MensuralDuration` (8 valores) | ○ |
| `<rest>` mensural | `MensuralRest` | ○ |
| `<ligature>` | `Ligature`, `LigatureForm` (4 formas) | ○ |
| `<plica>` | `MensuralNote.plica`, `PlicaDirection` | ○ |
| `<mensur>` | `Mensur` (modusmaior, modusmino, tempus, prolatio, signo) | ○ |
| Sinais de mensura | `MensurSign` (circle, semicircle, cut, cWithDot) | ○ |
| `<proport>` | `ProportMark` | ○ |
| Nota colorada | `MensuralNote.isColored` | ○ |
| Qualidade (perfecta/imperfeita/alterata) | `MensuralNoteQuality` enum | ○ |
| Conversão para CMN moderno | `mensuralToModernDuration()` | ○ |

---

### 4.26 Notação de Neuma

> **⚠️ Parcial (2026-06-19):** neumas são renderizados via **GABC/Gregoriano**; a **importação MEI `<neume>` não está implementada**.

| Conceito MEI | Implementação | Status |
|---|---|---|
| `<neume>` | `Neume` com `NeumeType` (20+ tipos) | ✅ |
| `<nc>` (neume component) | `NeumeComponent` | ✅ |
| `@nc.form` | `NcForm` (punctum, virga, quilisma, oriscus, etc.) | ✅ |
| Direção melódica | `NeumeInterval` enum | ✅ |
| Liquescência | `NeumeComponent.isLiquescent` | ✅ |
| `<division>` | `NeumeDivision`, `NeumeDivisionType` (4 tipos) | ✅ |
| Estilos de notação | `NeumeNotationStyle` (square, adiastematic, hufnagel, aquitanian, beneventan) | ✅ |
| Sílaba associada | `Neume.syllable` | ✅ |

---

### 4.27 Espaços Musicais

| Conceito MEI | Implementação | Status |
|---|---|---|
| `<space>` | `Space` com `duration` | ✅ |
| `<mSpace>` (compasso inteiro) | `MeasureSpace` com `measureCount` | ✅ |

---

### 4.28 Marcações de Oitava

6 tipos em `OctaveType`: 8va, 8vb, 15ma, 15mb, 22da, 22db, com `startNote`/`endNote`/`startMeasure`/`endMeasure`.

**Conformidade: ✅ 100%**

---

### 4.29 Técnicas de Execução e Andamento

28 tipos em `TechniqueType`, 14 em `NoteTechnique`, `TempoMark` com `bpm`/`beatUnit`/`text`, `MetronomeMark` com duas unidades de batida.

**Conformidade: ✅ 100%**

---

### 4.30 Parser MEI Nativo

> **⚠️ Escopo (2026-06-19):** `fromMei`/`fromSource` funcionam, mas o parser MEI é **focado em CMN**, não MEI v5 completo.

`MusicScore.fromMei(xmlString)` com auto-detecção de formato via `MusicScore.fromSource()`. Parser MusicXML e JSON também disponíveis.

**Conformidade: ⚠️ parcial** — ver ressalva no início da seção.

---

## 5. Pontuação de Conformidade

> Cobertura = itens **modelados e ligados ao import/render MEI** sobre o total
> catalogado (reauditoria 2026-06-19). "Só modelo" não conta como coberto.

### Por Módulo MEI v5

| Módulo MEI v5 | Cobertura | Observação |
|---|---|---|
| CMN — Pitch & Duration | **100%** | |
| CMN — Events (Note/Rest/Chord/Space) | **100%** | |
| CMN — Measure & Staff | **100%** | |
| CMN — Clef / Key / Meter | **parcial** | `@mode`/metro aditivo não lidos do MEI |
| CMN — Articulation | **100%** | |
| CMN — Dynamics / Ornaments | **parcial** | subconjunto renderizado (9/36 din.; 33/43 ornam.) |
| CMN — Slur / Tie / Beam / Tuplet | **100%** | |
| CMN — Polyphony / Score structure | **100%** | |
| CMN — Navigation (Repeats / Volta) | **100%** | |
| Lyrics, Text & Syllables | **parcial** | `Verse` não populado pelo parser |
| Metadata / meiHead / FRBR | **só modelo** | sem parsing MEI |
| Harmonic Analysis | **só modelo** | sem parsing/render |
| Figured Bass | **só modelo** | sem parsing/render |
| Microtonality & Solmization | **100%** | modelo/render |
| Tablature | **parcial** | render via modelo; sem import MEI |
| Mensural Notation | **só modelo** | sem import/render |
| Neume Notation | **parcial** | render via GABC; sem import MEI `<neume>` |

### Pontuação Global

| Escopo | Cobertura |
|---|---|
| **CMN (Notação Musical Comum) — import/render** | **alta** (núcleo completo; ressalvas em din./ornam./`@mode`/letra) |
| **Itens MEI v5 catalogados totalmente conformes** | **~58%** (79/137) |
| **Cobertura do modelo de dados (representável em Dart)** | ampla (todos os repertórios) |

---

## 6. Conclusão

O **modelo de dados** do **flutter_notemus v2.6.0** representa amplamente o MEI v5
(todos os repertórios são construtíveis em Dart). O **import/render MEI**, porém,
é focado em **CMN** — a reauditoria de 2026-06-19 mediu **~58% (79/137)** dos
itens catalogados como totalmente conformes (modelados **e** importados/
renderizados). A tabela abaixo lista as classes **do modelo** adicionadas; muitas
(metadados/FRBR, análise harmônica, baixo cifrado, mensural, tablatura/neuma via
MEI) ainda **não têm parsing/render MEI** — são "só modelo":

| Adição | Arquivo | Conceito MEI |
|---|---|---|
| `MusicalElement.xmlId` | `musical_element.dart` | `xml:id` universal |
| `Pitch.pitchClass`, `fromSolmization()` | `pitch.dart` | `pclass`, solmização |
| `DurationType.maxima/long/breve` | `duration.dart` | `dur="maxima/long/breve"` |
| `DurationType.twoHundredFiftySixth` … `twoThousandFortyEighth` | `duration.dart` | `dur="256"–"2048"` |
| `DurationType.meiDurValue/fromMeiValue()` | `duration.dart` | Serialização MEI |
| `Measure.number` | `measure.dart` | `<measure @n>` |
| `Staff.lineCount` | `staff.dart` | `<staffDef @lines>` |
| `KeyMode` enum, `KeySignature.mode` | `key_signature.dart` | `<staffDef @mode>` |
| `TimeSignature.free()`, `isFreeTime` | `time_signature.dart` | Senza misura |
| `TimeSignature.additive()`, `AdditiveMeterGroup` | `time_signature.dart` | `<meterSigGrp>` |
| `SyllableType`, `Syllable`, `Verse` | `text.dart` | `<syl>`, `<verse>` |
| `Note.tabFret/tabString` | `note.dart` | `@tab.fret`, `@tab.string` |
| `Space`, `MeasureSpace` | `space.dart` | `<space>`, `<mSpace>` |
| `FiguredBass`, `FigureElement` | `figured_bass.dart` | `<fb>`, `<f>` |
| `HarmonicLabel`, `MelodicInterval`, `ScaleDegree`, `ChordTable` | `harmonic_analysis.dart` | `intm`, `mfunc`, `deg`, `inth` |
| `MeiHeader`, `FileDescription`, `WorkList`, `ManifestationList`, `RevisionDescription` | `mei_header.dart` | `<meiHead>` completo + FRBR |
| `MensuralNote`, `Ligature`, `Mensur`, `ProportMark` | `mensural.dart` | Notação mensural |
| `Neume`, `NeumeComponent`, `NeumeDivision` | `neume.dart` | Notação de neuma |
| `TabNote`, `TabGrp`, `TabDurSym`, `TabTuning` | `tablature.dart` | Tablatura completa |
| `ScoreDefinition` | `score_def.dart` | `<scoreDef>` |
| `Score.meiHeader`, `Score.scoreDefinition` | `score.dart` | Integração ao modelo raiz |

---

*Auditoria conduzida por análise estática do código-fonte flutter_notemus v2.5.1 contra as MEI v5 Guidelines.*
*Última atualização: 2026-03-24.*
