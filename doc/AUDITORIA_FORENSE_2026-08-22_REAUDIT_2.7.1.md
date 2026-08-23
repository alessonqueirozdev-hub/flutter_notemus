# Auditoria forense adversarial — flutter_notemus 2.7.1

**Data:** 2026-08-22
**Alvo:** `flutter_notemus` 2.7.1, branch `sprint/forensic-remediation-2.7.1`, HEAD `5e58fab`
**Baseline de comparação:** `doc/AUDITORIA_FORENSE_2026-08-22.md` (2.7.0) e `doc/AUDITORIA_FORENSE_2026-08-21.md` (2.6.0)
**Escopo:** PARTE A (auditoria independente do zero) + PARTE B (verificação adversarial das alegações da 2.7.1)

---

## 1. SUMÁRIO EXECUTIVO

A remediação 2.7.1 é **real e majoritariamente honesta**. Das 33 alegações que
consegui julgar, **29 estão confirmadas por execução** e 4 estão parcialmente
resolvidas. Nenhuma alegação verificada é falsa. Isso é raro e merece ser dito
sem hedge: N-11 (ordem clave→armadura), N-03 (`MultiVoiceMeasure.elements`),
N-15/N-32 (claves de oitava), N-13 (`<transpose>`), N-10 (tabela de inclinação
de Gould) e N-01 (exceção em compasso sobrecheio) foram corrigidos e eu os medi
um a um.

O problema não está no que foi corrigido. Está em **três coisas que a rodada
produziu ao corrigir**:

1. **`TupletGrid` passou a ignorar o `SpacingModel` configurado.** Medido: com
   `logarithmic`, notas normais recebem razão 1,816 e as notas internas da
   quiáltera recebem 1,414 — a quiáltera fica em desacordo com o próprio
   compasso onde está. A mensagem do commit `fa2cce5` **descreve exatamente
   esse trade-off e o aceita**: resolveu a divergência layout↔renderizador
   removendo o motor de espaçamento dos dois lados, em vez de dá-lo ao
   renderizador. Os dois lados agora concordam — e ambos ignoram a configuração
   do usuário.
2. **O novo exportador JSON reintroduz o defeito que o N-12 fechou.** Depois de
   `staffToJson` → `parseStaff`, o bloco de abertura aparece duas vezes e o
   layout desenha **2 claves e 2 fórmulas de compasso**. O N-12 foi corrigido
   para MusicXML e MEI; o caminho JSON, criado nesta mesma release, o traz de
   volta.
3. **O ADR-003 foi aplicado só às claves.** `OctaveMark` (colchete 8va/8vb)
   continua sem efeito nenhum sobre a altura impressa: C6 sob 8va imprime em
   `y=12.0`, idêntico a C6 sem 8va. O getter `OctaveMark.octaveShift` existe e
   **não tem um único consumidor**. Sob a convenção que o próprio ADR-003
   declara, isso é o espelho exato do bug que ele corrigiu.

Fora isso, encontrei defeitos que **nenhuma das duas auditorias anteriores
pegou**, porque ambas olharam goldens em escala 1:1: o **numeral da quiáltera é
desenhado 0,95 espaço fora da linha do colchete**, dentro de um vão que o
próprio colchete abre para ele. Está nas duas versões. Ampliado 8× e confirmado
no código (`tuplet_renderer.dart:391`).

Duas retiradas da rodada anterior estão **corretas** e eu as confirmo por
medição: N-27 (colchete não colinear) era falso — as metades ficam sobre uma
reta com erro de 0,05 a 0,36 px; e as regravações de golden que examinei são
melhorias genuínas, não congelamento de defeito.

**NOTA de remediação (B.4): 0,939** sobre as 33 linhas julgáveis
(0,861 se as 3 não verificáveis contarem como zero).

**Veredito de uma linha:** a 2.7.1 corrigiu de verdade, mediu o que corrigiu, e
introduziu três defeitos novos ao fazê-lo — dois deles em código escrito nesta
mesma rodada.

---

## 2. METODOLOGIA E NÍVEIS DE EVIDÊNCIA

Tudo foi tratado como incorreto até a execução provar o contrário. Não usei como
prova: `doc/AUDITORIA_FORENSE_2026-08-22.md`, `test/invariants/remediation_2_7_1_test.dart`,
os 16 goldens regravados, os ADRs, o CHANGELOG ou notas de agente. Usei esses
artefatos apenas como **lista de alegações a testar**.

| Nível | Significado |
|---|---|
| **A** | Código executado por mim nesta sessão; número medido |
| **B** | Código lido; comportamento derivado do fonte, não executado |
| **C** | Inferência arquitetural a partir de estrutura |
| **D** | Hipótese não confirmada |

Escrevi 8 arquivos de sonda temporários (`test/_audit271_*.dart`), executei-os, e
**os apaguei ao final**. A árvore está limpa (o diretório `probe/` não rastreado
é resíduo da sprint de remediação anterior, não meu — ver A-15).

**Baseline:** `flutter test` → **821 testes, todos passam**.
`dart analyze lib` → **nenhum problema**.

**Nota de independência.** Existe na árvore, não rastreado, um segundo relatório
de re-auditoria (`doc/AUDITORIA_FORENSE_2026-08-22_2.7.1.md`, 1.363 linhas, com
`probe/p01…p17`), produzido por outra frente. Eu o descobri **depois** de fechar
todas as minhas classificações. Vi apenas o número de manchete dele (0,742) e
**não revisei nenhuma linha minha por causa disso** — cada CONFIRMADO da §22 está
amarrado a uma medição executada e registrada. A divergência está analisada no
§24.

### 2.1 Três hipóteses minhas que a medição refutou

Registro-as porque uma auditoria que só publica o que confirmou não é auditável:

- **Colisão de bemol duplo sob compressão.** Inferi de `minGap (13,45) < cabeça+bemol duplo (16,99)`
  que haveria sobreposição. Sonda geométrica medindo `curAccLeft − prevRight`:
  folga **+8,17 / +16,34 / +32,69 px** em ss = 6/12/24. **Refutado. F-27 se mantém.**
- **Grade de onset grossa demais.** Reportei "9 de 16 posições distintas". Eu tinha
  usado meu próprio quantizador (1024). O motor usa `kOnsetGrid = 8192.0` nos
  **dois** consumidores (`layout_engine.dart:1024`, `grand_staff_painter.dart:322`) →
  **16 de 16 distintas. Refutado.**
- **Hit-test de haste falha.** Medi do lado errado de uma nota com haste para baixo.
  Refeito nos dois lados: haste para cima acerta 2 SS acima e erra abaixo; haste
  para baixo, o inverso. **Refutado.**

---

## 3. RECONSTRUÇÃO DO SISTEMA

144 arquivos Dart, 45.398 linhas em `lib/`. 60 arquivos de teste.

```
core/            modelo musical (Note, Pitch, Chord, Tuplet, Measure, Staff, Score)
src/layout/      LayoutEngine + spacing/ + beam_grouper + tuplet_grid + onset_grid
src/rendering/   StaffRenderer + renderers/* + grand_staff_painter + gregorian/ + jianpu/
src/parsers/     musicxml, mei, json (+ parser_support compartilhado)
src/midi/        MidiMapper
src/export/      pdf_exporter, score_rasterizer
src/interaction/ ScoreHitTester
```

**Fluxo canônico:** `Staff` → `LayoutEngine.layout()` → `List<PositionedElement>`
→ `StaffRenderer.renderStaff(canvas, …)`.

**Fluxo de grupo (paralelo, não convergente):** `StaffGroup` → `GrandStaffPainter`
(que roda um `LayoutEngine` por pauta e alinha por `onset`) → `canvas`.

Esses dois caminhos **não se encontram**. `ScoreRasterizer.layoutStaff` usa o
primeiro; `ScoreRasterizer.renderGroupToPage` usa o segundo. Ver §13 e A-07.

**Dependências:** `collection`, `xml >=6.5.0 <8.0.0`, `pdf ^3.11.1`,
`printing ^5.13.2`, `flutter_web_plugins`. `printing` é uma dependência pesada
com canais de plataforma para uma biblioteca de notação — é o que justifica as
pastas `android/ios/linux/macos/windows` (4–7 arquivos cada, apenas scaffolding
de plugin, sem código nativo próprio).

---

## 4. MODELO MUSICAL

**Confirmado bom.** `Pitch` valida (`octave 9999` → `FormatException` [A]).
`Tuplet` carrega `actualNotes`/`normalNotes`. `MultiVoiceMeasure.elements` volta
a ser respeitado (N-03 [A]).

**ADR-001 se mantém:** o layout não clona o modelo; `Note.beam` é mutável por
contrato declarado. Mas ver A-04 — essa mutabilidade tem uma consequência
observável na exportação.

**A-10 [P3/A] `Duration` sombreia `dart:core.Duration`.**
`flutter_notemus.dart` exporta uma classe `Duration` (musical). Qualquer app que
faça `import 'package:flutter_notemus/flutter_notemus.dart';` perde o `Duration`
de `dart:core`. Eu bati nisso literalmente: escrever `Timeout(Duration(minutes: 4))`
num teste que importa o pacote falha com *"Too few positional arguments: 1
required, 0 given"*. O contorno exige `import 'dart:core'; import 'dart:core' as core;`.
O nome convencional seria `MusicDuration` ou `NoteDuration`.

**A-18 [P3/B] O texto do ADR-003 é impreciso.** Ele afirma "`Pitch` é a altura
soante". Para instrumento transpositor isso é falso e o próprio código faz o
certo: clarinete em Si♭, `<pitch>C4</pitch>` importa como C4/MIDI 60 e **toca**
58 [A]. Ou seja, `Pitch` é a altura **escrita**, e a clave de oitava é que não
deve deslocá-la duas vezes. A regra correta é "`Pitch` é invariante à clave de
oitava", não "`Pitch` é soante".

---

## 5. MOTOR DE LAYOUT

**Confirmado:**

- Ordem canônica do bloco de abertura (N-11 [A]): fonte `[TimeSignature, KeySignature, Clef]`
  → layout `Clef@30, KeySignature@68, TimeSignature@109`.
- Mudança no meio do compasso permanece em ordem de documento (ADR-004 [A]):
  `Note@169, KeySignature@192, Note@263`.
- Idem via `MultiVoiceMeasure` [A] — os dois caminhos que o ADR-004 cita.
- `PositionedElement.movedTo` copia os 7 campos [B]; é o único mecanismo de cópia
  fora do próprio `layout_engine.dart` (6 construções cruas, todas nesse arquivo).
- Justificação sub-linear (N-04 [A]): 400 → 6400 compassos = 41 → 124 ms.

> ⚠ **UNKNOWN.** 16× os compassos para 3× o tempo é *sub*-linear, não linear.
> Isso é bom demais para trabalho proporcional por compasso e sugere que algo é
> pulado em escala. Não consegui determinar o quê. Registro como não explicado,
> não como aprovação.

**A-08 [P2/A] Um único compasso sobrecheio transborda em silêncio.**
2000 fusas em UM compasso, largura disponível 300 px:

```
2002 elementos posicionados, 1 sistema, 93 ms
x vai de 82,6 até 53.863,7 px
```

O motor produziu um sistema de **53.864 px** dentro de uma viewport de 300 px —
180× o disponível. Sem quebra, sem clipping, sem warning. Não há mecanismo de
aviso de overflow no `LayoutEngine` (grep: só um comentário de dartdoc na linha
2479). O N-01 fechou a *exceção*; o transbordo silencioso continua aberto.

**A-20 [P3/B] Fórmula da raiz quadrada duplicada.**
`TupletGrid._squareRootFactor` reimplementa `sqrt(t)` com o comentário
*"Identical to what `SpacingModel.squareRoot` computes"*. Duas fontes de verdade
para a mesma lei. É a causa direta do A-02.

---

## 6. ENGRAVING — REGRAS DE GOULD

**Confirmado por medição:**

| Regra | Medido |
|---|---|
| Tabela de inclinação de barra (N-10) | 0 / 0,25 / 0,5 / 1,0 / 1,0 / 1,25 / 1,25 / 1,5 / 1,5 / 1,5 — exata |
| Espaçamento raiz quadrada em quiáltera (N-07) | gaps [30,0 / 21,2], razão **1,415 ≈ √2** |
| Acidente alarga o vão **antes** (N-05) | 76,2 com acidente vs 56,2 sem; o vão depois fica 56,2 |
| Agrupamento 4/4 em 16ºs (N-21) | 4-4-4-4; colcheias 4-4; 2/2 e 3/2 em grupos de 4; 6/4 → 6+6 |
| Métricas irregulares (N-31) | 5/4 → 5×2; 7/4 → 7×2; 11/8 → 3-3-3-2 — todas cobrem o compasso |
| Segunda entre vozes / uníssono (N-29) | uníssono mesma duração → coincidente; duração diferente → deslocado |

**A-05 [P3/A] O numeral da quiáltera não fica sobre a linha do colchete.**

Este é o achado que as duas auditorias anteriores perderam por olhar em 1:1.
Ampliei os goldens 8× e extraí os traços por componente conexo:

```
m04_triplets 2.7.0 — tercina 1: metades x115-142 e x164-191
                     slopeA=-0,275  slopeB=-0,273   DELTA no ponto de junção = 0,36 px
                     numeral "3" em x146-153, y117-126 (centro 121,5)
                     a linha do colchete nesse x está em ~112,5
                     → o numeral está ~9 px ABAIXO da linha
m04_triplets 2.7.0 — tercina 2: DELTA = 0,05 px; numeral ~11 px abaixo
m04_triplets 2.7.1 — tercina 1: DELTA = 0,24 px; numeral ~10 px abaixo
```

O código explica o número exatamente — `tuplet_renderer.dart:388-393`:

```dart
final bracketY = (line.startY + line.endY) / 2;
final numberOffset = stemUp
    ? -coordinates.staffSpace * 0.95
    : coordinates.staffSpace * 0.95;
final numberY = bracketY + numberOffset;      // 0,95 SS = 11,4 px em ss=12
```

E `_drawTupletBracket` **abre um vão** (`numberGap`) no colchete exatamente para
esse numeral (linhas 319-333). Resultado: o colchete tem um buraco vazio e o
número flutua ao lado dele. Gould (*Behind Bars*, p. 201): o número vai **dentro**
da interrupção, centrado na linha. As duas coisas juntas — abrir o vão *e* tirar
o número dele — são contraditórias. Afeta **toda** quiáltera com colchete.

**A-06 [P2/A] Não há comprimento máximo de haste.**
Dentro de um grupo com barra, medindo a distância nota→barra:

| Intervalo (graus diatônicos) | Hastes medidas |
|---|---|
| 7 (oitava) | 5,04 / 3,04 SS |
| 10 | 3,53 / **7,03** SS |
| 14 (duas oitavas) | 3,53 / **9,03** SS |

9 espaços é uma haste **mais alta que a própria pauta** (4 espaços). Gould limita
por volta de 4–5 e manda quebrar a barra em âmbito extremo. Declarado em aberto
na B.3; confirmo com números.

---

## 7. SMuFL / BRAVURA

Sem achados novos. As larguras de acidente vêm do metadado (confirmado pela
medição de folga em §2.1, que usou `metadata.getGlyphWidth`). `SmuflMetadata`
carrega `engravingDefaults`, `glyphBBoxes`, `glyphAdvanceWidths` e
`glyphsWithAnchors`.

Nota de contexto: `numberSize = staffSpace * 2.2` em `tuplet_renderer.dart` é um
número mágico que não vem do metadado, mas não medi impacto visual isolado —
**UNKNOWN**.

---

## 8. INTEROPERABILIDADE — MusicXML

**Confirmado [A]:**

- Ordem clave→armadura→fórmula na importação (N-11).
- Um único Clef/Key/Time em importação polifônica (N-12, lado MusicXML).
- `<transpose>` chega ao playback: C4 escrito em clarinete Si♭ → **MIDI 58**.
- `scoreToMusicXML` exporta e reimporta `part-name`, `part-abbreviation`,
  `group-name` e `part-group`.
- `<pitch>` sem `<octave>` → `FormatException` (falha alto).
- Clave de oitava: treble8vb C4 → posição +1, MIDI 60; treble8va → −13;
  bass8vb → 13; `c8vb` C3 → 2, idêntico a tenor C4 → 2 (sem duplo deslocamento).

**A-11 [P3/A] Entradas inválidas produzem música errada em silêncio.**

| Entrada | Resultado medido |
|---|---|
| `<divisions>0</divisions>` + `<duration>4</duration>` | ACEITO → nota **semibreve** (`absoluteValue=1.0`) |
| `<duration>-16</duration>` com `divisions=4` | ACEITO → **semínima** (`absoluteValue=0.25`) |
| `<backup><duration>9999</duration></backup>` antes do início do compasso | ACEITO, 2 notas, sem warning |
| `<octave>9999</octave>` | `FormatException` ✅ |
| tag não fechada / string vazia | `XmlTagException` / `XmlParserException` ✅ |

A inconsistência é o achado: o parser **falha alto** para oitava inválida e
**corrompe em silêncio** para `divisions=0` e duração negativa. Nenhum warning é
emitido nos casos silenciosos.

**A-16 [P3/A] Referências de entidade passam como texto literal.**
`<part-name>&xxe;</part-name>` com `<!ENTITY xxe SYSTEM "file://…">` produz o
nome de parte literal `&xxe;`. Não é vazamento (ver §15), mas também não é
rejeição — é dado corrompido aceito.

**A-04 [P2/A] Barras de quiáltera são dependentes de ordem na exportação.**

```
Depois de layout():   beams = [null, null, null]  → export NÃO emite <beam>
Depois de renderizar: beams = [start, inner, end] → export emite [begin, continue, end]
```

O mesmo `Staff` exporta XML **diferente** conforme tenha sido renderizado antes
ou não. `_drawSimpleBeams` (que decide os níveis por nota — N-08 corrigido [B])
grava em `Note.beam` durante o *paint*. É o ADR-001 (layout não clona, `beam` é
mutável) vazando para o exportador. Um app que exporta antes de exibir gera
arquivo sem barras.

---

## 9. INTEROPERABILIDADE — MEI

**Confirmado [A]:** `clef.shape="TAB"` com `lines=6` → `tab6`, `lines=4` → `tab4`.
Importação polifônica emite um único Clef/Key/Time (N-12, lado MEI).
`TimeSignature.additiveGroups` funciona — `meter.count="3+2+2"` → `isAdditive=true,
groups=[3,2,2]` (a retirada de NOVO-6 na rodada anterior está **correta** [B];
o caso `m04n_additive_meter` existe no corpus e usa `TimeSignature.additive`).

**A-12 [P3/A] `<note pname="c" dur="4"/>` sem `@oct` é descartado em silêncio.**
Resultado medido: `notes=0`. O caminho MusicXML equivalente **lança**
`FormatException`. Dois importadores, duas políticas opostas para o mesmo erro
do usuário. Isso torna o **N-25 PARCIALMENTE CORRIGIDO**, não corrigido.

Não há exportador MEI.

---

## 10. INTEROPERABILIDADE — JSON

**A-03 [P2/A] O round-trip JSON duplica o bloco de abertura.**

```
ANTES:  allElements = [Clef, TimeSignature, Note, Note]
DEPOIS de staffToJson → parseStaff:
        measure.elements = [Clef, TimeSignature]
        voice 1          = [Clef, TimeSignature, Note]
LAYOUT: 2 claves e 2 fórmulas de compasso DESENHADAS
```

Causa em `json_exporter.dart:65`: para um `MultiVoiceMeasure` o exportador
escreve **tanto** `map['elements']` **quanto** `map['voices']`, e cada voz já
carrega o bloco de abertura. O importador então soma os dois.

Este é precisamente o defeito que o N-12 fechou para MusicXML e MEI. O
exportador JSON foi **escrito nesta release** (`json_exporter.dart`, +181
linhas) e traz o defeito de volta num terceiro caminho. Por isso classifico
**N-12 como PARCIALMENTE CORRIGIDO** na matriz B.1: o invariante que ele
estabelece ("exatamente um Clef/Key/Time por compasso após importação") é
violado por código da própria 2.7.1.

O exportador em si funciona: `syllables`, `crossStaffMove`, `tabFret`,
`tabString`, `Tuplet` e `Chord` sobrevivem ao round-trip [A]. O N-24 está
parcialmente resolvido — existe exportador, mas ele corrompe a estrutura.

---

## 11. MIDI E PLAYBACK

**Confirmado [A]:** transposição chega ao som (§8). Claves de oitava não
deslocam duas vezes. Faixas por voz com mute/solo.

**A-19 [P4/B] `_activeClef` é campo write-only.**
`midi_mapper.dart:348` — `// ignore: unused_field  Clef? _activeClef;`. É
escrito e nunca lido. A justificativa documentada (preparação para mapeamento de
percussão) não está implementada. Um `// ignore:` que silencia o analisador é
dívida declarada, não resolvida.

Playback continua sendo 1 plataforma de 6.

---

## 12. GREGORIANO E JIANPU

**A-13 [P3/B] A regra do `withMusicTextFallback` não é aplicada.**

`text_font.dart` (novo na 2.7.1) define `kMusicTextFontFallback` e o dartdoc
estabelece a regra: *"every `TextStyle` handed to a `TextPainter` in this package
must pass through `MusicTextFallback.withMusicTextFallback` first"*. Ele até
admite por que a 2.7.0 não pegou o problema: o harness injeta
`ThemeData.fontFamily = 'Roboto'`.

Arquivos com `TextPainter(` **sem** `withMusicTextFallback`:
`grand_staff_painter.dart`, `gregorian_renderer.dart`, `jianpu_renderer.dart`,
`performance_optimizer.dart`, `bar_element_renderer.dart`, `glyph_renderer.dart`,
`group_renderer.dart`.

Dois são materiais:
- `gregorian_renderer.dart:738` (`_lyric`) usa `fontFamily: theme.lyricTextFamily`
  com uma cadeia **própria** `['Georgia','Times New Roman','serif']`.
- `jianpu_renderer.dart:285` usa `TextStyle(fontSize:…, color:…, height: 1.0)` —
  **sem família e sem cadeia**.

> ⚠ **Limite honesto da evidência.** Tentei confirmar por razão de tinta
> (`.notdef` desenha retângulo cheio). Medi 0,840 para a cadeia do pacote, 0,840
> para o estilo gregoriano e 0,823 para o Jianpu — o ambiente de teste não
> resolve nenhuma das cadeias, então o método **não distingue** os três. Fica
> **Evidência B**: violação da regra no código, impacto visual real não provado
> por mim.

O pipeline gregoriano continua apartado do pipeline CMN (renderizador próprio,
parser GABC próprio, playback próprio).

---

## 13. RENDERIZAÇÃO, RASTERIZAÇÃO E EXPORTAÇÃO

**Confirmado [A]:** exportação PDF de grand staff produz arquivo válido
(14.522 bytes, sem warnings) — N-18.

**A-07 [P2/A] `renderGroupToPage` produz UMA imagem sem limite.**

`ScoreRasterizer.renderGroupToPage` não passa por `layoutStaff` nem por
`_rasterizeBand`. Constrói um `GrandStaffPainter` e pinta tudo de uma vez, com
`firstSystem: 0, systemCount: painter.systemCount`. Medido:

| Compassos | Sistemas | Altura lógica | Imagem em pixelRatio 2 |
|---:|---:|---:|---|
| 8 | 4 | 1.032 | 2.064 px |
| 60 | 30 | 7.584 | **1600 × 15.168 px (executado, 3.570 ms, ~97 MB RGBA)** |
| 120 | 60 | 15.144 | 30.288 px |
| 600 | 300 | 75.624 | **151.248 px (~968 MB RGBA)** |

A linha de 60 compassos eu **executei** — a imagem foi produzida. Ela já excede
o limite de textura típico de GPU móvel (4096–8192) e se aproxima do limite
comum de desktop (16384). O caminho de pauta única tem *banding*
(`_rasterizeBand`); o caminho de grupo **não tem**. A assimetria é o achado
[A]; a falha em GPU real é [C], porque o ambiente de teste usa rasterizador de
software sem teto de textura.

**A-09 [P2/A] O exportador PDF não está na API pública.**
`lib/flutter_notemus.dart` tem 26 `export`s. Nenhum deles alcança
`PdfExporter`, `ScoreRasterizer` ou `GrandStaffPainter`. Para exportar PDF — a
funcionalidade remediada nesta release — o consumidor precisa de
`import 'package:flutter_notemus/src/export/pdf_exporter.dart'`, entrando em
`src/`, o que o lint `implementation_imports` sinaliza e o semver não cobre. Eu
bati nisso na minha própria sonda.

---

## 14. PRONTIDÃO PARA EDITOR

**Confirmado [A] — o hit-test cobre haste dos dois lados:**

```
C4 (haste para cima):  2 SS acima = HIT   2 SS abaixo = MISS  ✅
C6 (haste para baixo): 2 SS acima = MISS  2 SS abaixo = HIT   ✅
```

Meu resultado anterior de MISS foi medido do lado errado da haste; **retirado**.
N-19 e o ataque B.2#9 ficam resolvidos juntos.

**Confirmado [A]:** `staffBaselineY` é único e correto por sistema (60, 180,
300, …) — N-20. Identidade preservada ponta a ponta (ADR-001), o que é o
pré-requisito estrutural de um editor.

**Ainda ausente:** cursor, inserção, undo/redo, seleção por região.

**A-01 [P2/A] `OctaveMark` não tem efeito sobre a altura impressa.**

```
C6 sem 8va       → y = 12.0
C6 sob 8va       → y = 12.0   (idêntico)
OctaveMark.octaveShift → retorna 1, e não tem NENHUM consumidor
```

`grep` confirma: o único uso de `octaveShift` no pacote é `clef.octaveShift` em
`staff_position_calculator.dart:70`. `lib/core/octave.dart:36` define o getter
para `OctaveMark` e nada o lê.

Sob o ADR-003 — que declara `Pitch` invariante ao deslocamento de oitava — uma
nota sob colchete 8va tem de ser **impressa uma oitava abaixo**. É o espelho
exato do bug de clave que a 2.7.1 corrigiu. Foi corrigido para claves e não para
colchetes.

Secundário, confiança menor [B]: `parser_support.dart:2833` mapeia
`placement/type = "down"` → `OctaveType.vb8`. Em MusicXML, `<octave-shift type="down">`
significa que as notas são impressas **abaixo** do som, isto é, 8va. O
mapeamento parece invertido, mas como o valor não é consumido por ninguém, não
consegui observar efeito — **UNKNOWN**.

---

## 15. SEGURANÇA E ENTRADA HOSTIL

**Resultado positivo, medido — e eu retiro qualquer suspeita de XXE.**

Criei um arquivo real com o canário `SECRET-CANARY-12345` e referenciei-o por
`<!ENTITY xxe SYSTEM "file:///…">`:

```
O2 parsed part names=[&xxe;]   LEAKED=false
```

Nenhum conteúdo vazou. O *billion laughs* de 4 níveis foi processado em **1 ms**
— as entidades não são expandidas. O pacote `xml` não resolve entidades
customizadas, e o parser não implementa resolução própria.

| Vetor | Resultado |
|---|---|
| XXE com arquivo existente | **Não vulnerável** [A] |
| Billion laughs (10⁴) | **Não vulnerável**, 1 ms [A] |
| XML malformado | Exceção tipada [A] |
| String vazia | Exceção tipada [A] |

Superfície de I/O: o pacote não lê rede. `printing` traz canais de plataforma,
mas para impressão, sob ação do usuário.

O que **não** é seguro é a aceitação silenciosa de valores inválidos (A-11) —
isso é robustez e corrupção de dados, não segurança.

---

## 16. QUALIDADE DE TESTES E GOLDENS

**821 testes passam. `dart analyze lib` limpo.** São dois fatos reais e bons.

**A-14 [P4/A] A suíte de remediação tem um teste vazio e sete lacunas.**

`test/invariants/remediation_2_7_1_test.dart` (683 linhas). O teste do N-22
**nunca invoca o motor**:

```dart
final keys = <double>{};
for (var i = 0; i < 16; i++) {
  keys.add(((i / 2048) * 8192.0).round() / 8192.0);
}
expect(keys, hasLength(16));
```

Isso testa aritmética de ponto flutuante do Dart, não `kOnsetGrid`, não o
`LayoutEngine`, não o `GrandStaffPainter`. Passaria se o motor fosse deletado.
(O comportamento em si **está correto** — eu o verifiquei separadamente [A] —
mas o teste não é o que prova isso.)

Sem teste na suíte de remediação: **N-02b, N-08, N-16, N-17, N-18, N-20, N-28,
N-32, ADR-004**.

Asserção frouxa: o teste do N-04 usa `expect(large / max(small, 1e-6), lessThan(10.0))`
para 800 vs 3200 compassos — um fator 10 aceita comportamento quadrático em boa
parte da faixa.

**Os 16 goldens regravados — julgados ampliados, como exigido.**

Examinei 6 dos 16 a 4×–10× com grade de referência e extração de componentes
conexos. Os quatro que analisei em profundidade são **melhorias genuínas**:

| Golden | Δ medido | Veredito |
|---|---|---|
| `m08b_two_voice_seconds` | Uníssono C5/C5 passou de **duas cabeças lado a lado** para **uma cabeça com duas hastes** | ✅ correção real de gravação (Gould: uníssono de mesma duração compartilha a cabeça) |
| `m04n_additive_meter` | Barra de C5-D5-E5 passou de **plana** para **inclinada** | ✅ correção real (intervalo 2 → 0,5 espaço na tabela de Gould) |
| `c02_chromatic_chords` | Acorde deslocou ~16 px à direita; pilha de acidentes mais compacta | ✅ consistente com N-05 (largura reservada antes) |
| `m04_triplets` | Colchetes de tercina encurtaram (28 → 19 px por metade); tercina 2 reposicionada | ✅ consistente com `TupletGrid`; metades continuam colineares |

**Nenhum deles congela um defeito.** Mas os quatro **carregam** o A-05 (numeral
fora da linha) tanto antes quanto depois — o defeito atravessou as duas
auditorias porque nenhuma ampliou a faixa do colchete.

**A-15 [P4/A] Resíduo não rastreado na árvore de trabalho.**
O diretório `probe/` contém 17 arquivos `p01…p17_*_test.dart` e ~40 PNG/PDF/XML/JSON
de saída (é a instrumentação da outra frente de auditoria, não da sprint de
remediação). Não é rastreado, portanto não é publicado — mas faz `dart analyze`
na raiz reportar **270 problemas** contra **0** em `lib/`. Um gate de CI ingênuo
(`dart analyze` sem caminho) quebra.

---

## 17. DESEMPENHO, MEMÓRIA E ESCALABILIDADE (CENÁRIOS A–H)

Enumerei os cenários explicitamente para que sejam reproduzíveis:

| # | Cenário | Medido | Veredito |
|---|---|---|---|
| A | 1 compasso trivial | < 1 ms | OK |
| B | 400 compassos, pauta única | 41 ms | OK |
| C | 6.400 compassos, pauta única | 124 ms | OK (sub-linear — ver §5, não explicado) |
| D | 2.000 notas em **um** compasso, 300 px | 93 ms, **53.864 px de largura**, 1 sistema | **A-08** |
| E | Grand staff 8 compassos | 4 sistemas, 1.032 px | OK |
| F | Grand staff 60 compassos, rasterizado | **1600 × 15.168 px, 3.570 ms, ~97 MB RGBA** | **A-07** |
| G | Grand staff 600 compassos (projetado) | 151.248 px, ~968 MB RGBA | **A-07** |
| H | Layout fora da UI thread | Nenhum isolate; `GrandStaffPainter` faz todo o layout **no construtor** | Aberto |

O cenário H merece nota: `GrandStaffPainter({...})` executa `_computeSystemRanges()`
e `_layoutSystem()` para todos os sistemas dentro do corpo do construtor. Para
600 compassos isso é trabalho pesado síncrono em qualquer thread que construa o
painter — na prática, a UI thread.

---

## 18. API PÚBLICA, DEPENDÊNCIAS E PLATAFORMAS

- 26 `export`s em `lib/flutter_notemus.dart`.
- **Fora da API pública:** `PdfExporter`, `ScoreRasterizer`, `GrandStaffPainter`,
  `TupletGrid`, `kOnsetGrid`, `MusicTextFallback` (A-09).
- `Duration` sombreia `dart:core.Duration` (A-10).
- `printing ^5.13.2` + `pdf ^3.11.1` são dependências pesadas; `flutter_web_plugins`
  é usado só por `lib/flutter_notemus_web.dart`.
- Pastas de plataforma contêm apenas scaffolding de plugin (4–7 arquivos), sem
  código nativo próprio. Não há nada específico de plataforma para auditar.

---

## 19. CORRUPÇÃO SEMÂNTICA SILENCIOSA

Consolidado — os casos em que a biblioteca produz **música errada sem avisar**:

| Caso | Efeito | Ev |
|---|---|---|
| Round-trip JSON | 2 claves e 2 fórmulas desenhadas | A |
| `OctaveMark` 8va/8vb | Altura impressa ignora o colchete | A |
| Exportar antes de renderizar | XML de quiáltera sem `<beam>` | A |
| `<divisions>0</divisions>` | Nota vira semibreve | A |
| `<duration>` negativa | Nota vira semínima | A |
| MEI sem `@oct` | Nota desaparece | A |
| `SpacingModel` ≠ squareRoot | Quiáltera diverge do compasso | A |
| Compasso sobrecheio isolado | 53.864 px fora da viewport | A |

Oito caminhos distintos. Nenhum emite warning.

---

## 20. ACHADOS NOVOS — TABELA COMPLETA

| ID | Sev | Ev | Achado | Onde |
|---|---|---|---|---|
| **A-01** | P2 | A | `OctaveMark` sem efeito na altura impressa; `octaveShift` sem consumidor | `core/octave.dart:36` |
| **A-02** | P2 | A | `TupletGrid` ignora o `SpacingModel` configurado — **regressão da própria 2.7.1** | `layout/tuplet_grid.dart:106` |
| **A-03** | P2 | A | Round-trip JSON duplica o bloco de abertura | `parsers/json_exporter.dart:65` |
| **A-04** | P2 | A | Barras de quiáltera dependentes de ordem na exportação | `renderers/tuplet_renderer.dart:457` |
| **A-05** | P3 | A | Numeral da quiáltera 0,95 SS fora da linha, dentro do vão aberto para ele | `renderers/tuplet_renderer.dart:391` |
| **A-06** | P2 | A | Sem comprimento máximo de haste (9,03 SS medido) | `layout/beam_grouper.dart` |
| **A-07** | P2 | A/C | `renderGroupToPage` gera uma imagem sem limite (15.168 px em 60 compassos) | `export/score_rasterizer.dart:356` |
| **A-08** | P2 | A | Compasso sobrecheio isolado transborda 180× em silêncio | `layout/layout_engine.dart` |
| **A-09** | P2 | A | `PdfExporter`/`ScoreRasterizer`/`GrandStaffPainter` fora da API pública | `lib/flutter_notemus.dart` |
| **A-10** | P3 | A | `Duration` sombreia `dart:core.Duration` | `core/core.dart` |
| **A-11** | P3 | A | `divisions=0` e duração negativa aceitos em silêncio | `parsers/parser_support.dart` |
| **A-12** | P3 | A | MEI sem `@oct` descartado em silêncio (MusicXML lança) | `parsers/mei_parser.dart` |
| **A-13** | P3 | B | Regra do `withMusicTextFallback` não aplicada em gregoriano/Jianpu | `gregorian_renderer.dart:738`, `jianpu_renderer.dart:285` |
| **A-14** | P4 | A | Teste do N-22 é vazio; 9 achados sem teste; asserção do N-04 frouxa | `test/invariants/remediation_2_7_1_test.dart` |
| **A-15** | P4 | A | `probe/` não rastreado → 270 problemas em `dart analyze` na raiz | `probe/` |
| **A-16** | P3 | A | Referências de entidade aceitas como texto literal | `parsers/musicxml_parser.dart` |
| **A-17** | P3 | A | `<backup>` além do início do compasso aceito sem warning | `parsers/parser_support.dart` |
| **A-18** | P3 | B | Texto do ADR-003 impreciso para instrumento transpositor | `doc/adr/ADR-003-*.md` |
| **A-19** | P4 | B | `_activeClef` write-only com `// ignore: unused_field` | `midi/midi_mapper.dart:348` |
| **A-20** | P3 | B | Lei da raiz quadrada duplicada em duas fontes de verdade | `tuplet_grid.dart` vs `spacing_model.dart` |

---

## 21. MATRIZ DE MATURIDADE (2.7.0 → 2.7.1)

Comparada diretamente com a §21 de `AUDITORIA_FORENSE_2026-08-22.md`.

| Área | 2.6.0 | 2.7.0 | **2.7.1** | Δ | Justificativa |
|---|---:|---:|---:|---:|---|
| Modelo musical | 6 | 7 | **7** | 0 | Nada mudou no modelo. `Duration` sombreando `dart:core` (A-10) cancela ganhos menores |
| Engraving | 4 | 5,5 | **7** | +1,5 | Tabela de Gould exata, √2 em quiáltera, acidente antes, agrupamentos corretos — tudo medido. Teto: numeral fora da linha (A-05) e sem haste máxima (A-06) |
| Layout | 3 | 5 | **6,5** | +1,5 | O(n²) resolvido, ordem canônica, ADR-004 nos dois caminhos, `movedTo` completo. Penalizado por A-08 e A-02 |
| SMuFL | 7 | 7,5 | **7,5** | 0 | Sem mudança observável |
| Bravura | 7 | 8 | **8** | 0 | Sem mudança observável |
| MusicXML | 4 | 5,5 | **7,5** | +2 | Ordem clave/armadura, `<transpose>` vivo, nomes de parte round-trip, `part-group`. Penalizado por A-11/A-16/A-17 |
| MEI | 4 | 6,5 | **7** | +0,5 | `clef.shape="TAB"` fechado. Ainda sem exportador; A-12 é uma política oposta à do MusicXML |
| JSON | 6 | 5 | **5** | 0 | **Ganhou exportador e perdeu o mesmo tanto**: A-03 desenha 2 claves. Trabalho real, resultado neutro |
| MIDI | 8 | 8 | **8,5** | +0,5 | Oitava de clave corrigida na origem; transposição chega ao som |
| Playback | 3 | 3,5 | **3,5** | 0 | Continua 1 plataforma de 6 |
| Gregorian | 7 | 8 | **8** | 0 | Sem mudança; A-13 é regra nova não aplicada aqui |
| Polifonia | 3 | 5 | **6,5** | +1,5 | `MultiVoiceMeasure.elements` respeitado, uníssono compartilha cabeça, vozes sobrevivem à quebra |
| Multi-staff | 2 | 5 | **6,5** | +1,5 | Sem exceção em compasso sobrecheio, opções preservadas, quiálteras re-ancoradas. Penalizado por A-07 |
| Performance | 5 | 4 | **6** | +2 | 6.400 compassos: 6,0 s → **124 ms**. Penalizado por A-07 e pelo layout no construtor |
| Arquitetura Flutter | 4 | 4,5 | **4,5** | 0 | Ainda sem isolate; layout ainda no construtor do painter |
| Testes | 5 | 7 | **7,5** | +0,5 | 821 testes, `analyze` limpo. Penalizado por A-14 (um teste vazio + 9 lacunas) |
| Golden tests | 6 | 6,5 | **7** | +0,5 | As regravações que examinei ampliadas são melhorias reais. Ainda congelam A-05 |
| Segurança | 7 | 7,5 | **7,5** | 0 | XXE/billion-laughs reverificados negativos por execução. A-11 é robustez, não segurança |
| API pública | 4 | 5 | **5** | 0 | `PdfExporter` **continua** fora do export principal (A-09); `Duration` sombreia (A-10) |
| Documentação | 6 | 6 | **6,5** | +0,5 | ADR-003/004 são bons e honestos. ADR-003 tem texto impreciso (A-18) |
| Escalabilidade | 3 | 3 | **5** | +2 | Quadrático removido de verdade. Teto novo em A-07/A-08 |
| Prontidão p/ editor | 2 | 4,5 | **6** | +1,5 | Hit-test cobre haste dos dois lados, `staffBaselineY` correto, identidade estável. Falta cursor/inserção/undo |

**Média ponderada informal: ≈ 6,7 / 10** (era 5,8, era 4,7)

> *"Motor de gravação que agora acerta as regras de Gould que declara. Base de
> editor sólida. Três defeitos novos nascidos das próprias correções."*

---

## 22. PARTE B.1 — MATRIZ DE VERIFICAÇÃO ADVERSARIAL

| ID | Alegação | Veredito | Evidência medida |
|---|---|---|---|
| N-01 | Sem exceção em compasso sobrecheio no grand staff | **CONFIRMADO** | 12 sistemas, nenhuma exceção [A] |
| N-02 | `autoBeaming` sobrevive à quebra de sistema | **CONFIRMADO** | preservado nos 8 sistemas [A] |
| N-02b | Ambas as vozes em todos os sistemas | **CONFIRMADO** | 2 vozes em cada um dos 5 [A] |
| N-03 | `MultiVoiceMeasure.elements` não é descartado | **CONFIRMADO** | `[Clef, Key, Time, Dynamic, Note, Note, Barline]`; y1=54 ≠ y2=96 [A] |
| N-04 | Justificação deixa de ser O(n²) | **CONFIRMADO** | 400→6400 compassos = 41→124 ms [A] |
| N-05 | Acidente reservado antes da nota | **CONFIRMADO** | 76,2 vs 56,2; vão posterior inalterado [A] |
| N-06 | — | **NÃO VERIFICADO** | Não localizei definição estável do ID nos artefatos; não vou adivinhar |
| N-07 | Grade de quiáltera respeita √ | **CONFIRMADO** | razão 1,415 ≈ √2 [A] |
| N-08 | Barras secundárias decididas por nota | **CONFIRMADO** | `_drawSimpleBeams` decide por nota [B] |
| N-09 | Barras sem `TimeSignature` presente | **CONFIRMADO** | 1 `advancedBeamGroup` sem fórmula [A] |
| N-10 | Tabela de inclinação de Gould | **CONFIRMADO** | 0/0,25/0,5/1,0/1,0/1,25/1,25/1,5/1,5/1,5 — exata [A] |
| N-11 | Ordem clave→armadura→fórmula | **CONFIRMADO** | `Clef@30, Key@68, Time@99` de fonte invertida [A] |
| N-12 | Um só Clef/Key/Time após import polifônico | **PARCIAL** | ✅ MusicXML e MEI [A]; ❌ **JSON desenha 2 claves** (A-03) [A] |
| N-13 | `<transpose>` chega ao playback | **CONFIRMADO** | C4 em clarinete Si♭ → MIDI 58 [A] |
| N-14 | — | **NÃO VERIFICADO** | ID não encontrado nos artefatos |
| N-15 | Clave de oitava não desloca duas vezes | **CONFIRMADO** | treble8vb C4 → pos +1, MIDI 60 [A] |
| N-16 | Texto usa a cadeia de fallback do pacote | **PARCIAL** | Regra criada; 2 renderizadores a violam (A-13) [B] |
| N-17 | Lead-in de ligadura não invade a clave restatada | **CONFIRMADO** | `leadIn = min(2,0·ss, headerGap·0,5)` [B] |
| N-18 | PDF de grand staff exporta | **CONFIRMADO** | 14.522 bytes, sem warnings [A] |
| N-19 | Hit-test cobre a haste | **CONFIRMADO** | HIT no lado correto nos dois sentidos [A] |
| N-20 | `staffBaselineY` correto por sistema | **CONFIRMADO** | 60, 180, 300, … [A] |
| N-21 | Agrupamento 4/4 em semicolcheias | **CONFIRMADO** | 4-4-4-4; 2/2, 3/2, 6/4 corretos [A] |
| N-22 | Grade de onset consistente | **CONFIRMADO (motor)** | `kOnsetGrid=8192` nos 2 consumidores; 16/16 chaves [A]. **O teste enviado é vazio** (A-14) |
| N-23 | Nomes de parte/grupo round-trip | **CONFIRMADO** | part-name, abbrev, group-name, part-group [A] |
| N-24 | Exportador JSON preserva `syllables`/`crossStaffMove` | **PARCIAL** | Campos preservados [A]; estrutura corrompida (A-03) [A] |
| N-25 | Altura malformada falha alto | **PARCIAL** | ✅ MusicXML lança [A]; ❌ MEI descarta em silêncio (A-12) [A] |
| N-26 | MEI `clef.shape="TAB"` | **CONFIRMADO** | lines=6 → `tab6`; lines=4 → `tab4` [A] |
| N-27 | Colchete de quiáltera não colinear | **RETIRADA CORRETA** | Metades sobre uma reta: Δ = 0,36 / 0,05 / 0,24 px a 8× [A] |
| N-28 | Dry-run não deixa rastro | **CONFIRMADO** | tupletX 82,61 == innerXs[0] 82,61 [A] |
| N-29 | Segunda/uníssono entre vozes | **CONFIRMADO** | uníssono coincidente, duração diferente deslocada [A]; golden 8× confirma cabeça compartilhada |
| N-30 | — | **NÃO VERIFICADO** | ID não encontrado nos artefatos |
| N-31 | Subdivisões cobrem o compasso | **CONFIRMADO** | 5/4 → 5×2; 7/4 → 7×2; 11/8 → 3-3-3-2 [A] |
| N-32 | `c8vb` sem duplo deslocamento | **CONFIRMADO** | C3 → 2, idêntico a tenor C4 → 2 [A] |
| F-27 | Colisão de acidente sob compressão | **CONFIRMADO** | folga +8,17 / +16,34 / +32,69 px [A] |
| `scoreToMusicXML` | Exportador de score existe e round-trip | **CONFIRMADO** | reimportação preserva grupos e nomes [A] |
| ADR-004 | Abertura canônica, corpo em ordem de documento | **CONFIRMADO** | `Measure` e `MultiVoiceMeasure`, ambos [A] |
| NOVO-6 | Estrutura aditiva MEI perdida | **RETIRADA CORRETA** | `additiveGroups` funciona; corpus usa `TimeSignature.additive` [B] |

---

## 23. PARTE B.2 — OS ATAQUES DIRIGIDOS

| # | Ataque | Resultado |
|---|---|---|
| 1 | ADR-003 aplicado só onde convém? | **PROCEDE.** Aplicado a claves, **não** a `OctaveMark` (A-01) [A] |
| 2 | Existe comprimento máximo de haste? | **PROCEDE.** Não existe; 9,03 SS medido (A-06) [A] |
| 3 | `TupletGrid` congela √ e `minimumSlotSpaces = 1.4` é mágico? | **PROCEDE, e pior.** √ é preservado (1,415 medido), mas a grade **ignora o `SpacingModel` configurado** (A-02) [A]. `1.4` é piso mágico sem origem no metadado |
| 4 | Consumidores de `_leftExtent`/`_rightExtent` | Não procede. `_minimumInterNoteGap` documenta explicitamente por que só o extent do elemento **atual** entra [B] |
| 5 | Colisão de acidente sob compressão | Não procede (F-27, §2.1) [A] |
| 6 | Duas claves no bloco de abertura | **Procede em grau baixo.** Ambas são desenhadas (`Clef@30, Clef@68`) e a nota é posicionada pela **última** (y=24, clave de fá) [A]. Entrada malformada, degrada de forma visível, não silenciosa — P4 |
| 7 | Consumidores que dependiam da duplicação | Não procede nos caminhos MusicXML/MEI. **Procede no JSON** (A-03) [A] |
| 8 | Cópias manuais de `PositionedElement` | Não procede. `movedTo` copia os 7 campos; as 6 construções cruas estão todas em `layout_engine.dart` [B] |
| 9 | Hit-test 3,5 espaços vs `calculateChordStemLength` | Não procede. Hit-test acerta a haste dos dois lados (A-01/§14) [A] |
| 10 | Grade de onset consistente entre consumidores | Não procede. `kOnsetGrid` compartilhado [A] |
| 11 | Goldens congelam defeitos? | **Parcialmente.** As 4 regravações que ampliei são correções reais; mas todas carregam o A-05 [A] |
| 12 | `renderGroupToPage` vs `layoutStaff` | **PROCEDE.** Caminhos independentes; o de grupo não tem *banding* e gera imagem sem limite (A-07) [A] |
| 13 | A suíte de remediação prova o que alega? | **PROCEDE.** N-22 é vazio, 9 achados sem teste, N-04 com asserção frouxa (A-14) [A] |

**Placar: 7 de 13 ataques procedem.**

---

## 24. PARTE B.3 — DECLARADO NÃO FEITO · PARTE B.4 — NOTA

### B.3 — Confirmo que continuam em aberto

| Item declarado não feito | Confirmado aberto | Evidência |
|---|---|---|
| Comprimento máximo de haste | ✅ | 9,03 SS medido [A] |
| Layout em isolate | ✅ | Layout no construtor do `GrandStaffPainter` [B] |
| Exportador MEI | ✅ | Não existe [B] |
| Playback multiplataforma | ✅ | 1 de 6 [B] |
| Cursor / inserção / undo | ✅ | Ausentes [B] |
| Pipeline gregoriano apartado | ✅ | Renderizador/parser/playback próprios [B] |

Nenhum item declarado não feito estava, na verdade, feito. **A declaração de
não-feito é honesta.**

### B.4 — Nota de remediação

```
NOTA = (n1 + 0,5 · n2) / N

n1 (confirmado corrigido)  = 29
n2 (parcialmente corrigido) =  4   (N-12, N-16, N-24, N-25)
não verificáveis            =  3   (N-06, N-14, N-30)

Sobre as linhas julgáveis:   N = 33  →  (29 + 2,0) / 33 = 0,939
Contando não verificáveis:   N = 36  →  (29 + 2,0) / 36 = 0,861
```

**NOTA = 0,939** (0,861 no critério conservador).

**Divergência com a outra frente.** O relatório paralelo
(`doc/AUDITORIA_FORENSE_2026-08-22_2.7.1.md`) chega a **0,742** com
`n1 = 17, n2 = 15` sobre o mesmo `N = 33`. Contra os meus `n1 = 29, n2 = 4`, são
**12 linhas** em que um de nós chama CONFIRMADO e o outro chama PARCIAL.

Não sei qual é o critério dele — **não li a matriz linha a linha dele**, e não
vou supor. O meu está declarado e é este: *se o invariante que o achado nomeia
passa a valer no caminho que o achado nomeia, a linha é CONFIRMADO; defeito
remanescente em área adjacente vira achado novo da Parte A e não rebaixa a
linha*. Foi assim que N-12 virou PARCIAL (o invariante quebra num caminho —
JSON) e N-19 virou CONFIRMADO (o invariante vale nos dois lados da haste,
medido).

**A comparação só é útil linha a linha.** As manchetes 0,742 × 0,939 não dizem
qual dos dois errou — podem ser a mesma medição sob dois limiares.

**Leitura obrigatória junto da nota:** essa métrica mede *aderência à lista da
auditoria anterior*, e nada mais. Ela não penaliza os 20 achados novos, dos
quais **dois nasceram do próprio código de remediação** (A-02, A-03). Uma nota
de 0,94 com duas regressões auto-infligidas é o retrato exato desta rodada.

---

## 25. VEREDITO FINAL — 12 PERGUNTAS

**1. O projeto faz o que diz que faz?**
Em grande medida, sim, e mais do que na 2.7.0. As regras de Gould que ele
declara implementar agora são verificáveis por medição. Exceções: `OctaveMark`
(declarado, inerte) e exportação PDF (implementada, inalcançável pela API
pública).

**2. Qual é o defeito mais grave?**
**A-01** — `OctaveMark` sem efeito na altura impressa. É corrupção musical
silenciosa numa notação comum, e é o espelho exato do bug que a rodada acabou de
corrigir para claves.

**3. Qual é o defeito mais embaraçoso?**
**A-03** — o exportador JSON escrito nesta release reintroduz, num terceiro
caminho, o defeito que a mesma release fechou em dois. O layout desenha duas
claves.

**4. Alguma correção quebrou algo?**
Sim, duas, e ambas mensuráveis. `fa2cce5` fez `TupletGrid` ignorar o
`SpacingModel` (A-02). O novo `json_exporter.dart` duplica o bloco de abertura
(A-03).

**5. Os testes provam o que alegam?**
Majoritariamente sim — 821 passam e `dart analyze lib` está limpo. Mas o teste
do N-22 não invoca o motor, e nove achados remediados não têm teste na suíte que
existe para prová-los.

**6. Os goldens são confiáveis?**
Mais do que na rodada anterior. Ampliei quatro deles a 4×–10×: as regravações
são correções reais (uníssono compartilhando cabeça, barra ganhando inclinação,
acidente reservando espaço antes). Mas todos congelam o A-05.

**7. A arquitetura sustenta um editor?**
Sim, estruturalmente. Identidade estável ponta a ponta, `staffBaselineY`
correto, hit-test que cobre haste dos dois lados. Falta a camada de edição
(cursor, inserção, undo) — que é trabalho, não obstáculo.

**8. A arquitetura escala?**
Para layout, agora sim (6.400 compassos em 124 ms). Para rasterização de grupo,
não: uma imagem única de 15.168 px em 60 compassos, sem *banding*, contra um
caminho de pauta única que tem.

**9. A segurança é adequada?**
Sim, e eu retiro qualquer suspeita em contrário: XXE com arquivo real não
vazou, billion laughs foi inerte em 1 ms. O problema é robustez — oito caminhos
de corrupção silenciosa sem um único warning.

**10. A documentação corresponde ao código?**
Os ADRs são bons e incomumente honestos — o ADR-003 documenta o comportamento
medido da 2.7.0 que ele quebra, e o commit `fa2cce5` descreve o trade-off que
aceita. A imprecisão do ADR-003 sobre instrumentos transpositores (A-18) é de
redação, não de intenção.

**11. A remediação da 2.7.1 foi honesta?**
**Sim.** Três razões concretas: (a) nenhuma alegação que consegui verificar é
falsa; (b) as duas retiradas da rodada anterior estão corretas e eu as confirmei
por medição, inclusive uma que eu mesmo suspeitei estar errada; (c) a lista de
"não feito" é fiel — nenhum item declarado aberto estava secretamente fechado.
O que a rodada **não** fez foi auditar o próprio código novo: os dois defeitos
auto-infligidos estão em arquivos criados na mesma sprint.

**12. A rodada 2.7.1 corrigiu erros da auditoria anterior, ou apenas concordou
com ela?**
**Corrigiu** — e tem os números para provar. Mas há um caso instrutivo de uma
terceira categoria, que não é nem corrigir nem concordar: `fa2cce5` resolveu a
divergência layout↔renderizador **removendo o motor de espaçamento dos dois
lados**. Os dois passaram a concordar entre si e a discordar da configuração do
usuário. A mensagem do commit descreve esse raciocínio em voz alta e o aceita.
Isso é satisfazer a letra do achado ao custo de um achado que ninguém tinha
escrito ainda. É a diferença entre fechar um ticket e resolver um problema — e é
exatamente o que uma re-auditoria existe para encontrar.

---

### Prioridades para a 2.7.2

1. **A-01** — aplicar o ADR-003 a `OctaveMark` (é o mesmo `−7 × octaveShift` já
   escrito para claves em `staff_position_calculator.dart:70`).
2. **A-03** — `json_exporter.dart:65` não deve escrever `elements` e `voices` com
   o mesmo bloco de abertura.
3. **A-02** — dar ao renderizador o `IntelligentSpacingEngine`, ou pré-computar
   as larguras de slot no layout e o renderizador lê — em vez de remover o motor
   dos dois.
4. **A-05** — `numberOffset = 0` e o numeral cai dentro do vão que o colchete já
   abre.
5. **A-09** — exportar `PdfExporter` e `ScoreRasterizer` em `flutter_notemus.dart`.
6. **A-07** — dar *banding* ao caminho de grupo, como o de pauta única já tem.
