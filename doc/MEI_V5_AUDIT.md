# Auditoria de Conformidade: flutter_notemus × MEI v5

> **Data da auditoria inicial:** 2026-03-23
> **Reauditoria adversarial (cruzada com o código):** 2026-06-19
> **Reconciliação com o código (pós-auditoria forense):** 2026-08-22
> **Versão auditada:** flutter_notemus 2.7.0
> **Especificação de referência:** Music Encoding Initiative Guidelines v5
> **URL:** https://music-encoding.org/guidelines/v5/content/index.html

> **Nota de honestidade (2026-06-19).** A alegação de "100% de conformidade" era
> um *overclaim* — confundia *cobertura do modelo de dados* com *suporte real de
> import/render MEI*. As tabelas foram corrigidas para refletir o que o código
> de fato faz, e o número honesto continua sendo aproximadamente **~58% (79/137)
> dos itens catalogados totalmente conformes**.

> **Reconciliação de 2026-08-22.** A auditoria forense
> (`doc/AUDITORIA_FORENSE_2026-08-21.md`) creditou explicitamente esta tabela de
> conformância como **não divergente** — ela já dizia a verdade. O que ela pediu
> foi mais **resolução**: um único rótulo ("✅ conforme") mistura cinco perguntas
> diferentes que têm respostas diferentes. A §4.31 abaixo é essa separação; as
> seções 4.1–4.30 permanecem como estão e continuam descrevendo a **cobertura do
> modelo**.
>
> **Um fato precisa aparecer antes de qualquer tabela:** **não existe
> serializador MEI.** `lib/src/parsers/` contém `mei_parser.dart` e nenhum
> escritor. MEI é **import-only**. Portanto a coluna "EXPORTED" abaixo se refere
> a **MusicXML**, e a coluna "ROUND-TRIP" a **MusicXML → modelo → MusicXML**.
> Nenhum caminho MEI→MEI existe, e nenhum item deste documento pode ser lido
> como round-trip MEI.

**Legenda das tabelas 4.1–4.30 (cobertura do modelo):** ✅ modelado **e**
importado/renderizado · ⚠️ parcial · ○ só modelo · ➕ extensão fora do escopo MEI.

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
   - 4.31 [Matriz MODEL / PARSED / RENDERED / EXPORTED / ROUND-TRIP](#431-matriz-model--parsed--rendered--exported--round-trip)
5. [Pontuação de Conformidade](#5-pontuação-de-conformidade)
6. [Conclusão](#6-conclusão)

---

## 1. Resumo Executivo

O **modelo de dados** do **flutter_notemus v2.7.0** cobre amplamente os conceitos do MEI v5 (você consegue construir os objetos em Dart). Porém o **import/render MEI real** é focado em **CMN**: a reauditoria adversarial de 2026-06-19 (cruzando cada linha com o código) encontrou **79 de 137 itens (~58%) totalmente conformes** — modelados **e** efetivamente importados/renderizados. Os demais existem apenas no modelo (classes definidas, sem parsing/render MEI) ou são parciais. **A reconciliação de 2026-08-22 não mudou esse número**: as correções de 2.7.0 melhoraram a *fidelidade* de itens já contados como conformes (multi-`<section>`, `<verse>`/`<syl>`, contêineres) em vez de ligar módulos novos.

Bem suportado (CMN, import + render):
- Pitch/duration (`maxima`→`2048`), eventos (nota/pausa/acorde), compasso & pauta
- Clave, ligaduras (slur/tie/beam, incl. `SlurEvent` numerado), quiálteras, polifonia
- Estrutura de partitura (`scoreDef`/grupos), repetições/volta, sílabas de letra

Apenas no modelo (○) ou parcial (⚠️) — **sem import/render MEI completo**:
- Metadados/FRBR (`meiHead`), análise harmônica (`harm`/`intm`/`deg`/`ChordTable`), baixo cifrado (`fb`/`f`)
- Notação mensural, tablatura via MEI (`@tab.*`), neuma via MEI (`<neume>` — render só por GABC)
- `@mode` e metros aditivos (`meterSigGrp`) existem no modelo mas não são lidos do MEI
- `<space>`, `<mSpace>`, `<mRest>`, `<multiRest>` são modelados e **não** lidos pelo parser MEI

**A tabela por módulo virou uma matriz de cinco colunas** — ver **§4.31**. Um
único rótulo escondia que "modelado", "importado", "desenhado", "exportado" e
"round-trip" são cinco respostas distintas para o mesmo conceito.

### Corrigido em 2.7.0 (import MEI)

| Achado | O que mudou | Onde |
|---|---|---|
| **F-17** — só a primeira `<section>` era lida; a segunda metade da peça sumia sem aviso | o parser itera **todas** as `<section>` de topo (com detecção de aninhamento) e usa `findAllElements('measure')`, que também alcança compassos dentro de `<ending>`/`<expansion>` | `parser_support.dart::_MeiImportParser.parse`, `_topLevelSections` · invariante: `test/invariants/engraving_invariants_test.dart` → "F-17 — MEI reads every section" |
| **F-42** — `_slurById`/`_tieById`/`_afterNoteById` nunca eram limpos, então `xml:id` duplicados produziam ligaduras fantasma no compasso seguinte | os índices são limpos na entrada de cada compasso | `parser_support.dart::_collectMeiControlEvents` |
| `<verse>`/`<syl>` não populavam `Verse` | `<verse @n>` é lido e ordenado, e `@wordpos`/`@con` viram `SyllableType` | `parser_support.dart:3123-3140` |

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

### 4.31 Matriz MODEL / PARSED / RENDERED / EXPORTED / ROUND-TRIP

> **Por que esta seção existe.** A auditoria forense pediu que "conforme" fosse
> desmontado nas perguntas que ele esconde. Cada coluna é uma pergunta diferente,
> verificada no código em 2026-08-22:
>
> - **MODEL** — a classe/campo existe em `lib/core/` e pode ser construída em Dart.
> - **PARSED** — o **parser MEI** (`_MeiImportParser`) instancia isso a partir do XML.
>   Um conceito lido só do MusicXML **não** conta aqui; a coluna é sobre MEI.
> - **RENDERED** — algum renderizador desenha isso na tela.
> - **EXPORTED** — o escritor **MusicXML** emite isso. **Não existe escritor MEI**,
>   então esta coluna nunca pode significar "exportado como MEI".
> - **ROUND-TRIP** — MusicXML → modelo → MusicXML preserva o dado. A invariante
>   L9 (`test/invariants/engraving_invariants_test.dart`) cobre altura, duração,
>   articulação, ligadura de valor e letra; o resto é leitura de código.
>
> Legenda: ✅ sim · ⚠️ parcial · ❌ não · — não se aplica.

| Conceito MEI v5 | MODEL | PARSED (MEI) | RENDERED | EXPORTED (MusicXML) | ROUND-TRIP |
|---|:--:|:--:|:--:|:--:|:--:|
| Estrutura `<mei>`/`<music>`/`<body>`/`<mdiv>`/`<score>` | ✅ | ✅ | — | ❌ | ❌ |
| `<section>` (incl. múltiplas, `<ending>`, `<expansion>`) | ✅ | ✅ *(F-17 corrigido)* | — | ❌ | ❌ |
| Pitch `@pname`/`@oct`/`@accid`/`@accid.ges` | ✅ | ✅ | ✅ | ✅ | ✅ |
| Microtons (`@alter` fracionário, quartos de tom) | ✅ | ❌ *(o parser MEI deriva `alter` só do `@accid`)* | ✅ | ⚠️ | ❌ |
| `@dur` `maxima`→`2048` + `@dots` | ✅ | ✅ | ⚠️ *(glifos na faixa usual; o espaçamento agora cobre os 15 valores — L6)* | ✅ | ✅ |
| `<note>` / `<rest>` / `<chord>` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `<space>` / `<mSpace>` / `<mRest>` / `<multiRest>` | ✅ | ❌ | ❌ | ❌ | ❌ |
| Notas de ornamento (`@grace`) | ✅ | ✅ | ✅ | ✅ | ⚠️ *(acciaccatura vs appoggiatura perdida)* |
| `<measure>` + `@n` | ✅ | ✅ | ✅ *(números agora **desenhados**: `theme.showMeasureNumbers`, `staff_renderer.dart:299`)* | ✅ | ⚠️ |
| Barlines `@left`/`@right` | ✅ | ✅ | ✅ | ✅ | ⚠️ |
| `<clef>` / `@clef.*` (incl. `@dis`/`@dis.place`) | ✅ | ✅ | ✅ *(mudança intra-compasso agora em tamanho de cue e na ordem do documento — F-01)* | ⚠️ *(mapeamento de linha e claves de oitava — IO #10)* | ⚠️ |
| `<keySig>` / `@key.sig` | ✅ | ✅ | ✅ | ✅ | ⚠️ |
| `@mode` (modo da armadura) | ✅ | ❌ | ❌ | ❌ | ❌ |
| `<meterSig>` / `@meter.count`/`@meter.unit` | ✅ | ✅ | ✅ | ✅ | ⚠️ |
| `<meterSigGrp>` (metro aditivo) e senza misura | ✅ | ❌ | ✅ *(pelo modelo)* | ❌ | ❌ |
| `@artic` (articulações) | ✅ | ✅ | ✅ *(tipos estendidos e empilhamento canônico)* | ✅ | ✅ |
| `<dynam>` (incl. por `@startid`) | ✅ | ✅ | ⚠️ *(~30 dos 36 tipos com glifo + 6 formas em palavra; hairpin é geométrico)* | ✅ | ⚠️ |
| `@ornam` / `<fermata>` | ✅ | ✅ | ⚠️ | ✅ | ⚠️ |
| `<slur>` / `<tie>` (`@slur`/`@tie` e `@startid`/`@endid`) | ✅ | ✅ | ✅ *(agora partida em dois segmentos na quebra de sistema — F-26)* | ⚠️ *(sem continuação)* | ⚠️ |
| `<beam>` contêiner | ✅ | ✅ | ✅ *(compostos 3/8–12/8 agora agrupam certo — F-03)* | ✅ | ⚠️ |
| Níveis de barra 2..4 | ❌ *(`Note` só tem um `BeamType?`)* | ❌ | ❌ | ⚠️ | ❌ |
| `<tuplet>` contêiner (`@num`/`@numbase`) | ✅ | ✅ | ✅ *(aninhado, colchete inclinado, geometria interna registrada)* | ⚠️ | ⚠️ |
| `<layer>` (polifonia) | ✅ | ✅ | ⚠️ *(vozes 1–2 reais; 3–4 são empilhamento cego)* | ✅ *(`<backup>`)* | ⚠️ |
| `<scoreDef>` / `<staffDef>` / `<staffGrp>` | ✅ | ⚠️ *(defaults do `<scoreDef>` semeiam o 1º compasso; grupos/colchetes não são construídos do MEI)* | ✅ *(`GrandStaff`/`ScoreView`)* | ⚠️ | ❌ |
| Repetições / `<ending>` / voltas | ✅ | ✅ | ✅ | ⚠️ *(barra sim; `RepeatMark`/`VoltaBracket` não)* | ❌ |
| `<verse>` / `<syl>` (letras) | ✅ | ✅ | ✅ *(a sílaba agora **reserva largura** no layout — F-15)* | ✅ | ✅ |
| `<octave>` (marcas de oitava) | ✅ | ✅ | ✅ | ✅ | ⚠️ |
| `<tempo>` (`@mm`/`@midi.bpm`/`@unit`) | ✅ | ✅ | ⚠️ | ✅ | ⚠️ |
| `<meiHead>` / FRBR | ✅ | ❌ | — | ❌ | ❌ |
| Análise harmônica (`<harm>`, `@intm`, `@deg`) | ✅ | ❌ | ❌ | ❌ | ❌ |
| Baixo cifrado (`<fb>`/`<f>`) | ✅ | ❌ | ❌ | ❌ | ❌ |
| Tablatura (`@tab.fret`/`@tab.string`, `<tabGrp>`) | ✅ | ❌ | ❌ | ❌ | ❌ |
| Notação mensural | ✅ | ❌ | ❌ | ❌ | ❌ |
| Notação de neuma (`<neume>`/`<nc>`) | ✅ | ❌ | ✅ **por um caminho diferente** — o render vem de **GABC**, por um pipeline próprio (`gabc_parser.dart` → `gregorian_renderer.dart`), não do MEI | ❌ | ❌ |

**Como ler a linha do neuma.** É a única do documento em que ✅ e ❌ convivem na
mesma ideia, e é onde um leitor apressado erra: o canto gregoriano **é** de fato
renderizado, com neumas pré-compostos da Greciliae e classificação por contorno
melódico — mas nada disso é alcançável a partir de um arquivo MEI. Quem entregar
`<neume>` a `MusicScore.fromMei` não vê nada.

**Resumo em uma frase:** MEI entra (CMN, uma fatia grande e agora completa em
`<section>`), MEI não sai, e cinco famílias inteiras do modelo (`meiHead`,
harmonia, baixo cifrado, mensural, tablatura) nunca chegam a ser lidas.

---

## 5. Pontuação de Conformidade

> Cobertura = itens **modelados e ligados ao import/render MEI** sobre o total
> catalogado (reauditoria 2026-06-19, revisada em 2026-08-22). "Só modelo" não
> conta como coberto. Para a decomposição em cinco perguntas, ver **§4.31**.

### Por Módulo MEI v5

| Módulo MEI v5 | Cobertura | Observação (2026-08-22) |
|---|---|---|
| CMN — Pitch & Duration | **100%** | microtons continuam **não** lidos do MEI (`@accid` apenas) |
| CMN — Events (Note/Rest/Chord) | **100%** | |
| CMN — Espaços (`<space>`/`<mSpace>`/`<mRest>`/`<multiRest>`) | **só modelo** | não casados pelo leitor de `<layer>` |
| CMN — Measure & Staff | **100%** | `@n` agora também é **desenhado**, não só guardado |
| CMN — Clef / Key / Meter | **parcial** | `@mode` e `<meterSigGrp>` continuam não lidos do MEI |
| CMN — Articulation | **100%** | render estendido (portato/snap/stopped/open/thumb) e empilhado |
| CMN — Dynamics / Ornaments | **parcial** | ~30 dos 36 tipos de dinâmica com glifo + 6 formas em palavra (era 9/36); ornamentos 33/43 |
| CMN — Slur / Tie / Beam / Tuplet | **parcial** | contêineres ✅; **níveis de barra 2..4 não existem no modelo** (`Note.beam` é único) |
| CMN — Polyphony / Score structure | **parcial** | `<layer>` ✅; `<staffGrp>`/colchetes não são construídos a partir do MEI |
| CMN — Navigation (Repeats / Volta) | **100%** | import ✅; export MusicXML de `RepeatMark`/`VoltaBracket` ainda não |
| Lyrics, Text & Syllables | **100%** | *corrigido: `<verse>`/`<syl>` agora são lidos e `Verse` é populado* |
| Metadata / meiHead / FRBR | **só modelo** | sem parsing MEI |
| Harmonic Analysis | **só modelo** | sem parsing/render |
| Figured Bass | **só modelo** | sem parsing/render |
| Microtonality & Solmization | **parcial** | modelo + render ✅; **não** importável do MEI |
| Tablature | **só modelo** | sem import MEI e sem renderizador de tablatura |
| Mensural Notation | **só modelo** | sem import/render |
| Neume Notation | **parcial** | render real, mas por **GABC**; `<neume>` do MEI não é lido |
| **Serialização MEI (qualquer módulo)** | **0%** | **não existe escritor MEI** |

### Pontuação Global

| Escopo | Cobertura |
|---|---|
| **CMN (Notação Musical Comum) — import MEI** | **alta** (núcleo completo; agora incluindo múltiplas `<section>` e letras) |
| **Itens MEI v5 catalogados totalmente conformes** | **~58%** (79/137) — inalterado por 2.7.0 |
| **Cobertura do modelo de dados (representável em Dart)** | ampla (todos os repertórios) |
| **Export MEI** | **0%** — import-only |
| **Round-trip MEI→MEI** | **impossível hoje** (sem serializador) |

---

## 6. Conclusão

O **modelo de dados** do **flutter_notemus v2.7.0** representa amplamente o MEI v5
(todos os repertórios são construtíveis em Dart). O **import MEI**, porém,
é focado em **CMN** — a reauditoria de 2026-06-19 mediu **~58% (79/137)** dos
itens catalogados como totalmente conformes (modelados **e** importados/
renderizados), e a reconciliação de 2026-08-22 confirmou o número: 2.7.0 tornou
alguns desses itens *mais fiéis* (todas as `<section>`, `<verse>`/`<syl>`,
índices de eventos de controle limpos por compasso) sem ligar módulos novos.
**Não há exportação MEI de nenhum módulo.** A tabela abaixo lista as classes
**do modelo** adicionadas; muitas
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

*Auditoria original conduzida por análise estática do código-fonte contra as MEI v5 Guidelines (v2.5.1, 2026-03-24).*
*Reauditoria adversarial cruzada com o código: 2026-06-19 (v2.6.0) — origem do número honesto de ~58%.*
*Reconciliação com o código e matriz de cinco colunas (§4.31): 2026-08-22 (v2.7.0), após `doc/AUDITORIA_FORENSE_2026-08-21.md`.*
