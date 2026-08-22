# Re-auditoria forense adversarial — flutter_notemus 2.7.0

Auditoria independente + verificação de alegações. Toda afirmação marcada **[A]** foi
obtida executando código (10 arquivos de sonda, ~1.400 linhas, rodados sob
`flutter test` com Bravura/Greciliae carregados e imagens rasterizadas a 3×).
**[B]** = leitura de código. **[C]** = inferência arquitetural.

Baseline verificada: **792 testes, todos verdes** (`flutter test`, antes e depois das sondas).
Repositório devolvido intacto (`git status` = 0 alterações).

---

## 1. EXECUTIVE SUMMARY

A remediação 2.7.0 é **real e substancial, e é honesta na maior parte**. Das 38
alegações da matriz, **25 se confirmam integralmente e 13 se confirmam apenas
parcialmente; nenhuma é falsa e nenhuma regrediu no caso citado**. O defeito
arquitetural que a auditoria 2.6.0 apontava como bloqueador — *o layout clonava
os objetos do modelo* — foi de fato eliminado, e com ele caiu uma família inteira
de bugs. O alinhamento por onset entre pautas (a "falha definidora" da 2.6.0)
funciona e foi medido.

Mas a remediação **fechou os casos citados e deixou os casos vizinhos abertos**,
e introduziu pelo menos **30 achados novos**, três deles P1:

1. `GrandStaffPainter` **lança exceção** e derruba o widget quando o primeiro
   compasso de um sistema quebrado está sobrecheio — exatamente o que os
   importadores produzem [A].
2. `MultiVoiceMeasure.elements` é **silenciosamente descartado** pelo layout:
   clave, armadura, fórmula e dinâmicas somem, e **todas as notas são desenhadas
   na linha de base, sem altura** [A].
3. Toda partitura importada de MusicXML desenha **a clave DEPOIS da armadura e da
   fórmula de compasso** [A], porque a ordem canônica do MusicXML é
   `key, time, clef` e a correção do F-01 passou a respeitar a ordem do documento
   literalmente.

Além disso, o desempenho **piorou**: a justificação é O(sistemas × elementos), e
6.400 compassos levam **6,0 s** de layout [A] — o teto de 1.000 sistemas foi
removido e substituído por um comportamento assintótico pior.

**Nota de remediação: 0,83.** **Estado do projeto: renderizador CMN competente e
honesto, motor de gravação intermediário, base de editor agora plausível.**
Não está pronto para produção como *editor*; está próximo de estar pronto como
*visualizador* de partituras de origem confiável — desde que a ordem clave/armadura
no import seja corrigida.

---

## 2. NOTA DE REMEDIAÇÃO

### 2.1 Matriz linha a linha

| ID | Veredito | Evidência medida |
|---|---|---|
| **F-01** clave no meio do compasso | ✅ CONFIRMED FIXED | `[Sol, C4, Fá, C4]` → clave em x=106,4 **depois** da 1ª nota (x=82,6); y(c1)=96,0 ≠ y(c2)=24,0 [A] |
| **F-02** layout não clona; regra de acidentes em notas com barra | ✅ CONFIRMED FIXED | `F#4,F#4,F#5,F#4` → `[show, hide, show, hide]`; `noteXPositions[nota] != null` [A] |
| **F-02b** assinatura determinística | ✅ CONFIRMED FIXED | 3 layouts → `304971103` idêntico; modelo novo idêntico → mesma assinatura [A] |
| **F-03** compassos compostos em 3 | 🟡 PARTIALLY FIXED | 3/8→3-3, 6/8→3-3, 9/8→3-3-3, 12/8→3-3-3-3, 6/8 em 16ºs→6-6, 6/16→3-3, 9/16→3-3-3, 12/16→3-3-3-3, 2/2→4-4, 3/4→2-2-2, 3/4 em 16ºs→4-4-4 **todos corretos**. **Mas 4/4 com 16 semicolcheias → 8-8** (Gould: 4-4-4-4) e 5/8→2-3, 7/8→2-2-3, 8/8→3-3-2 são agrupamentos fixos sem como escolher [A] |
| **F-04** pautas alinhadas por onset | 🟡 PARTIALLY FIXED | Mecanismo real: onset em todo `PositionedElement` + `_alignStaves` por grade compartilhada [A/B]. **Mas `_alignStaves` só chama `overrideNoteX` para `Note` e `Chord` — as notas internas de uma `Tuplet` mantêm o X pré-alinhamento** [B], e as barras dentro dela apontam para coordenadas obsoletas |
| **F-05** compasso denso comprimido e rolável | 🟡 PARTIALLY FIXED | 32×16ºs @400px: maxX=966,8, contentWidth=984,8 (≥ maxX ✅), gap mínimo 26,90 > cabeça 14,16 ✅; idem 64 notas e staffSpace 6/12/24 [A]. **Mas com bemol-dobrado o piso falha** — ver F-27 |
| **F-06** `<divisions>`/`<duration>` sem `<type>` | ✅ CONFIRMED FIXED | nota sem `<type>`, divisions=4, duration=4 → `quarter`; pausa de compasso e quialtera OK [A] |
| **F-07** `<backup>`/`<forward>` | ✅ CONFIRMED FIXED | polifonia com `<backup>` → `MultiVoiceMeasure` com vozes 1 e 2, C5+C4 ambos presentes [A] |
| **F-08** instância de `Note` reutilizada | 🟡 PARTIALLY FIXED | 3 instâncias iguais → **3 `PositionedElement`** ✅ [A]. **Mas `noteXPositions.length == 1`** e guarda só o último X (194,93); `accidentalDecisions.length == 1`. A API pública de posição, o hit-test e a regra de acidentes só enxergam **uma** das três ocorrências [A] |
| **F-09** `Measure.add` voice-aware | ✅ CONFIRMED FIXED | 4+4 semínimas em vozes 1 e 2 aceitas; 5 na voz única rejeitadas; sem tag + voz 2 aceito [A] |
| **F-10** entrada inválida → exceção de domínio | 🟡 PARTIALLY FIXED | `<step>H</step>`, oitava 999999, step vazio, MEI `@pname="h"` → todos `FormatException` ✅ [A]. **`<pitch>` sem `<octave>` não lança e a nota é silenciosamente descartada** (0 notas importadas) [A] |
| **F-11** espaçamento proporcional nos 15 `DurationType` | 🟡 PARTIALLY FIXED | maxima 251,75 → 64º 26,90 estritamente decrescente ✅; pontos aumentam em todos ✅. **Mas 128º, 256º, 512º, 1024º e 2048º dão exatamente 26,90 — idênticos ao 64º.** A "lei" satura no piso anti-colisão nos 5 tipos mais curtos [A]. **E o conteúdo de quialtera é isento por completo** (grade fixa) |
| **F-13** justificação não estica clave/armadura | ✅ CONFIRMED FIXED | w=400/700/1200 → clave=30,00, armadura=68,21, fórmula=118,56, 1ª nota=170,16 **invariantes** [A] |
| **F-14** haste em grupo com barra ≥ mínimo | ✅ CONFIRMED FIXED | E4+F5+E4+C6 → hastes 3,84 / 7,67 / 3,50 / 9,34 espaços; mínimo medido 3,42–3,50 em todos os casos testados, sempre ≥ 2,5 [A] |
| **F-15** lyrics ocupam espaço horizontal | ✅ CONFIRMED FIXED | sem sílaba 56,16 → "Extraordinarily" 87,33 → 40 chars 148,53; 3 versos usam a mais larga; funciona em acorde [A] |
| **F-16** acidente de cortesia sempre desenhado | ✅ CONFIRMED FIXED | `paren=none`→hide, `parentheses`→**show**, `brackets`→**show**; bequadro de cortesia no compasso seguinte → `natural` [A]. Golden `m04p` confirma o glifo |
| **F-17** MEI lê todas as `<section>` | ✅ CONFIRMED FIXED | 2 seções + 1 aninhada → **3 compassos** [A] |
| **F-19/20/21** pitch | ✅ CONFIRMED FIXED | `C-1`→MIDI 0; `F#4 == F#4` e hash igual; `alter:1.0 == withAccidental(sharp)`; `F#4 != Gb4` [A] |
| **F-22** sem teto de 1000 sistemas | ✅ CONFIRMED FIXED | 1300 compassos → **1300 sistemas**, 3900 elementos, altura 156.072 px [A] |
| **F-24** claves 8va/8vb no playback | 🟡 PARTIALLY FIXED | treble→60, treble8vb→48, treble8va→72 ✅ [A]. **Mas `StaffPositionCalculator` devolve `-6` para C4 nas TRÊS claves** — a tela não desloca. E o MusicXML entrega `<pitch>` **soante**: importar C4 + `clef-octave-change=-1` produz **MIDI 48** e desenho na posição de C4 normal → **uma oitava errada nos dois lados** [A] |
| **F-25** geometria dentro de quialteras | ✅ CONFIRMED FIXED | grade de 30 px (=2,5 sp): notas simples, acorde e quialtera aninhada todos com X/Y registrados [A] |
| **F-26** ligadura cruzando sistema | ✅ CONFIRMED FIXED | render 3× mostra **dois segmentos**: um sai da nota e passa da barra "no ar", outro entra no sistema seguinte [A] |
| **F-27** larguras de acidente do metadado | 🟡 PARTIALLY FIXED | `accidentalDoubleFlat = 1,652` lido do metadado ✅ [A]. **Mas o piso anti-colisão usa `staffSpace * 0.6` fixo**, não a largura real: em compasso comprimido o bemol-dobrado (19,82 px) invade 7,08 px da cabeça anterior (folga = 12,74 px) [A]. **E a largura é reservada do lado errado** — ver N-05 |
| **F-29** calibração gregoriana da fonte | ✅ CONFIRMED FIXED | `diatonicStepUnits()` **medido = 158,0** (constante de fallback 157,5; Δ=0,5 = 0,3 %) [A] |
| **F-30** colisão entre vozes por onset | ✅ CONFIRMED FIXED | B4(v1) e A4(v2) no mesmo onset → deslocamento de **14,16 px = exatamente uma cabeça** [A] |
| **F-33** números de compasso | ✅ CONFIRMED FIXED | `{0:1, 1:2, ...}`, compasso 1 não numerado, desenhados no início de cada sistema (golden `s02`) [A] |
| **F-40** fonte SMuFL trocável | ✅ CONFIRMED FIXED | 1 único literal `'Bravura'` em `lib/`, e é o *default* de `SmuflFontDescriptor`; os renderizadores usam `packages/flutter_notemus/Bravura` via metadado [A/B] |
| **F-36** export PDF com notação real | 🟡 PARTIALLY FIXED | 10.128 bytes, `%PDF`, contém `/Subtype /Image`, 0 warnings ✅ [A]. **Mas `_addMusicPages` itera `group.staves` e chama `_addStaffPages` para cada pauta separadamente** — um grand staff sai como duas seções independentes, sem chave e sem mãos alinhadas [B] |
| **§30** playback por voz/pauta/seleção | 🟡 PARTIALLY FIXED | `MultiVoiceMeasure` e import MusicXML: mute/solo/tracks corretos [A]. **`Measure` simples com `Note.voice`: mute v2 = idêntico a "tudo", solo v2 = silêncio total, `separateTracksPerVoice` cria só `Staff 1 - Voice 1`** [A] |
| **§53** hit-test/seleção | 🟡 PARTIALLY FIXED | clique exato na cabeça acerta 7/7 numa barra realista [A]. **Falha em: haste (`null`), acidente (`null`), e qualquer acorde longe da linha central (`null` para C6-E6-G6)** — a caixa do acorde é centrada na base da pauta, altura 6 sp [A] |
| **§55** marcas de ensaio | ✅ CONFIRMED FIXED | golden `m04s_rehearsal_marks.png` mostra "A" e "B12" em caixa ✅ |
| **NOVO-1** nada cortado acima/abaixo | ✅ CONFIRMED FIXED | C9→top 140,4; C0→bottom 146,4; ensaio→16,8; 3 versos→39,6; C9+3 versos→140,4/39,6 [A] |
| **NOVO-2** `Tuplet.totalDuration` | ✅ CONFIRMED FIXED | misto 0,3333; só pausas 0,25; só acordes 0,25; aninhada 0,25 — todos exatos [A] |
| **NOVO-3** PDF reserva a mesma folga | ✅ CONFIRMED FIXED | C9: engine 332,4 == raster `logicalHeight` 332,4 [A] |
| **NOVO-4** numeração não muta o modelo | ✅ CONFIRMED FIXED | `Measure.number` continua `[null,null,null,null]` após layout; `GrandStaffPainter` usa `measureNumberOffset` [A/B] |
| **NOVO-5** acordes/quialteras aninhadas dentro de quialtera | ✅ CONFIRMED FIXED | acorde-em-quialtera X=202,6; aninhada F/G/A em 112,6/142,6/172,6 [A] |
| **NOVO-6** MEI `@mode`, aditivo, `@tab.*`, `<meiHead>` | 🟡 PARTIALLY FIXED | `@mode`→dorian ✅, `@tab.fret/@tab.string` inclusive em `<chord>` ✅, `meiHead`→título ✅, `<ending>`→2 `VoltaBracket` ✅, `lines="6"` ✅ [A]. **`meter.count="3+2+2"` vira `7/8` e a estrutura aditiva é perdida** — e o 7/8 depois é agrupado 2-2-3, contradizendo o arquivo. `clef.shape="TAB"` não produz clave nenhuma [A] |
| **NOVO-7** MusicXML `<transpose>`, `<unpitched>`, `<sound tempo>`, `<staff-lines>` | 🟡 PARTIALLY FIXED | `<staff-lines>1` → `lineCount=1` ✅; `<sound tempo="132">` → `TempoMark(132)` + evento MIDI ✅; `<unpitched>` não é mais descartado ✅ [A]. **`<transpose>` é lido para `Score.metadata['transpositions']` e nada o consome: `applyMusicXmlTransposition` não é chamada em `lib/`, `test/` nem `example/`** — nota com `<transpose>-2</transpose>` sai em MIDI 60, não 58 [A]. E `<unpitched>` vira nota afinada comum, sem como voltar |

### 2.2 Nota

```
ACHADOS VERIFICADOS: 38
  CONFIRMED FIXED    : 25   (25/38 = 65,8%)
  PARTIALLY FIXED    : 13   (34,2%)
  NOT FIXED          :  0
  REGRESSED          :  0   (nenhum dos 38 casos citados regrediu)
  UNVERIFIABLE       :  0

NOTA DE REMEDIAÇÃO = (25 + 0,5×13) / 38 = 31,5 / 38 = 0,829
ACHADOS NOVOS: 30 (0 regressões diretas + 30 encontrados na Parte A)
```

### 2.3 A remediação melhorou ou piorou o projeto?

**Melhorou, de forma inequívoca — com uma exceção medida (desempenho).**

O que melhorou de verdade, não de fachada:
- **A identidade do modelo sobrevive ao pipeline.** Isso não é cosmético: era a
  causa-raiz de quatro sintomas distintos e o bloqueador estrutural de qualquer
  editor. É a correção mais valiosa da release.
- **O alinhamento multi-pauta por onset musical** é a solução arquitetural certa
  (grade compartilhada, remapeamento monotônico), não um remendo.
- **Uma única métrica de largura** (medição por dry-run) elimina por construção a
  classe de bug F-12.
- **A suíte de testes deu um salto qualitativo real**: invariantes de propriedade,
  fuzz, e uma suíte *escrita para atacar a própria remediação*. Isso é raro e
  honesto.

O que piorou:
- **Desempenho.** 400→160 ms, 800→143 ms, 1600→262 ms, 3200→1156 ms, **6400→5991 ms**
  [A]. A justificação é O(sistemas × elementos): a mesma partitura em um único
  sistema leva 115 ms contra 664–717 ms em 800–1600 sistemas (**5,8–6,3×**) [A].
  Trocou-se um teto duro (1.000 sistemas) por uma degradação quadrática.
- **Superfície de falha nova no grand staff**: exceção em compasso sobrecheio e
  perda silenciosa das opções de beaming em sistemas quebrados.

E o padrão dominante: **a remediação corrigiu o caso citado no achado, e o teste
escrito junto testa exatamente esse caso.** Onze dos treze "PARTIALLY FIXED" são
o caso vizinho imediato.

---

## 3. REALIDADE VS DOCUMENTAÇÃO

| Documento | Afirma | Realidade medida |
|---|---|---|
| `README.md` §Editorial, linha 331 | "Rehearsal marks \| **MODEL ONLY** \| nada desenha" | **Falso — desenha.** Golden `m04s_rehearsal_marks.png` mostra caixas SMuFL; `SymbolAndTextRenderer:607` implementa. O README está **desatualizado em relação ao próprio CHANGELOG da release** |
| `README.md` §What's New 2.7.0 | "30 of 54 goldens were re-baselined" | **Errado.** 53 goldens no disco; 40 alterados no commit, dos quais 1 é novo → **39 regravados + 1 novo**. A mensagem de commit ("39 of the 52 existing... plus one new") está certa; o README, não |
| `README.md` §Editorial | "Instrument / group names \| **SUPPORTED**" | **Só para código escrito à mão.** `<part-name>` e `<group-name>` **não são importados**; `StaffGroup.name` volta `null` e `Staff` **não tem campo de nome** [A] |
| `README.md` §Editorial | "Transposing instruments \| **PARTIAL** \| import de `<transpose>` limitado" | **Mais grave que "limitado": é inerte.** `applyMusicXmlTransposition` é código morto, nunca chamado [A] |
| CHANGELOG | "layout 800 measures: 82ms → 87ms, still linear (1600 → 138ms)" | **Linear só até ~1600.** Medido: 800→143 ms, 1600→262 ms, 3200→1156 ms, 6400→5991 ms [A] |
| CHANGELOG / ADR-001 | "o layout não clona mais objetos do modelo" | **Verdadeiro, e melhor documentado que a média.** Mas o ADR não menciona que a alternativa escolhida — *escrever* em `Note.beam` — torna o layout uma operação **mutante** sobre o modelo do usuário [A: beams `[null×8]` → `[start,inner,inner,end]×2`] |
| `doc/AUDITORIA_FORENSE_2026-08-21.md` §20 | "Multi-staff: 2 — não alinha eventos simultâneos" | **Corrigido.** O alinhamento por onset existe e funciona |
| dartdoc `layout_engine.dart:1021` | "o dry run não deixa rastro em `_noteXPositions` and friends" | **Falso para quialteras.** `_layoutMeasureCursor` → `_registerTupletGeometry` → `_registerTupletNotes` escreve **direto** nos mapas do engine, não no cursor-sonda [B] |
| `MidiMapper` dartdoc:25 | "`Pitch.octave` é a oitava ESCRITA" | Convenção coerente **internamente**, mas **incompatível com MusicXML**, onde `<pitch>` é a oitava soante — e o importador não converte [A] |
| pubspec `flutter.plugin.platforms` | android, ios, linux, macos, web, windows | **Só Android tem motor real** (350 linhas Kotlin + 608 C++/Oboe). Os outros 5 são stubs que devolvem `false`/`null`. **O README §Current Status declara isso explicitamente** — documentação honesta |

---

## 4. ARQUITETURA ATUAL

### 4.1 O sistema reconstruído

```
lib/  140 arquivos .dart  43.784 linhas
  core/            41  modelo musical (Pitch, Duration, Note, Chord, Rest, Tuplet,
                       Measure, MultiVoiceMeasure, Voice, Staff, Score, StaffGroup,
                       Clef, KeySignature, TimeSignature, Barline, Slur, Text,
                       Neume, Mensural, Tablature, FiguredBass, MeiHeader, ...)
  src/parsers/      8  MusicXML, MEI, JSON, NotationParser (+ parser_support 3.4k linhas)
  src/layout/      15  LayoutEngine (2.352 linhas), spacing/, beam_grouper, validators
  src/beaming/      7  BeamAnalyzer, BeamGroup, BeamSegment, BeatPositionCalculator
  src/rendering/   40  StaffRenderer, GrandStaffPainter, renderers/*, gregorian/*, jianpu/*
  src/smufl/        3  metadata loader, coordenadas, categorias de glifo
  src/midi/         7  MidiMapper, MidiFileWriter, ChantMidiMapper, ponte nativa
  src/export/       4  PdfExporter, ScoreRasterizer, PdfPreviewWidget
  src/interaction/  1  ScoreHitTester
```

### 4.2 Pipeline declarado vs pipeline real

```
INPUT → PARSER → NORMALIZATION → MODEL → LAYOUT → ENGRAVING → RENDER → DISPLAY
```

**Existe de verdade**, com uma ressalva: não há etapa de *normalization*
separada. Os parsers escrevem direto em `Measure.elements` (o dartdoc admite que
isso contorna a validação de `Measure.add`), e `MeasureValidator` roda **dentro**
do layout, tarde demais para corrigir nada.

```
MODEL → MIDI MAPPING → TIMELINE → PLAYBACK → MIDI EXPORT
```

**Existe até `MIDI EXPORT`.** `PLAYBACK` existe apenas no Android.

```
MusicXML / MEI / JSON → PARSERS → NORMALIZED MODEL → SAME RENDERER
```

**Parcialmente falso.** MusicXML e MEI convergem no mesmo modelo; **JSON não tem
exportador** e o importador perde `syllables` e `crossStaffMove` [A].

### 4.3 Quantos pipelines de layout independentes existem?

**Quatro**, e é o problema estrutural central do projeto:

1. **`LayoutEngine`** — CMN monopauta. A única implementação com espaçamento
   proporcional, resolução de acidentes, compressão e onset.
2. **`GrandStaffPainter`** — multi-pauta. Chama `LayoutEngine` por pauta e depois
   remapeia. Tem **sua própria** fórmula de altura (`totalHeight`,
   `systemBlockHeight`) e sua própria reconstrução de compasso (`_systemStaff`).
3. **`TupletRenderer`** — grade fixa de 2,5 espaços, **seu próprio** desenhador de
   barras (`_drawSimpleBeams`) que lê a contagem de barras **só da primeira nota**.
4. **`GregorianRenderer`** — pipeline totalmente à parte (correto e coeso, mas
   sem nada em comum com o CMN).

A `ScoreRasterizer` é uma **quinta** cópia parcial da geometria de sistema — o
comentário `"Kept in sync with MusicScorePainter.paint"` é exatamente o padrão
que gerou o F-12. Medi: para pauta única ela **concorda** com
`LayoutEngine.calculateTotalHeight` (332,4 == 332,4) [A]. Para grand staff ela
nem participa: o PDF exporta cada pauta em separado.

---

## 5. MUSIC MODEL

**Nota: 7/10** (era 6).

**Sólido:** `DurationType` cobre maxima→2048ª com `realValue`/`absoluteValue`
corretos; `Pitch` agora tem `==`/`hashCode`, `Pitch.validated`, oitavas negativas
e microtons; `Tuplet.totalDuration` soma o conteúdo real inclusive aninhado [A];
`Measure` tem capacidade por voz.

**Problemas estruturais:**

- **`Note.beam` é estado mutável público que o layout escreve.** Serializar um
  `Staff` antes e depois de renderizar dá resultados diferentes [A]. É uma decisão
  consciente (ADR-001), mas transforma "renderizar" numa operação com efeito
  colateral sobre o dado do usuário.
- **`MultiVoiceMeasure` viola LSP de forma destrutiva.** Herda `elements` (público,
  documentado, alimentado por `Measure.add`), inclui-o em `allElements` — e o
  layout **nunca o lê**. Ver N-03.
- **Três fontes de verdade para "voz"**: `Note.voice`, `Voice.number`, e
  `PositionedElement.voiceNumber`. O layout usa a primeira, o MIDI usa a segunda.
- **Geometria com chave de identidade não suporta reuso.** Ver N-06/F-08.

---

## 6. ENGRAVING

**Nota: 5,5/10** (era 4). Progresso grande, teto ainda baixo.

**Correto e verificado [A]:** posição de altura por clave; linhas suplementares;
direção de haste (nota mais distante da linha central; empate → baixo);
comprimento de haste de acorde = extensão + 3,5 espaços a partir da cabeça
oposta; barras secundárias e terciárias corretas (8ª+2×16ª → níveis 1 e 2;
8ª+4×32ª → níveis 1, 2 e 3); acidentes intra-compasso com regra de oitava
(`F#4, F#4, F#5, F#4` → `show, hide, show, hide`); cortesia com parênteses;
número de compasso; ligaduras cruzando sistema em dois segmentos; pausa de
compasso centralizada; folga acima/abaixo reservada.

**Errado ou ausente [A]:**

- **Inclinação de barra é praticamente um sinal, não uma medida.** `maximumBeamSlant = 0.5`
  (comentário no código: *"Reduced maximum (was 1.0, too steep!)"*) e, para pares,
  `beam_analyzer.dart:232` corta em **0,25** com a justificativa *"Keep them
  visually closer to the flatter beam style already used by the stable beam
  showcase examples"* — o número foi calibrado contra os próprios exemplos do
  pacote, não contra a referência. Medi: 2ª ascendente → 0,25 sp; **6ª → 0,25 sp;
  duas oitavas → 0,25 sp** [A]. Gould pede 0,25 → 2 espaços conforme o intervalo.
- **Sem regra de comprimento máximo de haste nem quebra de barra por âmbito.**
  Grupo C4–C6 produz haste de **10,25 espaços** [A].
- **4/4 em semicolcheias agrupa 8-8**, enquanto 3/4 agrupa 4-4-4 [A].
- **Dentro de quialtera não há espaçamento rítmico nenhum**: semínima e colcheia
  na mesma tercina recebem **30,00 px cada** [A].
- **A largura do acidente é reservada do lado errado** (ver N-05).
- Unísono entre vozes é deslocado por uma cabeça inteira (Gould: cabeça única com
  duas hastes).
- Colchete de quialtera com as duas metades não colineares (visível no render 3×).

---

## 7. LAYOUT ENGINE

**Nota: 5/10** (era 3).

**Ganhos reais:** uma única métrica de largura (dry-run); `_spacingScale` com
piso; onsets carregados por todo elemento; assinatura estrutural determinística;
justificação que não estica o bloco de abertura; sem teto de sistemas.

**Defeitos:**

- **`_justifyHorizontally` é O(sistemas × elementos)** [A/B]: dois laços sobre
  `elements` inteiro dentro do laço de sistemas.
- **`_analyzeBeamGroups` retorna cedo se `timeSignature == null`** [B]: o exemplo
  de quick-start do README (um `Measure()` sem fórmula) **nunca recebe análise
  avançada de barras** — as barras são carimbadas, mas sem geometria [A: 0 grupos].
- **`_layoutMultiVoiceMeasure` ignora `measure.elements`** [B] — ver N-03.
- **A medição por dry-run tem efeito colateral em quialteras** [B]: escreve nos
  mapas do engine. Hoje é encoberto porque o layout real sobrescreve logo depois,
  mas é uma bomba-relógio.
- O dry-run **dobra** o custo de agrupamento de barras (`_processBeamsWithAnacrusis`
  roda 2× por compasso).

---

## 8. SMuFL / BRAVURA

**Nota: 7,5 / 8** (era 7 / 7).

Genuinamente SMuFL-compliant nas larguras e âncoras: `getGlyphWidth` alimenta
clave, cabeça e acidentes, `getEngravingDefault` alimenta espessura de linha e
`barlineSeparation`. `SmuflFontDescriptor` + família `packages/flutter_notemus/Bravura`
tornam a fonte de fato trocável — e o harness de golden usa isso como *guarda*
(se algum renderizador usasse `'Bravura'` puro, os goldens sairiam com caixas).
Nenhum codepoint hardcoded.

**Mas** a camada de *espaçamento* contradiz o metadado nos pontos críticos:
`_minimumInterNoteGap` usa `head * 0.9` e `+ staffSpace * 0.6` para acidente, em
vez das larguras que o próprio engine já sabe consultar — é por isso que o
bemol-dobrado colide [A].

---

## 9. MUSICXML

**Nota: 5,5/10** (era 4).

**Importado e verificado [A]:** `<divisions>`, `<duration>` sem `<type>`,
`<backup>`, `<forward>`, `<voice>`, vozes sintéticas, `<chord>`, `<grace>`,
articulações, `<slur number>`, `<lyric>`, `<dynamics>`, `<direction><words>`,
`<sound tempo>`, `<repeat>`, `<barline>`, `<staff-details><staff-lines>`,
`<clef-octave-change>`, `<unpitched>`, `<part-group>` com `brace`, multi-pauta
com roteamento cross-staff.

**Perdas medidas na importação:**

| Elemento | Destino |
|---|---|
| `<transpose>` | vai para `Score.metadata`, **ninguém consome** |
| `<unpitched>` | vira nota afinada comum, identidade perdida |
| `<part-name>` | descartado (`Staff` não tem nome) |
| `<group-name>` | descartado (`StaffGroup.name` = null) |
| `<pitch>` sem `<octave>` | **nota descartada em silêncio** |
| `<pitch>` + clave 8vb | interpretado como escrito → **uma oitava errada** |

**Ordem de elementos: defeito universal.** O MusicXML exige `key, time, clef`
dentro de `<attributes>`. A correção do F-01 passou a preservar a ordem do
documento, então **toda partitura importada desenha a clave depois da armadura**:
`KeySignature@30,0 → TimeSignature@69,6 → Clef@105,6` [A, confirmado também no
render 3×].

**Round-trip `MusicXML → modelo → staffToMusicXML → MusicXML`:** notas, alturas,
durações, vozes, `<backup>`, articulações, ligaduras, lyrics, dinâmicas, repetições
e `<divisions>` sobrevivem [A]. `<transpose>` e `<unpitched>` **não são emitidos**.
Não existe `scoreToMusicXML`: **o export é por pauta**, então `part-list`,
agrupamentos e nomes de parte não podem sair. Classificação: **lossy**.

---

## 10. MEI

**Nota: 6,5/10** (era 4). É a maior subida da release.

`MODEL ONLY | PARSED | RENDERED | EXPORTED | ROUND-TRIPPABLE`:

| Módulo | Status |
|---|---|
| Pitch/Duration, Events, Measure/Staff | PARSED + RENDERED |
| Clef/Key/Meter (`@mode`, `meter.count` aditivo) | PARSED + RENDERED, **estrutura aditiva perdida** |
| `<section>` (inclusive aninhadas) | PARSED ✅ |
| `<ending>` → `VoltaBracket` | PARSED + RENDERED ✅ |
| `@tab.fret` / `@tab.string`, inclusive em `<chord>` | PARSED + RENDERED ✅ |
| `<meiHead>` (fileDesc, titleStmt, contributors) | PARSED, **não renderizado, não exportado** |
| `clef.shape="TAB"` | **não mapeado — nenhuma clave** |
| Mensural, FiguredBass, HarmonicAnalysis | MODEL ONLY (documentado em `doc/MODEL_ONLY.md`) |
| Export MEI | **não existe** → nada é ROUND-TRIPPABLE |

A ordem clave/armadura no MEI está **correta** (`Clef, KeySignature, TimeSignature`)
[A] — o defeito é exclusivo do MusicXML.

---

## 11. MIDI / PLAYBACK

**MIDI: 8/10** (mantido). **Playback: 3,5/10** (era 3).

**Correto e medido [A]:** PPQ 960; tercina de semínimas = 640 ticks cada, exato;
mínima = 1920; expansão de repetição `C, D, C, D, E` em 0/3840/7680/11520/15360;
tempo de `<sound tempo>`; `separateTracksPerVoice` → `Staff 1 - Voice 1/2`;
`mutedVoices`/`soloVoices` funcionam em `MultiVoiceMeasure` e em import MusicXML;
canto gregoriano GABC → MIDI com alturas corretas (F3 G3 A3 A3 A3 C4 A3 G3 F3 F3).

**Errado:**
- **Claves de oitava aplicadas sobre `<pitch>` soante** = uma oitava de erro em
  qualquer parte de tenor importada.
- **`Note.voice` num `Measure` simples é ignorado**: mute não silencia nada, solo
  silencia tudo [A].
- `<transpose>` inerte → clarinete em Si♭ toca em altura escrita.

**Seleção para tocar:** por voz ✅, por pauta ✅ (`mutedStaves`/`soloStaves`), por
região **não** — `ScoreHitTester.selectTimeRange` devolve elementos, mas não há
caminho que alimente `MidiMapper` com uma faixa de onsets. Falta um
`MidiGenerationOptions.timeRange` e um `fromSelection`.

---

## 12. GREGORIAN

**Nota: 8/10** (era 7). O subsistema mais bem projetado do repositório.

Verificado [A]: GABC `(c4) Ky(f)ri(gh)e(h.) *(;) e(hjh)le(g)i(f)son.(f.) (::)`
→ 9 elementos, clave `doClef`, **0 construções não suportadas**, e playback com
as 10 alturas corretas. A calibração vertical é **medida do arquivo de fonte**
(`diatonicStepUnits() = 158,0` contra o fallback 157,5) — a alegação F-29 é
verdadeira e o método é o certo (deduzir o passo diatônico dos glifos de âmbito
conhecido, não fixar uma constante). 5.782 glifos no `greciliae_glyphnames.json`.

**Ressalva estrutural:** é um pipeline paralelo. Não compartilha layout,
espaçamento, hit-test, export PDF nem seleção com o CMN. Nada do que a 2.7.0
adicionou para o editor (identidade, onset, `ScoreHitTester`) alcança o canto.

---

## 13. POLYPHONY / MULTI-STAFF

**Polifonia: 5/10** (era 3). **Multi-staff: 5/10** (era 2).

O alinhamento por onset é a correção mais importante da release e **funciona**:
`_onsetAnchorsOf` monta a grade, `_alignStaves` toma o máximo por instante e
remapeia cada pauta por partes lineares (monotônico por construção, então não
reordena eventos).

**Mas:**
- `_alignStaves` **não re-ancora notas internas de quialtera** [B] — as barras
  dentro delas ficam com X obsoleto.
- A quantização `(onset*1024).round()` **colapsa** onsets abaixo de 1/1024:
  16 onsets distintos de fusas de 2048 → **9 chaves** [A]. Irrelevante na prática,
  mas a alegação de suportar 1/2048 na grade não se sustenta.
- `_systemStaff` reconstrói o primeiro compasso de cada sistema quebrado com
  `Measure()` novo → **perde `autoBeaming`, `beamingMode`, `manualBeamGroups`,
  `number`** [A: 8 compassos com `autoBeaming: false`, só o compasso 0 preservado].
- E **lança `MeasureCapacityException`** se esse compasso estiver sobrecheio [A].

---

## 14. FLUTTER ARCHITECTURE

**Nota: 4,5/10** (era 4).

`RepaintBoundary`, `LruCache` de `TextPainter`, `shouldRepaint` baseado em
assinatura estrutural (agora que ela é determinística, o culling finalmente
funciona), `FutureBuilder` para metadados, `dispose` correto.

**Problemas:** o layout inteiro roda no construtor do `CustomPainter`
(`GrandStaffPainter` faz `_computeSystemRanges` + `_layoutSystem` ali) — logo,
**qualquer rebuild reexecuta o layout**, e uma exceção de modelo derruba a árvore
de widgets em vez de virar um erro tratável. Zero isolates: 6 s de layout em
6.400 compassos bloqueiam a UI thread. `SmuflMetadata` continua com singleton
global, embora `SmuflMetadata.independent` já exista.

---

## 15. PERFORMANCE

**Nota: 4/10 — REGREDIU** (era 5).

Medido [A], mesma máquina, após warm-up:

| Compassos | Elementos | Layout | Razão vs anterior |
|---:|---:|---:|---:|
| 400 | 3.800 | 160,1 ms | — |
| 800 | 7.600 | 143,3 ms | 0,89× |
| 1.600 | 15.200 | 261,8 ms | 1,83× |
| 3.200 | 30.400 | 1.155,6 ms | **4,41×** |
| 6.400 | 60.800 | 5.991,3 ms | **5,18×** |

Isolamento da causa [A]: a mesma partitura em **um único sistema** (largura 1e8,
onde a justificação é pulada por ser o último sistema) leva **115 ms** para 1.600
*e* para 3.200 compassos; com 800/1.600 sistemas leva 664/717 ms — **5,8× e 6,3×**.

**Causa-raiz [B]:** `_justifyHorizontally` itera `elements` inteiro (duas vezes)
para **cada sistema**. Custo O(S·N) com S ∝ N.

**Causa secundária:** `_calculateMeasureWidthCursor` executa o layout completo do
compasso uma segunda vez, dobrando o custo de agrupamento de barras.

---

## 16. TESTES — e o que os novos testes NÃO testam

**Nota: 7/10** (era 5). 594 → **792 testes**. A disciplina é real: as invariantes
L1–L11 codificam propriedades, não fotos, e `layout_self_adversarial_test.dart`
foi escrito explicitamente para atacar a remediação. Isso é honesto e raro.

**Agora, o que elas não testam** — cada item abaixo é um bug que passa com a
suíte verde:

| Teste | Assere | O que escapa |
|---|---|---|
| `L6 all fifteen duration types are ordered` | `greaterThanOrEqualTo` | **≥ deixa passar a saturação**: 128ª..2048ª têm espaçamento *idêntico* ao da 64ª. A lei proporcional cobre 10 dos 15 tipos, não 15 |
| `L8 noteheads do not overlap` | 24 semifusas **sem acidentes**, piso `head*0.85` | Não testa acidente nenhum. Com bemol-dobrado há sobreposição de 7,08 px [A]. E `0.85` já tolera cabeças encostando |
| `autoBeaming: false leaves the author beams untouched` | **um** compasso, `LayoutEngine` direto | Não passa por `GrandStaffPainter`, logo nunca exercita `_systemStaff` — que destrói a configuração em todo sistema quebrado [A] |
| `compression does not leak into the following bar` | `closeTo(refGap, refGap * 0.35)` | **Tolerância de ±35 %** — esconderia um erro de espaçamento de um terço |
| `L7 four quarters against two halves` | 2 pautas, durações simples | Não testa quialtera contra semínimas (o caso em que `_alignStaves` deixa X obsoleto), nem 3+ pautas, nem sistemas quebrados |
| `F-03 compound meters` | 3/8, 6/8, 9/8, 12/8, 6/8-em-16ºs | Não testa **4/4 em semicolcheias** (agrupa 8-8, errado), nem 5/8, 7/8, 8/8, nem compasso aditivo vindo do MEI |
| `L2 a reused Note instance is not swallowed` | conta `PositionedElement` | Não verifica `noteXPositions` — que colapsa 3 ocorrências em 1 [A] |
| Toda a suíte de invariantes | usa `Measure()` + `elements.add` | **Nunca constrói um `MultiVoiceMeasure` com clave em `measure.elements`** — o caminho que perde tudo [A] |
| Goldens | via `pumpCase`, que injeta `ThemeData.fontFamily = 'Roboto'` | O número de compasso **não pede fallback de fonte nenhum** (`_renderMeasureNumbers` monta o `TextStyle` sem `fontFamilyFallback`). O golden só passa porque o harness injeta uma fonte que a biblioteca nunca pede. No caminho `ScoreRasterizer`/PDF ele sai como **caixa `.notdef`** [A, visto no render] |
| Todos | | Nenhum teste passa por `ScoreRasterizer`/`PdfExporter` com texto |

**Sobre os goldens (B.2.10):** abri as imagens e reampliei os casos críticos a 3×.
Os 39 regravados que examinei são **melhores** que os anteriores, não piores —
hastes de acorde corretas, `m04s_rehearsal_marks` correto, `s02_ode_to_joy` com
numeração de compasso correta. **Nenhum dos que examinei está errado no sentido de
ter congelado uma regressão.** Mas eles **congelam** os defeitos de qualidade que
a 2.7.0 não tocou: barras quase horizontais, grade fixa de quialtera, colchete de
quialtera partido.

---

## 17. SEGURANÇA

**Nota: 7,5/10** (era 7). **Não encontrei evidência de falha nesta área.**

Verificado por execução [A]:
- **XXE:** `<!ENTITY xxe SYSTEM "file:///etc/passwd">` → documento parseia, entidade
  **não é resolvida**, campo vira `null`. Nenhum arquivo é lido.
- **Billion laughs** (6 níveis, ~10⁷ chars expandidos): parseia em **6 ms**, sem
  expansão. Sem DoS.
- **Aninhamento profundo** (20.000 níveis): `FormatException` em 87 ms. Falha segura.
- **Sem I/O de arquivo em `lib/`**: `grep -rn "dart:io\|File(\|Directory(\|Process\."` → **zero ocorrências**. Não há path traversal possível.
- **Entrada malformada** já não derruba: `FormatException` de domínio.
- Sem segredos no repositório; CI sem credenciais expostas.

**Ressalvas:**
- Entidades não resolvidas viram `null` **em silêncio** — perda de dado sem aviso.
- `Pitch` valida por `assert` no construtor `const`: em **release os asserts somem**.
  A mitigação real é `Pitch.validated`, que os parsers usam; e `_stepSemitone`
  lança `StateError` em vez de estourar null. Aceitável, mas o construtor público
  continua sem rede em release.
- Compasso sobrecheio vindo de import + grand staff = **exceção não tratada** que
  derruba a árvore de widgets (N-01). É robustez, não segurança, mas é o mesmo
  vetor: arquivo de terceiro derruba o app.

---

## 18. API PÚBLICA

**Nota: 5/10** (era 4).

**Melhor:** `noteXPositions`/`noteYPositions` finalmente úteis (identidade estável);
`ScoreHitTester` exportado; `AccidentalDisplay`/`AccidentalResolver` exportados
junto com o mapa que os usa; `SmuflFontDescriptor` torna a fonte trocável.

**Problemas:**
- **`PdfExporter`/`ScoreRasterizer` não são exportados** de `lib/flutter_notemus.dart`;
  só via `package:flutter_notemus/src/export/export.dart` — importar de `src/` é o
  que a convenção Dart diz para não fazer.
- **`Note.beam` é mutável e o layout escreve nele.** Faz parte do contrato agora.
- `MusicXMLParser` expõe `staffToMusicXML` mas **não** `scoreToMusicXML`.
- `JsonMusicParser` só tem `parseStaff` — não há exportador JSON.
- `Measure` expõe `elements` publicamente, mas em `MultiVoiceMeasure` escrever ali
  não tem efeito de renderização — sem `@Deprecated`, sem `assert`, sem doc.

---

## 19. DÍVIDA TÉCNICA POR CATEGORIA

**Duplicação de implementação (a mais cara)** — 4 pipelines de layout, 2 fórmulas
de altura, 2 desenhadores de barra, 2 caminhos de rasterização.

**Números mágicos com justificativa circular** — `maxTwoNoteAutoSlantSpaces = 0.25`
("looks like our showcase"), `maximumBeamSlant = 0.5` ("was 1.0, too steep!"),
`head * 0.9`, `staffSpace * 0.6` para acidente, `minimumSpacingScale = 0.35`,
`tupletInnerSpacing = 2.5`, `averageGlyphWidth = 0.5` em `_syllableWidth`,
clamp de haste de acorde em `6.0`.

**Estimativas onde há medição disponível** — largura de sílaba por contagem de
caracteres (`text.length * staffSpace * 0.85 * 0.5`) enquanto o renderizador usa
`TextPainter` real; caixas do `ScoreHitTester` estimadas em vez de derivadas da
geometria desenhada.

**Contratos implícitos não documentados** — "clave deve estar dentro da voz 1"
(`MultiVoiceMeasure`); "`Pitch` é altura escrita" (incompatível com MusicXML).

**Código morto alcançável só por dartdoc** — `applyMusicXmlTransposition`.

**Comentários e identificadores em portunhol/inglês macarrônico** — `"Not chamar
BeamGrouper newmente"`, `"ANÃƒÂLISE DE BEAMING"`, `"CORREÇÃO CRÃƒÂTICA"`. Aparece
em `pub.dev` como dartdoc corrompida.

---

## 20. TOP 10 PROBLEMAS

Ordenados por `impacto × probabilidade × dano arquitetural`.

| # | ID | Sev | Problema | Por que aqui |
|---|---|---|---|---|
| 1 | N-11 | **P1** | Clave desenhada depois da armadura em **toda** importação MusicXML | Probabilidade 100 % em qualquer arquivo real, visível em qualquer screenshot, erro de gravação elementar |
| 2 | N-03 | **P1** | `MultiVoiceMeasure.elements` descartado → notas sem altura | Silencioso, plausível de olhar, corrompe a música; API convida ao erro |
| 3 | N-01 | **P1** | `GrandStaffPainter` lança em compasso sobrecheio num sistema quebrado | Derruba o app com arquivo de terceiro; o próprio dartdoc diz que importadores geram esses compassos |
| 4 | N-04 | **P2** | Justificação O(n²) — 6.400 compassos = 6,0 s na UI thread | Regressão de desempenho; bloqueia escalabilidade e vira jank |
| 5 | N-15 | **P2** | Claves de oitava: `<pitch>` soante tratado como escrito | Toda parte de tenor/soprano-8vb sai uma oitava errada, na tela **e** no som |
| 6 | N-10 | **P2** | Inclinação de barra fixa em ±0,25/0,5 espaço | Afeta cada grupo de colcheias de cada partitura; é a diferença visual entre "gravado" e "desenhado" |
| 7 | N-07/N-08 | **P2** | Quialtera: grade fixa de 2,5 sp + desenhador de barra próprio que lê só a 1ª nota | Tercinas são onipresentes; ritmo interno fica visualmente errado e barras secundárias somem |
| 8 | N-05/F-27 | **P2** | Largura de acidente reservada **depois** da nota | Mede-se: gap antes +6,3 px, depois +15,6 px [A]. Causa a colisão sob compressão |
| 9 | N-02 | **P2** | Sistemas quebrados perdem `autoBeaming`/`manualBeamGroups`/`number` | Descarta a intenção explícita do autor, em silêncio |
| 10 | N-13 | **P2** | `<transpose>` inerte (`applyMusicXmlTransposition` é código morto) | Instrumentos transpositores tocam errado; o dado está lá, inalcançável |

---

## 21. MATRIZ DE MATURIDADE (2.6.0 → 2.7.0)

| Área | 2.6.0 | 2.7.0 | Δ | Justificativa da mudança |
|---|---:|---:|---:|---|
| Modelo musical | 6 | **7** | +1 | `==`/`hashCode`, `Pitch.validated`, oitavas negativas, `Tuplet.totalDuration` correto, capacidade por voz. Não sobe mais porque o layout agora **muta** `Note.beam` e `MultiVoiceMeasure` quebra LSP de forma destrutiva |
| Engraving | 4 | **5,5** | +1,5 | F-01/03/14/15/16/26/33/55 e o clipping resolvidos e medidos. Teto pela inclinação de barra fixa, grade de quialtera, lado do acidente e 4/4 em 16ºs |
| Layout | 3 | **5** | +2 | Métrica única por dry-run, compressão com piso, onsets, determinismo, sem teto. Penalizado por O(n²), pelo gate de `TimeSignature` e por `MultiVoiceMeasure` |
| SMuFL | 7 | **7,5** | +0,5 | Larguras de acidente agora do metadado. Ainda há pisos mágicos que contradizem o metadado |
| Bravura | 7 | **8** | +1 | `SmuflFontDescriptor` + família qualificada por pacote = fonte de fato trocável, com o harness servindo de guarda |
| MusicXML | 4 | **5,5** | +1,5 | Os quatro pilares de timing corrigidos + staff-lines + sound tempo + unpitched. **Derrubado pela ordem clave/armadura**, `<transpose>` inerte e perda de nomes de parte |
| MEI | 4 | **6,5** | +2,5 | Todas as `<section>`, `@mode`, `@tab.*`, `meiHead`, `<ending>`. Falta grupo aditivo, `clef.shape="TAB"` e exportador |
| JSON | 6 | **5** | **−1** | Nada melhorou, e a auditoria anterior foi generosa: **não há exportador**, e o import descarta `syllables` e `crossStaffMove` [A] |
| MIDI | 8 | **8** | 0 | Ganhou faixas/mute/solo por voz; perdeu o mesmo tanto ao aplicar oitava de clave sobre `<pitch>` soante |
| Playback | 3 | **3,5** | +0,5 | Mute/solo/faixa por voz é útil. Continua 1 plataforma de 6 |
| Gregorian | 7 | **8** | +1 | Calibração medida da fonte (158,0), não estimada. Continua sendo um pipeline apartado |
| Polifonia | 3 | **5** | +2 | Colisão por onset funciona (deslocamento de exatamente 1 cabeça), capacidade por voz, MIDI por voz. Travado por `MultiVoiceMeasure.elements` e por `Note.voice` ignorado no MIDI |
| Multi-staff | 2 | **5** | +3 | **A falha definidora da 2.6.0 foi corrigida** e medida. Penalizado por exceção em compasso sobrecheio, perda de opções em sistema quebrado e quialteras não re-ancoradas |
| Performance | 5 | **4** | **−1** | Teto de sistemas removido, mas justificação O(n²): 6.400 compassos = 6,0 s, contra 115 ms em sistema único |
| Arquitetura Flutter | 4 | **4,5** | +0,5 | `shouldRepaint` finalmente eficaz. Layout ainda no construtor do painter, sem isolate |
| Testes | 5 | **7** | +2 | 792 testes, invariantes de propriedade, fuzz, suíte auto-adversarial. Penalizado por asserções mais fracas que as alegações e por não cobrir os caminhos grand-staff/MultiVoice/raster |
| Golden tests | 6 | **6,5** | +0,5 | F-04 descongelado, caso novo, regravações são melhorias reais. Ainda congelam defeitos de qualidade, e um deles só passa por causa de fonte injetada pelo harness |
| Segurança | 7 | **7,5** | +0,5 | Crash em entrada inválida resolvido; XXE/billion-laughs/I-O reverificados negativos por execução |
| API pública | 4 | **5** | +1 | API de posição utilizável, hit-tester. `PdfExporter` fora do export principal; `Note.beam` mutável virou contrato |
| Documentação | 6 | **6** | 0 | CHANGELOG e ADRs excelentes; README contradiz o CHANGELOG sobre marcas de ensaio e erra a contagem de goldens |
| Escalabilidade | 3 | **3** | 0 | Teto removido, quadrático introduzido — troca lateral |
| Prontidão p/ editor | 2 | **4,5** | +2,5 | **O bloqueador estrutural caiu**: identidade estável ponta a ponta. `ScoreHitTester` existe e acerta cabeças. Falta hit-test de haste/acidente/acorde alto, cursor, inserção, undo |

**Média ponderada informal: ≈ 5,8 / 10** (era 4,7) — *"renderizador CMN competente
e honesto; motor de gravação intermediário; base de editor agora plausível."*

---

## 22. TESTES QUE PRECISAM SER CRIADOS

```dart
// I1  Ordem canônica de elementos de sistema (pega N-11)
∀ measure: idx(Clef) < idx(KeySignature) < idx(TimeSignature) no LAYOUT,
   qualquer que seja a ordem no documento de origem

// I2  MultiVoiceMeasure não perde nada (pega N-03)
∀ mv: ∀ e ∈ mv.elements, ∃ p ∈ layout(mv) com p.element == e
∀ mv com clave: |{p.position.dy : p.element is Note}| == |alturas distintas|

// I3  Renderizar nunca lança (pega N-01)
∀ staff arbitrário (inclusive compassos sobrecheios), ∀ largura:
   GrandStaffPainter(...) não lança

// I4  Renderizar é idempotente sobre o modelo (pega a mutação de beam)
serialize(staff) antes == serialize(staff) depois, para tudo exceto o que
o ADR-001 declarar explicitamente mutável

// I5  Opções de beaming sobrevivem à quebra de sistema (pega N-02)
∀ i: layout_wrapped(staff)[i].autoBeaming == staff.measures[i].autoBeaming

// I6  Espaçamento é estritamente proporcional (endurece L6)
∀ d1 < d2 ∈ DurationType: span(d2) > span(d1)   // '>' e não '>='
∀ tuplet com durações mistas: x(nota_longa→próxima) > x(nota_curta→próxima)

// I7  Nada colide, COM acidentes (endurece L8)
∀ compasso comprimido, ∀ par de notas consecutivas:
   x[i] - x[i-1] ≥ larguraCabeça + larguraAcidente(nota[i], do METADADO)

// I8  Inclinação de barra segue Gould (pega N-10)
slope(grupo) ∈ tabela_gould[intervalo(primeira, última)] ± 0.125 espaço
∀ nota em grupo com barra: 2.5 ≤ comprimentoHaste ≤ 6.0 espaços

// I9  Barras secundárias por nota, não pela primeira (pega N-08)
∀ tuplet: níveis de barra desenhados == níveis exigidos por CADA nota

// I10 Layout é O(n) (pega N-04)
t(4n) / t(n) < 6   para n ∈ {400, 1600, 6400}

// I11 Claves de oitava não deslocam duas vezes (pega N-15)
midi(import("<pitch>C4</pitch> + clef-octave-change=-1")) == 60

// I12 <transpose> chega ao som (pega N-13)
midi(import("<transpose><chromatic>-2</chromatic></transpose> + C4")) == 58

// I13 Hit-test cobre o que é desenhado (pega N-19)
∀ elemento desenhado, ∀ ponto de tinta desse elemento:
   hitTest(ponto).element == elemento

// I14 Texto usa a cadeia de fallback do pacote (pega N-16)
raster sem tema: nenhum glifo .notdef no bitmap

// I15 Fidelidade de import de nomes (pega N-23)
import(<part-name>X</part-name>).nome == 'X'
```

Além disso: **fuzz sobre `GrandStaffPainter`** (hoje o fuzz cobre só os parsers) e
**um teste de rasterização** que verifique ausência de `.notdef` no PDF.

---

## 23. PLANO DE CORREÇÃO

### Fase 0 — emergência (destrava uso real, ~1 dia)
1. **N-11**: ordenar clave → armadura → fórmula no bloco de abertura do compasso.
   *Não é um `if`*: `_layoutMeasureCursor` deve separar "bloco de abertura"
   (ordenação canônica) de "mudança no meio do compasso" (ordem do documento). O
   F-01 continua válido; só o *lead* passa a ser ordenado.
2. **N-01**: `_systemStaff` deve copiar `orig.elements` **direto** (`elements.add`),
   não via `Measure.add`. Validar é responsabilidade do importador, não do painter.
3. **N-02**: no mesmo ponto, copiar `autoBeaming`, `beamingMode`,
   `manualBeamGroups`, `number`.

### Fase 1 — críticas (~3 dias)
4. **N-03**: `_layoutMultiVoiceMeasure` deve emitir `measure.elements` como bloco
   de abertura antes das vozes. Depois disso, remover a duplicação `metadataElements`
   + `voice(1)` dos parsers (N-12) — os dois são um par compensatório, têm de cair juntos.
5. **N-04**: pré-agrupar `elements` por sistema **uma vez** (`Map<int, List<int>>`),
   e justificar por bucket. O(n).
6. **N-15**: no importador MusicXML, converter soante→escrito quando houver
   `clef-octave-change` (ou, melhor, mudar a convenção para "`Pitch` é soante" e
   deslocar no `StaffPositionCalculator` — decisão arquitetural, documentar no ADR).
7. **N-13**: chamar `applyMusicXmlTransposition` no importador, ou expor
   `Score.toConcertPitch()`.

### Fase 2 — arquiteturais (~2 semanas)
8. **Unificar o layout de quialtera**: `Tuplet` deixa de ser um elemento opaco com
   grade própria e passa a ser um *container de tempo* cujo conteúdo entra no
   mesmo cursor, com `_getRhythmicValue` escalado pela razão. Resolve N-07, N-08,
   N-27, F-11-em-quialtera e o re-ancoramento em `_alignStaves` de uma vez.
9. **Uma fórmula de altura**: `GrandStaffPainter.totalHeight` e
   `LayoutEngine.calculateTotalHeight` viram uma função só.
10. **Tirar o layout do construtor do painter**; mover para um objeto de layout
    memoizado, com caminho para isolate.
11. **Documentar e travar o contrato de `MultiVoiceMeasure`** (ou eliminar a
    subclasse e fazer `Measure` sempre multivoz).

### Fase 3 — gravação profissional (~3 semanas)
12. Tabela de inclinação de barra de Gould (N-10) + comprimento máximo de haste +
    quebra de barra por âmbito.
13. Reservar a largura do acidente **antes** da nota (N-05) e usar a largura do
    metadado no piso anti-colisão (F-27).
14. 4/4 em subdivisões < colcheia agrupa por tempo (N-21).
15. Medir a sílaba com `TextPainter` em vez de contar caracteres.
16. Unísono entre vozes com cabeça única.

### Fase 4 — interoperabilidade (~2 semanas)
17. `scoreToMusicXML` (part-list, part-group, nomes) + exportar `<transpose>` e
    `<unpitched>`.
18. Importar `<part-name>`/`<group-name>`; adicionar `Staff.name` (N-23).
19. Exportador JSON + preservar `syllables`/`crossStaffMove` (N-24).
20. MEI: preservar o grupo aditivo (`TimeSignature.additiveGroups`), mapear
    `clef.shape="TAB"`, exportador MEI.
21. `<pitch>` sem `<octave>` → `FormatException` (N-25).

### Fase 5 — editor profissional (~1 mês+)
22. `ScoreHitTester` derivado da geometria **desenhada** (bounding boxes emitidas
    pelos renderizadores), não estimada — inclui haste, acidente, linha suplementar,
    e caixa de acorde na altura real (N-19, N-20).
23. Modelo de comando (insert/delete/modify) + undo/redo sobre identidades estáveis.
24. Cursor e seleção por região alimentando `MidiMapper` (playback de seleção).
25. Levar identidade/onset/hit-test ao pipeline gregoriano.

---

## 24. ARQUITETURA RECOMENDADA

```
                    ┌──────────────────────────────────────┐
  MusicXML ─┐       │  IMPORT LAYER                        │
  MEI ──────┼──────▶│  parse → NORMALIZE → validate        │
  JSON ─────┤       │  (converte soante↔escrito, aplica    │
  GABC ─────┘       │   transpose, ordena bloco de abertura,│
                    │   emite diagnósticos)                 │
                    └───────────────┬──────────────────────┘
                                    ▼
                    ┌──────────────────────────────────────┐
                    │  MUSIC MODEL  (imutável)             │
                    │  identidade estável; nenhuma          │
                    │  informação de layout dentro          │
                    └───────────────┬──────────────────────┘
                                    ▼
                    ┌──────────────────────────────────────┐
                    │  LAYOUT  (puro: Model → LayoutResult) │
                    │  UM cursor. Tuplet é container de     │
                    │  tempo, não elemento opaco.           │
                    │  Beams em LayoutResult, NÃO em Note.  │
                    │  Onset é a única coordenada temporal. │
                    └───────────────┬──────────────────────┘
                                    ▼
                    ┌──────────────────────────────────────┐
                    │  ENGRAVING  (Gould como tabela de      │
                    │  dados, não como constantes espalhadas)│
                    │  emite BoundingBox por elemento →      │
                    │  alimenta hit-test E colisão           │
                    └───────┬───────────────────┬───────────┘
                            ▼                   ▼
                    ┌───────────────┐   ┌───────────────────┐
                    │ CANVAS RENDER │   │ RASTER/PDF RENDER │
                    │  (widget)     │   │  (mesmo código)   │
                    └───────────────┘   └───────────────────┘
```

Três mudanças carregam quase todo o valor:

1. **`LayoutResult` passa a ser o único dono da informação de layout.** Beams,
   posições e decisões de acidente saem do modelo. `Note.beam` volta a ser
   `final` e vira *dica do autor*, não saída do motor.
2. **`Tuplet` deixa de ser opaco.** Um container de tempo com razão; o conteúdo
   passa pelo mesmo cursor. Elimina o quarto pipeline de layout.
3. **Cada renderizador emite a `BoundingBox` do que desenhou.** Uma fonte de
   verdade para colisão, hit-test, skyline e folga de canvas — em vez de três
   estimativas independentes.

---

## 25. VEREDITO FINAL

**1. O engine está pronto para produção?**
Como **visualizador** de partituras de origem confiável, em Android/desktop, com
partituras de até ~1.500 compassos: **sim, com uma ressalva bloqueante** — a
ordem clave/armadura em import MusicXML (N-11) precisa cair antes. Como
**editor**: não.

**2. O engraving é profissional?**
**Não ainda — mas deixou de ser amador.** As regras estruturais (posição, haste,
acidente intra-compasso, cortesia, ligadura entre sistemas, número de compasso,
folga) estão certas e medidas. O que falta é a camada de *refinamento*: inclinação
de barra, espaçamento dentro de quialtera, lado do acidente. Um gravador
profissional reprovaria a saída; um músico leria sem dificuldade.

**3. O modelo musical é sólido?**
**Sim, com uma rachadura.** Cobertura e precisão são boas. A rachadura é
`MultiVoiceMeasure`: uma subclasse cujo campo herdado público é ignorado pelo
consumidor principal.

**4. MusicXML é confiável?**
**Não para round-trip.** Para leitura de conteúdo rítmico e de alturas, sim
(timing, backup/forward, divisions, polifonia, cross-staff funcionam e foram
medidos). Mas a ordem de gravação está errada em 100 % dos arquivos, transposição
e percussão são perdidas, e não existe export em nível de `Score`.

**5. MEI é realmente suportado?**
**Na importação, sim, e melhorou muito.** Sem exportador, portanto **não é
interoperável** — é um formato de entrada, não de intercâmbio. A tabela do README
diz `✅ modeled and imported/rendered` e essa é a leitura correta; nenhuma linha
promete round-trip.

**6. MIDI/playback é musicalmente confiável?**
**O MIDI, sim** — ties, quialteras, repetições, voltas, vozes, tempo, tudo medido
e exato ao tick. **Menos** para claves de oitava e instrumentos transpositores.
**Playback, não**: existe em 1 de 6 plataformas, o que o README declara.

**7. O sistema suporta partituras complexas?**

| Cenário | Veredito | Justificativa medida |
|---|---|---|
| **A** Piano, 500 compassos | **PARTIAL** | Alinha por onset ✅; ~90 ms; mas quebra de sistema perde opções de beaming e um compasso sobrecheio derruba o painter |
| **B** SATB, 300 compassos | **PARTIAL** | Golden `grand_staff_satb` existe; mesmas ressalvas de A |
| **C** Orquestra, 100 instrumentos | **FAIL** | `GrandStaffPainter` faz um `LayoutEngine` por pauta por sistema, tudo no construtor, na UI thread; sem isolate; sem streaming |
| **D** 4 vozes independentes por pauta | **PARTIAL** | Vozes 3–4 são posicionadas por interpolação sobre a voz 1; colisão só trata o caso de duas vozes (`// only handles the two-voice case`) |
| **E** Lyrics longas | **PASS** | 40 chars alargam o vão para 148,53 px [A]; largura estimada por contagem de caracteres é o limite |
| **F** MusicXML complexo | **PARTIAL** | `<backup>`, `<forward>`, sem `<type>`, beams secundários, `<unpitched>` ✅; `<transpose>` inerte; ordem de clave errada |
| **G** Gregoriano extenso | **PASS** | GABC → 9 elementos, 0 não suportado, playback correto [A] |
| **H** repeats + volta + quialteras + ties + cross-staff | **PARTIAL** | Cada peça funciona isolada e foi medida; a combinação quialtera + grand staff deixa X obsoleto nas notas internas |

**8. A arquitetura suporta um editor profissional?**
**Agora suporta a fundação; ainda não o editor.** O que mudou é decisivo: os
objetos do usuário sobrevivem ao pipeline, então existe algo para selecionar. O
que falta é a superfície: hit-test derivado da geometria real (hoje erra haste,
acidente e acorde alto), modelo de comando, undo/redo, cursor, inserção.

**9. Maiores riscos**
1. Ordem clave/armadura em import — visível para todo usuário, imediatamente.
2. `MultiVoiceMeasure` descartando conteúdo — silencioso e corrompe a música.
3. Exceção de layout derrubando a árvore de widgets com arquivo de terceiro.
4. Quadrático no layout, na UI thread.
5. **Meta-risco:** o padrão "corrigir o caso citado + escrever o teste desse
   caso". Ele se repete em 13 das 38 linhas verificadas. Sem invariantes que
   quantifiquem a regra (e não o exemplo), a próxima auditoria vai encontrar a
   mesma forma de achado num vizinho diferente.

**10. Ordem correta de correção**
Fase 0 (N-11, N-01, N-02) → Fase 1 (N-03/N-12 juntos, N-04, N-15, N-13) →
Fase 2 (unificar quialtera, unificar altura, tirar layout do construtor) →
Fase 3 (Gould) → Fase 4 (interop) → Fase 5 (editor). Ver §23.

**11. A remediação da 2.7.0 foi honesta?**

**Sim.** Este é o achado mais importante do relatório e merece ser dito sem
qualificação: **verifiquei 38 alegações executando código e nenhuma é falsa.**
Vinte e cinco são integralmente verdadeiras; treze são verdadeiras no caso
alegado e incompletas no caso vizinho. Nenhuma é inventada, nenhuma descreve
código que não existe, nenhuma regrediu no cenário citado.

A mensagem de commit é precisa — inclusive nos números de goldens, onde é o
README que erra. Os ADRs descrevem intenções que estão implementadas. O CHANGELOG
declara explicitamente que a saída mudou de propósito. O README declara que
5 de 6 plataformas de áudio são stubs. A auditoria anterior foi **commitada no
repositório** para que suas alegações pudessem ser conferidas — e conferi.

Três ressalvas de honestidade, todas menores:
- a afirmação de **linearidade** de desempenho não se sustenta acima de ~1.600
  compassos (é a única alegação numérica que a medição contradiz);
- a afirmação "a lei é computada sobre todos os 15 tipos de duração" é
  tecnicamente verdadeira, mas o resultado satura em 5 deles, e o teste escrito
  para prová-la usa `≥` em vez de `>`;
- o README ficou para trás do CHANGELOG (marcas de ensaio, contagem de goldens).

Nenhuma delas é engano deliberado. **A 2.7.0 é uma release de remediação honesta
que fez o trabalho difícil (a correção arquitetural) e deixou o trabalho tedioso
(os casos vizinhos) para depois.**

---

# ADENDO — correções à própria auditoria (verificadas durante a remediação 2.7.1)

Ao implementar as correções, duas conclusões deste relatório se mostraram
**erradas** e são retiradas. Registrá-las é parte do processo: o ciclo só
funciona se cada rodada puder corrigir a anterior, inclusive a si mesma.

| Achado | Status | Por quê |
|---|---|---|
| **NOVO-6 / "estrutura aditiva do MEI é perdida"** | **RETIRADO** | Falso. `TimeSignature.additiveGroups` existe, `_meiMeterFromCounts` popula-o e `BeamGrouper._beamGroupSubdivisions` já o honrava. Medido: `meter.count="3+2+2"` → `isAdditive=true, groups=[3,2,2]`. Minha inferência veio de imprimir só `numerator`, que legitimamente vale 7. A parte real do NOVO-6 era apenas `clef.shape="TAB"` (corrigido). |
| **N-27 / "colchete de quiáltera com metades não colineares"** | **RETIRADO** | Falso. `_drawTupletBracket` calcula uma única reta e interpola ambas as metades com o mesmo `yAt(x)`. O que li como desalinhamento era a própria inclinação da reta vista em baixa resolução. |

E dois achados **novos** apareceram durante a verificação:

| ID | Sev | Achado | Evidência |
|---|---|---|---|
| **N-31** | P3 | As subdivisões de barra de 5/4 eram `[0.5, 0.5]` = 1,0 contra um compasso que vale 1,25. A quinta semínima caía fora da tabela e produzia um grupo residual. | Medido: dez colcheias em 5/4 → `4-4-2` |
| **N-32** | P2 | `c8vb` embutia a oitava na própria `ClefReference` (`baseOctave: 3`), implementando a convenção *soante* enquanto **todas as outras** claves de oitava implementavam a *escrita*. A base já era internamente inconsistente antes de qualquer correção. | `_getClefReference` em `staff_position_calculator.dart` |

O N-32 é o que decidiu o ADR-003: não havia uma convenção coerente a preservar,
então a escolha passou a ser qual das duas adotar, e não se valia a pena mudar.
