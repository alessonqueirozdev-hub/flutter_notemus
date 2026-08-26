# Auditoria Forense, Adversarial e Arquitetural — flutter_notemus 2.6.0

**Data:** 2026-08-21 · **Branch:** `sprint/engraving-quality` (HEAD `5bfab60`) · **Flutter** 3.41.0 / Dart 3.11.0
**Método:** leitura integral de `lib/` (229 arquivos Dart), execução da suíte (`594 testes, 100% verdes`), `flutter analyze` (16 issues, todos `info`), e **7 rodadas de sondas adversariais executáveis** escritas especificamente para tentar quebrar o motor. Sondas removidas ao final; o repositório está limpo.

**Níveis de evidência:** A = confirmado executando código · B = confirmado lendo o código · C = inferência arquitetural forte · D = hipótese.

---

# 1. EXECUTIVE SUMMARY

`flutter_notemus` é um projeto sério, com massa crítica real: modelo musical amplo (129 classes/enums em `lib/core`), uso genuíno de metadados SMuFL (âncoras `stemUpSE`/`stemDownNW`, `engravingDefaults`), pipeline MIDI de qualidade acima da média, 52 goldens de imagem reais, e uma documentação que — após auditorias anteriores — já foi corrigida para ser honesta (o README admite explicitamente "~58% dos itens catalogados realmente ligados").

Isso não muda o veredito técnico. **O motor não está pronto para produção como engine de gravação profissional, e a razão é arquitetural, não cosmética.**

Três defeitos estruturais explicam a maioria dos bugs encontrados:

1. **O layout tem duas fontes de verdade para largura.** `_calculateMeasureWidthCursor` estima a largura de um compasso com espaçamento **fixo por nota** (`3.5 SS`), enquanto `_calculateRhythmicSpacing` posiciona as notas com espaçamento **proporcional à duração**. As decisões de quebra de sistema usam a estimativa; o desenho usa a outra. Consequência medida: um compasso de 32 semicolcheias em uma linha de 400 px produz `maxX = 1222,7 px` — **3× de estouro, num `CustomPaint` cuja largura é fixada no viewport e cujo scroll horizontal é inerte**. A música simplesmente desaparece.

2. **O motor clona objetos `Note` no meio do pipeline.** `_processBeamsWithAnacrusis` recria cada nota que entra numa barra de ligação para gravar o `BeamType`. Como `Note` não implementa `==`/`hashCode`, todos os mapas identity-keyed construídos *antes* desse ponto — `accidentalDecisions`, `noteXPositions` — deixam de casar. Resultado medido: **a regra de acidentes de Gould (Behind Bars) simplesmente não se aplica a notas com barra de ligação** (4 fás sustenidos seguidos imprimem 4 sustenidos em colcheias, e 1 em semínimas), a assinatura de layout é **não determinística entre execuções idênticas**, e a API pública `noteXPositions` devolve `null` para as notas do usuário.

3. **A pauta múltipla não tem uma linha do tempo comum.** `GrandStaffPainter` executa um `LayoutEngine` **independente por pauta** e depois tenta consertar com um remapeamento linear por trechos entre âncoras de barras de compasso. Medido: num compasso 4/4 com 4 semínimas na clave de sol e 2 mínimas na de fá, **o tempo 3 desalinha 38,1 px (>3 espaços de pauta)**. Isso é o requisito nº 1 de gravação de música para teclado/conjunto, e ele não é atendido.

Além disso, a gravação tem erros musicais diretamente visíveis: **todos os compassos compostos (3/8, 6/8, 9/8, 12/8) agrupam errado** — o primeiro grupo sai com 2 notas em vez de 3 e a última nota fica órfã sem barra —, hastes dentro de grupos com barra podem cair para **1,75 espaços** (mínimo profissional: 2,5; padrão 3,5), e **letras de música não influenciam o espaçamento horizontal em nada** (uma sílaba "Extraordinarily" produz exatamente o mesmo espaçamento que nenhuma sílaba).

Na interoperabilidade, o importador de MusicXML **ignora `<divisions>`/`<duration>`** (uma nota sem `<type>` vira semínima), **ignora `<backup>`/`<forward>`** (polifonia colapsa em sequência: um compasso 4/4 chega ao modelo com valor 2,0) e lê apenas o primeiro elemento `<beam>` (barras secundárias/parciais perdidas na importação). O importador MEI lê apenas a **primeira `<section>`** — a segunda metade da peça some silenciosamente.

Em contraste, e isso precisa ser dito com a mesma clareza: **o subsistema MIDI é sólido.** Ligaduras de valor consolidam corretamente, quinálteras dão 320 ticks exatos com PPQ 960, polifonia real (C5 0–1920, D5 1920–3840, C4 0–3840), e repetições expandem na ordem correta (C D E C D E F). Os goldens são reais e as posições de layout **são** determinísticas (só a assinatura não é). O uso de SMuFL é genuíno, não decorativo.

**Veredito de uma linha:** é um renderizador de notação musical competente e um exportador MIDI bom, montado sobre um motor de layout que ainda é uma coleção de heurísticas locais, não um motor de gravação. Os defeitos são corrigíveis, mas três deles exigem mudança estrutural, não patch.

---

# 2. REALIDADE VS DOCUMENTAÇÃO

O README já foi corrigido por auditorias anteriores e é, no geral, honesto. As divergências que **restam** são estas:

| Afirmação | Onde | Realidade verificada | Ev. |
|---|---|---|---|
| `CMN — Slur / Tie / Beam` **✅** (legenda: "modelado **e** importado/renderizado") | README tabela | `_musicXmlBeamType` lê só `findElements('beam').firstOrNull` → barras secundárias e parciais **não são importadas**. Agrupamento em compasso composto está errado. Deveria ser **◐**. | A/B |
| `CMN — Polyphony` **✅** | README tabela | `Measure.add()` **lança exceção** ao receber 2 vozes na mesma lista; `<backup>` é ignorado no import; colisão entre vozes só trata 2 vozes e casa por `dx.round()`. Deveria ser **◐**. | A |
| `CMN — Tuplets ✅ ... nested tuplets` | README tabela | `Tuplet.isNested`/`parentTuplet` só são lidos em `getModifiedDuration`. Nenhum renderizador consulta aninhamento. Quinálteras aninhadas são **model-only** no desenho. | B |
| `CMN — Measure & Staff ✅ Measure (@n)` | README tabela | `Measure.number` **nunca é renderizado** — `grep` por número de compasso em `lib/` não retorna nada. O modelo guarda; a partitura não mostra. | B |
| "applies viewport culling so only visible systems are repainted" | dartdoc de `MusicScorePainter` | O culling existe, mas `shouldRepaint` compara `positionedElementsSignature`, que **muda a cada layout do mesmo Staff** (F-02) — logo repinta sempre. E `repaint: Listenable.merge([hCtrl, vCtrl])` força repintura por pixel de rolagem. | A |
| "Lyrics can affect note spacing (syllable width)" | comentário em `layout_engine.dart:1120` | Falso para o caminho real (`Note.syllables`). Medido: espaçamento idêntico (56,16 px) com e sem sílaba de 15 caracteres. | A |
| `stemUpXOffset = 0.7` / `stemDownXOffset = -0.8` em `stem_renderer.dart:20/:25` | `doc/MAGIC_NUMBERS_REFERENCE.md` §1 | **Constantes não existem mais.** Foram substituídas por âncoras SMuFL. O documento de referência de magic numbers está obsoleto. | B |
| `#2 — Within-measure accidental persistence` = **RESOLVED** | `doc/LIBRARY_AUDIT_BACKLOG.md` | **Resolvido apenas para notas sem barra.** Ver F-02. Regressão silenciosa introduzida pela interação com o beaming. | A |
| `#51 — spacing model is dead code` (aberto) | mesmo backlog | Continua verdadeiro, e **piorou**: a tabela foi corrigida para raiz quadrada mas ficou **incompleta**, criando inversão rítmica (F-11). | A |
| Badge `SMuFL 1.40` | README | O uso é real, mas a carga é um **singleton de processo** amarrado a `assets/smufl/bravura_metadata.json`. Não há API para carregar outra fonte SMuFL. É *Bravura-compatible*, não *SMuFL-agnostic*. | B |
| `version: 2.6.0` | pubspec | Histórico contém `1d88853 bump to 2.7.0` seguido de `7ab8611 renumber to 2.6.0`. CHANGELOG lista 2.6.0. Consistente hoje, mas o README documenta features "2.7.0" (`528feae docs(readme): extensive 2.7.0 docs`). | B |

**Divergências que NÃO encontrei** (crédito devido): a tabela de conformância MEI, a lista de módulos *model-only*, o estado do export PDF (placeholder, com TODO real no código em `pdf_exporter.dart:121`) e o estado do playback nativo (só Android tem motor real: 608 linhas de C++ + 350 de Kotlin; iOS/macOS/Windows/Linux/Web retornam `false`/`null`) estão **corretamente documentados**.

---

# 3. ARQUITETURA ATUAL

## 3.1 O pipeline como ele realmente é

```
FONTE (JSON | MusicXML | MEI | GABC | API Dart)
   │
   ├─ NotationParser.detect  ──► _JsonImportParser
   │                          ├─► _MusicXmlImportParser   (parser_support.dart, 2802 linhas)
   │                          └─► _MeiImportParser
   │
   ▼
MODELO  lib/core/*  (Staff → Measure → List<MusicalElement>)
   │                 MultiVoiceMeasure guarda vozes FORA de `elements`
   │
   ▼
LayoutEngine  (1836 linhas — instanciado a cada build do widget)
   │  ├─ AccidentalResolver.resolve(measures)     ← mapa identity-keyed nas notas ORIGINAIS
   │  ├─ por compasso: _processBeamsWithAnacrusis ← ✱ CLONA as notas com barra ✱
   │  ├─ LayoutCursor: avança X por _calculateRhythmicSpacing
   │  ├─ quebra de sistema por _calculateMeasureWidthCursor (OUTRA fórmula)
   │  ├─ _justifyHorizontally  (estiramento linear, não justificação)
   │  ├─ _centerFullMeasureRests
   │  ├─ _resolveCrossVoiceCollisions
   │  └─ _analyzeBeamGroups → AdvancedBeamGroup[]
   │
   ▼
List<PositionedElement>  (elemento + Offset absoluto + system + voiceNumber)
   │
   ▼
MusicScorePainter.paint()  ──► agrupa por system (O(n) POR FRAME)
   │                        ──► instancia StaffRenderer POR SISTEMA VISÍVEL, POR FRAME
   ▼
StaffRenderer.renderStaff  (3 passadas: elementos → beams avançados → grupos/ligaduras)
   └─ 15 renderizadores especializados + SMuFLPositioningEngine
```

**Pipeline paralelo, independente, para pauta múltipla:**

```
Score/StaffGroup ──► GrandStaffPainter
                       └─ UM LayoutEngine POR PAUTA (independentes)
                       └─ _alignStaves(): remapeamento linear por trechos
                          entre âncoras = [início do conteúdo] + [Xs das barras]
```

**Pipeline paralelo, independente, para canto gregoriano:**

```
GABC ──► GabcParser ──► List<Neume|NeumeDivision> ──► GregorianLayout.build
                                                       └─ GregorianPainter (glifos Greciliae pré-compostos)
```

**Pipeline paralelo, independente, para Jianpu:** `JianpuScore` → `JianpuRenderer`.

**Pipeline MIDI (o mais limpo do projeto):**

```
Staff/Score ──► MidiMapper._buildTrackFromStaff
                  ├─ _expandRepeats (voltas, passes)
                  ├─ ticks = realValue × 4 × ticksPerQuarter (× razão de quináltera)
                  ├─ consolidação de ligaduras de valor
                  └─ MidiSequence{ticksPerQuarter, tracks[], warnings[]}
                       └─ MidiFileWriter / MidiNativeSequenceBridge → MethodChannel
```

## 3.2 O que essa arquitetura significa

- **Não existe um "motor de gravação" único.** Existem **quatro** pipelines de layout desconexos (CMN single-staff, CMN grand-staff, gregoriano, jianpu). O gregoriano e o jianpu nem sequer passam por `PositionedElement`.
- **Não existe separação MUSIC MODEL / LAYOUT MODEL / RENDER MODEL.** `Note` carrega `beam` (decisão de layout) e o mixin `BoundingBoxSupport` (estado de render) dentro do objeto musical. O layout muta o modelo — clonando notas.
- **Não existe passe de layout global.** Cada decisão (largura de compasso, quebra, justificação, colisão) é local e sequencial, aplicada sobre um resultado já materializado. Não há convergência, não há iteração, não há custo global mínimo.
- **`MultiVoiceMeasure` é uma classe-cisão:** herda de `Measure` mas guarda as vozes em `_voicesByNumber`, deixando `elements` quase vazia. Toda a API herdada (`currentMusicalValue`, `isValidlyFilled`, `canAddDuration`) devolve valores sem sentido para ela. É polimorfismo quebrado (violação de LSP) que já força `if (measure is MultiVoiceMeasure)` em 7 arquivos distintos.

---

# 4. MUSIC MODEL

## 4.1 O que está certo

- `DurationType` cobre `maxima` → `2048th` com valores relativos corretos e nomes de glifo SMuFL corretos. `Duration.absoluteValue` implementa pontos de aumento corretamente (verificado).
- `Pitch` separa `step`/`octave`/`alter` (diatônico + cromático), suporta microtons por `alter` fracionário, `pitchClass`, `frequency` (correto, incluindo microtons — verificado numericamente), solmização.
- `AccidentalResolver` é uma boa peça de arquitetura: resolve a decisão **a partir do modelo**, independente do layout, com chave `step+oitava` e persistência da armadura — exatamente a regra de Gould.
- `Score` / `StaffGroup` / `ScoreDefinition` / `MeiHeader` dão uma espinha real para partitura completa.

## 4.2 Defeitos do modelo

### F-19 · `PitchUtils.intervalInSemitones` conta a alteração duas vezes — **P2, Ev. A**
```
ID: F-19 | SEVERIDADE: P2 | EVIDÊNCIA: A
ARQUIVO: lib/core/pitch.dart  LINHA: ~396  COMPONENTE: modelo/pitch
PROBLEMA: midiNumber JÁ inclui effectiveAlter.round(); o método soma (alter2 - alter1) de novo.
COMPORTAMENTO ATUAL (medido):
   intervalInSemitones(C4, C#4) = 2.0   (correto: 1)
   intervalInSemitones(C4, Eb4) = 2.0   (correto: 3)
   intervalInSemitones(C4, E4)  = 4.0   (correto: 4 — só acerta quando alter=0)
IMPACTO: API pública exportada. Qualquer consumidor que calcule intervalos
         (transposição, análise, teste de colisão de segunda) obtém valores errados.
CAUSA RAIZ: dupla contabilização — confusão entre "altura cromática absoluta"
            e "delta de alteração".
CORREÇÃO: return (pitch2.midiNumber - pitch1.midiNumber).toDouble()
                 + (pitch2.effectiveAlter - pitch2.effectiveAlter.round())
                 - (pitch1.effectiveAlter - pitch1.effectiveAlter.round());
RISCO DA CORREÇÃO: baixo. TESTE: tabela de intervalos C4→{C#4,Db4,Eb4,E4,F#4,B4,C5}.
```

### F-20 · `Pitch.fromString` corrompe oitavas negativas silenciosamente — **P3, Ev. A**
`Pitch.fromString('C-1')` devolve `C1` (MIDI 24 em vez de 0). O loop de acidentes não reconhece `-` e não para; o `substring` acaba pegando só o dígito. É corrupção semântica silenciosa, não exceção.

### F-21 · Igualdade inconsistente/ausente — **P3, Ev. A**
- `Pitch ==` compara `alter` cru, não `effectiveAlter`: `Pitch(step:'F',octave:4,alter:1.0) == Pitch.withAccidental(F,4,sharp)` → **false**, para duas alturas idênticas.
- `Duration` **não tem** `==`/`hashCode`: `Duration(quarter,dots:1) == Duration(quarter,dots:1)` → **false** (só `const` idênticos coincidem por canonicalização). Impede qualquer cache/dedup por duração.
- `Note`, `Chord`, `Rest`, `Clef` — identidade pura. Isso é *defensável* como escolha, mas então **clonar notas no meio do pipeline é proibido** (ver F-02).

### F-10 · Modelo aceita `step` inválido; o comportamento diverge por subsistema — **P1, Ev. A**
`<step>H</step>` no MusicXML entra no modelo sem validação. Depois:
- `StaffPositionCalculator.calculate` → `_stepToDiatonic[step] ?? 0` → desenha silenciosamente como **dó**;
- `Pitch.midiNumber` → `stepToSemitone[step]!` → **`_TypeError: Null check operator used on a null value`**.

Ou seja: **entrada não confiável derruba o app na tocada, e mente na tela.** Duas políticas contraditórias para o mesmo dado inválido.

### F-09 · `Measure.add()` proíbe polifonia legítima — **P1, Ev. A**
`currentMusicalValue` soma **todos** os elementos linearmente, sem noção de voz. Adicionar 4 semínimas na voz 1 e 4 na voz 2 no mesmo compasso 4/4 lança `MeasureCapacityException`. Mas `Note` tem campo `voice` — o modelo *convida* a esse uso.

Pior: **os parsers contornam a validação** escrevendo direto em `measure.elements.add(...)` (`parser_support.dart:235`). Logo o invariante não é do modelo — é um obstáculo que só atinge quem usa a API documentada.

### F-25 · `Tuplet` é opaco para o layout — **P2, Ev. A**
Medido: um `Tuplet` recebe **uma** posição (`x=82.6`); suas notas internas ficam com `noteXPositions == null` para todas. Consequências encadeadas:
- as notas da quiáltera **não participam** do espaçamento rítmico, da justificação, do skyline, nem de `_analyzeBeamGroups`;
- `AccidentalResolver` até percorre `Tuplet.elements`, mas o mapa nunca é consultado para elas no caminho de largura;
- quinálteras aninhadas não têm suporte de desenho.

### F-24 · Convenção de oitava das claves transpositoras é internamente contraditória — **P2, Ev. B**
`StaffPositionCalculator._getClefReference` trata `treble8vb`/`bass8vb` com a **mesma** referência das claves normais (comentário explícito: "o cálculo visual usa apenas a oitava escrita"), mas `c8vb` usa `baseOctave: 3` — isto é, a **convenção oposta** (altura soante). Duas semânticas contraditórias dentro do mesmo `switch`.

E `MidiMapper` **não referencia `Clef` em lugar algum** — `grep` por `Clef|octaveShift|transpos` retorna zero. Logo:
- se `Pitch` for a altura **soante** (convenção do MusicXML, que é o que o parser grava): o **desenho** fica uma oitava errado em claves 8va/8vb;
- se `Pitch` for a altura **escrita** (convenção que o teste `treble8vb_staff_position_test.dart` consagra): o **playback** fica uma oitava errado.

Não existe leitura em que ambos estejam certos.

### Fontes de verdade (§51)

| Dado | Fonte de verdade real | Risco |
|---|---|---|
| altura | `Note.pitch` | ok |
| duração | `Duration` no `Note`; para `Chord`, `Chord.duration` **duplica** a das notas internas (podem divergir sem erro) | médio |
| posição X | `PositionedElement.position` **e** `LayoutEngine._noteXPositions` — dois mapas que precisam ser ressincronizados manualmente após a justificação, e a sincronização **só cobre `Note` de topo, não notas dentro de `Chord`** | **alto** |
| voz | `Note.voice` **e** `Voice.number` **e** `PositionedElement.voiceNumber` — três lugares; `Voice.add()` tem um comentário admitindo que não propaga (`"voice tracking is manual"`) | **alto** |
| barra de ligação | `Note.beam` (sobrescrito por clone) **e** `AdvancedBeamGroup` | **alto** |
| acidente exibido | `Pitch.accidentalGlyph` **e** `LayoutEngine.accidentalDecisions` (identity-keyed, quebra com clones) | **alto** |
| compasso ativo | `Measure.timeSignature` (varre `elements`) **e** `inheritedTimeSignature` (mutado pelo layout) | médio |

---

# 5. ENGRAVING

## 5.1 Notas, hastes, ledger lines

- Posição vertical: `StaffPositionCalculator` é uma boa peça — única fonte, testada (25 testes), com claves C corretas nas 5 linhas e ledger lines calculadas. **Não encontrei evidência de falha aqui.**
- Anexação da haste: `StemRenderer` usa `positioningEngine.calculateStemAttachmentOffset` a partir das âncoras `stemUpSE`/`stemDownNW` da Bravura, com recuo de meia espessura. **Correto e escalável.** (Os antigos empurrões em pixels crus documentados em `MAGIC_NUMBERS_REFERENCE.md` foram removidos — o doc é que ficou para trás.)
- Direção da haste: `farthestPos >= 0 ? down : up` — regra correta (linha central → haste para baixo).

### F-14 · Comprimento de haste em grupos com barra viola o mínimo — **P2, Ev. A**
```
ID: F-14 | SEVERIDADE: P2 | EVIDÊNCIA: A
ARQUIVO: lib/src/beaming/beam_analyzer.dart  LINHA: ~166-172
PROBLEMA: beamBaseY = média de (Y da PRIMEIRA nota, Y da ÚLTIMA nota) ∓ altura padrão.
          O grupo inteiro não é considerado; só as pontas.
MEDIDO (Mi4 + Fá5 colcheias em 2/4, hastes para cima, staffSpace=12):
          Mi4: noteY=84.0  beamY=18.0 → haste = 5,50 SS
          Fá5: noteY=36.0  beamY=15.0 → haste = 1,75 SS   ◄── 50% do mínimo
ESPERADO: Behind Bars — nenhuma haste abaixo de ~2,5 SS; padrão 3,5 SS.
IMPACTO: em qualquer grupo com salto largo, uma haste vira um toco.
         Em grupos com nota interna extrema, a cabeça pode atravessar a barra.
CAUSA RAIZ: a geometria da barra é calculada a partir de 2 pontos, não do envelope
            do grupo. `calculateBeamHeight` recebe `allStaffPositions` mas só o usa
            para estender FORA da pauta (>4 / <-4) — notas internas extremas DENTRO
            da pauta não influenciam nada.
CORREÇÃO ESTRUTURAL: calcular a reta da barra e depois deslocá-la rigidamente até
            que min(comprimento de haste) ≥ mínimo, para TODAS as notas do grupo
            (é o algoritmo do LilyPond/Verovio: fit + shift).
TESTE: invariante "toda haste de todo grupo ≥ 2.5 SS" sobre um corpus gerado.
```

## 5.2 Acidentes

### F-02 · Notas com barra perdem a resolução de acidentes (Behind Bars) — **P1, Ev. A** ⚠ regressão
```
ID: F-02 | SEVERIDADE: P1 | EVIDÊNCIA: A
ARQUIVO: lib/src/layout/layout_engine.dart  LINHAS: 233 e 1726-1813
COMPONENTE: layout / acidentes / beaming / determinismo

PROBLEMA: `accidentalDecisions` = AccidentalResolver.resolve(...) devolve um
  Map<Note, AccidentalDisplay>.IDENTITY, chaveado nas notas ORIGINAIS do modelo.
  Em seguida `_processBeamsWithAnacrusis` CONSTRÓI NOVOS objetos `Note` para toda
  nota que entra num grupo com barra (para gravar o BeamType). Como `Note` não tem
  `==`, `accidentalDecisions[clone]` é sempre `null` → cai no default `.show`.

MEDIDO (4× Fá♯4 no mesmo compasso):
   semínimas: [show, hide, hide, hide]        ✅ correto
   colcheias: [NULL→show, NULL→show, NULL→show, NULL→show]   ❌ 4 sustenidos impressos

DANOS COLATERAIS DO MESMO CLONE:
   (a) `engine.noteXPositions[minhaNota]` → **null** para notas com barra.
       A API pública documentada como "Expor positions X das notas" é inútil
       justamente onde importa (medido: mapa com 2 entradas, nenhuma é a do usuário).
   (b) `PositionedElement.computeSignature` mistura `element.hashCode` (identidade).
       Como os clones mudam a cada execução, a "deterministic signature" do
       `LayoutResult` MUDA entre layouts idênticos.
       MEDIDO: mesmo Staff, 3 execuções → 400447158 / 480065883 / 172987804.
       Efeito: `shouldRepaint` sempre true → o culling de viewport documentado
       nunca economiza nada.
   (c) Qualquer referência externa a `Note` (seleção, hit-test, ligaduras
       resolvidas por identidade, futura edição) quebra após o layout.

COMO REPRODUZIR: 4 colcheias Fá♯4 num compasso; inspecionar
   `engine.accidentalDecisions` e `engine.noteXPositions` após `layout()`.

CAUSA RAIZ ARQUITETURAL: o layout MUTA o modelo musical. `BeamType` é uma decisão
   de LAYOUT armazenada dentro do objeto MUSICAL, e como o objeto é imutável, a
   única saída foi cloná-lo. O nível MUSIC MODEL e o nível LAYOUT MODEL estão
   fundidos.

CORREÇÃO (não é "adicionar um if"):
   Introduzir `LayoutNote { final Note source; BeamType? beam; double x, y; int staffPos; }`
   e mover `beam` para lá. `PositionedElement` passa a apontar para `source`, e
   TODOS os mapas passam a ser chaveados por `source`. Alternativa mínima
   (paliativa): propagar as entradas dos mapas para os clones no momento da clonagem
   — resolve (a) e (b) mas mantém a dívida.

RISCO DA CORREÇÃO: médio-alto (toca beaming, render e goldens).
TESTE NECESSÁRIO: (i) invariante `noteXPositions.keys ⊇ notas do modelo`;
   (ii) `layoutWithSignature().signature` estável em N execuções;
   (iii) golden de 4 colcheias Fá♯ mostrando 1 sustenido.
```

### F-16 · Acidentes de cortesia/editoriais são descartados — **P2, Ev. A**
`AccidentalResolver._decide` ignora `note.accidentalParenthesis`. Medido: uma nota marcada `AccidentalParenthesis.parentheses` cuja alteração já vigora no compasso recebe `hide` — o acidente de cortesia **some**. O campo do modelo (importado corretamente do MusicXML `cautionary`/`parentheses`) é decorativo nesse caminho.

### F-27 · Larguras de acidente: um ramo morto e dois valores errados — **P3, Ev. B**
Em `_getElementWidthSimple`:
```dart
if (glyphName.contains('Flat') || glyphName.contains('flat')) accWidth = accidentalFlatWidth;
else if (...'Natural'...) accWidth = 0.92;
else if (...'DoubleSharp') accWidth = 1.0;
else if (...'DoubleFlat')  accWidth = 1.5;   // ◄── INALCANÇÁVEL
```
`'accidentalDoubleFlat'` contém `'Flat'` → cai no primeiro ramo. O ramo do dobrado-bemol **nunca executa**. Valores reais da Bravura vs. usados:

| Glifo | Bravura (real) | Código | Erro |
|---|---|---|---|
| `accidentalNatural` | 0,672 | 0,92 hardcoded | +37% (superdimensiona) |
| `accidentalDoubleFlat` | 1,652 | 1,18 (via ramo `Flat`) | **−29%** (colide com a nota anterior) |
| `accidentalFlat` (fallback) | 0,904 | `_accidentalFlatWidthFallback = 1.18` | valor copiado de `noteheadBlack` |
| `fClef` (fallback) | 2,736 | `_fClefWidthFallback = 2.756` | fallback escrito à mão, não derivado |

Todos esses números **já estão no `bravura_metadata.json` carregado**. São magic numbers redundantes com a própria fonte de verdade.

## 5.3 Beaming

### F-03 · Compassos compostos agrupam errado (3/8, 6/8, 9/8, 12/8) — **P1, Ev. A** ⚠ patch pela metade
```
ID: F-03 | SEVERIDADE: P1 | EVIDÊNCIA: A
ARQUIVO: lib/src/layout/beam_grouper.dart  LINHAS: 173-210 (_groupCompoundTime)

PROBLEMA: a quebra de grupo testa o compasso do FIM da nota:
    final currentBeat = (currentBeatPosition / beatUnit).floor();
    final nextBeat    = (nextBeatPosition   / beatUnit).floor();
    if (currentBeat != nextBeat && currentGroup.isNotEmpty) { flush; }
  A nota que COMPLETA o tempo é empurrada para o grupo seguinte (off-by-one),
  porque `nextBeatPosition` já pertence ao tempo seguinte.

MEDIDO:
  3/8  × 3 colcheias  → [start, end, null]                       (esperado 3 ligadas)
  6/8  × 6 colcheias  → [start, end | start, inner, end | null]  (esperado 3+3)
  9/8  × 9 colcheias  → [2 | 3 | 3 | órfã]                       (esperado 3+3+3)
  12/8 × 12 colcheias → [2 | 3 | 3 | 3 | órfã]                   (esperado 3+3+3+3)
  6/8  × 12 semicolcheias → [5 | 6 | órfã]                       (esperado 6+6)
  3/4  × 6 colcheias  → [2|2|2]  ✅   2/4 × 8 semicolch. → [4|4] ✅

POR QUE O BUG EXISTE: `_groupSimpleTime` FOI CORRIGIDO — o comentário no código
  documenta a correção ("Previously the break only fired when a SINGLE note
  spanned two beats — which never happens for eighths... (V4)") e usa
  `startBeat = (currentPosition / beatUnit + 0.0001).floor()`.
  `_groupCompoundTime` FICOU COM A LÓGICA ANTIGA. O patch foi aplicado a um
  caminho e esquecido no gêmeo.

IMPACTO: 6/8, 9/8 e 12/8 são dos compassos mais comuns da música ocidental.
  Toda partitura nesses compassos sai visivelmente errada e com uma nota solta
  com bandeirola no fim de cada compasso.

CORREÇÃO: unificar as três funções (`_groupSimpleTime`, `_groupCompoundTime`,
  `_groupIrregularTime`) numa única que receba a LISTA DE SUBDIVISÕES do compasso
  e agrupe pelo início da nota. Elimina a duplicação que causou o esquecimento.
RISCO: baixo. TESTE: tabela de compassos × contagens esperadas por grupo.
```

Também: `_getGroupingStrategy` classifica **3/8 como composto** (`denominator==8 && numerator%3==0`). 3/8 é simples ternário — deveria ser um único grupo de 3, e a rota "composta" com `beatUnit = 3/8` colide com o off-by-one acima.

O que **funciona** no beaming: barras parciais/fracionárias (medido: colcheia pontuada + semicolcheia → `L1:0-1, L2:1-1F` — correto), níveis secundários por duração, e o desenho das hastes a partir da barra (`renderOnlyNotehead` evita haste dupla).

## 5.4 Ligaduras (slurs/ties)

### F-26 · O renderizador de ligaduras não conhece o conceito de sistema — **P2, Ev. B/A**
`grep -n "system" lib/src/rendering/renderers/slur_renderer.dart` → **zero ocorrências**. Medido: uma ligadura de valor com início no sistema 2 (x=248,7) e fim no sistema 3 (x=80,2) existe no layout. Sem noção de sistema, a curva é traçada de um ponto ao outro — atravessando para trás e por cima de outra pauta — ou é descartada. Ligaduras que cruzam quebra de linha **precisam** ser partidas em dois segmentos (Behind Bars).

O que existe de bom: `SlurRenderer` usa `slurEndpointThickness`/`slurMidpointThickness` da Bravura e âncoras `stemUpSE`/`stemDownNW`; há `SkyBottomLineCalculator` alimentado por notas/pausas para evitar colisão. `SlurEvent` numerado suporta ligaduras concorrentes/aninhadas no modelo e é importado do MusicXML `<slur number=>`.

## 5.5 Letras (lyrics)

### F-15 · Sílabas não influenciam o espaçamento horizontal — **P2, Ev. A**
```
MEDIDO (3 semínimas, staffSpace=12, largura 5000 px):
   sem sílaba          → espaçamento 56,16 px
   sílaba "a"          → 56,16 px
   sílaba "Christe"    → 56,16 px
   sílaba "Extraordinarily" → 56,16 px
```
`_getElementWidthSimple(Note)` considera acidente e pontos, mas **nunca** `note.syllables`. Uma sílaba longa simplesmente se sobrepõe à nota seguinte. Isso invalida qualquer uso vocal/coral sério — e é exatamente o requisito §15 do briefing.

(Existe hífen e uma "melisma line" de 1 SS fixa; as issues #13/#14 do projeto já reconhecem que ambas precisam de um segundo passe de layout.)

## 5.6 Outros elementos

- **Articulações:** `ArticulationRenderer` posiciona acima/abaixo conforme a haste; empilhamento múltiplo listado como PARTIAL pelo próprio backlog (#13).
- **Dinâmicas:** 9 de 36 tipos renderizados (README honesto); *hairpins* com comprimento automático até a próxima dinâmica/barra — bom. Espessura vem de `hairpinThickness` da Bravura. ✅
- **Quinálteras:** colchete e número renderizados, com número multidígito e razão; mas as notas internas estão fora do pipeline (F-25).
- **Barras de compasso e repetições:** 15 tipos; `repeatBoth` com fallback; espessuras `thinBarlineThickness`/`thickBarlineThickness` da Bravura. ✅ Mas `LayoutEngine.barlineSeparation = 2.5` (constante Dart) contra `barlineSeparation: 0.4` da Bravura — **6× maior que o padrão SMuFL**, ignorando o metadado carregado.
- **Números de compasso:** **inexistentes no desenho** (F-33).

---

# 6. LAYOUT ENGINE

## F-12 · Duas fórmulas de largura incompatíveis — **P1, Ev. A/B (causa raiz de F-05)**
```
ID: F-12 | SEVERIDADE: P1 | EVIDÊNCIA: A
ARQUIVO: lib/src/layout/layout_engine.dart  LINHAS: 802-827 vs 1656-1722

ESTIMATIVA (decide quebra de sistema):
   totalWidth += Σ larguras;  totalWidth += (nMusicais - 1) × 3.5 × staffSpace
   ← ESPAÇAMENTO FIXO, INDEPENDENTE DA DURAÇÃO

REALIDADE (posiciona as notas):
   spacing = 3.5 × fator(duração da nota ANTERIOR) × staffSpace
   ← fator: semibreve 2.0 … fusa 0.25

DIVERGÊNCIA: para semibreves a realidade gasta 2× a estimativa; para semicolcheias
   gasta 0,5×. As decisões de quebra são tomadas com números que não descrevem o
   desenho.
```

## F-05 · Compasso mais largo que a linha estoura e é cortado — **P1, Ev. A**
```
ID: F-05 | SEVERIDADE: P1 | EVIDÊNCIA: A
ARQUIVOS: layout_engine.dart (LayoutCursor.needsSystemBreak:108) + flutter_notemus.dart (~340)

CADEIA:
 1. `needsSystemBreak` retorna false incondicionalmente para o PRIMEIRO compasso
    do sistema — correto em si (não há para onde quebrar)...
 2. ...mas não existe NENHUM mecanismo de compressão, redução de escala local
    ou quebra intra-compasso quando o compasso não cabe.
 3. O widget monta `SizedBox(width: viewportWidth)` e `CustomPaint(size: Size(viewportWidth, ...))`.
    O `SingleChildScrollView` horizontal envolve um filho de largura EXATAMENTE
    igual ao viewport → **nunca rola**.
 4. `painter.paint` faz `canvas.clipRect(0,0,size.width,size.height)`.

MEDIDO: 1 compasso com 32 semicolcheias, availableWidth=400 → maxX = 1222,7 px,
        um único sistema. **~67% da música fica fora da tela, sem rolagem.**

IMPACTO: perda visual total de conteúdo musical. Em telas estreitas (celular)
        qualquer compasso denso desaparece parcialmente.
CORREÇÃO ESTRUTURAL: (a) unificar a métrica de largura (F-12); (b) implementar
        compressão proporcional quando largura_necessária > largura_disponível
        (reduzir espaçamento até o mínimo de colisão, depois reduzir staffSpace);
        (c) tornar o canvas realmente rolável horizontalmente como fallback.
TESTE: invariante `max(x) ≤ availableWidth` para um corpus de densidades.
```

## F-11 · Inversão rítmica fora da faixa semínima–fusa — **P2, Ev. A**
```
final durationFactors = { whole:2.0, half:1.414, quarter:1.0, eighth:0.707,
                          sixteenth:0.5, thirtySecond:0.354, sixtyFourth:0.25 };
...
final factor = durationFactors[prevDuration] ?? 1.0;   // ◄── fallback fatal
```
`breve`, `long`, `maxima`, `128th`, `256th`, `512th`, `1024th`, `2048th` **não estão no mapa** e caem em `1.0` (= semínima).

Medido (largura ocupada por 4 notas iguais, staffSpace=12):

| Duração | Vão medido | Esperado (√) |
|---|---|---|
| breve | 168,5 | > semibreve |
| **semibreve** | **294,5** | 294,5 |
| mínima | 220,6 | ✓ |
| semínima | 168,5 | ✓ |
| colcheia | 131,6 | ✓ |
| semicolcheia | 105,5 | ✓ |
| fusa | 87,1 | ✓ |
| semifusa | 74,0 | ✓ |
| **1/128** | **168,5** | ~63 |
| **1/256** | **168,5** | ~57 |

Uma **breve fica mais estreita que uma semibreve**, e uma **1/128 ocupa 2,3× o espaço de uma 1/64**. O `DurationType` anuncia `maxima → 2048th`; o espaçador cobre 7 dos 15 valores.

## F-13 · "Justificação" é um estiramento afim — **P2, Ev. A**
`_justifyHorizontally` calcula `offset = extraSpace × (x - minX)/(maxX - minX)` e soma a cada elemento. Isso multiplica **todos** os vãos pelo mesmo fator, incluindo o bloco fixo clave→armadura→fórmula, que por convenção **não** deve ser esticado. Além disso:
- `fillThreshold = 0.7`: sistemas que preenchem menos de 70% **não são justificados**. Medido em 1400 px de largura: `maxX = 930` de 1340 úteis (69%) → sistema deixado irregular **no meio da partitura**, não só na última linha.
- `minX`/`maxX` incluem elementos flutuantes (dinâmicas, textos), distorcendo a razão.
- A ressincronização pós-justificação de `_noteXPositions` **só cobre `PositionedElement.element is Note`** — notas dentro de `Chord` mantêm X pré-justificação (o mapa é escrito por `LayoutCursor.addElement` para cada nota do acorde). Barras sobre acordes lêem esse mapa.

## F-01 · Mudança de clave no meio do compasso corrompe a altura desenhada — **P1, Ev. A**
```
ID: F-01 | SEVERIDADE: P1 | EVIDÊNCIA: A
ARQUIVOS: layout_engine.dart:1036-1046 (_layoutMeasureCursor)
          layout_engine.dart:148-210  (LayoutCursor.addElement)

PROBLEMA: `_layoutMeasureCursor` particiona os elementos em
   `systemElements` (Clef/KeySignature/TimeSignature) e `musicalElements`,
   e desenha TODOS os systemElements PRIMEIRO, no início do compasso,
   independentemente da posição original. Em seguida, `LayoutCursor.addElement`
   grava `_currentClef` na ordem em que recebe os elementos — logo, quando as
   notas chegam, `_currentClef` já é a ÚLTIMA clave do compasso.

COMPORTAMENTO ATUAL (medido) — compasso [Clave Sol, Dó4, Clave Fá, Dó4]:
   Clef   x=30.0     Clef   x=68.2      ◄ as duas claves no início da barra
   Note   x=121.4  y=24.0
   Note   x=177.6  y=24.0               ◄ AS DUAS NOTAS NA MESMA ALTURA
   Dó4 em clave de sol deveria estar em staffPosition -6 (y=96);
   ambas foram desenhadas em staffPosition +6 (y=24) = clave de fá.
   ERRO: 12 posições de pauta (uma décima segunda) na primeira nota.

IMPACTO: mudança de clave no meio do compasso é padrão em piano, violoncelo,
   fagote e trombone. A partitura sai com alturas erradas E com o símbolo da
   clave no lugar errado. É corrupção musical visível.

CAUSA RAIZ: o layout confunde "elemento de cabeçalho de sistema" com "elemento
   que aparece no início do compasso". A informação de ordem temporal é perdida
   pela partição.

CORREÇÃO ESTRUTURAL: não particionar. Percorrer os elementos NA ORDEM,
   tratando clave/armadura/fórmula como elementos posicionáveis no fluxo
   (renderizados em tamanho de cue quando ocorrem no meio — o
   `StaffRenderer._renderElement` já detecta isso e aplica `sizeFactor: 0.72`,
   mas nunca recebe o caso porque o layout já reordenou).
   O cabeçalho de sistema (restatement) já é injetado separadamente pelo caller.
RISCO: médio (mexe no núcleo do posicionamento). TESTE: golden de mudança de
   clave intra-compasso + asserção de staffPosition por nota.
```

## F-08 · Reutilizar a mesma instância de `Note` apaga notas — **P1, Ev. A**
```
ID: F-08 | SEVERIDADE: P1 (perda silenciosa de dados) | EVIDÊNCIA: A
ARQUIVO: lib/src/layout/layout_engine.dart:1756  (`final processedNotes = <Note>{}`)

  for (final element in elements) {
    if (element is Note && !processedNotes.contains(element)) { ... }
    else if (element is! Note) { processedElements.add(element); }
    // ◄ a segunda ocorrência de uma MESMA instância cai em NENHUM ramo
  }

MEDIDO: 3 instâncias idênticas de `Note` adicionadas ao compasso →
        **1 nota renderizada**. Duas desapareceram sem aviso, sem exceção,
        sem warning.
IMPACTO: `final n = Note(...)` reutilizado em ritmos repetidos é um idioma
        natural em Dart. A biblioteca engole notas.
CORREÇÃO: usar índice (não conjunto de identidade) para marcar processamento:
        iterar por índice e consumir `beamGroups` por posição.
TESTE: invariante `count(Note em elements) == count(Note em positionedElements)`.
```

## F-30 · Colisão entre vozes casada por `dx.round()` — **P3, Ev. B**
`_resolveCrossVoiceCollisions` agrupa por `'${system}_${dx.round()}'`. Como as vozes 2+ são posicionadas por **interpolação linear** na linha do tempo da voz 1, dois ataques simultâneos podem cair em 123,4 e 123,6 → chaves `123` e `124` → **nenhum grupo, nenhuma resolução de colisão**. Além disso o algoritmo só desloca (para a esquerda, uma largura de cabeça) e só trata `minDiff ≤ 1`; uníssonos entre vozes deveriam fundir/compartilhar cabeça, não deslocar.

## Onde o layout **está** bem
- Reafirmação de clave/armadura no início de cada sistema (`layoutInternal`, com deduplicação contra clave já presente no compasso). ✅
- Elementos flutuantes (dinâmicas, tempo, oitavas, voltas, respirações) corretamente excluídos do avanço do cursor e co-posicionados com o elemento rítmico seguinte. ✅ Boa decisão.
- Pausa de compasso inteiro centralizada entre o conteúdo e a barra (Behind Bars p.158). ✅
- **Complexidade real: linear.** Medido: 50→800 compassos = 20→82 ms. Não há O(n²) no layout.
- **Posições são determinísticas.** Medido: duas execuções sobre o mesmo `Staff` produzem sequências de `(tipo, x, y, sistema)` idênticas. Goldens são confiáveis.

---

# 7. SMuFL / BRAVURA

## O que é genuíno

- `bravura_metadata.json` completo: 642 glifos com âncoras, `glyphBBoxes`, `glyphAdvanceWidths`, 29 `engravingDefaults`.
- **Âncoras realmente usadas:** `stemUpSE`/`stemDownNW` para anexação de haste (`smufl_positioning_engine.dart:102-152`), `cutOutNW` para compensação óptica, `opticalCenter` em marcas de repetição, `above`/`below` para articulações.
- **`engravingDefaults` realmente usados:** `staffLineThickness`, `stemThickness`, `thinBarlineThickness`, `thickBarlineThickness`, `legerLineThickness`, `legerLineExtension`, `hairpinThickness`, `beamThickness`, `beamSpacing`, `bracketThickness`, `slur*Thickness`, `tie*Thickness`, `tupletBracketThickness`.
- **Nenhum codepoint Unicode hardcoded** — `grep` por `'\uE0xx'` em `lib/` retorna zero. Tudo passa por `glyphnames.json`. Isso é raro e bem feito.
- Registro da fonte com nome qualificado por pacote (`packages/flutter_notemus/Bravura`), com o harness de golden usando isso como guarda contra regressão.

## Onde não é SMuFL-compliant, é Bravura-compatible

### F-40 · `SmuflMetadata` é singleton de processo — **P3, Ev. B**
```dart
static final SmuflMetadata _instance = SmuflMetadata._internal();
factory SmuflMetadata() => _instance;
...
rootBundle.loadString('packages/flutter_notemus/assets/smufl/bravura_metadata.json')
```
O caminho do asset é **literal**. Não existe API para carregar Petaluma, Leland, Sebastian ou qualquer outra fonte SMuFL. Trocar de fonte exige editar o pacote. Um estado global mutável também impede duas partituras com fontes diferentes no mesmo app e complica testes paralelos.

### F-28 · Constantes que contradizem os metadados carregados — **P3, Ev. B**
| Constante no código | Valor | SMuFL/Bravura | Comentário |
|---|---|---|---|
| `LayoutEngine.barlineSeparation` | **2.5** SS | `barlineSeparation: 0.4` | 6× o padrão; nome idêntico ao do metadado |
| `LayoutEngine.legerLineExtension` | 0.4 | `legerLineExtension: 0.4` | duplicado (correto, mas redundante) |
| `SMuFLPositioningEngine.standardStemLength` | `_loadEngravingDefault('stemLength', 3.5)` | **`stemLength` NÃO EXISTE em `engravingDefaults`** | lê uma chave inexistente; sempre cai no fallback 3,5. Aparência de derivação, realidade de magic number |
| `BeamRenderer.stemThickness` | `0.12 * staffSpace` | `stemThickness: 0.12` | hardcoded em vez de ler o metadado ao lado |
| `minimumBeamSlant / maximumBeamSlant / twoNoteBeamMaxSlant` | 0.15 / 0.5 / 0.5 | — | heurísticas (comentário: *"Reduced maximum (was 1.0, too steep!)"*) |
| `_fClefWidthFallback` | 2.756 | 2.736 | fallback escrito à mão |
| `_accidentalFlatWidthFallback` | 1.18 | 0.904 | valor de `noteheadBlack` copiado por engano |

### F-41 · Falha silenciosa se os metadados não carregarem — **P3, Ev. B**
`staff_renderer.dart:102,105` chamam `metadata.getEngravingDefault('staffLineThickness')` **sem fallback** → o default do método é `0.0`. Pauta com espessura zero = invisível, sem erro.

**Resposta direta à pergunta §13:** o código é **Bravura-compatible com uso correto de metadados SMuFL**, não SMuFL-agnostic. Trocar a fonte hoje exige editar constantes de fallback, o caminho do asset, e revalidar 52 goldens.

---

# 8. MUSICXML

## 8.1 Importação — o que entra de verdade

| Elemento | Status | Nota |
|---|---|---|
| `score-partwise` / `score-timewise` | ✅ | ambos |
| `part-list` / `part-group` / `group-symbol` | ✅ | vira `StaffGroup` com `BracketType` |
| múltiplas partes e múltiplas pautas por parte | ✅ | `parseMusicXmlScore` → `Score` |
| `attributes` (clef/key/time/staves) | ✅ | filtro por `<clef number>` |
| **`divisions`** | ❌ | **nunca lido** |
| **`duration`** | ❌ | **nunca lido** |
| `type` + `dot` | ✅ | única fonte de duração |
| `pitch` (step/octave/alter) | ✅ | |
| `accidental` (+ `cautionary`/`parentheses`) | ✅ | importado (mas descartado depois — F-16) |
| `chord` | ✅ | fusão em `Chord` |
| **`backup`** | ❌ | `case 'backup': break;` |
| **`forward`** | ❌ | `case 'forward': break;` |
| `voice` | ✅ | única base da polifonia |
| `staff` + cross-staff | ✅ | `_crossStaffMap` com `crossStaffMove` |
| `beam` | ◐ | **só o primeiro `<beam>`**; `number=2,3,4` perdidos |
| `tuplet` / `time-modification` | ✅ | |
| `tie` | ◐ | último `<tie>` vence; nota que é `stop`+`start` perde um |
| `slur` (incl. `number`) | ✅ | `SlurEvent` |
| `articulations` (17) | ✅ | |
| `ornaments` + `fermata` | ✅ | |
| `lyric` (`text`, `syllabic`) | ✅ | `Syllable`/`SyllableType` |
| `direction` (dinâmicas, tempo, segno/coda, wedge, octave-shift) | ✅ | |
| `barline` / `repeat` / `ending` | ✅ | |
| `breath-mark` / `caesura` | ✅ | |
| `grace` | ✅ | flag; `slash`/`steal-time` não |
| `transpose` (instrumentos transpositores) | ❌ | |
| `percussion` / `unpitched` | ❌ | `_musicXmlPitch` devolve `null` → **nota descartada** |
| `cue` | ❌ | |
| `sound` (tempo em `<sound tempo=>`) | ❌ | |

### F-06 · `<divisions>`/`<duration>` ignorados — **P1, Ev. A**
```
MEDIDO: <divisions>4</divisions> + <duration>16</duration> sem <type>
        → importado como SEMÍNIMA (correto: semibreve).
```
`<type>` é **opcional** no MusicXML; `<duration>` é a fonte autoritativa de tempo. Exportadores reais omitem `<type>` (notadamente em pausas de compasso `<rest measure="yes"/>` e em saídas programáticas). O resultado é corrupção rítmica silenciosa.

### F-07 · `<backup>`/`<forward>` ignorados — **P1, Ev. A**
```
MEDIDO (compasso 4/4 com <backup>):
   [mínima Dó5][mínima Ré5]<backup 16>[semibreve Dó4]
   → Measure simples com 3 notas EM SEQUÊNCIA, valor somado = 2,0 num compasso de 1,0.
MEDIDO (<forward> de 2 tempos antes da voz 2):
   voz 2 = [Sol3/mínima] começando no tempo 1 em vez do tempo 3.
```
A polifonia funciona **apenas** quando o arquivo traz `<voice>` explícito. Sem ele (exportadores simples, arquivos legados) as vozes colapsam em sequência. `<forward>` (lacunas intencionais, vozes que entram tarde) desloca todos os ataques seguintes.

## 8.2 Exportação — o que sai

Correto: `divisions=480`, `<duration>` calculado (incluindo razão de quinálteras), clave com `clef-octave-change`, armadura, fórmula, acidentes, pontos, articulações, ligaduras de valor e de expressão, ornamentos, letras, barras, repetições, `<backup>` entre vozes em `MultiVoiceMeasure`.

---

# 9. MEI

## F-17 · Apenas a primeira `<section>` é lida — **P2, Ev. A**
```dart
final section = score.findAllElements('section').firstOrNull;
if (section == null) return Staff();
```
```
MEDIDO: documento MEI com 2 <section> (1 compasso cada) → 1 compasso importado.
        A segunda metade da peça desaparece sem aviso.
```
MEI usa `<section>` para divisões estruturais de forma rotineira (e `<ending>`/`<expansion>` para repetições). Descartar tudo além da primeira é perda de dados de primeira ordem.

## Outros achados MEI

- **Contêineres `<beam>`/`<tuplet>` tratados corretamente** (recursão com `beamOverride` posicional) — boa correção, confirmada em `mei_import_test.dart`.
- **Eventos de controle por `@startid`/`@endid`** (slur, tie, dynam) resolvidos por `xml:id` — arquitetura certa para MEI.
- **F-42 (P4):** `_slurById`/`_tieById`/`_afterNoteById` são campos de instância **nunca limpos entre compassos**. `xml:id` duplicados (documentos malformados) produzem ligaduras fantasma.
- Não implementado (e **corretamente documentado** como model-only): `<neume>`, mensural, `@tab.*`, `meiHead`, análise harmônica, baixo cifrado, `@mode`, compasso aditivo.

## Classificação por módulo (o que a auditoria confirma)

| Módulo | MODEL | PARSED | RENDERED | EXPORTED | ROUND-TRIP |
|---|---|---|---|---|---|
| CMN núcleo (nota/pausa/acorde) | ✅ | ✅ | ✅ | ✅(MusicXML) | ◐ |
| Clave/armadura/compasso | ✅ | ✅ | ✅ | ✅ | ✅ |
| Beam | ✅ | ◐ | ◐ (F-03) | ✅ | ◐ |
| Tuplet | ✅ | ✅ | ◐ (F-25) | ✅ | ◐ |
| Slur/Tie | ✅ | ✅ | ◐ (F-26) | ✅ | ◐ |
| Polifonia (layer/voice) | ✅ | ✅ | ◐ | ✅ | ◐ |
| Dinâmicas | ✅ | ✅ | ◐ (9/36) | ❌ | ❌ |
| Letras | ✅ | ✅ | ◐ (F-15) | ✅ | ✅ |
| Estrutura (section) | ✅ | ❌ (F-17) | — | ❌ | ❌ |
| Neume/Mensural/Tab/meiHead/Harmonia/Baixo cifrado | ✅ | ❌ | ❌/gregoriano à parte | ❌ | ❌ |

---

# 10. MIDI / PLAYBACK

**Este é o subsistema mais sólido do projeto.** Fui adversarial e não consegui quebrá-lo nos casos testados.

## Verificado (Ev. A, PPQ 960)

| Teste | Resultado | Veredito |
|---|---|---|
| Nota + pausa | `noteOn 60 @0` / `noteOff @960`; pausa não gera evento | ✅ |
| Ligadura de valor | Ré4 `@960 → @2880` (duas semínimas fundidas num evento) | ✅ |
| Quiáltera 3:2 de colcheias | 3 notas de **320 ticks** cada, total exato 960 | ✅ |
| Polifonia (`MultiVoiceMeasure`) | Dó5 0–1920, Ré5 1920–3840, Dó4 0–3840 (sobreposto) | ✅ |
| Repetição `repeatForward`…`repeatBackward` | ordem `60, 62, 64, 60, 62, 64, 65` | ✅ |
| Faixa Conductor | `tempo bpm=120 @0` + `timeSignature 4/4 @0` | ✅ |
| Notas de ornamento (appoggiatura) | rouba tempo da principal (`graceStart = startTick - graceTicks`) | ✅ correto |
| Voltas | `MidiEvent.marker('volta …')` + filtro por passe | ✅ |
| Warnings | canal `warnings[]` na `MidiSequence` | ✅ boa prática |

## Limitações reais (não bugs, mas tetos arquiteturais)

### F-24b · Claves transpositoras ignoradas — **P2, Ev. A**
`MidiMapper` não referencia `Clef`. Ver F-24: uma parte de tenor em clave de sol 8vb toca uma oitava errada em uma das duas convenções possíveis. Idem `<transpose>` do MusicXML (não importado).

### §30 — Seleção por parte/pauta/voz
- **Por pauta:** ✅ possível hoje — `MidiMapper.fromScore` gera **uma faixa por pauta** (`'Staff N'`) com instrumento configurável via `options.instrumentsByStaff`.
- **Por voz:** ❌ **todas as vozes de uma pauta compartilham a mesma faixa e o mesmo canal** (medido: `ch=0` para as duas vozes). Não há como solar/silenciar uma voz.
- **Por região/seleção da partitura:** ❌ nenhuma API aceita intervalo de compassos.
- **Mudanças necessárias:** (1) carregar `voiceNumber` nos `MidiEvent`/`MidiTrack` e emitir uma faixa por (pauta, voz); (2) parametrizar `_buildTrackFromStaff` com `measureRange`; (3) expor `mute`/`solo` em `MidiGenerationOptions`. É trabalho localizado — o mapeador já percorre vozes separadamente.

## Playback nativo — realidade por plataforma (Ev. B)

| Plataforma | Implementação | Status |
|---|---|---|
| **Android** | `native_audio_engine.cpp` (608 linhas) + `FlutterNotemusPlugin.kt` (350) | ✅ motor real |
| iOS | `FlutterNotemusPlugin.swift` (32 linhas) | ⚫ stub: `nativeIsReady → false` |
| macOS | idem (32 linhas) | ⚫ stub |
| Windows | `flutter_notemus_plugin.cpp` (64 linhas) | ⚫ stub |
| Linux | `flutter_notemus_plugin.cc` (84 linhas) | ⚫ stub |
| Web | `flutter_notemus_web.dart` (44 linhas) | ⚫ stub |

Isto está **corretamente documentado** em `doc/OPEN_ISSUES.md` #1/#15. Não é uma divergência — é uma limitação declarada.

---

# 11. GREGORIAN

Este é o subsistema com o design mais **deliberado** do projeto, e a abordagem está certa: usar os **neumas pré-compostos da Greciliae** (desenhados por tipógrafos de canto) em vez de montar geometria a partir de Bravura. Isso é a decisão correta e diferencia o projeto.

## O que é musical de verdade (não só glifo)

| Elemento | Musical? | Evidência |
|---|---|---|
| Punctum, virga, punctum inclinatum, quilisma, oriscus, stropha | ✅ | formas de `NcForm`, mapeadas por nome de glifo |
| Podatus/pes, clivis/flexus, torculus, porrectus, scandicus, climacus | ✅ | **classificados a partir do contorno melódico** (âmbito diatônico), não pedidos pelo usuário |
| Climacus descendente | ✅ | montado a partir de Punctum + PunctumInclinatum (não há glifo pré-composto para todo âmbito) |
| Liquescência / deminutus | ✅ | modificadores `~ < >` do GABC |
| Episema, ictus, mora | ✅ | glifos dedicados, com **variante de episema por forma da cabeça** |
| Divisiones (` , ; : ::) | ✅ | com espaçamento assimétrico de respiração |
| Custos | ✅ | com variante de comprimento pela distância até a próxima altura |
| Clave do/fá em linhas 1–4, bemol de clave (`cb`/`fb`) | ✅ | altura relativa à linha da clave |
| Sílabas, hifenização por contiguidade no fonte GABC | ✅ | inclusive hífen repetido para sílabas distantes |
| Playback | ✅ | `ChantMidiMapper` com `softB` (si bemol de clave) propagado do parser |

Isso é **muito além de "desenhar símbolos"**. A classificação por contorno é a parte difícil e ela existe.

## F-29 · Descalibração vertical: 147 vs ~157,5 unidades por grau — **P3, Ev. B (medido no asset)**
```
ID: F-29 | SEVERIDADE: P3 | EVIDÊNCIA: B (medição direta do greciliae_glyphnames.json)
ARQUIVO: lib/src/rendering/gregorian/gregorian_renderer.dart:60-62

const double _fontScale     = 3.4;    // fontSize = staffSpace * 3.4
const double _unitsPerStep  = 147.0;  // "um grau diatônico = 147 unidades de fonte"
const double _firstNoteAnchor = 70.0;

MEDIÇÃO NO ARQUIVO DE FONTE ENVIADO (unitsPerEm = 1000), centro do bbox:
   PesOneNothing   cy = 158,5
   PesTwoNothing   cy = 230,0   Δ = 71,5
   PesThreeNothing cy = 309,0   Δ = 79,0
   PesFourNothing  cy = 388,0   Δ = 79,0
   → o centro sobe 79 por +1 de âmbito ⇒ a NOTA SUPERIOR sobe 2×79 = **158 unidades por grau**.
   Confirmação independente por ymax: 344 → 480 → 638 → 796 → 953
   (Δ = 136, 158, 158, 157).

DISCREPÂNCIA: o renderizador desenha as LINHAS da pauta assumindo 147 u/grau
   (lineGap = 2×147×scale = 0,9996 × staffSpace — daí o 3,4 ter sido escolhido),
   mas as notas INTERNAS de cada neuma pré-composto estão a ~157,5 u/grau.
   Erro relativo: **+7,1%, cumulativo com o âmbito.**
   Âmbito 4 → desvio de 4 × 10,5 = 42 unidades = 0,143 espaço de pauta
   (≈29% da distância linha↔espaço). Âmbito 5 → 0,18 SS.

EFEITO: em neumas de âmbito grande (pes/scandicus/porrectus amplos) a nota
   superior não assenta exatamente na linha/espaço; fica visivelmente "entre".
POR QUE PASSOU: os goldens capturam o que o renderizador produz — validam
   regressão, não correção contra a métrica da fonte.
CORREÇÃO: `_unitsPerStep = 157.5` e `_fontScale = 1000/(2×157.5) ≈ 3.175`,
   preservando lineGap == staffSpace. Ou derivar ambos da fonte em tempo de
   carga (os dados já estão no JSON: `centerYUnits` já é lido).
TESTE: property test — para cada PesN, |cy(PesN) − cy(PesN−1) − _unitsPerStep/2| < 2.
```

## Outras limitações do gregoriano

- Pipeline **totalmente separado**: não passa por `PositionedElement`, `LayoutEngine`, `CollisionDetector` nem pelo skyline. Não há reuso de nada do CMN.
- `GabcResult` carrega **apenas a primeira clave** para o renderizador; mudanças de clave no meio do canto são parseadas mas o registro visual inicial não acompanha (documentado no próprio comentário do parser).
- Fusões complexas (`@`), acidentes suaves e claves duplas: "degradam graciosamente" (assumido pelo autor, Tier B v1).
- Altura absoluta declaradamente adiada ("absolute pitch deferred") — as alturas são relativas à clave, o que é musicalmente correto para canto, mas o `ChantMidiMapper` precisa então fixar uma referência (usa dó4/fá4).

**Veredito gregoriano:** ✅ **realmente implementado e musicalmente informado**, com uma descalibração vertical de ~7% mensurável e corrigível em duas linhas. É a parte do projeto mais próxima de "qualidade de editor".

---

# 12. POLYPHONY / MULTI-STAFF

## F-04 · A pauta múltipla não tem linha do tempo compartilhada — **P1, Ev. A**
```
ID: F-04 | SEVERIDADE: P1 | EVIDÊNCIA: A
ARQUIVO: lib/src/rendering/grand_staff_painter.dart  (_alignStaves, ~linha 223)

ARQUITETURA ATUAL: um `LayoutEngine` INDEPENDENTE por pauta. Depois,
   `_alignStaves` extrai âncoras = [X do primeiro elemento musical] + [X de cada
   barra de compasso] e remapeia cada pauta por interpolação linear por trechos
   até as âncoras compartilhadas (máximo entre pautas).

CONSEQUÊNCIA: DENTRO de um compasso, cada pauta mantém seu próprio espaçamento
   proporcional. Eventos simultâneos só se alinham por coincidência.

MEDIDO (compasso 4/4, clave de sol com 4 semínimas, clave de fá com 2 mínimas,
        staffSpace=12, largura 600):
   sol: [116.2, 172.4, 228.5, 284.7]
   fá : [116.8, 190.4]
   tempo 1: Δ = 0,6 px    ✅
   tempo 3: Δ = 38,1 px   ❌  (>3 espaços de pauta)

ESPERADO: em qualquer editor profissional o tempo 3 das duas mãos está na
   MESMA coordenada X. É o requisito mais básico de partitura de teclado.

CAUSA RAIZ ARQUITETURAL: não existe um "sistema de espaçamento" que receba
   TODOS os eventos de TODAS as pautas, construa uma linha do tempo rítmica
   única (a "spring/rod chain" do Gould–Verovio–LilyPond) e derive UMA coluna X
   por instante musical.

CORREÇÃO ESTRUTURAL (não é patch):
   1. Extrair da `LayoutEngine` um passe `TimeGrid.build(List<Staff>)` que colete
      todos os onsets (tempo musical racional) de todas as pautas/vozes;
   2. resolver a largura de CADA coluna pela maior necessidade entre as pautas
      (é aqui que entra o `IntelligentSpacingEngine` hoje morto);
   3. o layout por pauta passa a CONSULTAR a grade em vez de calcular X.
   Esse mesmo passe resolve F-12 (largura única), a interpolação linear de vozes,
   e habilita justificação real.

RISCO: alto (reescreve o núcleo). Mas é a única correção verdadeira.
TESTE: property test — para todo par (pauta A, pauta B) e todo onset t comum,
   |x_A(t) − x_B(t)| < 0,5 px.
```

Observação relacionada: `_alignStaves` usa `anchorCount = min` entre pautas. Uma pauta com menos barras (compassos vazios, `<multi-rest>`) alinha só o prefixo comum; o resto é deslocado por uma constante.

## Polifonia dentro de uma pauta

| Aspecto | Status | Nota |
|---|---|---|
| Vozes 1–2 | ◐ | funciona via `MultiVoiceMeasure`; voz 2 alinhada por **interpolação LINEAR no tempo** da voz 1 (não por espaçamento proporcional) |
| Vozes 3–4 | ⚫ | `Voice.getHorizontalOffset` empilha deslocamentos `0.6 × (n−1)` cegamente; nenhuma regra de gravação |
| Direção de haste por voz | ✅ | `forcedStemDirection`, ímpar↑/par↓ |
| Pausas por voz | ❌ | nenhum deslocamento vertical de pausa por voz |
| Colisão de segundas/uníssonos | ◐ | F-30 |
| Beaming por voz | ✅ | `_processBeamsWithAnacrusis` roda por voz |
| Ligaduras cientes de voz | ❌ | `SlurRenderer` não recebe `voiceNumber` |
| Voz mais longa que a voz 1 | ⚠ | `_interpolateTimelineX` satura na última âncora → notas se empilham no fim do compasso |
| `Measure.add` com 2 vozes | ❌ | F-09 |
| `MultiVoiceMeasure.currentMusicalValue` | ❌ | sempre ~0 (vozes fora de `elements`) → `MeasureValidator` reprova todo compasso polifônico |

---

# 13. FLUTTER ARCHITECTURE

## F-23 · Layout completo recalculado a cada `build` — **P2, Ev. B**
```dart
return LayoutBuilder(builder: (context, constraints) {
    var layoutEngine = LayoutEngine(widget.staff, ...);      // ◄ novo a cada build
    var layoutResult = layoutEngine.layoutWithSignature();   // ◄ layout completo
    ...
    if (hasBoundedHeight && (adaptiveScale - 1.0).abs() > 0.02) {
      layoutEngine = LayoutEngine(widget.staff, ...);        // ◄ SEGUNDA passada
      layoutResult = layoutEngine.layoutWithSignature();
    }
```
Não há memoização por `(staff, width, staffSpace)`. Qualquer `setState` ancestral, mudança de tema, rotação, teclado subindo ou mudança de `MediaQuery` refaz o layout inteiro — potencialmente duas vezes. Medido: 82 ms para 800 compassos (uma passada). Duas passadas em rotação = ~165 ms de jank.

## F-22 · Teto rígido de 1000 sistemas — **P2, Ev. B**
```dart
final firstSystem = firstSystemRaw.clamp(0, 999);
final lastSystem  = lastSystemRaw.clamp(0, 999);
```
Medido: 4000 compassos produzem **4000 sistemas**. Ao rolar além do sistema 999, `firstSystem == lastSystem == 999` → o painter desenha um único sistema fora do viewport. **A partitura fica em branco** a partir do sistema 1000. Uma sinfonia ou um saltério inteiro atinge isso.

## F-05b · Rolagem horizontal inerte
`SingleChildScrollView(horizontal) → SizedBox(width: viewportWidth)`. O filho tem exatamente a largura do viewport; o controlador nunca sai de `offset 0`. O `horizontalController` é passado ao painter e ao `Listenable.merge`, mas nunca varia.

## Custo por frame

```
MEDIDO (paint com culling, viewport 800×600):
   50 compassos  (268 elementos)  →  ~24 ms (após warm-up de 82 ms)
   200 compassos (1068 elementos) →  24 ms
   800 compassos (4268 elementos) →  26 ms
```
O culling funciona (só ~2 sistemas desenhados), mas **cada `paint()` reconstrói `Map<int, List<PositionedElement>>` sobre TODOS os elementos** e **instancia um `StaffRenderer` completo (15 sub-renderizadores) por sistema visível**. Como `repaint: Listenable.merge([hCtrl, vCtrl])` dispara a cada pixel de rolagem, isso é **O(n) de alocação por frame**. 26 ms > 16,7 ms de orçamento a 60 fps.

**Correções:** (1) pré-agrupar por sistema uma vez no `LayoutResult`; (2) cachear `StaffRenderer` por `(staffSpace, theme)`; (3) preferir `ListView.builder` de sistemas a um único `CustomPaint` gigante.

## O que está bem
- `RepaintBoundary` envolvendo o `CustomPaint`. ✅
- `ScrollController`s descartados em `dispose`. ✅ Não encontrei vazamento de listener.
- Metadados carregados uma vez via `FutureBuilder`. ✅
- Sem `Timer`/`Stream` pendurado no widget de partitura. ✅

## Concorrência (§35)
- **Nenhum `Isolate`.** Parsing, layout e geração MIDI são todos síncronos na UI thread. Um MusicXML de orquestra congela o app.
- `SmuflMetadata._isLoaded` sem guarda: duas chamadas concorrentes a `load()` executam `rootBundle.loadString` duas vezes (idempotente, mas desperdício e janela de leitura parcial).
- `GreciliaeFont` tem o mesmo padrão.
- Não encontrei race condition destrutiva — porque não há concorrência real. Isso é simultaneamente "seguro" e o teto de escalabilidade.

---

# 14. PERFORMANCE

| Fase | Complexidade medida/lida | Veredito |
|---|---|---|
| Parsing MusicXML | O(n) | ✅ |
| **Layout** | **O(n) medido** (50→800 compassos: 20→82 ms) | ✅ bom |
| `_justifyHorizontally` | O(sistemas × n) — varre TODOS os elementos por sistema | ⚠ O(n·s); com 1000 sistemas vira O(n²) |
| `_centerFullMeasureRests` | O(compassos) com busca por faixa | ✅ |
| `_analyzeBeamGroups` | O(n) | ✅ |
| `MusicScorePainter.paint` | O(n) **por frame** (reagrupamento) + alocação de renderizadores | ⚠ |
| `StaffRenderer._renderElement` | **O(n²)** em três lugares | ⚠ |
| MIDI | O(n × passes de repetição) | ✅ |

### F-35 · Varreduras quadráticas no renderizador — **P3, Ev. B**
`_renderElement` é chamado para cada elemento e, dentro dele:
- `for (int j = index-1; j >= 0; j--)` — detecção de clave de cue (para no limite do sistema, ok);
- `for (int j = index+1; ...)` — extensão de *hairpin* (para no limite do sistema, ok);
- `for (final pe in allElements)` — nota de referência para `OctaveMark` — **não** para no limite do sistema → O(n) por marca de oitava, sobre a partitura inteira.

Com o culling, `allElements` é a lista do sistema, o que limita o dano — mas o custo cresce com sistemas densos.

### `_justifyHorizontally`: O(sistemas × n)
Para cada sistema, faz duas varreduras completas de `elements` (min/max e depois reposicionamento). Com 4000 sistemas × 20k elementos isso é ~10⁸ operações. Foi a única razão pela qual o teste de 4000 compassos foi lento.

---

# 15. TESTES

## Panorama
- **594 testes, todos verdes**, ~74 s. `flutter analyze`: 16 issues, todos `info`, nenhum no código de produção relevante.
- **52 goldens de imagem reais** (`matchesGoldenFile`), com harness que carrega Bravura/Greciliae + fonte de texto real e desabilita escalonamento adaptativo. `test/golden/failures/` está no `.gitignore`. **Isso é qualidade acima da média para um pacote pub.dev.**
- Testes de round-trip MusicXML, import MEI, MIDI, quinálteras, LRU cache, spacing.

## Matriz FEATURE → IMPLEMENTAÇÃO → TESTE → QUALIDADE DO TESTE → RISCO

| Feature | Impl. | Teste | Qualidade do teste | Risco |
|---|---|---|---|---|
| `StaffPositionCalculator` | ✅ | 25 testes | **boa** (casos-limite, claves C, ledger) | baixo |
| MIDI (ties/tuplets/repeats) | ✅ | `midi_mapper_test` | **boa** | baixo |
| Goldens CMN + chant | ✅ | 52 imagens | **boa como regressão**, **nula como correção** | médio |
| **Espaçamento (`IntelligentSpacingEngine`)** | ⚫ **morto** | 390 linhas | **COBERTURA FALSA** — testa código que o produto nunca executa | **alto** |
| Beaming composto | ❌ F-03 | — | **inexistente** | **alto** |
| Acidentes em notas com barra | ❌ F-02 | `accidental_resolver_test` só usa semínimas | **cegueira por seleção de caso** | **alto** |
| Alinhamento grand-staff | ❌ F-04 | `grand_staff_golden_test` (560 linhas) | goldens congelam o desalinhamento | **alto** |
| Largura de compasso vs quebra | ❌ F-12/F-05 | — | inexistente | **alto** |
| `<divisions>`/`<backup>` | ❌ F-06/F-07 | `musicxml_import_test` usa arquivos com `<type>` e `<voice>` | **fixtures escolhidas para passar** | **alto** |
| Determinismo da assinatura | ❌ F-02b | — | inexistente | médio |
| Espaçamento com letras | ❌ F-15 | `lyrics_import_test` só valida import | não testa layout | médio |
| Clave intra-compasso | ❌ F-01 | — | inexistente | **alto** |
| `Measure.add` polifônico | ❌ F-09 | `voice_test` usa só `MultiVoiceMeasure` | evita o caminho quebrado | médio |
| Fuzzing / robustez | ❌ | — | inexistente | **alto** (F-10 derruba) |

## O que os testes NÃO testam (a pergunta adversarial)

1. **Nenhuma invariante musical.** Nenhum teste afirma "a soma das durações == capacidade do compasso", "nenhuma cabeça colide", "toda haste ≥ 2,5 SS", "max(x) ≤ largura disponível".
2. **Nenhum teste de propriedade.** Zero `parse(export(x)) ≈ x` generalizado; o round-trip existente é um caso único e **não verifica** dinâmica e tremolo — que de fato se perdem (medido).
3. **Nenhum fuzzing.** Um `<step>H</step>` derruba com `_TypeError`.
4. **Goldens congelam bugs.** `grand_staff_golden_test.dart` tem 560 linhas e passa com o desalinhamento de 38 px de F-04 gravado na imagem.
5. **`test/spacing_test.dart` testa um motor desligado.** É o exemplo mais puro de cobertura falsa que encontrei: 390 linhas verdes sobre código que nenhum caminho de produção alcança.
6. **`treble8vb_staff_position_test.dart` consagra uma das duas convenções contraditórias de F-24** — o teste protege a inconsistência.

---

# 16. SEGURANÇA

Fui atrás dos vetores realistas ("o que acontece se alguém abrir uma partitura maliciosa?").

| Vetor | Resultado | Ev. |
|---|---|---|
| **XXE** (`<!ENTITY xxe SYSTEM "file:///C:/Windows/win.ini">`) | Documento parseia; entidade **não é resolvida**; nenhum acesso a arquivo. O pacote `xml` do Dart não busca entidades externas. **Não encontrei evidência de falha nesta área.** | A |
| **Billion laughs** (entidades aninhadas, profundidades 4 e 6) | Parseado em 134–156 ms, sem explosão de memória. O `xml` do Dart não expande entidades customizadas recursivamente. **Sem DoS por expansão.** | A |
| XML truncado / não-XML / vazio | `XmlParserException` limpa e capturável | A |
| **`<step>H</step>`** | **`_TypeError: Null check operator used on a null value`** — crash com erro interno inútil | **A** |
| `<octave>999999</octave>` | Aceito. `midiNumber = 12000000`. Sem clamp. Layout gera Y astronômico | A |
| `<duration>-5</duration>` | Ignorado (duração vem de `<type>`) — sem dano, por acidente | A |
| `<type>bogus</type>` | Cai em `quarter` silenciosamente | A |
| JSON malformado / campos desconhecidos / tipos errados | Degradação silenciosa para defaults; nunca lança | A |
| Path traversal / leitura de arquivo | **Nenhum I/O de arquivo na biblioteca** (só `rootBundle`) | B |
| Desserialização insegura | Nenhum `dart:mirrors`, nenhum `eval` | B |
| Segredos/credenciais no repo ou CI | Nenhum encontrado | B |
| Dependências | `xml`, `pdf`, `printing`, `collection` — todas mantidas, sem CVE conhecida | B |

### F-10 (repetido aqui como achado de segurança) — **P1**
```
ID: F-10 | SEVERIDADE: P1 | EVIDÊNCIA: A
PROBLEMA: entrada não confiável derruba o processo.
COMO REPRODUZIR: MusicXMLParser.parseMusicXML(xml com <step>H</step>) e então
                 tocar/exportar → _TypeError.
COMPORTAMENTO ESPERADO: rejeitar no parser com uma exceção de domínio
                 (`InvalidPitchException` com linha/elemento), ou normalizar
                 com um warning na coleção de warnings que a MidiSequence já tem.
CAUSA RAIZ: ausência de validação de fronteira. O modelo aceita `String step`
            livre; nenhuma checagem entre parser e uso.
CORREÇÃO: validar `step ∈ {C..B}` e `octave ∈ [-1, 10]` no construtor de `Pitch`
          (ou numa factory `Pitch.tryParse`), e propagar warnings do parser.
TESTE: fuzz corpus de MusicXML/MEI/JSON malformados com asserção
       "nunca lança fora de FormatException/NotationException".
```

**Resumo de segurança:** superfície de ataque pequena e o parser XML subjacente é seguro por padrão. O risco real não é exfiltração — é **crash e corrupção silenciosa por falta de validação de domínio**.

---

# 17. API PÚBLICA

## Problemas

- **`noteXPositions` / `noteYPositions` são inutilizáveis** para o caso principal (notas com barra) — F-02. A dartdoc diz "✅ Expor positions X das notes for Rendering needs"; medido: `null`.
- **`LayoutResult.signature`** é documentada como "deterministic signature" e **não é** — F-02b.
- **`Measure.add`** lança em polifonia legítima (F-09) enquanto os parsers do próprio pacote contornam por `elements.add` — dois contratos para a mesma classe.
- **`PitchUtils.intervalInSemitones`** exportada e incorreta (F-19).
- **`Measure.elements` é `final List` público e mutável** — o invariante de capacidade é decorativo.
- **`Tuplet.showBracket` / `showNumber` `@Deprecated`** ainda no construtor público; nenhum caminho de migração automatizado.
- **`MusicScorePainter` é público** e exige `horizontalController`/`verticalController` obrigatórios — acoplamento a `ScrollController` que um consumidor com layout próprio não tem.
- **Sobreposição de nomes:** existem **duas** `CollisionDetector` (`lib/src/layout/collision_detector.dart` **exportada** e `lib/src/layout/spacing/collision_detector.dart`) e **dois** `SlurCalculator` (`lib/src/layout/slur_calculator.dart` e `lib/src/rendering/slur_calculator.dart`). Confusão garantida.
- **`export 'src/layout/layout_engine.dart'`** expõe `LayoutEngine`, `LayoutCursor`, `PositionedElement` — internals de layout viram superfície semver.
- **Texto da API corrompido:** dartdoc pública contém `"music notetion"`, `"Key Classs"`, `"Definesss"`, `"paUses"`, `"calculateTestes"`. Isso aparece em `pub.dev`.

## Pontos bons
- Fábricas nomeadas claras: `MusicScore.fromJson/fromMusicXml/fromMei/fromSource`.
- `NotationParser.detect` com auto-detecção de formato.
- Null-safety consistente; nenhuma API pública com `dynamic` desnecessário.
- `MidiGenerationOptions` bem desenhada (instrumentos por pauta, PPQ, metrônomo, ornamentos).
- `MidiSequence.warnings` — canal de diagnóstico explícito, boa prática.

---

# 18. DÍVIDA TÉCNICA

### Arquitetural (a mais cara)
1. Ausência de grade temporal compartilhada (F-04, F-12) — bloqueia pauta múltipla, justificação e polifonia corretas.
2. Fusão MUSIC MODEL / LAYOUT MODEL (`beam` e `BoundingBoxSupport` dentro de `Note`) → clonagem → F-02/F-08.
3. `MultiVoiceMeasure extends Measure` com estado paralelo → violação de LSP, 7 sítios de `is MultiVoiceMeasure`.
4. Quatro pipelines de layout desconexos (CMN, grand-staff, gregoriano, jianpu).
5. Layout recalculado no `build` (F-23), sem cache nem isolate.

### Algorítmica
6. Tabela de espaçamento incompleta (F-11).
7. `_groupCompoundTime` com off-by-one (F-03) — duplicação de três funções quase-iguais.
8. Geometria de barra por 2 pontos (F-14).
9. "Justificação" afim (F-13).

### Musical
10. Clave intra-compasso (F-01), acidentes de cortesia (F-16), claves transpositoras (F-24), números de compasso ausentes (F-33), quinálteras aninhadas (F-34).

### Tipográfica
11. ~300 literais `X.X * staffSpace` em `lib/`; larguras de acidente hardcoded que já existem no metadado (F-27); `barlineSeparation` 6× o SMuFL (F-28); calibração gregoriana (F-29).

### Flutter
12. Teto de 999 sistemas (F-22); rolagem horizontal inerte (F-05b); alocação por frame (F-35); sem isolates.

### Performance
13. `_justifyHorizontally` O(sistemas × n); reagrupamento por frame; `StaffRenderer` por sistema por frame.

### Testes
14. **Cobertura falsa** em `spacing_test.dart` (390 linhas sobre motor morto); zero invariantes musicais; zero fuzzing; goldens congelam bugs.

### Documentação
15. `MAGIC_NUMBERS_REFERENCE.md` obsoleto; backlog marca #2 como RESOLVED quando está quebrado para notas com barra; ~32 arquivos com texto corrompido por `sed` em massa (`notetion`, `Definesss`, `paUses`, `Rendersr`) e 3 com mojibake de dupla codificação (`CORREÃƒâ€¡ÃƒÆ’O CRÃƒÂTICA`).

### API
16. Internals exportados; nomes duplicados; APIs documentadas que não funcionam.

### Interoperabilidade
17. `<divisions>`/`<backup>`/`<forward>` (F-06/F-07); MEI multi-section (F-17); beams secundários (F-18); `<transpose>`, percussão/`unpitched`, cue notes.

### Segurança
18. Ausência de validação de domínio na fronteira do parser (F-10).

### ~2.800 linhas de código morto (Ev. B, `grep` de referências fora do próprio arquivo)
`SkylineCalculator`(358) · `BoundingBoxAdapter`(306) · `SpacingResult`(356) · `TupletValidator`(151) · `PerformanceOptimizer`(125) · `AnimationConfig`(301) · `HarmonicAnalysis`(218) · `FiguredBass`(82) · `Mensural`(254) · `AdaptiveTheme`(392) · `lib/core/tablature.dart`(160) + `lib/src/music_model/tablature.dart`(385) · e o `IntelligentSpacingEngine` inteiro (~1.600 linhas em `lib/src/layout/spacing/`, construído em `layout_engine.dart:268` e **nunca invocado** — só `_spacingPreferences.restSpacingRatio` é lido).

---

# 19. TOP 10 PROBLEMAS

Ordenados por `impacto × probabilidade × dano arquitetural`.

| # | ID | Sev. | Problema | Por que está aqui |
|---|---|---|---|---|
| 1 | **F-04** | **P1** | Pauta múltipla sem grade temporal comum — tempo 3 desalinha 38,1 px | É o requisito básico de partitura de teclado/conjunto. Dano arquitetural máximo: a correção é reescrever o núcleo de espaçamento. |
| 2 | **F-02** | **P1** | Clonagem de notas quebra acidentes em barras, `noteXPositions` e o determinismo da assinatura | Um único defeito produz 3 bugs visíveis + torna o modelo hostil a um editor futuro. Já causou uma **regressão sobre um item marcado RESOLVED**. |
| 3 | **F-05**+**F-12** | **P1** | Compasso denso estoura a linha e é cortado sem rolagem | Perda visual total de música. Causa raiz: duas fórmulas de largura. |
| 4 | **F-01** | **P1** | Clave no meio do compasso → alturas erradas (12 posições) e clave no lugar errado | Corrupção musical visível em repertório comum (piano, cello, fagote). |
| 5 | **F-03** | **P1** | 3/8, 6/8, 9/8, 12/8 agrupam errado + nota órfã | Compassos compostos são ubíquos. É um patch aplicado pela metade (simples corrigido, composto esquecido). |
| 6 | **F-06**+**F-07** | **P1** | MusicXML: `<divisions>`/`<duration>`/`<backup>`/`<forward>` ignorados | Corrupção rítmica e de vozes na importação — o formato de troca principal. |
| 7 | **F-08** | **P1** | Reutilizar uma instância de `Note` apaga notas silenciosamente | Perda de dados sem nenhum sinal. Idioma Dart natural dispara o bug. |
| 8 | **F-10** | **P1** | Entrada inválida derruba com `_TypeError` e mente no desenho | Segurança/robustez: partitura maliciosa ou só malformada quebra o app. |
| 9 | **F-14**+**F-11** | **P2** | Hastes de 1,75 SS em grupos; espaçamento invertido fora de semínima–fusa | Qualidade tipográfica: o resultado não passa por revisão de gravador. |
| 10 | **F-15** | **P2** | Letras não afetam o espaçamento | Inviabiliza uso vocal/coral, que é um dos casos de uso declarados. |

*Menções honrosas fora do top 10:* F-22 (teto de 999 sistemas), F-17 (MEI multi-section), F-29 (calibração gregoriana), F-31 (cobertura falsa em `spacing_test.dart`).

---

# 20. MATRIZ DE MATURIDADE

| Área | Nota | Justificativa |
|---|---:|---|
| Modelo musical | **6** | Amplo, bem nomeado, cobre maxima→2048th, microtons, MEI. Perde pontos por: igualdade ausente/inconsistente, `beam` dentro de `Note`, `MultiVoiceMeasure` quebrando LSP, ausência de validação de domínio, duplicação de fonte de verdade em X/voz/acidente. |
| Engraving | **4** | Base SMuFL genuína e várias regras de Gould implementadas (clave reafirmada, pausa centralizada, acidentes intra-compasso, barras parciais). Derrubado por F-01, F-03, F-14, F-15, F-16 e F-27. |
| Layout | **3** | Linear e determinístico nas posições — mérito real. Mas duas métricas de largura, "justificação" afim, `fillThreshold` arbitrário, estouro sem fallback, e o motor de espaçamento sofisticado desligado. |
| SMuFL | **7** | Âncoras e `engravingDefaults` usados de verdade, zero codepoints hardcoded. Perde por constantes que contradizem o metadado e por chave inexistente (`stemLength`). |
| Bravura | **7** | Carregamento correto, fallback presente, escala por `staffSpace` consistente. Perde por singleton amarrado ao asset — trocar de fonte exige editar o pacote. |
| MusicXML | **4** | Cobertura de elementos ampla e export com `divisions` correto. Derrubado por `divisions`/`duration`/`backup`/`forward` na importação — os quatro pilares do timing. |
| MEI | **4** | Contêineres beam/tuplet e `@startid`/`@endid` bem feitos; documentação honesta. Derrubado por `<section>` única e ausência de `@tab.*`/`@mode`/`meiHead`. |
| JSON | **6** | Tolerante, sem exceções em entrada suja, schema documentado em `doc/json_schema.md`. Perde por não ter versionamento nem rejeição de campos inválidos (aceita `octave: "abc"` silenciosamente). |
| MIDI | **8** | Ties, quinálteras, polifonia, repetições, voltas, ornamentos com roubo de tempo, warnings. Perde por ignorar claves transpositoras e por não ter faixa/canal por voz. |
| Playback | **3** | Arquitetura de bridge nativo bem desenhada e **um** motor real (Android, 608 linhas C++). Cinco plataformas são stubs — honestamente documentado, mas continua sendo 1/6. |
| Gregorian | **7** | O melhor design do projeto: neumas pré-compostos, classificação por contorno, liquescência, episema/mora/ictus, custos, divisiones, GABC, playback com si bemol. Perde por descalibração de 7% e por ser um pipeline totalmente à parte. |
| Polyphony | **3** | Vozes 1–2 funcionam por interpolação linear; 3–4 são empilhamento cego; `Measure.add` bloqueia; pausas não deslocam; colisão frágil. |
| Multi-staff | **2** | Existe, renderiza, tem chaves/colchetes e barras de sistema — e **não alinha eventos simultâneos**. Para gravação, isso é a falha definidora. |
| Performance | **5** | Layout O(n) e culling reais. Penalizado por relayout a cada build, alocação por frame, teto de 999 sistemas, zero isolates. |
| Flutter architecture | **4** | `RepaintBoundary`, dispose correto, `FutureBuilder` para metadados. Penalizado por layout no `build`, painter monolítico, scroll horizontal inerte, estado global singleton. |
| Testes | **5** | 594 verdes, disciplina real, harness de golden bem pensado. Penalizado por cobertura falsa, ausência de invariantes, zero fuzzing e fixtures escolhidas para passar. |
| Golden tests | **6** | Existem, são imagens reais, cobrem CMN + chant + grand staff, `failures/` ignorado, plataforma documentada. Penalizado por congelarem bugs conhecidos (F-04). |
| Segurança | **7** | Superfície pequena, parser XML seguro por padrão, sem XXE, sem DoS de entidade, sem I/O de arquivo, sem segredos. Penalizado por crash em entrada inválida. |
| API pública | **4** | Fábricas claras, null-safe, opções MIDI boas. Penalizado por APIs documentadas que não funcionam, internals exportados, nomes duplicados e dartdoc corrompida em `pub.dev`. |
| Documentação | **6** | Honestidade acima da média (README admite ~58%; backlog de 72 itens com verificação adversarial; OPEN_ISSUES realista). Penalizado por `MAGIC_NUMBERS_REFERENCE.md` obsoleto, por marcar #2 RESOLVED e pelo texto corrompido. |
| Escalabilidade | **3** | Modelo representa sinfonia; o renderizador não (teto de 999 sistemas, relayout por build, sem isolate, sem streaming de páginas). |
| Prontidão para editor profissional | **2** | Nada de cursor, seleção, hit-test, undo/redo, clipboard (issues #17/#18/#19 abertas). Pior: **o layout clona e substitui os objetos do modelo**, então nem sequer existe uma identidade estável para selecionar. |

**Média ponderada informal: ≈ 4,7 / 10** — "biblioteca de renderização competente, motor de gravação incipiente".

---

# 21. TESTES QUE PRECISAM SER CRIADOS

## Invariantes (property-based) — prioridade máxima
```dart
// L1  Nada é desenhado fora da linha
∀ staff, ∀ largura w: max(p.position.dx for p in layout(w)) ≤ w        // pega F-05

// L2  Toda nota do modelo aparece no layout
count(Note em measure.elements) == count(Note em positioned)            // pega F-08

// L3  Identidade preservada
∀ n em staff: engine.noteXPositions.containsKey(n)                      // pega F-02

// L4  Assinatura determinística
layoutWithSignature(s).signature == layoutWithSignature(s).signature    // pega F-02b

// L5  Comprimento mínimo de haste
∀ grupo, ∀ nota: |noteY − beamY(noteX)| ≥ 2.5 × staffSpace              // pega F-14

// L6  Monotonicidade rítmica do espaçamento
dur(a) > dur(b) ⇒ vão(a) ≥ vão(b), para TODOS os 15 DurationType        // pega F-11

// L7  Alinhamento vertical em pauta múltipla
∀ onset t comum a duas pautas: |x_A(t) − x_B(t)| < 0.5 px               // pega F-04

// L8  Sem colisão de cabeças
∀ par de noteheads no mesmo sistema: bbox_a ∩ bbox_b == ∅ ou vozes diferentes com deslocamento

// L9  Round-trip
parse(export(score)) ≈ score  (comparação campo a campo, lista de perdas explícita)

// L10 Timeline MIDI preserva duração musical
Σ ticks(compasso) == capacidade(compasso) × 4 × PPQ
```

## Testes de correção específicos (cada um falha hoje)
1. `mid_measure_clef_test` — compasso `[Sol, Dó4, Fá, Dó4]`: asserção `staffPosition(n1) == -6 && staffPosition(n2) == +6` e `x(clave Fá) > x(n1)`.
2. `compound_beaming_test` — tabela `{3/8:[3], 6/8:[3,3], 9/8:[3,3,3], 12/8:[3,3,3,3], 6/8 em 16as:[6,6]}`.
3. `accidental_beamed_test` — 4 colcheias Fá♯4 → decisões `[show,hide,hide,hide]`.
4. `cautionary_accidental_test` — nota com `AccidentalParenthesis.parentheses` sempre `show`.
5. `dense_measure_no_overflow_test` — 32 semicolcheias em 400 px.
6. `duplicate_note_instance_test` — 3 instâncias iguais → 3 renderizadas.
7. `polyphonic_measure_add_test` — `Measure.add` com 2 vozes não lança.
8. `musicxml_divisions_test` — `<duration>16</duration>`, `divisions=4`, sem `<type>` → semibreve.
9. `musicxml_backup_test` — polifonia sem `<voice>` vira `MultiVoiceMeasure` com 2 vozes.
10. `musicxml_forward_test` — voz que entra no tempo 3 tem onset 0,5.
11. `musicxml_secondary_beam_test` — `<beam number="2">` importado.
12. `mei_multi_section_test` — 2 seções → 2 compassos.
13. `lyric_spacing_test` — sílaba de 15 caracteres alarga o vão.
14. `cross_system_tie_test` — ligadura em quebra de linha gera **dois** segmentos.
15. `pitch_utils_interval_test` — tabela de intervalos.
16. `pitch_from_string_negative_octave_test` — `'C-1'` → oitava −1.
17. `octave_clef_playback_test` — decidir a convenção e travá-la nos dois lados (render + MIDI).
18. `greciliae_calibration_test` — property test sobre `PesN` no arquivo de fonte.
19. `system_count_over_1000_test` — 1200 sistemas ainda renderizam.
20. `layout_memoization_test` — dois `build` com as mesmas constraints não recalculam.

## Fuzzing
- Corpus gerado de MusicXML/MEI/JSON com: steps inválidos, oitavas extremas, durações negativas, IDs duplicados, tuplets aninhados malformados, beams sem `end`, compassos sem clave, XML truncado em cada byte.
- Asserção: **nunca** lança fora de `FormatException`/exceção de domínio própria; **nunca** entra em loop; **nunca** produz modelo com `step` fora de `C..B`.

## Golden tests que faltam
Mudança de clave intra-compasso · 6/8 e 12/8 · grand staff com ritmos diferentes por mão (o teste de F-04) · letras longas · ligadura em quebra de sistema · dobrado-bemol antes de nota (largura) · breve e 1/128 lado a lado · 4 vozes numa pauta · quiáltera aninhada.

---

# 22. PLANO DE CORREÇÃO

## FASE 0 — Emergência (dias; nada aqui é arquitetural)
| # | Ação | Corrige |
|---|---|---|
| 0.1 | Validar `step`/`octave` na fronteira do parser e no construtor de `Pitch`; propagar warnings | F-10 |
| 0.2 | Trocar o `Set<Note>` identity por índice em `_processBeamsWithAnacrusis` | F-08 |
| 0.3 | Completar `durationFactors` com os 15 `DurationType` (√ do valor relativo) e remover o fallback `?? 1.0` | F-11 |
| 0.4 | Corrigir `_groupCompoundTime` para usar `startBeat`; reclassificar 3/8 como simples | F-03 |
| 0.5 | Corrigir `PitchUtils.intervalInSemitones` e `Pitch.fromString` (oitava negativa) | F-19, F-20 |
| 0.6 | Reordenar os `if/else` de largura de acidente e ler as larguras do metadado Bravura | F-27 |
| 0.7 | Elevar `clamp(0, 999)` para o número real de sistemas | F-22 |
| 0.8 | Respeitar `accidentalParenthesis` no `AccidentalResolver` | F-16 |

## FASE 1 — Correções críticas (semanas)
| # | Ação | Corrige |
|---|---|---|
| 1.1 | **Unificar a métrica de largura**: `_calculateMeasureWidthCursor` passa a somar exatamente os mesmos `_calculateRhythmicSpacing` que o layout aplica | F-12 |
| 1.2 | Compressão proporcional quando o compasso não cabe + canvas realmente rolável na horizontal | F-05 |
| 1.3 | **Não particionar system elements**: percorrer os elementos na ordem; clave/armadura/fórmula intra-compasso viram elementos de fluxo em tamanho de cue | F-01 |
| 1.4 | Ler `<divisions>` e `<duration>`; usar `<type>` só como forma gráfica; tratar `<rest measure="yes">` | F-06 |
| 1.5 | Implementar `<backup>`/`<forward>` como cursor temporal no acumulador de vozes | F-07 |
| 1.6 | Ler todos os `<beam number=>`; modelar níveis de barra por nota | F-18 |
| 1.7 | Iterar **todas** as `<section>` do MEI | F-17 |
| 1.8 | Geometria de barra: ajustar a reta até que toda haste ≥ mínimo | F-14 |
| 1.9 | Reservar largura de sílaba em `_getElementWidthSimple` | F-15 |
| 1.10 | Escrever as invariantes L1–L6 e L10 como testes que falham hoje | testes |

## FASE 2 — Correções arquiteturais (meses) — **as três reescritas necessárias**
| # | Ação | Corrige |
|---|---|---|
| 2.1 | **`LayoutNote`**: separar MUSIC MODEL de LAYOUT MODEL. `beam`, `x`, `y`, `staffPos`, `boundingBox` saem de `Note` e vão para um objeto de layout que **referencia** a nota. Fim da clonagem. Todos os mapas passam a ser chaveados pela nota-fonte. | **F-02** (+ habilita editor) |
| 2.2 | **`TimeGrid` global**: um passe que colete todos os onsets de todas as pautas e vozes, resolva a largura de cada coluna pela maior necessidade, e sirva de fonte única de X. `GrandStaffPainter` e `LayoutEngine` consultam a grade. | **F-04, F-12, polifonia** |
| 2.3 | **Ligar o `IntelligentSpacingEngine`** dentro do `TimeGrid` (é exatamente onde ele faz sentido) ou **apagá-lo** junto com `spacing_test.dart`. Escolher — manter as duas coisas é a pior opção. | F-31 |
| 2.4 | Justificação real: bloco de cabeçalho com largura fixa; só a região de notas estica; remover `fillThreshold` (só o último sistema fica irregular) | F-13 |
| 2.5 | `MultiVoiceMeasure` deixa de herdar de `Measure`: introduzir `Measure { List<Voice> voices }` com a voz única como caso `voices.length == 1`. Elimina os 7 `is MultiVoiceMeasure`. | F-09, LSP |
| 2.6 | Memoizar `LayoutResult` por `(identityHash(staff), width, staffSpace)`; mover parsing e layout de partituras grandes para `Isolate` | F-23 |
| 2.7 | Pré-agrupar por sistema no `LayoutResult`; cachear `StaffRenderer`; considerar `ListView.builder` de sistemas | F-35 |

## FASE 3 — Engraving profissional
- Ligaduras/tie cientes de sistema, com quebra em dois segmentos (F-26).
- Quinálteras entram no pipeline de espaçamento; aninhamento renderizado (F-25, F-34).
- Números de compasso (F-33); marcas de ensaio; texto de sistema.
- Colisão entre vozes: uníssonos fundidos, cabeças opostas, deslocamento por lado de haste; casamento por onset musical em vez de `dx.round()` (F-30).
- Pausas deslocadas por voz; vozes 3–4 com regras reais.
- Calibração gregoriana derivada da fonte (F-29).
- Skyline/`CollisionDetector` aplicados a articulações, dinâmicas e letras — hoje só a ligaduras.

## FASE 4 — Interoperabilidade
- `<transpose>`, `<sound tempo>`, cue notes, percussão/`unpitched`, `<multi-rest>`.
- MEI: `@tab.*`, `@mode`, compasso aditivo, `meiHead`, `<expansion>`.
- Round-trip com **relatório explícito de perdas** (a `MidiSequence` já tem `warnings` — replicar o padrão nos parsers).
- Versionamento do JSON.
- Escolher e travar a convenção de oitava para claves transpositoras nos dois lados (F-24).

## FASE 5 — Editor profissional
Só faz sentido **depois de 2.1** (identidade estável). Ordem: hit-test (`PositionedElement` + bbox) → seleção por elemento/compasso/pauta/voz/região → cursor e entrada de notas → comandos com undo/redo (o modelo precisará virar imutável com *command pattern*) → clipboard → playback de seleção (ver §30, mudanças já mapeadas).

---

# 23. ARQUITETURA RECOMENDADA

```
                      ┌───────────────────────────┐
  MusicXML/MEI/JSON ─►│  PARSERS + VALIDAÇÃO      │─► warnings[]  (nunca crash)
  GABC              ─►│  (fronteira de confiança) │
                      └────────────┬──────────────┘
                                   ▼
                      ┌───────────────────────────┐
                      │  MUSIC MODEL (imutável)   │  ← ÚNICA fonte de verdade musical
                      │  Score→Part→Staff→Measure │     sem `beam`, sem bbox, sem X/Y
                      │  →Voice→Event             │     identidade estável e permanente
                      └────────────┬──────────────┘
                                   ▼
                      ┌───────────────────────────┐
                      │  SEMANTIC TIMELINE        │  ← onsets racionais (Rational, não double)
                      │  TimeGrid.build(Score)    │     UMA coluna por instante musical
                      └──────┬─────────────┬──────┘
                             │             │
              ┌──────────────▼──┐   ┌──────▼──────────────┐
              │  LAYOUT MODEL   │   │  MIDI / PLAYBACK    │
              │  LayoutNote{    │   │  (já bom hoje;      │
              │    Note source; │   │   + canal por voz,  │
              │    beam, x, y,  │   │   + claves transp.) │
              │    staffPos,bbox│   └─────────────────────┘
              │  }              │
              │  ├ SpacingEngine (o que hoje está morto)
              │  ├ CollisionDetector / Skyline (para TUDO, não só ligaduras)
              │  └ Justification (cabeçalho fixo + região elástica)
              └────────┬────────┘
                       ▼
              ┌─────────────────┐
              │  RENDER MODEL   │  ← lista plana de draw-ops por sistema,
              │  DrawOp[]       │     pré-agrupada, cacheável, sem alocação por frame
              └────────┬────────┘
                       ▼
        ┌──────────────────────────────┐
        │ CustomPainter | PDF | SVG    │  ← um único back-end de desenho
        │ (mesmo RENDER MODEL)         │     resolve o PDF placeholder de graça
        └──────────────────────────────┘
```

### Os cinco princípios que faltam hoje

1. **O layout nunca muta o modelo.** Nem clona. `LayoutNote.source` é a ponte. Isso resolve F-02, F-08 e é pré-requisito absoluto para um editor.
2. **Uma coluna X por instante musical, para a partitura inteira.** Não por pauta, não por voz. Resolve F-04 e F-12 e habilita justificação de verdade.
3. **Tempo musical é `Rational`, não `double`.** Hoje `realValue` é `double` e o código já convive com `tolerance = 0.0001` e `+ 0.0001` espalhados. Quinálteras aninhadas e compassos aditivos vão quebrar isso.
4. **Métricas vêm da fonte, constantes vêm de um único lugar.** Um `EngravingRules` (o arquivo já existe, com 504 linhas!) alimentado por `bravura_metadata.json`, e zero literais `X.X * staffSpace` fora dele.
5. **Toda perda de informação é reportada.** O padrão `MidiSequence.warnings` é bom — deve valer para parsers, layout (compasso não coube, sistema truncado) e export.

### Sobre o estado da arte (§65) — comparação arquitetural, não de features

- **Verovio/LilyPond** resolvem espaçamento com uma cadeia global de molas/hastes (*springs and rods*) sobre uma linha do tempo única, e depois **iteram** até convergir. `flutter_notemus` faz um único passe local por compasso, sem conhecimento global. **Essa é a diferença que produz F-04, F-12 e F-13** — não é questão de esforço, é de topologia do algoritmo.
- **MuseScore/Dorico** mantêm `Element` com identidade estável do modelo até a tela, o que é o que viabiliza seleção, edição e undo. `flutter_notemus` destrói essa identidade no meio do layout (F-02). **Essa é a diferença que bloqueia a Fase 5.**
- **Onde `flutter_notemus` está à frente da média:** o uso de âncoras SMuFL reais (muitos renderizadores web usam offsets arbitrários), a decisão de usar neumas pré-compostos da Greciliae em vez de geometria (Verovio faz o mesmo; a maioria dos projetos amadores não), e um pipeline MIDI com semântica de repetição/volta que muitos renderizadores nem tentam.

---

# 24. VEREDITO FINAL

**1. O engine está realmente pronto para produção?**
**Não, para gravação profissional.** Sim, para um caso de uso restrito e bem delimitado: exibir trechos curtos, monofônicos ou de acordes simples, em uma pauta, em compasso simples, sem letras longas, sem mudança de clave interna, e com o autor controlando o conteúdo. Fora desse envelope o motor produz saída musicalmente incorreta ou cortada.

**2. O engraving é profissional?**
**Não.** Tem fundações profissionais (SMuFL real, várias regras de Gould implementadas de verdade) e defeitos que nenhum gravador aceitaria: 6/8 agrupado errado, hastes de 1,75 espaços, letras que não empurram nada, clave interna deslocando alturas em uma décima segunda, e mãos de piano que não se alinham.

**3. O modelo musical é sólido?**
**Parcialmente.** A cobertura de conceitos é genuinamente ampla. A engenharia do modelo não é: igualdade ausente/inconsistente, decisões de layout dentro do objeto musical, herança quebrada em `MultiVoiceMeasure`, múltiplas fontes de verdade para X/voz/acidente, e nenhuma validação de fronteira.

**4. MusicXML é confiável?**
**Não para importação.** Confiável para exportação (`divisions=480`, durações reais, vozes com `<backup>`). Na importação, os quatro elementos que definem o tempo musical — `divisions`, `duration`, `backup`, `forward` — são ignorados. Um arquivo do MuseScore com `<voice>` e `<type>` importa bem; um arquivo gerado programaticamente ou legado corrompe.

**5. MEI é realmente suportado?**
**Suportado para CMN de uma seção, e a documentação diz isso honestamente.** Contêineres `<beam>`/`<tuplet>` e `@startid`/`@endid` estão bem feitos. Mas só a primeira `<section>` é lida — o que significa que documentos MEI estruturados perdem conteúdo silenciosamente. O badge `MEI v5 CMN` está correto; a nota de ~58% no README também.

**6. MIDI/playback é musicalmente confiável?**
**MIDI: sim.** Verifiquei ligaduras, quinálteras, polifonia e repetições e todos batem exatamente. É o subsistema que eu não consegui quebrar. Duas ressalvas reais: claves transpositoras ignoradas e nenhuma faixa/canal por voz.
**Playback: não, exceto Android.** Cinco das seis plataformas são stubs — declarado abertamente na documentação.

**7. O sistema suporta partituras complexas?**
**Não.** Teste de estresse conceitual (§66):

| Cenário | Veredito | Por quê |
|---|---|---|
| **A** Piano, 500 compassos | **FAIL** | F-04 (mãos desalinhadas) + F-23 (relayout por build) |
| **B** SATB, 300 compassos | **FAIL** | F-04 + F-15 (letras não espaçam) |
| **C** Orquestra, 100 instrumentos | **FAIL** | F-04 em escala, sem isolate, teto de 999 sistemas |
| **D** 4 vozes independentes por pauta | **FAIL** | vozes 3–4 sem regras; `Measure.add` bloqueia; colisão frágil |
| **E** Letras longas | **FAIL** | F-15 — sobreposição garantida |
| **F** MusicXML complexo | **FAIL** | F-06, F-07, F-18 |
| **G** Gregoriano extenso | **PARTIAL** | funciona de verdade; ~7% de descalibração vertical (F-29) |
| **H** repeats + volta + quinálteras + ties + cross-staff | **PARTIAL** | MIDI ✅ correto; render ◐ (quinálteras fora do pipeline, ties cruzando sistema) |

**8. A arquitetura suporta um editor profissional?**
**Não, e o bloqueio é específico e nomeável:** `_processBeamsWithAnacrusis` substitui os objetos `Note` do usuário por clones. Sem identidade estável do modelo até a tela, não existe seleção, não existe hit-test confiável, não existe undo. Nenhuma quantidade de trabalho em cursor/teclado/mouse contorna isso. **A Fase 2.1 é pré-requisito de tudo em §53.**

**9. Quais são os maiores riscos?**

| Risco | Natureza |
|---|---|
| **Perda silenciosa de música** — notas apagadas (F-08), vozes colapsadas (F-07), seções MEI descartadas (F-17), durações trocadas (F-06), compassos cortados sem rolagem (F-05). O usuário não recebe nenhum sinal. | **O mais grave.** Corrupção sem aviso destrói a confiança de forma irrecuperável. |
| **Correções pela metade viram regressões** — #2 marcado RESOLVED e quebrado para notas com barra; `_groupSimpleTime` corrigido e `_groupCompoundTime` esquecido; tabela de espaçamento corrigida e deixada incompleta. | Padrão sistêmico: patches locais sem teste de invariante. |
| **Cobertura falsa** — 594 testes verdes sobre um motor de espaçamento desligado e goldens que congelam o desalinhamento de F-04. | Os testes dão uma sensação de segurança que os dados não sustentam. |
| **Dívida arquitetural composta** — cada nova feature é construída sobre a ausência de grade temporal e sobre a clonagem de notas, aumentando o custo da correção. | O custo de 2.1 e 2.2 cresce todo sprint. |
| **Divergência doc↔código reaparecendo** — o README foi corrigido, mas `MAGIC_NUMBERS_REFERENCE.md` já ficou obsoleto e o backlog já tem um item RESOLVED incorreto. | Sem teste que ligue afirmação a comportamento, a honestidade não se sustenta sozinha. |

**10. Qual é a ordem correta para corrigi-los?**

```
1. Fase 0 inteira (dias)     — para de sangrar: crash, notas apagadas, 6/8, espaçamento invertido
2. L1–L6 + L10 como testes   — as invariantes ANTES das correções grandes, senão a Fase 2 regride
3. F-12 → F-05 → F-01        — unifica largura, para de cortar música, conserta clave interna
4. F-06 + F-07 + F-18 + F-17 — torna a importação confiável (o formato de troca é a porta de entrada)
5. ►► 2.1 LayoutNote ◄◄      — DESTRAVA acidentes, noteXPositions, determinismo E o editor
6. ►► 2.2 TimeGrid ◄◄        — DESTRAVA pauta múltipla, justificação, polifonia — e liga o
                                IntelligentSpacingEngine que já está escrito e testado
7. F-14, F-15, F-26, F-25    — qualidade tipográfica sobre fundação já correta
8. Fase 4 (interop) e 5 (editor)
```

O ponto não-óbvio: **os itens 5 e 6 não são refatorações "de limpeza"**. São os dois únicos trabalhos que convertem uma pilha de correções pontuais em um motor. Tudo em Engraving (Fase 3), tudo em Editor (Fase 5) e metade dos bugs P1 deste relatório são sintomas dessas duas ausências. Fazer as Fases 0/1 sem elas produz um motor melhor com o mesmo teto.

---

## Nota de método e limites desta auditoria

**O que provei executando código (Ev. A):** F-01, F-02, F-03, F-05, F-06, F-07, F-08, F-09, F-10, F-11, F-13, F-14, F-15, F-16, F-17, F-18(parcial), F-19, F-20, F-21, F-25, F-04, além dos resultados positivos de MIDI, determinismo de posições, complexidade de layout e segurança XML.

**O que provei lendo o código (Ev. B):** F-12, F-22, F-23, F-24, F-26, F-27, F-28, F-29 (com medição direta do arquivo de fonte), F-30, F-31, F-32, F-33, F-34, F-35, F-40, F-41, F-42.

**O que NÃO consegui verificar (UNKNOWN — declarado, não escondido):**
- Comportamento real em **iOS, macOS, Linux e Web** — nenhum dispositivo/emulador disponível nesta sessão. Julguei apenas o código nativo (que é stub, exceto Android).
- **Aparência visual** dos 52 goldens — verifiquei que passam e que o harness é sólido, mas não inspecionei as imagens uma a uma para julgar qualidade tipográfica.
- **Issues do GitHub (§46)** — sem acesso à rede nesta sessão; usei `doc/OPEN_ISSUES.md` e `doc/LIBRARY_AUDIT_BACKLOG.md` como espelho declarado do backlog. As conclusões sobre issues são, portanto, **Ev. C** (o item #2 marcado RESOLVED e refutado é Ev. A quanto ao comportamento, C quanto ao estado da issue).
- **Playback em áudio real** no Android — verifiquei a existência e o tamanho do motor C++, não seu comportamento sonoro.
- **Comportamento sob carga real de scroll** (jank percebido) — medi o custo de `paint()` isoladamente, não em um device sob 60 fps.
