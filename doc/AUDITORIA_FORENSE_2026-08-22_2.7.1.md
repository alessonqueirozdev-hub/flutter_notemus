# RE-AUDITORIA FORENSE, ADVERSARIAL E DE VERIFICAÇÃO — flutter_notemus 2.7.1

**Data:** 2026-08-22 · **Commit auditado:** `5e58fab` (branch `sprint/forensic-remediation-2.7.1`)
**Baseline de testes:** `flutter test` → **821 testes, 0 falhas, 31 s** (medido duas vezes)
**Método:** 17 arquivos de sonda executáveis em `probe/`, rodados com `flutter test`.
Todo número marcado **[A]** foi produzido por execução de código nesta rodada.

---

## 1. EXECUTIVE SUMMARY

Verifiquei **33 alegações** da remediação 2.7.1 executando código. **17 são
integralmente verdadeiras, 15 são verdadeiras no caso citado e falsas no caso
vizinho, 1 regrediu, nenhuma é inventada.** Nota de remediação: **0,742**
(contra 0,829 da rodada anterior).

A queda da nota não significa que a 2.7.1 seja pior que a 2.7.0 — significa que
**esta rodada corrigiu problemas mais difíceis e deixou vizinhos mais visíveis**.
As três correções estruturais da release (ADR-003 `Pitch` soante, ADR-004 bloco
de abertura, grade de quialtera única) são reais, medidas e certas na direção.

**O que a 2.7.1 realmente consertou (medido):** ordem clave→armadura→fórmula em
ambas as rotas; oitava de clave aplicada uma única vez no desenho; `<transpose>`
soando; compasso sobrecheio não derruba mais o painter; polifonia e opções de
beaming sobrevivem à quebra de sistema; `MultiVoiceMeasure.elements` chegam ao
layout; duplicação removida de MusicXML e MEI; layout **linear** (12.800
compassos = 589 ms [A]); tabela de inclinação de Gould; níveis de barra por nota;
piso anti-colisão pelo metadado no fluxo principal; grade de onset a 1/8192;
uníssono entre vozes; `clef.shape="TAB"`.

**Os cinco achados que mais importam desta rodada, todos novos:**

1. **[R-01, P1]** Uma mudança de clave no meio de um compasso **polifônico** é
   invisível para o restatement de sistema: todo sistema quebrado seguinte
   restata a clave **errada**. Medido: sistemas 3–5 restatam `treble` quando a
   clave vigente é `bass` [A]. Corrupção silenciosa de altura.
2. **[R-02/R-03, P1]** Quiálteras não sobrevivem ao round-trip MusicXML e
   `<time-modification>` de arquivos de terceiros é ignorado. Medido: um compasso
   de 0,5 volta valendo 0,625; três semínimas de tercina tocam 33 % longas demais [A].
3. **[R-04, P1]** **Apagiaturas consomem tempo musical no layout.** Um compasso
   com duas apagiaturas vale 1,1875 e os onsets das notas reais saem deslocados
   em 0,1875 [A] — a grade compartilhada do ADR-002, a bandeira da 2.7.0, quebra.
   O MIDI está certo; layout e playback discordam.
4. **[R-05, P1]** **Hastes de acorde ficam presas em 6,0 espaços.** Um acorde
   C3–C6 é desenhado com a haste boiando no meio da pauta, sem tocar nenhuma das
   duas cabeças. Provado numericamente e **em imagem ampliada**.
5. **[R-07/R-08, P2]** Dentro de uma quiáltera, acidentes colidem com folga de
   **−20,78 px** e o `TupletRenderer` **ignora as decisões do resolvedor de
   acidentes** — a mesma música imprime sustenidos repetidos dentro da quiáltera
   e os omite fora dela. Provado em imagem.

**Padrão dominante, de novo:** a remediação corrige o caso do achado e escreve o
teste desse caso. Quinze dos trinta e três verificados falham no vizinho
imediato. E há um agravante novo: **o `TupletGrid` — a correção mais elegante da
release — introduziu uma regressão de legibilidade que foi congelada em golden**
(`m04m_tuplet_ratio`).

**Veredito curto:** visualizador CMN competente para partituras de origem
confiável e sem apagiaturas, quiálteras densas ou acordes largos. Não é um motor
de gravação profissional. Não é ainda a base de um editor, mas está mais perto.

---

## 2. NOTA DE REMEDIAÇÃO

### 2.1 Matriz de verificação (Parte B)

| ID | Alegação | Veredito | Evidência medida |
|---|---|---|---|
| **N-11** | Compasso abre clave→armadura→fórmula | ✅ **CONFIRMED FIXED** | Autoral `[key,time,clef]` → `Clef@30,0 · Key@68,2 · Time@107,9`; import MusicXML idem [A] |
| **N-01** | Compasso sobrecheio no início de sistema quebrado | ✅ **CONFIRMED FIXED** | 12 compassos, o 5º com 6 semínimas em 4/4, painter a 300 px → 12 sistemas, **sem exceção** [A] |
| **N-02** | `autoBeaming`/`beamingMode`/`manualBeamGroups`/`number` sobrevivem | ✅ **CONFIRMED FIXED** | `autoBeaming:false` → `{null}` em 8 sistemas; `manualBeamGroups [[0,1,2],[3..7]]` → `start,inner,end,start,inner,inner,inner,end` [A] |
| **N-02b** | Vozes sobrevivem ao rebuild | ✅ **CONFIRMED FIXED** | 10 sistemas × 8 notas × vozes `{1,2}` [A] |
| **N-03** | `MultiVoiceMeasure.elements` chegam ao layout | ✅ **CONFIRMED FIXED** | clave+armadura+fórmula+dinâmica desenhados; 4 notas, Y distintos, `noteXPositions=4` [A] |
| **N-12** | Parsers não duplicam o bloco de abertura | 🟡 **PARTIALLY FIXED** | MusicXML e MEI: 1 clave, 1 armadura, 1 fórmula ✅ [A]. **O importador JSON continua duplicando**: round-trip produz `elements=[Clef,Key,Time]` **e** `voice1=[Clef,Key,Time,…]` → layout desenha **2 claves, 2 armaduras, 2 fórmulas** [A] |
| **N-04** | Layout linear | ✅ **CONFIRMED FIXED** | Com aquecimento: 400=94,5 ms · 800=149,3 · 1600=169,7 · 3200=202,6 · 6400=**285,0** · 12800=**588,7 ms**; razões 1,58/1,14/1,19/1,41/2,07 [A] |
| **N-05** | Acidente reserva espaço ANTES da nota | ✅ **CONFIRMED FIXED** | `C4,E4♯,G4,B4`: vão anterior 76,21 vs base 56,16 (+20,05); vão posterior 56,16 = base. 1ª nota do compasso: 82,61 → 107,76 (♯) → 115,63 (♭♭) [A] |
| **F-27** | Piso anti-colisão usa a largura do metadado | 🟡 **PARTIALLY FIXED** | 32 semicolcheias comprimidas a 400 px, todas com acidente real: folga = **+6,37 / +12,74 / +25,49 px** em ss 6/12/24, para ♭♭, ×, ♭ ✅ [A]. **Dentro de quiáltera o piso não existe** → ver R-07 |
| **N-07** | Quiáltera espaça por duração | 🔴 **REGRESSED** | Semínima+colcheia → 30,00/21,21 ✅; colcheia+2 semicolcheias → 21,21/16,80/16,80 ✅ [A]. **Mas o piso 1,4 SS deixa 0,22 SS entre cabeças** (era 1,32 SS na grade fixa de 2,5). O golden `m04m_tuplet_ratio` congelou a piora [A] |
| **N-07b** | Layout e renderer usam a MESMA grade | ✅ **CONFIRMED FIXED** | `TupletGrid` sem parâmetro de engine; ambos chamam `slotWidth`. Aninhada: layout `[82,6 · 103,8 · 120,6 · 137,4 · 154,2 · 171,0 · 187,8]` == `offsets` [A] |
| **N-08** | Níveis de barra por nota dentro da quiáltera | ✅ **CONFIRMED FIXED** | `levels` por nota + stub fracionário em `_drawSimpleBeams` [B]; fora da quiáltera colcheia+2×16ª → `L1[0..2], L2[1..2]` [A] |
| **N-09** | Análise de barras sem fórmula de compasso | ✅ **CONFIRMED FIXED** | `Measure()` sem `TimeSignature`, 8 colcheias → `[4,4]`, 1 segmento cada [A] |
| **N-10** | Inclinação segue a tabela de Gould | ✅ **CONFIRMED FIXED** | 0→0,000 · 2ª→0,250 · 3ª→0,500 · 4ª/5ª→1,000 · 6ª/7ª→1,250 · 8ª+→1,500; idêntico para grupos de 3 [A] |
| **N-21** | 4/4 agrupa semicolcheias por tempo | 🟡 **PARTIALLY FIXED** | 4/4: 16×16ª→`4-4-4-4`, 8×8ª→`4-4` ✅; 2/2→`4-4`, 3/2→`4-4-4`, 6/4→`6-6`, 6/8→`3-3`, 9/8→`3-3-3`, 12/8→`3-3-3-3` ✅ [A]. **6/2, 9/2, 12/2, 15/2 agrupam colcheias de 12 em 12** [A] |
| **N-31** | Subdivisões cobrem o compasso inteiro | 🟡 **PARTIALLY FIXED** | A soma fecha ✅. **Mas a granularidade do fallback é 1 unidade**, então em 2/8, 4/8, 10/8, 13/8, 14/8, 16/8 e em 2/16, 4/16, 5/16, 7/16, 8/16, 10/16, 11/16, 14/16, 16/16 **nenhuma nota recebe barra** [A] |
| **N-13** | `<transpose>` chega ao playback | 🟡 **PARTIALLY FIXED** | Clarinete Si♭: `Pitch` continua C4, MIDI **58** ✅; export emite `<transpose>` e reimporta ✅; `<double/>` **soa** (MIDI 27) e **não avisa** ✅ [A]. **MEI `trans.semi`/`trans.diat` é ignorado** → `transposition=null`, MIDI 60 [A] |
| **N-15 / ADR-003** | `Pitch` é a altura SOANTE | 🟡 **PARTIALLY FIXED** | `clef-octave-change` −1/0/+1 → MIDI 60 nos três; `staffPosition` 1 / −6 / −13 ✅; `c8vb`: `calc(C3,c8vb)=2 == calc(C4,tenor)=2` ✅; deslocamento uniforme nas 21 claves [A]. **MEI `clef.dis`/`clef.dis.place` é ignorado** (clave sai `treble`, shift 0) [A]. **Gregoriano e Jianpu não passam por `StaffPositionCalculator`** [B] |
| **N-16** | Texto usa a cadeia de fontes do pacote | 🟡 **PARTIALLY FIXED** | Toda `TextStyle` passa por `withMusicTextFallback` ✅ [B]; com uma face real registrada como `Academico`, "Allegro (♩ = 120)" e a lyric renderizam perfeitamente [A]. **Sem ela — e o pacote não empacota nenhuma das quatro — o rasterizador headless ainda produz caixas `.notdef`**, inclusive registrando `serif` [A] |
| **N-17** | Lead-in de ligadura não atravessa a clave | ✅ **CONFIRMED FIXED** | Render 3× de quebra com armadura restatada: o arco de ligadura **e** o de legato começam **depois** dos 4 bemóis [A, imagem] |
| **N-18** | PDF exporta grand staff como grand staff | 🟡 **PARTIALLY FIXED** | Usa `GrandStaffPainter`, com chave e barras de sistema ✅ [B]. **Mas gera UMA imagem com TODOS os sistemas em UMA página**: 14 sistemas, 1000×3552 px lógicos, recortados em `usableHeight` ≈ 760 pt → **~60 % da música some do PDF** [A]. A alegação "1 imagem por sistema" é falsa |
| **N-19** | Hit-test derivado do desenho | 🟡 **PARTIALLY FIXED** | Clique no acidente devolve a `Note` correta (identidade preservada) ✅; acorde C6-E6-G6 acerta ✅ [A]. **A caixa usa haste fixa de 3,5 SS**: um C2 tem haste desenhada de 10,0 SS e a ponta fica **70,8 px fora da caixa** [A] |
| **N-20** | `PositionedElement.staffBaselineY` | 🟡 **PARTIALLY FIXED** | Presente e correto em todos os caminhos de pauta única ✅ [A]. **Num grand staff todas as pautas reportam `staffBaselineY = 60,0`** — é local à pauta, não ao sistema, contra o que o dartdoc afirma [A] |
| **N-22** | Grade de onset resolve 1/2048 | ✅ **CONFIRMED FIXED** | 16 notas de 1/2048 → **16 chaves distintas** (`kOnsetGrid = 8192`); aninhada 1/3 de 1/5 → `totalDuration` exato 0,3333/0,25 [A] |
| **N-23** | Nomes de parte/grupo importados e exportados | 🟡 **PARTIALLY FIXED** | `part-name`/`part-abbreviation`/`Staff.name`/`abbreviation`/`transposition` sobrevivem ✅; 4 `<part-group>` emitidos ✅ [A]. **`group-abbreviation` é perdido; `bracket: none` volta como `bracket`; `score-timewise` perde os nomes; MEI `<staffGrp><label>` não é lido** [A] |
| **N-24** | Round-trip JSON | 🟡 **PARTIALLY FIXED** | `syllables`, `crossStaffMove`, `tabFret/tabString`, quiáltera, acorde e `MultiVoiceMeasure` sobrevivem ✅ [A]. **`name`, `abbreviation`, `lineCount` e `transposition` são exportados e NÃO relidos**; e o bloco de abertura é duplicado [A] |
| **N-25** | `<pitch>` sem `<octave>` falha alto | 🟡 **PARTIALLY FIXED** | MusicXML: sem `<octave>`, sem `<step>`, step `H`, oitava 99 → 4 `FormatException` com mensagem útil ✅ [A]. **MEI `<note pname="c" dur="4"/>` sem `@oct`: não lança e a nota DESAPARECE** (compasso vazio) [A] |
| **N-26** | MEI `clef.shape="TAB"` | ✅ **CONFIRMED FIXED** | `lines=6`→`tab6`, `lines=4`→`tab4`, `lines=5`→`tab6` [A] |
| **N-28** | Dry-run não escreve nos mapas | 🟡 **PARTIALLY FIXED** | `_registerTupletGeometry` protegido por `_measuring` ✅ [B]. **Mas `_processBeamsWithAnacrusis` roda no dry-run e escreve `Note.beam` no modelo do usuário** [B/A] |
| **N-29** | Uníssono entre vozes compartilha posição | ✅ **CONFIRMED FIXED** | Mesma duração → 82,61/82,61; durações diferentes → 82,61/68,45 (exatamente uma cabeça, 14,16 px) [A] |
| **N-32** | `c8vb` deslocado uma única vez | ✅ **CONFIRMED FIXED** | `calculate(C3,c8vb) == 2 == calculate(C4,tenor)` [A] |
| **scoreToMusicXML** | Export em nível de partitura | 🟡 **PARTIALLY FIXED** | Grupos, `<part-group>` start/stop, nomes, abreviações de pauta, transposição, título e compositor reimportam ✅ [A]. **`group-abbreviation` some e `bracket: none` vira `bracket`** [A] |
| **ADR-004** | Convenção na abertura, ordem no corpo | ✅ **CONFIRMED FIXED** | `Measure`: `[key,time,clef]`→`Clef,Key,Time`; `[treble,C4,bass,C4]`→ordem preservada e posições `[−6, 6]`; `MultiVoiceMeasure`: `Clef@30 · Key@68,2 · Time@98,3` [A] |

### 2.2 Nota

```
ACHADOS VERIFICADOS: 33
  CONFIRMED FIXED : 17   (51,5 %)
  PARTIALLY FIXED : 15   (45,5 %)
  NOT FIXED       :  0
  REGRESSED       :  1   (N-07, grade de quialtera)
  UNVERIFIABLE    :  0

NOTA = (17 + 0,5 × 15) / 33 = 24,5 / 33 = 0,742      (2.7.0: 0,829)

ACHADOS NOVOS INTRODUZIDOS PELA REMEDIAÇÃO: 1 regressão direta (N-07/R-10)
ACHADOS NOVOS TOTAIS (Parte A + vizinhos da Parte B): 42
```

### 2.3 A remediação melhorou ou piorou o projeto?

**Melhorou — mais do que a nota sugere — mas com uma regressão real e uma
mudança de risco que ninguém declarou.**

Melhorou de forma estrutural, não cosmética:

- **ADR-003 é a decisão certa e foi aplicada com disciplina.** Verifiquei as 21
  claves, os três consumidores centrais (`StaffPositionCalculator`, `MidiMapper`,
  os exportadores) e os dois lados do round-trip. O deslocamento acontece em
  exatamente um lugar. Isso elimina uma classe inteira de bug.
- **ADR-004 resolve o conflito real** entre "ordem do documento" (necessária no
  meio do compasso) e "convenção de gravação" (necessária na abertura), e o faz
  posicionalmente, não textualmente. As duas rotas usam o mesmo helper.
- **O desempenho voltou a ser linear** e agora suporta 12.800 compassos em 589 ms
  [A]. A alegação de 313 ms para 6.400 é conservadora: medi 285 ms.
- **`TupletGrid` é a abstração certa** — uma geometria, dois consumidores.

Piorou:

- **A grade de quiáltera regrediu na legibilidade** para valores curtos, e a
  regressão foi congelada em golden (`m04m_tuplet_ratio`). O piso `1,4` SS foi
  escolhido "just above a black notehead" — mas uma cabeça preta mede 1,18 SS de
  *avanço*, e duas cabeças em graus conjuntos a 1,4 SS de distância, com 0,5 SS
  de degrau vertical, ficam visualmente fundidas.
- **A superfície de colisão dentro da quiáltera piorou**: com a grade fixa de
  2,5 SS (30 px) um bemol simples cabia (14,16 + 14,45 = 28,6 < 30). Com 1,4 SS
  (16,8 px) **nenhum acidente cabe**.
- **Risco novo não declarado:** `_minimumInterNoteGap` deixou de somar
  `previousRight`. No fluxo principal isso é correto (o cursor já avançou) e eu
  provei que a folga é sempre `head × 0,9 > 0` [A]. Mas o argumento só vale
  porque **todo** avanço passa pelo cursor — e o conteúdo de quiáltera não passa.

**A honestidade continua alta.** Nenhuma das 33 alegações é falsa. Os ADRs
descrevem o que o código faz — com **uma exceção**: ADR-003 afirma que
`<transpose><double/>` é "recorded and warned about, not sounded"; medi que ele
**é sonorizado** (MIDI 27, não 39) e **não gera aviso**. É a única discrepância
ADR↔código que encontrei, e ela erra para o lado bom.

---

## 3. REALIDADE VS DOCUMENTAÇÃO

| Documento | Afirma | Realidade medida |
|---|---|---|
| CHANGELOG 2.7.1 | "text no longer rasterises as `.notdef` boxes" | **Meio verdadeiro.** A cadeia funciona quando o host tem `Academico`/`Century Schoolbook`/`Edwin`. O pacote não empacota nenhuma. Sem elas, e mesmo com `serif` registrado, o rasterizador headless devolve caixas [A] |
| README §2.7.1 | "PDF exports a grand staff as a grand staff" | **Meio verdadeiro.** Sai com chave e alinhamento, mas **numa única página, com ~60 % da música cortada** [A] |
| README §2.7.1 | "Layout is linear again: 6 400 bars 5 991 ms → 313 ms" | **Verdadeiro e conservador.** Medi 285 ms com aquecimento; 12.800 = 589 ms [A] |
| README §2.7.1 | "53 goldens in total" | **Verdadeiro.** `ls test/golden/goldens/*.png` = 53 |
| CHANGELOG 2.7.1 | "16 goldens were re-baselined" | **Verdadeiro.** `git show --stat cab8048` lista exatamente 16 PNG |
| ADR-003 "To revisit" | "`<transpose><double/>` is recorded and warned about, not sounded" | **Falso.** É sonorizado (−12 adicionais) e não avisa. `Transposition.semitones` inclui `doubled ? -12 : 0` [A/B] |
| ADR-003 "To revisit" | "`Transposition.diatonic` is carried but not yet used" | **Verdadeiro** |
| README linha 104 | "meiHead parsed since 2.7.0 via `MEIParser.scoreFromMei`" | **Verdadeiro** [A] |
| README linha 170 | "MEI header (meiHead) — model API; **not yet parsed from MEI XML**" | **Falso e contradiz a linha 104** |
| `parser_support.dart` :92 | "GAP: `MEIParser` still only exposes `parseMEI` … this entry point is not reachable" | **Comentário obsoleto.** `MEIParser.scoreFromMei` existe e funciona [A] |
| README | "SMuFL-compliant engraving" | **Parcial.** `BeamRenderer` usa 0,40/0,60 SS contra `beamThickness=0,5`/`beamSpacing=0,25` do próprio `bravura_metadata.json` que ele carrega — e diz por quê num comentário ("looked too heavy on Flutter canvases") |
| README §MEI | "MEI is import-only. There is no MEI serializer" | **Verdadeiro e honesto** |
| Auditoria 2.7.0, ADENDO | N-27 (colchete de quiáltera não colinear) **RETIRADO** | **A retirada procede.** `_drawTupletBracket` calcula uma reta e usa o mesmo `yAt(x)` nos dois segmentos e nos dois ganchos [B] |
| Auditoria 2.7.0, ADENDO | NOVO-6 (estrutura aditiva do MEI perdida) **RETIRADO** | **A retirada procede.** `3+2+2/8` → `isAdditive=true` e agrupamento `[3,2,2]`; testei 4 padrões aditivos, todos corretos [A] |

---

## 4. ARQUITETURA ATUAL

```
INPUT ──┬─ MusicXML (partwise + timewise) ─┐
        ├─ MEI v5 (staff/score/meiHead) ───┤
        └─ JSON ───────────────────────────┤
                                           ▼
                            parser_support.dart  (3 importadores,
                            um arquivo de 3.700 linhas)
                                           │
                                           ▼
                        MODELO  (core/: Staff, Measure,
                        MultiVoiceMeasure, Note, Chord, Tuplet…)
                                           │
                   ┌───────────────────────┼──────────────────────┐
                   ▼                       ▼                      ▼
            LayoutEngine            MidiMapper            ChantMidiMapper
        (2.608 linhas, cursor)   (1.390 linhas)        (pipeline à parte)
                   │                       │
        ┌──────────┴──────────┐            ▼
        ▼                     ▼        MidiFileWriter / backend nativo
  StaffRenderer      GrandStaffPainter
  (pauta única)      (N pautas, N LayoutEngine por sistema)
        │                     │
        └──────────┬──────────┘
                   ▼
     ScoreRasterizer ──► PdfExporter
```

**Pipelines de layout independentes que existem de fato: quatro.** A rodada
anterior contou quatro e disse ter reduzido a três. **Refuto:** continuam quatro,
e a redução não aconteceu.

1. `LayoutEngine._layoutMeasureCursor` — pauta única, monofônico.
2. `LayoutEngine._layoutMultiVoiceMeasure` — polifônico (código separado, com
   voz-líder e interpolação para vozes 3+).
3. `TupletRenderer` — a quiáltera tem **grade própria** (`TupletGrid`), **desenhador
   de barras próprio** (`_drawSimpleBeams`), **espessura de barra diferente**, e
   **não recebe as decisões de acidente**. Compartilhar a grade removeu *uma*
   divergência de quatro.
4. `GregorianRenderer` / `ChantScore` — modelo, clave, altura, onset e playback
   próprios; não passa por `Clef`, `Pitch` nem `StaffPositionCalculator`.

O `GrandStaffPainter` é um quinto caminho de *composição*, não de layout: ele
instancia um `LayoutEngine` por pauta por sistema e depois realinha por onset.

**Onde a arquitetura existe e onde é conceitual:**

| Camada | Existe? | Observação medida |
|---|---|---|
| `INPUT → PARSER` | ✅ real | 3 formatos, um arquivo compartilhado |
| `PARSER → NORMALIZATION` | 🟡 parcial | não há passo de normalização: cada importador escreve direto no modelo. `<time-modification>` prova o custo [A] |
| `MODEL → LAYOUT` | ✅ real | mas o layout **muta** o modelo (`Note.beam`) [A] |
| `LAYOUT → ENGRAVING` | 🟠 fundido | não há camada de gravação separada; renderizadores recalculam geometria (haste, acidente, cluster) que o layout não conhece |
| `ENGRAVING → RENDER` | ✅ real | `StaffRenderer`/`GrandStaffPainter` |
| `RENDER → RASTER/PDF` | 🟡 parcial | dois caminhos que discordam da largura [A] |
| `MODEL → MIDI → PLAYBACK` | ✅ real | MIDI exato; playback nativo em 1 de 6 plataformas |
| `MODEL → EXPORT` | 🟡 parcial | MusicXML sim (lossy), JSON sim (lossy), MEI **não existe** |

---

## 5. MUSIC MODEL

**Nota: 7/10** (era 7).

**Sólido e verificado [A]:** `Pitch` com `alter` fracionário e `accidentalType`
(microtonais incluídos); `Duration` de `maxima` a 1/2048 com pontos;
`Tuplet.totalDuration` exato inclusive aninhado (1/3 de 1/5 = 0,3333);
`Transposition` como tipo de primeira classe; `Staff.name/abbreviation/lineCount`;
`Measure.musicalValueByVoice` correto para polifonia; `Pitch.validated` rejeita
oitava 11 (`FormatException`) e o construtor cru dispara `AssertionError`.

**Rachaduras medidas:**

- **`Note.isGraceNote` não é respeitado pelo modelo de tempo.** `Measure.
  currentMusicalValue` conta apagiaturas: um compasso 4/4 com 4 semínimas e
  2 apagiaturas vale **1,1875** [A]. Consequência em cadeia: validação de
  capacidade errada, onsets errados, alinhamento multi-pauta errado.
- **`Note.beam` é mutável e escrito pelo layout**, inclusive durante a passada de
  medição (dry-run) [A]. Decisão consciente (ADR-001), mas continua sendo estado
  de layout dentro do modelo.
- **Mapas com chave de identidade colapsam instâncias repetidas.** Três usos da
  mesma `Note` → 3 `PositionedElement` desenhados, mas `noteXPositions.length == 1` [A].
- **`MultiVoiceMeasure` quebra LSP de forma sutil**: `elements` significa
  "elementos de sistema do compasso" na subclasse e "todo o conteúdo" na base.
  Depois da 2.7.1 os consumidores concordam, mas o contrato continua implícito.
- **`Chord` não modela deslocamento de segundas.** `ChordRenderer` calcula
  offsets de cluster no desenho; o modelo e o layout não os conhecem [A/B].

**Fonte de verdade — onde ela realmente está:**

| Aspecto | Fonte de verdade | Risco |
|---|---|---|
| pitch | `Note.pitch` (soante, ADR-003) | gregoriano usa `NeumeComponent.pitchName/octave` — **segunda convenção** |
| duration | `Note.duration` | `<time-modification>` do MusicXML é perdido → **duração importada ≠ duração do arquivo** [A] |
| position X | `LayoutEngine._noteXPositions` | cluster de acorde e cross-staff não estão lá [A] |
| position Y | `_noteYPositions` | idem |
| voice | `Voice.number` **e** `Note.voice` | duas fontes; `MidiMapper` usa uma, o layout a outra |
| measure | `Measure.number` ?? índice | ok |
| staff | posição na lista | `crossStaffMove` só é honrado em grupos com barra [A] |
| lyrics | `Note.syllables` | ok |
| dynamics/articulation | elemento/nota | ok |
| beam | **`Note.beam`, escrito pelo layout** | modelo mutado; dry-run escreve também [A] |
| slur/tie | `Note.slur/tie` + `SlurEvent` | duas representações coexistem |
| tempo | `TempoMark` + `Score.metadata` | conductor emite **dois** eventos de tempo no tick 0 [A] |
| repeat | `Barline`/`RepeatMark`/`VoltaBracket` | três tipos para o mesmo domínio |

---

## 6. ENGRAVING

**Nota: 5/10** (era 5,5). **Desceu.**

### Correto e verificado [A]

Posição por clave nas 21 claves (com deslocamento de oitava uniforme); linhas
suplementares (C0→15 linhas, C10→16, e nenhuma para as posições ±5); direção de
haste; acidentes intra-compasso com regra de oitava; cortesia e editorial nunca
suprimidos (`parentheses`→show); acidente reserva espaço **antes** da nota;
piso anti-colisão pelo metadado no fluxo principal; **tabela de inclinação de
Gould aplicada literalmente**; níveis secundários/terciários por nota; barra sem
fórmula de compasso; ligadura entre sistemas em dois segmentos com lead-in depois
da armadura; número de compasso; folga acima/abaixo para notas extremas.

### Errado ou ausente [A]

- **Haste de acorde com clamp em 6,0 espaços.** `calculateChordStemLength` faz
  `(span/2 + 3,5).clamp(min, 6.0)`. Medido: `span=14` (duas oitavas) precisa de
  10,5 SS e recebe 6,00 → **a haste não alcança a cabeça oposta**. Em imagem
  ampliada, o acorde C3–C6 aparece com a haste **boiando no meio da pauta, sem
  tocar nenhuma das duas cabeças**.
- **Acidentes dentro de quiáltera colidem.** Folga medida a ss=12:
  ♭♭ = **−20,78 px**, ×  = −12,96, ♭ = −11,81, ♯ = −12,91. A cabeça mede 14,16 px:
  o acidente cobre a cabeça anterior inteira. Provado em imagem.
- **`TupletRenderer` não recebe `accidentalDecisions`.** `C♯4` seguido de tercina
  de três `C♯4`: o resolvedor decide `hide, hide, hide` [A] e o renderizador
  imprime **três sustenidos**. A mesma figura fora da quiáltera sai correta.
  Duas imagens lado a lado provam.
- **Duas geometrias de barra.** `BeamRenderer` 0,40/0,60 SS; `TupletRenderer`
  0,50/0,25 SS. Visível no mesmo compasso [A, imagem]. Bravura diz 0,5/0,25 — o
  desenhador *principal* é o que contradiz o metadado.
- **Sem comprimento máximo de haste e sem quebra de barra por âmbito.** C3↔C5
  num grupo com barra: hastes de **8,54 e 3,04 SS** [A]; em grupo de 4, até
  **10,85 SS**. A barra atravessa a pauta em diagonal.
- **Segundas dentro de acorde não reservam largura.** `C5-D5-E5` e `C5-E5-G5`
  reservam ambos 14,16 px, e os três `noteXPositions` são idênticos [A]. O
  desenho desloca; o layout não sabe.
- **Colunas de acidente de acorde não reservam largura.** 2, 3, 4 ou 5 acidentes
  → sempre `leftExtent = 25,82 px` (uma coluna) [A]. O renderizador desenha
  várias colunas para a esquerda.
- **Cabeças longas reservam a largura da cabeça preta.** Semibreve real 20,26 px,
  breve 31,44 px, reservado 14,16 px em todos [A].
- **Colchete/número de quiáltera não entram na folga do canvas.**
  `contentTopOverflow` e `contentBottomOverflow` devolvem **0,00** para um
  compasso que é só uma quiáltera [A] → recorte no raster e no PDF.
- **Quiáltera com acorde ou pausa nunca recebe barra** (`_applyAutomaticBeams`
  exige que todos os elementos sejam `Note`); 128ª e mais curtas também não [B].

---

## 7. LAYOUT ENGINE

**Nota: 5,5/10** (era 5).

**O que melhorou de verdade:** métrica única por dry-run com o mapa protegido;
`canonicalOpeningBlock` estável e usado pelas duas rotas; extensão esquerda/
direita separada, com a reserva do acidente na lacuna certa; piso anti-colisão
pelo metadado; **linearidade** (12.800 compassos = 589 ms).

**Contas verificadas [A]:**

- `_minimumInterNoteGap = leftExtent(atual) + head × 0,9`. Provei que a folga
  resultante é exatamente `head × 0,9` (6,37 / 12,74 / 25,49 px em ss 6/12/24)
  para ♭♭, × e ♭ — ou seja, o argumento "o cursor já avançou `rightExtent`" é
  **correto** no fluxo principal.
- `_rightExtent = width − leftExtent` é consistente com `_getElementWidthSimple`
  para `Note` e `Chord`.

**Onde o modelo de extensões ainda não fecha:**

- `_leftExtent(Tuplet) = 0` e `_getElementWidthSimple(Tuplet) = TupletGrid.
  totalWidth`. Uma quiáltera cuja primeira nota tem acidente não reserva nada
  à esquerda.
- `contentWidth` soma `position.dx + _getElementWidthSimple(element)` — soma a
  extensão esquerda de novo. Medido: nota com ♭♭ em x=115,63, largura 37,58,
  borda direita real 129,79, contribuição contada 153,21 (+23,42) [A].
- `_layoutMeasureCursor` **não reseta `previousRhythmic`** depois de um elemento
  de sistema no meio do compasso, então o vão da nota seguinte é calculado
  contra a nota **anterior à clave** *e* soma o avanço da clave.
- `canonicalOpeningBlock` só ordena clave/armadura/fórmula (rank 0/1/2, resto 3).
  **Duas claves na abertura**: as duas são desenhadas (30,0 e 68,2) e a **última**
  posiciona as notas [A]. Não é erro do motor, mas é comportamento indefinido.

**Quiáltera:** `TupletGrid` fixa a lei em `sqrt` deliberadamente, para não
divergir do renderizador. A justificativa é boa, mas o efeito é que **o
`SpacingModel` configurado não vale dentro de quiáltera** — e o piso
`minimumSlotSpaces = 1,4` faz **10 dos 15 `DurationType`** (de 1/16 a 1/2048)
receberem exatamente o mesmo slot [A]. A "lei proporcional" satura mais cedo do
que a lei do fluxo externo.

De onde veio o `1,4`? Do dartdoc: "just above a black notehead (1.18 staff
spaces in Bravura)". É um número escolhido para não flatten os valores curtos —
e é **menor que qualquer acidente** (♮ 0,672 + 0,3; ♯ 0,996 + 0,3; ♭♭ 1,652 + 0,3).

---

## 8. SMuFL / BRAVURA

**Nota: 7/10** (era 7,5). **Desceu.**

**Verificado [A]:** larguras de acidente vêm de `glyphAdvanceWidths`; nenhum
literal `'Bravura'` nos renderizadores (a família é
`packages/flutter_notemus/Bravura` via `SmuflFontDescriptor`); `stemThickness`,
`beamThickness` (no caminho cross-staff) e `legerLine*` lidos de
`engravingDefaults`; codepoints via `getCodepoint`.

**Não-conformidades medidas:**

| Item | Bravura diz | O código usa |
|---|---|---|
| `beamThickness` | 0,5 | **0,40** (`BeamRenderer`) / 0,50 (`TupletRenderer`) |
| `beamSpacing` | 0,25 | **0,60** (`BeamRenderer`) / 0,25 (`TupletRenderer`) |
| `noteheadWhole` | 1,688 | 1,18 no layout |
| `noteheadDoubleWhole` | 2,396 | 1,18 no layout |
| `restWhole/restQuarter` | 1,132 / 1,08 | 1,5 fixo para toda pausa |
| `textFontFamily` | `[Academico, Century Schoolbook, Edwin, serif]` | usado literalmente — e nenhuma das faces é empacotada |

O `BeamRenderer` documenta a divergência ("The theoretical SMuFL defaults looked
too heavy on Flutter canvases") — é uma escolha, não um bug. Mas ela **contradiz
o outro desenhador de barras do mesmo pacote** e contradiz a alegação
"SMuFL-compliant" do README.

---

## 9. MUSICXML

**Nota: 5,5/10** (era 5,5).

**Import — verificado [A]:** `score-partwise` e `score-timewise`; `divisions`;
`<backup>`/`<forward>` → `MultiVoiceMeasure`; `<voice>`; beams; ties; slurs;
articulações; dinâmicas; lyrics; `<clef-octave-change>`; `<transpose>` (incluindo
`<octave-change>` e `<double/>`); `<part-name>`/`<part-abbreviation>`;
`<part-group>`; `<staff-lines>`; `<sound tempo>`; `<unpitched>` (como nota
afinada); `<grace>`; validação de `<pitch>` com 4 mensagens de erro úteis.

**Perdas medidas na importação:**

- **`<time-modification>` é ignorado quando não há `<notations><tuplet>`.**
  Três semínimas de tercina (`duration=4`, `divisions=6`) importam como
  **semínimas inteiras**: o compasso passa a valer 1,0 em vez de 0,75 e o MIDI
  toca 960 ticks em vez de 640 [A]. **Corrupção semântica silenciosa.**
- `<cue/>` vira nota normal.
- `<unpitched>` vira nota afinada e sai como `<pitch>`.
- `score-timewise` perde `<part-name>` [A].

**Export — round-trip medido:**

```
IN  [CLtreble K-3 M4/4 Dmf T3:2{C4,D4,E4} NF4/quarter.1 tstart a staccato,accent LAl  C{C5,E5,G5}/quarter][NF4/whole]
OUT [CLtreble K-3 M4/4 Dmf NC4/8th NC4… (a quiáltera virou 3 colcheias soltas)  …]
valor do compasso: 0,5 → 0,625
```

- **O exportador emite `<time-modification>` mas NÃO emite
  `<notations><tuplet type="start"/>`.** Como o próprio importador precisa da
  notação `<tuplet>` para abrir o grupo, **o round-trip destrói toda quiáltera e
  altera a duração do compasso** [A].
- `<group-abbreviation>` não é emitido; `bracket: none` vira `bracket` na volta.
- `<unpitched>` é reescrito como `<pitch>`.

**Classificação do round-trip: LOSSY, com corrupção.** Não é "mostly lossless":
uma quiáltera não é apenas perdida, ela **muda a aritmética do compasso**.

---

## 10. MEI

**Nota: 6/10** (era 6,5). **Desceu.**

| Módulo | MODEL | PARSED | RENDERED | EXPORTED | ROUND-TRIP |
|---|---|---|---|---|---|
| CMN núcleo (note/rest/chord/layer/staff) | ✅ | ✅ | ✅ | ❌ | ❌ |
| `<section>` (inclusive aninhadas) | ✅ | ✅ | ✅ | ❌ | ❌ |
| `scoreDef`/`staffDef` (`lines`, `clef.*`, `key.sig`, `@mode`, `meter.*`) | ✅ | ✅ | ✅ | ❌ | ❌ |
| Métrica aditiva `meter.count="3+2+2"` | ✅ | ✅ | ✅ | ❌ | ❌ |
| `clef.shape="TAB"` | ✅ | ✅ | ✅ | ❌ | ❌ |
| **`clef.dis` / `clef.dis.place`** | ✅ | ❌ | ❌ | ❌ | ❌ |
| **`trans.semi` / `trans.diat`** | ✅ | ❌ | ❌ | ❌ | ❌ |
| `<staffGrp @symbol>` | ✅ | ✅ | ✅ | ❌ | ❌ |
| **`<staffGrp><label>`** | ✅ | ❌ | ❌ | ❌ | ❌ |
| `meiHead` (fileDesc/titleStmt/respStmt) | ✅ | ✅ | n/a | ❌ | ❌ |
| `@tab.fret`/`@tab.string` | ✅ | ✅ | ✅ | ❌ | ❌ |
| `<ending>` → `VoltaBracket` | ✅ | ✅ | ✅ | ❌ | ❌ |
| Mensural, `<neume>`, figured bass | ✅ | ❌ | ❌ | ❌ | ❌ |

**Achado crítico:** `_meiNote` devolve `null` quando falta `@pname` **ou** `@oct`
— e o chamador simplesmente não adiciona nada. Medido: `<note pname="c" dur="4"/>`
sem `@oct` produz um **compasso vazio, sem exceção e sem aviso** [A]. O dartdoc
documenta isso como um "GAP" para notas de tablatura pura, mas a regra vale para
**qualquer** nota malformada. É o caso simétrico do N-25, que foi corrigido só do
lado MusicXML.

**Não existe exportador MEI** — confirmado por leitura completa de
`lib/src/parsers/`. O README diz isso explicitamente e está certo.

---

## 11. MIDI / PLAYBACK

**Nota: 8/10** (era 8).

**Exato ao tick, verificado [A]:**

- Ligadura: duas semínimas C4 ligadas → `On60@0, Off60@1920` (uma nota, 2×960).
- Quiáltera: tercina de colcheias → 320 ticks cada (960/3), exato.
- Total de compasso: 3840 ticks para 4/4 a 960 PPQ.
- Transposição de instrumento: clarinete Si♭ → 58; `<double/>` + `octave-change`
  → 27 (−9 −12 −12), correto pela especificação.
- Oitava de clave **não** é aplicada (ADR-003): 60 nas seis claves testadas.
- Polifonia: vozes simultâneas em `72@0, 60@0, 74@960, 62@960`.
- Fórmula de compasso: `3/4@0` e `5/8@2880` no conductor.
- **Apagiaturas: corretas.** `74@0, 76@0, 72@0, 74@960, …`, total 3840 [A] —
  o MIDI acerta exatamente o que o layout erra.
- Arquivo `.mid` válido: `MThd`, 2 faixas, 1 meta de tempo, 1 meta de compasso.

**Defeitos:**

- **Dois eventos de tempo no tick 0** quando há `TempoMark`: `bpm 120` (default)
  seguido de `bpm 92` (real) [A]. Players que honram o primeiro tocam no tempo
  errado.
- `_activeClef` é escrito e nunca lido (`// ignore: unused_field`) — estado morto
  desde a ADR-003. **É dívida, não preparação:** a justificativa no dartdoc
  ("percussion mapping and staff-line-addressed instruments need clef context")
  descreve um recurso que não existe.
- **Playback nativo em 1 de 6 plataformas** (documentado no README).
- `<unpitched>` toca como nota afinada.

---

## 12. GREGORIAN

**Nota: 8/10** (era 8).

**Verificado [A]:** `GabcParser.parse` de uma frase real com clave, neumas,
liquescência, episema e duas divisiones → **12 elementos, 0 não suportados**,
clave `c4`; `ChantMidiMapper.fromChant` produz sequência; alturas corretas
(`A(f)` → F3, `ve(g)` → G3).

**Continua um pipeline apartado, e o ADR-003 não o alcança:**

- O canto usa `ChantClef`, `Neume`, `NeumeComponent.pitchName/octave` — **não**
  `Clef`, `Pitch` nem `StaffPositionCalculator` [A/B]. A "altura soante" do
  ADR-003 é uma convenção que o gregoriano nunca implementou nem precisou.
- Identidade, onset, hit-test, `PositionedElement` e o export PDF do CMN **não
  alcançam o canto**.
- A calibração vertical contra `greciliae_glyphnames.json` continua medida
  (não reverifiquei o número 158,0 desta vez; a rodada anterior o mediu).

**Consequência:** o gregoriano é excelente no que faz e **invisível** para toda a
infraestrutura que a 2.7.0/2.7.1 construíram. Qualquer editor terá de tratá-lo
como um segundo produto.

---

## 13. POLYPHONY / MULTI-STAFF

**Nota: 5,5/10** (era 5).

**Verificado [A]:**

- `MultiVoiceMeasure.elements` chegam ao layout, com bloco de abertura canônico.
- Vozes sobrevivem a 10 quebras de sistema.
- Uníssono entre vozes: coincidente com durações iguais, deslocado exatamente
  uma cabeça (14,16 px) com durações diferentes.
- Grade de tempo compartilhada: onsets 0,000 e 0,500 caem em X 83,2 e 194,9 nas
  duas pautas de um grand staff.
- Quiáltera re-ancorada depois do alinhamento (X internos batem com a pauta de
  baixo).
- Orquestra 100×100 constrói em **423 ms** [A].

**Falhas medidas:**

- **[R-01] Clave no meio de compasso dentro de uma voz**: `_systemStaff` varre
  `measure.elements`, nunca `allElements`. Resultado medido: sistema 2 abre
  **sem clave nenhuma** (`bass@142` no meio), e sistemas 3, 4 e 5 restatam
  **`treble`** quando a clave vigente é `bass` [A].
- **[R-27] `staffBaselineY` é local à pauta**: num grand staff de duas pautas,
  **as duas** reportam 60,0 [A], contra o dartdoc.
- **[R-21] `crossStaffMove` só funciona em grupos com barra.** Uma semínima com
  `crossStaffMove: 1` é desenhada na pauta de origem [A]. E mesmo nos grupos com
  barra, `alignedSystem()` e o hit-test continuam reportando a pauta de origem.
  `_clefOf(target)` usa a **primeira** clave da pauta de destino, ignorando
  mudanças.
- Vozes 3+ continuam interpoladas sobre a voz 1; a colisão trata o caso de duas
  vozes.

---

## 14. FLUTTER ARCHITECTURE

**Nota: 4,5/10** (era 4,5).

- **Layout continua no construtor do `CustomPainter`.** `GrandStaffPainter`
  constrói todos os sistemas em `_systems` no construtor. 100 pautas × 100
  compassos = **423 ms na UI thread** [A] = ~25 frames perdidos.
- **Zero isolates.** Nenhuma ocorrência de `Isolate` em `lib/`.
- `shouldRepaint` usa assinatura estrutural e é determinístico (5 layouts →
  1 assinatura distinta [A]).
- `LruCache` para largura de texto medida por `TextPainter` — correto e
  compartilhado entre layout e renderização.
- `TextPainter.dispose()` é chamado. Sem vazamento aparente.
- **Dependência de tema para texto:** o caminho headless (`ScoreRasterizer`,
  `PdfExporter`) depende de faces que o pacote não empacota.

---

## 15. PERFORMANCE

**Nota: 6/10** (era 4). **A maior subida da release.**

Medições com aquecimento (3 execuções de 200 compassos antes):

| Compassos | ms | razão vs anterior |
|---:|---:|---:|
| 400 | 94,5 | — |
| 800 | 149,3 | 1,58 |
| 1.600 | 169,7 | 1,14 |
| 3.200 | 202,6 | 1,19 |
| 6.400 | **285,0** | 1,41 |
| 12.800 | **588,7** | 2,07 |

**Linear.** O quadrático da 2.7.0 (6.400 = 5.991 ms) desapareceu.

Grand staff (2 pautas):

| Compassos | sistemas | ms |
|---:|---:|---:|
| 50 | 17 | 16,2 |
| 100 | 34 | 22,4 |
| 200 | 67 | 32,0 |
| 400 | 134 | 52,3 |
| 800 | 267 | 120,6 |

Também linear. **Orquestra 100 pautas × 100 compassos: 423 ms**, tudo no
construtor, na UI thread.

**Complexidade estimada e confirmada:** `LayoutEngine.layout()` é O(n) em
elementos; `GrandStaffPainter` é O(pautas × compassos) mais um `LayoutEngine`
extra por pauta para `_measureWidths`. Não medi regressão de memória.

**O teste N-04 da rodada 2.7.1 usa `lessThan(10.0)` sobre uma razão de tempo.**
Isso não é medição: uma razão de 10 por duplicação é pior que O(n³). A
propriedade "linear" não é testável com essa tolerância — é ruído de máquina
travestido de invariante.

---

## 16. TESTES — e o que os novos testes NÃO testam

**Nota: 7/10** (era 7).

`flutter test` → **821 testes, 0 falhas, 31 s** [A]. Suíte real, com invariantes
de propriedade, fuzz de parser e uma suíte auto-adversarial.

### `test/invariants/remediation_2_7_1_test.dart` — leitura asserção a asserção

Trinta testes, um por achado citado. **O que eles não testam:**

| Teste | Testa | Não testa |
|---|---|---|
| N-11 | import 3♭ 4/4 | ordem quando há **duas** claves na abertura |
| N-01 | 1 compasso sobrecheio no 5º | compasso sobrecheio **polifônico**; clave no meio no início do sistema |
| N-02 | `autoBeaming:false` | que o **restatement** ache a clave vigente dentro de uma voz |
| N-05/F-27 | ♭♭ **alternado** com ♮ | dois ♭♭ **em graus conjuntos** (que colapsam por resolução, não por espaço) e **acidente dentro de quiáltera** |
| N-07 | semínima+colcheia, colcheia+2×16ª | 16ª, 32ª … 1/2048 (todas idênticas); acidente; ponto; acorde; **legibilidade** |
| N-08 | níveis fora da quiáltera | níveis **dentro** da quiáltera (o caso que o achado citava) |
| N-10 | tabela de inclinação | **comprimento de haste resultante** — o próprio enunciado do achado pedia |
| N-21 | 4/4 | 4/8, 2/8, 13/8, 16/8, x/16 (11 métricas sem barra nenhuma) |
| N-31 | 5/4, 7/4, 11/8 | as métricas em que a soma fecha mas cada tempo cabe **uma** nota |
| N-13 | Si♭ → 58 | MEI `trans.semi` |
| N-15 | `clef-octave-change` MusicXML | MEI `clef.dis`; gregoriano; Jianpu |
| N-19 | acidente + acorde agudo | **haste** (erro medido: 70,8 px) |
| N-23/24 | nomes e round-trip JSON de conteúdo | `Staff.name/abbr/lineCount/transposition` no JSON; duplicação do bloco no JSON |
| N-25 | MusicXML | **MEI** — que o próprio enunciado pedia ("e MEI equivalente") |
| N-04 | razão < 10,0 | qualquer coisa. `lessThan(10.0)` não distingue linear de cúbico |

**Não existe teste algum** para: N-16 (fontes), N-17 (lead-in), N-18 (PDF grand
staff), N-20 (`staffBaselineY`), N-26 (TAB), N-28 (dry-run), N-07b (grade única),
`scoreToMusicXML`, ADR-004 na rota `MultiVoiceMeasure`.

### Tolerâncias frouxas em `test/invariants/`

`lessThan(10.0)` sobre razão de tempo (N-04) é a pior. As demais `closeTo` que
li usam tolerâncias de 0,5–1,0 px sobre grandezas de dezenas de px — aceitáveis.

### Goldens

53 arquivos, 16 regravados nesta rodada. Abri **os quatro mais diagnósticos em
resolução ampliada** e comparei com `git show cab8048^`:

- `m04_triplets`: **melhor**. A inclinação de Gould aparece; antes as barras eram
  praticamente horizontais.
- `m04m_tuplet_ratio`: **pior, e é uma regressão congelada.** As cinco
  semicolcheias 5:4 passaram de 2,5 SS para 1,4 SS de passo; as cabeças em graus
  conjuntos ficam a 0,22 SS uma da outra e **se fundem visualmente**; a pilha de
  barras encosta nas cabeças.
- `c02_chromatic_chords`, `s01_c_major_scale`: sem regressão visível.

**Sobre a retirada de N-27 pela rodada anterior:** confirmo que procede. O
código calcula uma reta e interpola os dois segmentos e os dois ganchos com o
mesmo `yAt(x)`. O que se lê como degrau em baixa resolução é o vão do número.

---

## 17. SEGURANÇA

**Nota: 7,5/10** (era 7,5). Nada mudou e nada quebrou.

Reverifiquei por execução [A]:

- **XXE:** `<!ENTITY xxe SYSTEM "file:///etc/passwd">` → a entidade **não é
  expandida**; o texto sai literal `&xxe;`. Sem leitura de arquivo.
- **Billion laughs** (8 níveis, fator 10 = 10⁸): parseado em **1 ms**, resultado
  de 4 caracteres. Sem expansão exponencial.
- **Entrada malformada:** `FormatException` de domínio em 4 casos MusicXML.
  **Exceto MEI**, onde a nota some em silêncio — é um problema de integridade de
  dados, não de segurança.
- **Path traversal:** os parsers recebem `String`, não caminhos. `PdfExporter` e
  `ScoreRasterizer` não abrem arquivos.
- **Desserialização:** JSON via `jsonDecode` com validação de tipo por campo.
- **Segredos:** nenhum literal suspeito em `lib/`.
- **Dependências:** `xml`, `pdf`, `printing`, `collection` — todas de primeira
  linha; 19 com versões novas disponíveis fora do constraint.

---

## 18. API PÚBLICA

**Nota: 5/10** (era 5).

**Boa:** `LayoutEngine.noteXPositions/noteYPositions/noteStaffPositions`,
`elementWidth`, `elementLeftExtent`, `accidentalDecisions`, `contentWidth`,
`contentTopOverflow`, `ScoreHitTester` com `ScoreHit`/`ScoreSelection`,
`PositionedElement` com onset/measure/voice/system/baseline.

**Problemas:**

- `Duration` do pacote **sombreia `dart:core.Duration`**. Qualquer teste ou app
  que faça `Timeout(Duration(minutes: 1))` ou `Future.delayed(Duration(...))`
  depois de importar o pacote **não compila**. Bati nisso duas vezes escrevendo
  as sondas. É a pior armadilha de ergonomia da API pública.
- `PdfExporter` e `ScoreRasterizer` continuam fora do barrel — só acessíveis por
  `package:flutter_notemus/src/...`.
- `Note.beam` mutável, escrito pelo motor, é contrato público.
- `MeasureValidator`, `TupletGrid`, `BeamRenderer`, `SMuFLPositioningEngine` são
  `src/` mas necessários para qualquer verificação séria.
- `PositionedElement.staffBaselineY` tem dartdoc que não corresponde ao
  comportamento em grand staff.

---

## 19. DÍVIDA TÉCNICA

| Categoria | Itens |
|---|---|
| **Duplicação de pipeline** | 4 caminhos de layout; 2 desenhadores de barra com geometrias diferentes; 2 caminhos de raster que discordam da largura |
| **Modelo mutado pelo layout** | `Note.beam` escrito inclusive no dry-run |
| **Identidade** | mapas por identidade colapsam instâncias repetidas (3→1) |
| **Estado morto** | `MidiMapper._activeClef` (`// ignore: unused_field`) |
| **Comentários obsoletos** | "GAP: `scoreFromMei` não é alcançável" (é); README linha 170 vs 104 |
| **ADR desatualizado** | ADR-003 sobre `<double/>` |
| **Números mágicos** | ver tabela abaixo |
| **Idioma misto no código** | `parser_support.dart` e `staff_position_calculator.dart` têm dartdoc meio traduzido ("Calculatora unificada de staff positions", "Data reference by type de clef") |

### Números mágicos com origem rastreada

| Valor | Local | Função | Por quê existe | Justificável? | Deveria vir de metadado? |
|---|---|---|---|---|---|
| `1.4` | `TupletGrid.minimumSlotSpaces` | piso de slot | "just above a black notehead" | **Não** — ignora acidente, ponto, acorde | Sim: `noteheadBlack` + maior acidente do slot |
| `2.5` | `TupletGrid.quarterSlotSpaces` | slot da semínima | "keep the old flat grid so goldens don't move" | Circular | Deveria vir do `SpacingModel` |
| `6.0` | `calculateChordStemLength` clamp | teto de haste | nenhuma justificativa no código | **Não** — quebra o acorde | Não; deveria ser `span + 3,5` sem teto |
| `3.5` | `_stemLengthSpaces` (hit-test) | caixa | Behind Bars p.13 | Sim como base, **não** como caixa | Deveria chamar `calculateStemLength` |
| `0.4 / 0.60` | `BeamRenderer` | espessura/vão | "SMuFL defaults looked too heavy" | Escolha declarada, mas **contradiz o outro desenhador** | Sim: `engravingDefaults` |
| `0.5 / 0.25` | `TupletRenderer` | espessura/vão | hardcoded | Coincide com Bravura por acaso | Sim |
| `head * 0.9` | `_minimumInterNoteGap` | ar mínimo | herdado | Aceitável — a folga medida é positiva | Não |
| `0.3` / `0.5` | `_leftExtent` | vão acidente↔cabeça | "SMuFL advises 0.25–0.3" | Sim | Parcialmente |
| `1.5` | largura de pausa | reserva | herdado | Não — toda pausa igual | Sim |
| `1.18` | fallback de cabeça | reserva | Bravura | Sim como fallback; **não** como largura de semibreve/breve | Sim |
| `0.35` | `minimumSpacingScale` | compressão | herdado | Aceitável | Não |
| `midMeasureCueScale` | clave no meio | 72 % | Gould | Sim | Não |

### Trabalho declarado como NÃO FEITO — confirmado que continua aberto

| Item | Confirmado | Custo estimado |
|---|---|---|
| `Tuplet` opaco no fluxo | ✅ [A] `TupletRenderer` tem grade, barras e acidentes próprios | **Alto** (2–3 semanas) — é a refatoração-mãe |
| Sem comprimento máximo de haste / quebra por âmbito | ✅ [A] 10,85 SS medido | Médio (3–5 dias) |
| `Note.beam` mutável | ✅ [A] escrito no dry-run também | Alto (toca layout, beaming e testes) |
| Mapas por identidade colapsam | ✅ [A] 3 instâncias → 1 entrada | Médio (chave composta ou `IdentityMap` por ocorrência) |
| Sem exportador MEI | ✅ [B] | Alto (2 semanas) |
| `<unpitched>` vira nota afinada | ✅ [A] | Baixo (1–2 dias) |
| `Transposition.diatonic` sem uso | ✅ [B] | Médio (respelling correto) |
| Layout no construtor, zero isolates | ✅ [A] 423 ms | Alto |
| Playback nativo 1/6 | ✅ (README) | Muito alto |
| Gregoriano à parte | ✅ [A] | Muito alto |
| Cue notes, ossia, números de página, notas coloridas, partes vinculadas | ✅ | Médio cada |

---

## 20. TOP 10 PROBLEMAS

| # | ID | Sev | Problema | Impacto |
|---|---|---|---|---|
| 1 | **R-01** | P1 | Clave no meio de compasso polifônico não alcança o restatement de sistema | Todo sistema quebrado seguinte desenha a clave errada; alturas erradas em silêncio |
| 2 | **R-03** | P1 | `<time-modification>` ignorado sem `<tuplet>` | Quiálteras de arquivos de terceiros importam com duração errada; MIDI 33 % longo |
| 3 | **R-04** | P1 | Apagiaturas consomem tempo musical no layout | Quebra a grade compartilhada do ADR-002; valor de compasso errado |
| 4 | **R-05** | P1 | Haste de acorde presa em 6,0 SS | Acordes largos com haste destacada das cabeças |
| 5 | **R-02** | P1 | Round-trip MusicXML destrói quiálteras | Compasso muda de duração ao exportar e reimportar |
| 6 | **R-06** | P1 | MEI descarta nota sem `@oct` em silêncio | Perda de música sem erro |
| 7 | **R-07/R-08** | P2 | Acidentes em quiáltera: colisão de −20,8 px e decisões do resolvedor ignoradas | Ilegível e musicalmente errado |
| 8 | **R-09** | P2 | 11 métricas perdem toda a barra de ligação | 4/8, 13/8, x/16 saem com bandeirolas soltas |
| 9 | **R-12/R-13** | P2 | PDF/raster de grand staff corta a música | ~60 % perdido numa página A4 |
| 10 | **R-10** | P2 | Regressão de legibilidade da grade de quiáltera congelada em golden | O golden protege o defeito |

### Achados no formato completo — os cinco P1

```
ID:                     R-01
SEVERIDADE:             P1 crítico
EVIDÊNCIA:              A
ARQUIVO:                lib/src/rendering/grand_staff_painter.dart
LINHA:                  160-166 (_systemStaff), 202-204 (_restated)
COMPONENTE:             GrandStaffPainter — restatement de clave/armadura
PROBLEMA:               O varredor de clave vigente lê `measure.elements`; num
                        MultiVoiceMeasure as mudanças no meio do compasso vivem
                        DENTRO da voz (por decisão do ADR-004).
COMPORTAMENTO ATUAL:    10 compassos polifônicos, clave→bass no meio do 3º, a
                        400 px: sys2 abre SEM clave (bass@142 no meio);
                        sys3, sys4 e sys5 restatam `treble@30`. [A]
COMPORTAMENTO ESPERADO: sys3+ devem restatar `bass`.
IMPACTO:                Toda nota a partir do sistema seguinte é desenhada uma
                        décima segunda fora. Silencioso.
CAUSA RAIZ:             `_systemStaff` usa `.elements` e não `.allElements`.
POR QUE O BUG EXISTE:   ADR-004 moveu as mudanças de meio de compasso para
                        dentro das vozes e nenhum consumidor foi reauditado.
COMO REPRODUZIR:        probe/p14_final_test.dart :: P14.1
COMO CORRIGIR:          `_systemStaff` deve varrer `allElements` na ordem
                        musical. Estrutural: extrair um `ClefTracker` único que
                        o layout, o restatement e o `MidiMapper` compartilhem —
                        hoje existem três varreduras de clave independentes.
RISCO DA CORREÇÃO:      Baixo. Muda só a escolha da clave restatada.
TESTE NECESSÁRIO:       Invariante: "para todo sistema s>0, a clave restatada é a
                        última clave em ordem musical antes do 1º compasso de s",
                        varrendo Measure e MultiVoiceMeasure.
```

```
ID:                     R-03
SEVERIDADE:             P1 crítico
EVIDÊNCIA:              A
ARQUIVO:                lib/src/parsers/parser_support.dart
LINHA:                  ~1700 (importador MusicXML de nota)
COMPONENTE:             MusicXML import
PROBLEMA:               `<time-modification>` só é honrado quando existe
                        `<notations><tuplet>`; sozinho, é descartado, e `<type>`
                        vence `<duration>`.
COMPORTAMENTO ATUAL:    3 semínimas com duration=4/divisions=6 e
                        time-modification 3:2 → 3 semínimas inteiras.
                        currentMusicalValue = 1.0 (esperado 0.75);
                        MIDI 960 ticks cada (esperado 640). [A]
COMPORTAMENTO ESPERADO: Um Tuplet 3:2, ou pelo menos durações de 640 ticks.
IMPACTO:                Corrupção semântica: a música importada não é a música
                        do arquivo. Afeta qualquer exportador que emita
                        time-modification sem a notação tuplet.
CAUSA RAIZ:             O construtor de quiáltera é dirigido pela NOTAÇÃO e não
                        pela MODIFICAÇÃO DE TEMPO. Não há passo de normalização
                        que reconcilie `<duration>` com `<type>`.
POR QUE O BUG EXISTE:   O importador foi construído caso a caso a partir de
                        arquivos que traziam os dois elementos.
COMO REPRODUZIR:        probe/p14_final_test.dart :: P14.2
COMO CORRIGIR:          Estrutural: introduzir uma etapa NORMALIZATION entre
                        parser e modelo que valide `sum(duration) == divisions ×
                        beats` e reconcilie type × time-modification × duration.
                        Abrir Tuplet por `<time-modification>` e usar `<tuplet>`
                        apenas para o colchete.
RISCO DA CORREÇÃO:      Médio. Muda a importação de arquivos existentes.
TESTE NECESSÁRIO:       Propriedade: para todo import, `sum(duration)` do XML ==
                        `currentMusicalValue × divisions × 4`.
```

```
ID:                     R-04
SEVERIDADE:             P1 crítico
EVIDÊNCIA:              A
ARQUIVO:                lib/core/measure.dart (musicalValueOf),
                        lib/src/layout/layout_engine.dart (_getRhythmicValue)
COMPONENTE:             Modelo de tempo / layout
PROBLEMA:               `Note.isGraceNote` não é excluído do cálculo de valor
                        rítmico nem do avanço de onset.
COMPORTAMENTO ATUAL:    4/4 com 4 semínimas + 2 apagiaturas:
                        currentMusicalValue = 1.1875;
                        onsets = [0.0000, 0.1250, 0.1875, 0.4375, 0.6875, 0.9375]
                        (as 4 notas reais deviam estar em 0, .25, .5, .75). [A]
                        O MIDI está correto (total 3840 ticks).
COMPORTAMENTO ESPERADO: Apagiatura = duração musical zero.
IMPACTO:                Grade compartilhada do ADR-002 quebrada: num grand staff,
                        a pauta com apagiatura não alinha com nenhuma outra.
                        Validação de capacidade de compasso errada.
CAUSA RAIZ:             `isGraceNote` é uma flag de renderização; nada no
                        caminho de tempo a consulta.
POR QUE O BUG EXISTE:   A grade de onset foi introduzida na 2.7.0 sobre um
                        modelo que já ignorava apagiaturas.
COMO REPRODUZIR:        probe/p16_last_test.dart :: P16.2
COMO CORRIGIR:          `Measure.musicalValueOf` e `_getRhythmicValue` devolvem 0
                        para `isGraceNote`. Estrutural: a apagiatura deve ser
                        posicionada como PRÉ-ANEXO da nota principal, ocupando
                        largura mas não onset.
RISCO DA CORREÇÃO:      Baixo-médio. Muda a largura de compassos com apagiatura.
TESTE NECESSÁRIO:       Invariante: `sum(onsets distintos)` de um compasso ==
                        `currentMusicalValue`, com e sem apagiatura; e num grand
                        staff, duas pautas com/sem apagiatura alinham.
```

```
ID:                     R-05
SEVERIDADE:             P1 crítico
EVIDÊNCIA:              A
ARQUIVO:                lib/src/rendering/smufl_positioning_engine.dart
LINHA:                  362  (`length.clamp(minimumStemLength, 6.0)`)
COMPONENTE:             calculateChordStemLength
PROBLEMA:               Teto absoluto de 6,0 espaços num comprimento que precisa
                        ser >= a extensão do acorde.
COMPORTAMENTO ATUAL:    span=7 meias-posições → precisa 7,00 SS, recebe 6,00.
                        span=14 → precisa 10,50, recebe 6,00.
                        span=21 → precisa 14,00, recebe 6,00.
                        Render de C3+C6: a haste NÃO toca nenhuma das duas
                        cabeças; fica boiando no meio da pauta. [A, imagem]
COMPORTAMENTO ESPERADO: `chordSpan + 3,5`, sem teto (Behind Bars).
IMPACTO:                Acorde de âmbito > ~11ª sai visualmente quebrado. Afeta
                        piano, harpa, guitarra, redução coral.
CAUSA RAIZ:             Clamp copiado da haste de nota única, onde 6,0 é um
                        limite razoável, para a haste de acorde, onde não é.
POR QUE O BUG EXISTE:   Nenhum teste cobre acorde com âmbito > uma oitava.
COMO REPRODUZIR:        probe/p04_beaming_test.dart :: P04.5;
                        probe/p11_visual_test.dart :: P11.3 (imagem)
COMO CORRIGIR:          Remover o teto (`clamp(minimumStemLength, infinity)`).
                        Estrutural: `calculateStemLength` e
                        `calculateChordStemLength` deveriam ser uma função só,
                        que o renderizador E o hit-test chamam (ver R-14).
RISCO DA CORREÇÃO:      Baixo. Só alonga hastes que hoje estão curtas demais.
                        Alguns goldens com acordes largos vão mudar.
TESTE NECESSÁRIO:       Propriedade: para todo acorde, a haste alcança a cabeça
                        oposta (`stemLength × ss >= |yTop − yBottom|`).
```

```
ID:                     R-06
SEVERIDADE:             P1 crítico
EVIDÊNCIA:              A
ARQUIVO:                lib/src/parsers/parser_support.dart
LINHA:                  3678-3684 (_meiNote)
COMPONENTE:             MEI import
PROBLEMA:               `if (rawStep == null || octave == null) return null;` —
                        e o chamador descarta o null sem registrar nada.
COMPORTAMENTO ATUAL:    `<note pname="c" dur="4"/>` sem `@oct` → compasso vazio,
                        sem exceção, sem aviso. [A]
COMPORTAMENTO ESPERADO: `FormatException` como no lado MusicXML (N-25).
IMPACTO:                Perda silenciosa de música num formato de intercâmbio.
CAUSA RAIZ:             O `return null` existe para tolerar nota de tablatura
                        pura; a tolerância vazou para todo caso malformado.
POR QUE O BUG EXISTE:   N-25 foi corrigido no MusicXML e o enunciado do achado
                        ("e MEI equivalente") não foi executado.
COMO REPRODUZIR:        probe/p08_interop_test.dart :: P08.4
COMO CORRIGIR:          Separar os dois casos: nota de tablatura (tem
                        `@tab.fret`) → derivar altura da afinação ou emitir
                        aviso estruturado; nota sem `@pname`/`@oct` e sem
                        `@tab.*` → `FormatException`.
RISCO DA CORREÇÃO:      Baixo.
TESTE NECESSÁRIO:       Fuzz de MEI: nenhum documento pode reduzir a contagem de
                        `<note>` sem lançar ou avisar.
```

---

## 21. MATRIZ DE MATURIDADE (2.7.0 → 2.7.1)

| Área | 2.7.0 | 2.7.1 | Δ | Justificativa da mudança |
|---|---:|---:|---:|---|
| Modelo musical | 7 | **7** | 0 | `Transposition` de primeira classe e `Staff.name/abbr` são ganhos reais; anulados pela descoberta de que **apagiatura consome tempo musical** [A] — um defeito de modelo, não de layout |
| Engraving | 5,5 | **5** | **−0,5** | Gould, níveis por nota e reserva de acidente são ganhos medidos. Mas descobri três defeitos de gravação que a rodada anterior não viu: haste de acorde destacada, acidentes de quiáltera ilegíveis, e o renderizador de quiáltera desobedecendo o resolvedor |
| Layout | 5 | **5,5** | +0,5 | Métrica única, extensões separadas, piso pelo metadado e **linearidade**. Teto por: quiáltera fora do cursor, `contentWidth` somando duas vezes, `previousRhythmic` não resetado |
| SMuFL | 7,5 | **7** | **−0,5** | Larguras de acidente do metadado ✅. Mas o desenhador **principal** de barras contradiz `beamThickness`/`beamSpacing` do próprio metadado e discorda do desenhador de quiáltera; semibreve/breve reservam largura de cabeça preta |
| Bravura | 8 | **8** | 0 | Descritor de fonte continua sólido; nenhum literal de família nos renderizadores |
| MusicXML | 5,5 | **5,5** | 0 | `<transpose>` completo, ordem de abertura, `scoreToMusicXML`, nomes de parte — ganhos grandes. **Zerados** pela descoberta de que quiáltera não sobrevive ao round-trip e `<time-modification>` sozinho é ignorado |
| MEI | 6,5 | **6** | **−0,5** | `clef.shape="TAB"` e a confirmação de que aditivo funciona. Mas **`clef.dis` e `trans.semi` são ignorados** (o ADR-003 não alcança o MEI) e **nota sem `@oct` some em silêncio** |
| JSON | 5 | **6** | +1 | Existe exportador; `syllables`, `crossStaffMove`, `tabFret`, quiáltera, acorde e polifonia sobrevivem [A]. Não sobe mais porque **metadados de pauta são exportados e não relidos** e o **bloco de abertura é duplicado** |
| MIDI | 8 | **8,5** | +0,5 | Transposição de instrumento correta, `<double/>` sonorizado, oitava de clave removida do caminho errado, apagiaturas exatas. Penalizado por dois eventos de tempo no tick 0 |
| Playback | 3,5 | **3,5** | 0 | Nada mudou; continua 1 plataforma de 6 |
| Gregorian | 8 | **8** | 0 | Continua correto e continua um pipeline apartado; o ADR-003 não o alcança |
| Polifonia | 5 | **5,5** | +0,5 | `MultiVoiceMeasure.elements` chegam ao layout, vozes sobrevivem à quebra, uníssono correto. Travado pela clave dentro de voz (R-01) e pelas vozes 3+ interpoladas |
| Multi-staff | 5 | **5** | 0 | Compasso sobrecheio corrigido, quiáltera re-ancorada, grade de onset provada. **Anulado** por R-01 (clave errada em sistema quebrado), `staffBaselineY` local e `crossStaffMove` só em grupos com barra |
| Performance | 4 | **6** | **+2** | O quadrático caiu. 12.800 compassos = 589 ms; grand staff linear; orquestra 100×100 = 423 ms. Não sobe mais: tudo no construtor, na UI thread, sem isolate |
| Arquitetura Flutter | 4,5 | **4,5** | 0 | Nenhuma mudança estrutural: layout no construtor, zero isolates |
| Testes | 7 | **7** | 0 | 821 testes, +30 de regressão com números medidos. Não sobe: **quinze dos trinta testam exatamente o caso citado**, e nove alegações da própria rodada não têm teste nenhum |
| Golden tests | 6,5 | **6** | **−0,5** | 15 dos 16 regravados são melhorias reais. **Um congelou uma regressão** (`m04m_tuplet_ratio`), e é justamente o caso que o `TupletGrid` deveria ter melhorado |
| Segurança | 7,5 | **7,5** | 0 | XXE, billion-laughs e I/O reverificados negativos por execução |
| API pública | 5 | **5** | 0 | Ganhou `elementLeftExtent`, `accidentalDecisions`, `Transposition`. Perde o mesmo tanto: `Duration` continua sombreando `dart:core`, exportadores fora do barrel |
| Documentação | 6 | **6,5** | +0,5 | ADR-003 e ADR-004 são excelentes — explicam o trade-off, não só a decisão. Penalizado por uma contradição interna no README (meiHead), um comentário obsoleto no parser e uma linha errada no ADR-003 |
| Escalabilidade | 3 | **5** | **+2** | Linearidade real: 12.800 compassos e orquestra de 100 pautas construídos sem estourar. Teto: UI thread |
| Prontidão p/ editor | 4,5 | **5** | +0,5 | Hit-test acerta acidente e acorde agudo; `movedTo` preserva campos; identidade estável. Falta: haste (erro de 70,8 px), `staffBaselineY` de grand staff, cursor, inserção, undo |

**Média ponderada informal: ≈ 6,0 / 10** (era 5,8) — *"o motor ficou rápido e a
semântica de altura ficou coerente; a gravação musical não acompanhou."*

---

## 22. TESTES QUE PRECISAM SER CRIADOS

```dart
// I1  Restatement de clave em sistema quebrado — pega R-01
test('a clave restatada é a última em ORDEM MUSICAL, inclusive dentro de voz', () {
  // MultiVoiceMeasure com Clef(bass) na voz 1, meio do compasso 3, 10 compassos
  // Para todo sistema s>0: clefs(s).first == bass
});

// I2  Aritmética de importação — pega R-03
test('sum(<duration>) do XML == currentMusicalValue x divisions x 4', () {
  // propriedade sobre 20 documentos gerados: com/sem <type>, com/sem <tuplet>,
  // com/sem <time-modification>, tercinas, quintinas, aninhadas
});

// I3  Apagiatura tem duração zero — pega R-04
test('onsets são idênticos com e sem apagiaturas', () {
  // e num grand staff, as duas pautas continuam alinhadas
});

// I4  Haste alcança a cabeça oposta — pega R-05
test('para todo acorde, stemLength*ss >= |yTop - yBottom|', () {
  // spans de 0 a 28 meias-posições
});

// I5  MEI não perde nota — pega R-06
test('nenhum documento MEI reduz a contagem de <note> sem lançar', () {
  // fuzz: remover @oct, @pname, @dur, um de cada vez
});

// I6  Folga dentro de quiáltera — pega R-07
test('dentro de quiáltera, gap >= cabeça + acidente do elemento seguinte', () {
  // 15 DurationType x 5 acidentes x ss 6/12/24
});

// I7  Quiáltera obedece o resolvedor — pega R-08
test('accidentalDecisions vale igual dentro e fora de quiáltera', () {
  // rasterizar as duas versões e comparar contagem de glifos de acidente
});

// I8  Toda métrica agrupa — pega R-09/R-42
test('para toda métrica n/d com n<=16 e d em {2,4,8,16}, toda nota beamável '
     'de um compasso exatamente cheio pertence a um grupo, e nenhum grupo '
     'excede um tempo composto', () {});

// I9  Legibilidade de slot — pega R-10
test('o passo mínimo entre cabeças em graus conjuntos >= 1,75 SS', () {});

// I10 Round-trip que preserva a aritmética — pega R-02
test('parse(export(s)).currentMusicalValue == s.currentMusicalValue', () {
  // para 30 compassos gerados com quiálteras, acordes, pontos, ligaduras
});

// I11 JSON round-trip completo — pega R-11/R-20
test('parse(staffToJson(s)) == s em name/abbr/lineCount/transposition e '
     'na CONTAGEM de elementos do bloco de abertura', () {});

// I12 Paginação de PDF — pega R-12
test('PDF de N sistemas tem ceil(N/systemsPerPage) páginas de música e '
     'nenhum sistema é cortado', () {});

// I13 Hit-test == desenho — pega R-14
test('a caixa de qualquer elemento contém a ponta da haste que o renderizador '
     'desenha, chamando a MESMA função de comprimento', () {});

// I14 Geometria de barra única — pega R-15
test('BeamRenderer e TupletRenderer produzem a mesma espessura e o mesmo vão, '
     'ambos lidos de engravingDefaults', () {});

// I15 Largura reservada >= largura desenhada — pega R-16/R-17/R-28
test('para todo elemento, elementWidth >= largura realmente pintada', () {
  // medir por bounding box do raster
});

// I16 Folga de canvas inclui colchete de quiáltera — pega R-22
test('contentTopOverflow/BottomOverflow > 0 quando há colchete fora da pauta', () {});

// I17 Desempenho como PROPRIEDADE, não como razão frouxa
test('t(2n)/t(n) <= 2,6 para n em {800, 1600, 3200, 6400}', () {
  // com aquecimento e mediana de 5 execuções; substitui lessThan(10.0)
});
```

---

## 23. PLANO DE CORREÇÃO

### Fase 0 — emergência (1 semana). Nada sai antes disso.

1. **R-01** — `_systemStaff` varre `allElements` em ordem musical. *(2 h)*
2. **R-05** — remover o clamp `6.0` de `calculateChordStemLength`. *(1 h + regravar goldens)*
3. **R-04** — apagiatura com valor rítmico zero em `musicalValueOf` e `_getRhythmicValue`. *(4 h)*
4. **R-06** — `_meiNote` lança em vez de devolver `null` para nota não-tablatura. *(2 h)*
5. **R-08** — `TupletRenderer` recebe e usa `accidentalDecisions`. *(3 h)*

### Fase 1 — corrupção de dados (2 semanas)

6. **R-03/R-02** — etapa de NORMALIZATION no import: reconciliar `<duration>` ×
   `<type>` × `<time-modification>`; abrir `Tuplet` pela modificação de tempo;
   emitir `<notations><tuplet>` no export. *(1 semana)*
7. **R-11/R-20** — importador JSON: parar de duplicar o bloco de abertura, ler
   `name/abbr/lineCount/transposition`. *(1 dia)*
8. **R-18/R-19** — MEI: `clef.dis`, `clef.dis.place`, `trans.semi`, `trans.diat`,
   `<staffGrp><label>`. *(2 dias)*
9. **R-12/R-13** — paginação do grand staff no PDF (uma banda por página, como o
   caminho de pauta única já faz) e `logicalWidth = max(width, contentWidth)`
   em `renderGroupToPage`. *(2 dias)*

### Fase 2 — unificar a quiáltera (3 semanas) — **a refatoração-mãe**

10. `Tuplet` deixa de ser opaco: um *container de tempo com razão* cujo conteúdo
    passa pelo **mesmo cursor** do resto do compasso. Isso resolve de uma vez:
    R-07 (folga de acidente), R-10 (legibilidade), R-31 (saturação de slot),
    R-15 (geometria de barra), R-40 (acorde/pausa sem barra), R-41 (extensão
    esquerda), R-22 (folga de canvas). **Elimina o terceiro pipeline de layout.**

### Fase 3 — refinamento de gravação (2 semanas)

11. **R-09/R-42** — tabela de subdivisão que garanta tempo composto mínimo de
    2 unidades e trate x/8 e x/16 genericamente.
12. Comprimento máximo de haste + quebra de barra por âmbito (**R-23**).
13. **R-16/R-17** — colunas de acidente e deslocamento de segundas entram na
    largura reservada e em `noteXPositions`.
14. **R-28** — larguras de cabeça por `DurationType` a partir do metadado.
15. **R-15** — `BeamRenderer` lê `engravingDefaults`.

### Fase 4 — interoperabilidade (3 semanas)

16. Exportador MEI.
17. `<unpitched>` como tipo próprio, com round-trip.
18. `Score.toConcertPitch()` usando `Transposition.diatonic`.
19. Cue notes.

### Fase 5 — editor (8+ semanas)

20. **R-14** — hit-test chama as mesmas funções de geometria do renderizador.
21. Sair do construtor do painter; layout incremental por sistema; isolate.
22. Modelo de comando + undo/redo; cursor; inserção.
23. Chave de posição por *ocorrência* (não por identidade de `Note`).

---

## 24. ARQUITETURA RECOMENDADA

```
          INPUT (MusicXML | MEI | JSON | GABC)
                        │
                        ▼
        ┌───────────────────────────────────┐
        │  PARSER  — fiel à fonte, sem juízo │
        │  emite eventos + diagnósticos      │
        └───────────────┬───────────────────┘
                        ▼
        ┌───────────────────────────────────┐
        │  NORMALIZATION  ← NÃO EXISTE HOJE  │
        │  reconcilia duration × type ×      │
        │  time-modification; valida a       │
        │  aritmética do compasso; converte  │
        │  unpitched, cue, grace; devolve    │
        │  uma lista de perdas EXPLÍCITA     │
        └───────────────┬───────────────────┘
                        ▼
        ┌───────────────────────────────────┐
        │  MODELO IMUTÁVEL                   │
        │  Tuplet = container de tempo       │
        │  grace = duração zero              │
        │  Note.beam volta a ser `final`     │
        └───────────────┬───────────────────┘
                        ▼
        ┌───────────────────────────────────┐
        │  LAYOUT — UM cursor, um só         │
        │  quiáltera passa pelo mesmo cursor │
        │  onset é a única coordenada de     │
        │  tempo; beams saem em LayoutResult │
        └───────────────┬───────────────────┘
                        ▼
        ┌───────────────────────────────────┐
        │  ENGRAVING                         │
        │  Gould como TABELA DE DADOS        │
        │  cada elemento emite sua           │
        │  BoundingBox real → alimenta       │
        │  colisão, hit-test, skyline e      │
        │  folga de canvas de UMA fonte      │
        └────┬──────────────────────┬───────┘
             ▼                      ▼
     ┌───────────────┐      ┌──────────────────┐
     │ CANVAS RENDER │      │ RASTER/PDF       │
     │ (widget)      │      │ (MESMO código)   │
     └───────────────┘      └──────────────────┘
```

Três mudanças carregam quase todo o valor — e são as **mesmas três** que a
rodada anterior recomendou, com uma adicionada:

1. **`Tuplet` deixa de ser opaco.** Elimina sete achados desta rodada de uma vez.
   É a maior alavanca isolada do projeto.
2. **Cada renderizador emite a `BoundingBox` do que desenhou.** Hoje existem
   quatro estimativas independentes de "quanto isto ocupa" (layout, hit-test,
   colisão, folga de canvas) e elas discordam em 6 pontos medidos.
3. **`LayoutResult` passa a ser o único dono da informação de layout.**
   `Note.beam` volta a ser `final`.
4. **NOVO: uma etapa de NORMALIZATION entre parser e modelo.** Ela não existe, e
   a sua ausência é a causa-raiz de R-02, R-03, R-04 e R-06 — quatro dos seis
   P1 desta rodada. Um parser fiel + um normalizador que *valida a aritmética*
   e *declara as perdas* é o que separa "importa" de "importa corretamente".

---

## 25. VEREDITO FINAL

**1. O engine está realmente pronto para produção?**
Como **visualizador** de partituras de origem confiável, em Android/desktop, até
~12.000 compassos: **sim, com três ressalvas bloqueantes** — R-01 (clave errada
em sistema quebrado com polifonia), R-03 (quiálteras importadas com duração
errada) e R-04 (apagiaturas desalinhando o grand staff). Como **editor**: não.

**2. O engraving é profissional?**
**Não.** As regras estruturais estão certas e medidas. O que reprova é a camada
de refinamento e, agora, três defeitos que um gravador enxerga na primeira
página: haste de acorde que não toca as cabeças, acidentes ilegíveis dentro de
quiáltera, e acidentes que aparecem dentro da quiáltera e desaparecem fora.
Um músico lê a maior parte da saída; um gravador reprova.

**3. O modelo musical é sólido?**
**Sim, com duas rachaduras.** A cobertura é boa e a precisão de `Duration`,
`Pitch` e `Tuplet` é exata ao tick. As rachaduras são: apagiatura com duração
não-zero (que corrompe o tempo) e `Note.beam` mutável escrito pelo motor
(inclusive na passada de medição).

**4. MusicXML é confiável?**
**Para leitura de alturas e ritmos simples, sim. Para quiálteras, não. Para
round-trip, não.** A ordem de gravação foi corrigida e é o ganho visível da
release. Mas `<time-modification>` sozinho é ignorado e o exportador não emite
`<tuplet>`, então **exportar e reimportar muda a duração do compasso**.

**5. MEI é realmente suportado?**
**Na importação de CMN, sim — e regrediu em confiança.** `clef.dis`, `trans.semi`
e `<label>` são ignorados, e uma nota malformada **desaparece sem erro**. Sem
exportador, continua sendo um formato de entrada e não de intercâmbio — o README
diz isso e está certo.

**6. MIDI/playback é musicalmente confiável?**
**O MIDI, sim, e melhorou** — transposição de instrumento, `<double/>`, oitava de
clave removida do lugar errado, apagiaturas exatas ao tick. As duas ressalvas
são o tempo duplicado no tick 0 e `<unpitched>` tocando afinado.
**Playback: não** — 1 plataforma de 6, o que o README declara.

**7. O sistema suporta partituras complexas?**

| Cenário | Veredito | Justificativa medida |
|---|---|---|
| **A** Piano 500 compassos | **PASS** | Layout linear; grade de onset provada; grand staff 800 compassos = 120,6 ms [A]. Falha só se houver apagiatura (R-04) ou clave no meio de compasso polifônico (R-01) |
| **B** SATB 300 compassos | **PARTIAL** | Mesmas ressalvas de A, mais vozes 3–4 interpoladas |
| **C** Orquestra 100 instrumentos | **PARTIAL** | 100×100 constrói em **423 ms** [A] — deixou de ser FAIL. Continua na UI thread, sem isolate, sem streaming |
| **D** 4 vozes independentes por pauta | **PARTIAL** | Vozes 3+ posicionadas por interpolação sobre a voz 1; colisão trata duas vozes |
| **E** Lyrics longas | **PASS** | Largura medida por `TextPainter` real, compartilhada entre layout e render |
| **F** MusicXML complexo | **FAIL** | `<backup>`/`<forward>`/sem `<type>`/beams secundários/`<transpose>` ✅, mas **`<time-modification>` sozinho corrompe a duração** [A] |
| **G** Gregoriano extenso | **PASS** | GABC → 12 elementos, 0 não suportados, playback correto [A] |
| **H** repeats + volta + quiálteras + ties + cross-staff | **PARTIAL** | Cada peça isolada funciona e foi medida; cross-staff só honra `crossStaffMove` em grupos com barra [A] |

**8. A arquitetura suporta um editor profissional?**
**A fundação sim; a superfície ainda não.** Identidade estável, hit-test que
acerta acidente e acorde agudo, `movedTo` que não perde campos, seleção por
região/compasso/sistema/voz/onset. Falta: caixa de haste correta (erro medido de
70,8 px), `staffBaselineY` absoluto em grand staff, chave de posição por
ocorrência, modelo de comando, undo/redo, cursor, inserção.

**9. Maiores riscos**
1. **R-01** — clave errada em sistema quebrado: visível para todo usuário de
   piano/coral, e silencioso.
2. **R-03/R-02** — a duração importada não é a duração do arquivo.
3. **R-04** — a grade compartilhada, principal conquista da 2.7.0, quebra na
   presença de apagiaturas.
4. **R-05** — acorde largo desenhado quebrado.
5. **Meta-risco, agravado:** a quiáltera é o terceiro pipeline e concentra
   **sete** achados desta rodada. Toda correção pontual nela vai gerar o próximo
   achado vizinho. Ou ela entra no cursor, ou a próxima auditoria encontra a
   mesma forma de defeito num vizinho diferente.
6. **Meta-risco novo:** o `TupletGrid` mostrou que **uma boa abstração aplicada
   sem uma medida de qualidade produz uma regressão que os goldens congelam.**
   Faltou um invariante de legibilidade antes de trocar a grade.

**10. Ordem correta de correção**
Fase 0 (R-01, R-05, R-04, R-06, R-08) → Fase 1 (NORMALIZATION: R-03/R-02;
JSON: R-11/R-20; MEI: R-18/R-19; PDF: R-12/R-13) → **Fase 2: quiáltera no
cursor** → Fase 3 (métricas, haste, colunas de acidente) → Fase 4 (interop) →
Fase 5 (editor). Ver §23.

**11. A remediação da 2.7.1 foi honesta?**

**Sim.** Verifiquei 33 alegações executando código e **nenhuma é falsa**.
Dezessete são integralmente verdadeiras; quinze são verdadeiras no caso alegado
e incompletas no vizinho; uma regrediu num vizinho. Nenhuma descreve código que
não existe.

Os números do CHANGELOG conferem: 16 goldens regravados (contei), 53 no total
(contei), 313 ms para 6.400 compassos (medi 285 — a alegação é **conservadora**).
Os ADRs descrevem intenções implementadas e — o que é raro — descrevem as
*opções rejeitadas* e o *custo* da escolhida.

Três ressalvas de honestidade:
- **ADR-003 está desatualizado num ponto:** diz que `<transpose><double/>` é
  "recorded and warned about, not sounded". Ele **é** sonorizado e **não** avisa.
  O código está certo e o ADR errado — erro na direção boa, mas é o único caso
  em que um documento desta rodada não corresponde ao código.
- **"PDF exporta grand staff como grand staff"** é meia verdade: a geometria está
  certa e a paginação não existe, então ~60 % da música é cortada.
- **"text no longer rasterises as `.notdef` boxes"** vale quando o host tem uma
  das quatro faces nomeadas — e o pacote não empacota nenhuma.

**12. A rodada 2.7.1 corrigiu erros da auditoria anterior, ou apenas concordou
com ela?**

**Corrigiu de verdade, e as duas retiradas procedem.**

- **NOVO-6 ("estrutura aditiva do MEI é perdida") — retirada correta.** Medi:
  `meter.count="3+2+2"` → `isAdditive=true`, e o agrupamento sai `[3,2,2]`.
  Testei quatro padrões aditivos, todos corretos.
- **N-27 ("colchete de quiáltera com metades não colineares") — retirada
  correta.** `_drawTupletBracket` calcula uma reta e usa o mesmo `yAt(x)` nos dois
  segmentos e nos dois ganchos. Verifiquei o código e reampliei o golden.

Mais: a rodada **encontrou dois achados que a auditoria anterior não tinha visto**
(N-31 e N-32), e o N-32 — a inconsistência do `c8vb` — foi o que **derrubou a
premissa** de que existia uma convenção de altura coerente a preservar. Essa é a
melhor evidência de que o ciclo funciona: uma rodada de remediação que descobre
que o problema é maior do que o auditor tinha diagnosticado, e muda a decisão
arquitetural por causa disso.

**Eu, por minha vez, corrijo a rodada anterior em dois pontos:**

| Item | Correção |
|---|---|
| §4 da 2.7.0: "quatro pipelines de layout, reduzidos a três" | **Falso.** Continuam **quatro**. Compartilhar `TupletGrid` removeu *uma* divergência de quatro (a grade); a quiáltera mantém desenhador de barras próprio, espessura própria e ignora as decisões de acidente |
| §16 da 2.7.0: "os 39 regravados que examinei são melhores, nenhum congelou regressão" | **Verdadeiro para os 39 daquela rodada.** Mas **um dos 16 desta rodada congelou**: `m04m_tuplet_ratio` |

---

## Reprodutibilidade

Todas as medições marcadas **[A]** são reproduzíveis com:

```bash
flutter test probe/
```

| Sonda | Cobre |
|---|---|
| `p01_pitch_adr003_test.dart` | ADR-003 em 21 claves, transposição, MEI, JSON |
| `p02_layout_test.dart` | bloco de abertura, extensões, dry-run, tuplet |
| `p03_accidental_gap_test.dart` | F-27 com decisões reais do resolvedor; quiáltera |
| `p04_beaming_test.dart` | N-08/09/10/21, hastes, acidentes em quiáltera |
| `p05_meters_test.dart` | todas as métricas n/d com preenchimento exato |
| `p06_grandstaff_test.dart` | N-01/02/02b/03/12/20/29, grade de onset |
| `p07_perf_test.dart` / `p15_breadth_test.dart` | N-04 com e sem aquecimento |
| `p08_interop_test.dart` | round-trip MusicXML/JSON, `scoreToMusicXML`, N-25/26 |
| `p09_xmldump_test.dart` | XML/JSON emitidos, gravados em `probe/out_*` |
| `p10_render_test.dart` / `p11_visual_test.dart` | raster, hit-test, PDF, imagens |
| `p12_misc_test.dart` | barras, MIDI, segurança, gregoriano, determinismo |
| `p13_golden_geom_test.dart` | geometria congelada por `m04m_tuplet_ratio` |
| `p14_final_test.dart` | R-01, `<time-modification>`, MEI score, cross-staff |
| `p16_last_test.dart` | apagiaturas, larguras de cabeça, colunas de acidente |
| `p17_font_test.dart` | N-16 com face real registrada |

Imagens julgadas em resolução ampliada: `probe/v_*.png`, `probe/z*.png`,
`probe/cmp_*.png`.
