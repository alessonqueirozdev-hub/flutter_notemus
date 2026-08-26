# SUPERPROMPT — RE-AUDITORIA FORENSE, ADVERSARIAL E DE VERIFICAÇÃO
## flutter_notemus 2.7.1 (pós-remediação da re-auditoria)

> **Como usar:** cole TUDO o que está abaixo da linha em um chat novo, com o
> repositório aberto. Não dê nenhum outro contexto ao auditor. Não diga a ele o
> que foi corrigido — a matriz da Parte B já contém as *alegações*, e o trabalho
> dele é justamente derrubá-las.

---

# PAPEL

Você é um **Principal Engineer + Music Engraving Specialist + Flutter/Dart Architect + MusicXML/MEI Specialist + SMuFL Specialist + MIDI/Music Technology Engineer + QA Engineer + Security Auditor**.

Sua missão tem **duas partes indissociáveis**:

**PARTE A — Auditoria forense completa e independente** do repositório, do zero,
exatamente como se ninguém nunca o tivesse auditado.

**PARTE B — Verificação adversarial de alegações.** Uma re-auditoria da 2.7.0
verificou 38 alegações e catalogou 30 achados novos; a rodada 2.7.1 afirma
tê-los corrigido. Você deve **verificar cada alegação executando código**, e
produzir uma nota de remediação quantificada.

Este é um projeto real e ativo. NÃO faça uma revisão superficial.

---

# 0. REGRAS FUNDAMENTAIS

Trate todo o repositório como potencialmente incorreto até que a **execução** de
código prove o contrário.

NÃO presuma que uma funcionalidade existe porque existe:
classe, enum, método, comentário, dartdoc, README, CHANGELOG, ADR, arquivo em
`doc/`, nome de teste, ou um teste que passa.

**Em especial, nesta rodada:**

1. **NÃO confie em `doc/AUDITORIA_FORENSE_2026-08-22.md`.** É a re-auditoria
   anterior. Ela própria já teve **dois achados retirados por estarem errados**
   (ver o ADENDO no fim do arquivo). Pode conter mais.
2. **NÃO confie em `test/invariants/remediation_2_7_1_test.dart`.** Foi escrito
   pela MESMA rodada que fez as correções. Um teste escrito pelo autor da
   correção pode testar exatamente o caso fácil que ele consertou. **Leia cada
   asserção e pergunte: o que ela NÃO testa?**
3. **NÃO confie nos goldens.** 16 dos 53 foram regravados nesta rodada. Um
   golden regravado documenta o que o renderizador faz, não o que ele deveria
   fazer. Abra as imagens **em resolução ampliada** (a 900 px de largura elas
   enganam — a rodada anterior leu erroneamente "hastes de acorde detachadas" e
   "colchete de quiáltera partido" por olhar em escala 1:1). Julgue-as como
   gravador musical.
4. **NÃO confie nos ADRs** (`doc/adr/`), inclusive os novos ADR-003 e ADR-004.
   Verifique se a intenção foi implementada e se as consequências declaradas são
   reais. O ADR-003 declara uma **mudança semântica quebrante**; confira se ela
   foi aplicada em TODOS os consumidores.
5. **NÃO confie nas notas dos agentes** nem em `CHANGELOG.md`.

Classifique cada capacidade como:
✅ REALMENTE IMPLEMENTADA E VALIDADA · 🟢 IMPLEMENTADA COM RISCOS · 🟡 PARCIAL ·
🟠 SUPERFICIAL · 🔴 INCORRETA · ⚫ MODELADA/PLACEHOLDER · ❌ NÃO IMPLEMENTADA ·
❓ NÃO FOI POSSÍVEL PROVAR

**Níveis de evidência obrigatórios:** **A** = confirmado executando código (sonda
que você escreveu e rodou) · **B** = confirmado lendo o código · **C** =
inferência arquitetural forte · **D** = hipótese.

**NUNCA apresente hipótese como fato.** Se não conseguir provar, escreva
`UNKNOWN` e diga por quê. **Se descobrir que um achado da auditoria anterior
está errado, retire-o explicitamente** — o ciclo só funciona se cada rodada
puder corrigir a anterior.

---

# PARTE A — AUDITORIA COMPLETA

Execute integralmente o escopo abaixo. Nada foi removido em relação às rodadas
anteriores.

## A.1 Reconstrução do sistema

Mapeie: estrutura do projeto, `lib/`, modelos, renderizadores, layout engine,
parsers, exporters, MusicXML, MEI, JSON, MIDI, playback, fontes, SMuFL, Bravura,
Greciliae, widgets, painters, engines, utilitários, exemplos, testes, CI/CD,
documentação, plataforma nativa (Android, iOS, Windows, Linux, macOS, Web) e
dependências externas.

Produza os mapas:

```
INPUT → PARSER → NORMALIZATION → INTERNAL MUSIC MODEL → LAYOUT ENGINE
      → ENGRAVING → RENDERING → DISPLAY
```
```
INTERNAL MODEL → MIDI MAPPING → TIMELINE → PLAYBACK → MIDI EXPORT
```
```
MusicXML / MEI / JSON → PARSERS → NORMALIZED MODEL → SAME RENDERER
```

Diga **onde essa arquitetura realmente existe e onde é apenas conceitual**.
**Conte quantos pipelines de layout independentes existem de fato** — a rodada
anterior contou quatro e reduziu a três; confirme ou refute.

## A.2 Engraving musical

Audite como **especialista em gravação musical profissional**, não como revisor
de software.

**Notas:** posicionamento horizontal e vertical, notehead, stem, stem direction,
stem length, stem attachment, ledger lines, accidentals, spacing, chord spacing,
overlapping, grace notes, cue notes, cross-staff notes. Teste C4, notas extremas
(C0, C8, B10), acordes, intervalos muito próximos e muito largos.

**Accidentals:** sharp, flat, natural, double sharp, double flat, microtonais,
posicionamento, collision avoidance, stacking, spacing, repetidos, cautelares,
editoriais, em acordes, em múltiplas vozes. *O sistema sabe quando um acidente
deve aparecer, ou apenas renderiza o que recebeu?*

**Ritmo e duração:** de `maxima` a 1/2048, pontos, quialteras, quialteras
aninhadas, breve, longa, máxima, aritmética e normalização. Procure erros em
`notation duration → beat duration → ticks → milliseconds → MIDI`.

**Beaming:** automático, manual, agrupamento, direção, **inclinação**, espessura,
espaçamento, barras parciais, pausas dentro de grupos, cross-staff, multi-voz,
quialteras + beams, grace notes, colisão, anexação, posicionamento vertical.
Determine se o algoritmo segue regras musicais reais ou heurísticas geométricas.

**Stems, chords, voices, multi-staff, layout engine, engraving algorítmico,
SMuFL, Bravura, texto e lyrics, slurs e ties, articulações, dinâmicas,
quialteras, claves, armaduras, fórmulas de compasso, barras e repetições** —
cada um com o mesmo rigor. Para cada um, pergunte se existe *semântica musical*
ou apenas desenho.

Perguntas que você **deve** responder com evidência A:
- Todas as pautas compartilham uma verdadeira coordenada temporal, ou cada pauta
  é renderizada independentemente e depois posicionada?
- Existe layout determinístico ou uma coleção de heurísticas e offsets?
- O código é realmente SMuFL-compliant ou apenas Bravura-compatible?
- Uma lyric longa empurra a próxima nota, ou sobrepõe?
- Existe algoritmo de routing de ligaduras ou curvas aproximadas?

## A.3 Interoperabilidade

**MusicXML:** auditoria REAL do parser. Quais elementos são importados,
ignorados, parcialmente interpretados, descartados silenciosamente, convertidos
incorretamente. Cubra `score-partwise`, `score-timewise`, `part-list`,
`part-group`, `attributes`, `divisions`, notes, rests, chords, **backups**,
**forwards**, voices, staff, beams (incl. `number=2,3,4`), tuplets, ties, slurs,
articulations, dynamics, ornaments, lyrics, directions, tempos, repeats,
endings, clefs, keys, meters, **transposition**, instruments,
**percussion/unpitched**, grace notes, **cue notes**.

**Round-trip:** `MusicXML → parser → modelo → export → MusicXML`. Liste **cada
perda** e classifique: lossless / mostly lossless / lossy / severely lossy.
Existe agora `scoreToMusicXML` — teste-o, não só `staffToMusicXML`.

**MEI v5:** compare a especificação com parser, modelo, renderizador e
exportador. Separe: `MODEL ONLY | PARSED | RENDERED | EXPORTED | ROUND-TRIPPABLE`.

**JSON:** existe agora `JsonMusicParser.staffToJson` / `scoreToJson`. Teste o
round-trip de verdade. Schema, nullability, defaults, enums, versionamento,
entrada malformada, campos desconhecidos.

## A.4 MIDI e playback

Pipeline completo. Pitch, duration, velocity, channel, tempo, PPQ, ticks, ties,
tuplets, voices, repeats, volta, grace notes, **transposição**, percussão,
múltiplas partes, múltiplas faixas. Playback: tempo, scheduling, note-off,
polifonia, sincronização, drift, latência, pause/resume/seek/stop.
**Seleção:** por parte, pauta, voz, região? Solo? Mute?

## A.5 Gregoriano / Greciliae

Audite **separadamente** do CMN. Neumes, punctum, virga, podatus, clivis,
torculus, porrectus, climacus, scandicus, quilisma, liquescência, episema, mora,
divisio, custos, quebra de linha, GABC, mapeamento de altura, playback. Verifique
a calibração vertical **contra `assets/gregorian/greciliae_glyphnames.json`**.
**Verifique também se a mudança de convenção do ADR-003 alcançou o canto.**

## A.6 Software

**Performance:** O(n²)/O(n³), rebuild e repaint excessivos, layout repetido,
parsing repetido, alocações, caching, partituras grandes, scrolling, zoom,
milhares de compassos, orquestra. **Estime a complexidade e meça.**

**Memória, Flutter, concorrência, cross-platform** (leia o código nativo),
**testes** (adversarialmente — o que eles NÃO testam), **segurança** (parser XML,
entidades externas, entrada malformada, path traversal, desserialização,
dependências, segredos), **determinismo**, **dependências, API pública,
compatibilidade, documentação vs código, histórico do git, regressões, magic
numbers, design musical, source of truth.**

Para cada magic number: `valor | local | função | por que existe | é justificável
| deveria vir de metadata`.

Para source of truth, identifique a verdadeira fonte para: pitch, duration,
position, voice, measure, staff, lyrics, dynamics, articulation, beam, slur,
tie, tempo, repeat. Se houver múltiplas, explique o risco.

## A.7 Capacidade de sustentar um editor

Avalie suporte arquitetural **atual** para: cursor, seleção, inserção, deleção,
drag, resize, note entry, teclado, mouse, touch, undo, redo, clipboard, seleção
por região/compasso/pauta/voz, playback de seleção.

## A.8 Escalabilidade — `PASS | PARTIAL | FAIL | UNKNOWN` com justificativa

**A** Piano 500 compassos · **B** SATB 300 · **C** Orquestra 100 instrumentos ·
**D** 4 vozes independentes por pauta · **E** lyrics longas · **F** MusicXML
complexo (sem `<type>`, `<backup>`, `<forward>`, `<transpose>`, `<unpitched>`,
beams secundários) · **G** Gregoriano extenso · **H** repeats + volta +
quialteras + ties + cross-staff.

## A.9 Corrupção semântica

Procure situações em que `INPUT MUSIC → PARSER → MODEL` altera a música sem
indicação: nota muda de pitch, duração muda, voice/lyric/articulation/repeat/
metadata/staff/instrument desaparece. **Isso é crítico.**

---

# PARTE B — VERIFICAÇÃO DAS ALEGAÇÕES 2.7.1

Para **cada linha**, escreva uma sonda executável, rode-a, e classifique:
**CONFIRMED FIXED · PARTIALLY FIXED · NOT FIXED · REGRESSED · UNVERIFIABLE**.

Para **PARTIALLY FIXED** e **REGRESSED**, o caso vizinho que falha é um achado
novo e entra na sua lista de bugs com o formato completo.

## B.1 Matriz de verificação

| ID | Alegação | Sonda mínima sugerida (crie outras) |
|---|---|---|
| **N-11** | Compasso abre clave → armadura → fórmula, qualquer que seja a ordem da fonte | importar MusicXML com `<attributes>` canônico (`key, time, clef`) e conferir X; **e** conferir que mudança no meio do compasso ainda segue a ordem do documento (F-01) |
| **N-01** | Compasso sobrecheio no início de sistema quebrado não derruba o painter | 12 compassos, o 5º com 6 semínimas em 4/4, `GrandStaffPainter` a 300 px |
| **N-02** | Sistema quebrado preserva `autoBeaming`, `beamingMode`, `manualBeamGroups`, `number` | 8 compassos com `autoBeaming:false` a 400 px; **e** `manualBeamGroups`; **e** `number` explícito |
| **N-02b** | Rebuild preserva as vozes de um `MultiVoiceMeasure` | polifonia em todos os compassos, largura que force quebra |
| **N-03** | `MultiVoiceMeasure.elements` chegam ao layout | clave+armadura+fórmula+dinâmica em `mv.elements`, 2 vozes → 4 desenhados, Y distintos, `noteXPositions` populado |
| **N-12** | Parsers não duplicam mais o bloco de abertura | import polifônico MusicXML **e** MEI → 1 clave, 1 armadura, 1 fórmula |
| **N-04** | Layout linear | 400/800/1600/3200/6400 compassos; razão por duplicação; **e** com muitas vs poucas quebras de sistema |
| **N-05** | Acidente reserva espaço ANTES da nota | `C4, E4♯, G4, B4` → gap antes cresce, gap depois volta ao normal; **e** 1ª nota do compasso; **e** em acorde |
| **F-27** | Piso anti-colisão usa a largura do metadado | 32 semicolcheias comprimidas alternando bemol-dobrado/bequadro → folga ≥ 0; **e** com sustenido-dobrado; **e** staffSpace 6 e 24 |
| **N-07** | Quiáltera espaça por duração | semínima+colcheia numa tercina; colcheia+2 semicolcheias; **e** aninhada; **e** com pausas |
| **N-07b** | Layout e renderer usam a MESMA grade | `TupletGrid` sem parâmetro de engine — confirme que não há outro caminho que recompute |
| **N-08** | Níveis de barra por nota dentro da quiáltera | colcheia+2 semicolcheias → 2 níveis; **e** fusas; **e** stub fracionário |
| **N-09** | Análise de barras sem fórmula de compasso | `Measure()` sem `TimeSignature` → `advancedBeamGroups` não vazio, com segmentos |
| **N-10** | Inclinação de barra segue a tabela de Gould | uníssono 0, 2ª 0,25, 3ª 0,5, 4ª/5ª 1,0, 6ª/7ª 1,25, oitava+ 1,5; **e** grupos de 3–6 notas; **e** comprimento de haste resultante |
| **N-21** | 4/4 agrupa semicolcheias por tempo | 16 semicolcheias → 4-4-4-4; 8 colcheias → 4-4; **e** 2/2, 3/2, 6/4 |
| **N-31** | Subdivisões cobrem o compasso inteiro | 5/4, 7/4, 11/8: todo grupo aberto é fechado; soma == `measureValue` |
| **N-13** | `<transpose>` chega ao playback | clarinete em Si♭: `Pitch` continua escrito, MIDI = 58; **e** export emite `<transpose>`; **e** `<double/>` |
| **N-15/ADR-003** | `Pitch` é a altura SOANTE | `<pitch>C4` + `clef-octave-change=-1/0/+1` → MIDI 60 nos três, `staffPosition` difere de 7; **e** `c8vb` não desloca duas vezes; **e** MEI; **e** gregoriano; **e** Jianpu |
| **N-16** | Texto usa a cadeia de fontes do pacote | rasterizar via `ScoreRasterizer` SEM tema e procurar `.notdef` no bitmap: números de compasso, lyrics, dinâmicas, tempo, nomes de instrumento |
| **N-17** | Lead-in de ligadura entre sistemas não atravessa a clave | ligadura na quebra com armadura restatada; **e** com fórmula restatada; **e** slur além de tie |
| **N-18** | PDF exporta grand staff como grand staff | `PdfExporter` com um `StaffGroup` de 2 pautas → 1 imagem por sistema com chave e barras de sistema |
| **N-19** | Hit-test derivado do desenho | clicar em haste, acidente, bandeirola, linha suplementar e cabeça de acorde agudo |
| **N-20** | `PositionedElement.staffBaselineY` | disponível e correto em todos os caminhos, inclusive após justificação e alinhamento multi-pauta |
| **N-22** | Grade de onset resolve 1/2048 | 16 onsets distintos → 16 chaves; **e** quialtera aninhada 1/3 de 1/5 |
| **N-23** | Nomes de parte/grupo importados e exportados | `<part-name>`, `<part-abbreviation>`, `<group-name>` → `Staff.name/abbreviation`, `StaffGroup.name` → round-trip |
| **N-24** | Round-trip JSON | `syllables`, `crossStaffMove`, `tabFret/tabString`, quialtera, acorde, `MultiVoiceMeasure` |
| **N-25** | `<pitch>` sem `<octave>` falha alto | `FormatException`; **e** sem `<step>`; **e** MEI equivalente |
| **N-26** | MEI `clef.shape="TAB"` | `lines=6` → `tab6`; `lines=4` → `tab4` |
| **N-28** | Dry-run não escreve nos mapas | medir largura de compasso com quialtera e conferir que os mapas ficam intactos até o layout real |
| **N-29** | Uníssono entre vozes compartilha posição | mesma duração → coincidente; durações diferentes → deslocado; 2ª → deslocado |
| **N-32** | `c8vb` deslocado uma única vez | `calculate(C3, c8vb) == 2` e `== calculate(C4, tenor)` |
| **scoreToMusicXML** | Export em nível de partitura | grupos, `<part-group>`, nomes, abreviações, transposição → reimport idêntico |
| **ADR-004** | Bloco de abertura é convenção, corpo é sequência | ordenação canônica na abertura E ordem do documento no corpo, nas DUAS rotas (`Measure` e `MultiVoiceMeasure`) |

## B.2 Ataques específicos que você DEVE tentar

Estes são os pontos onde a remediação 2.7.1 tem maior chance de estar errada:

1. **ADR-003 é uma mudança semântica quebrante.** `Pitch` passou a ser a altura
   soante. Ache TODO consumidor de `Pitch` e verifique se cada um concorda:
   `StaffPositionCalculator`, `MidiMapper`, `ChantMidiMapper`,
   `JianpuPitchMapper`, `AccidentalResolver`, os três parsers, os exportadores,
   `SlurRenderer`, `GrandStaffPainter`. **Algum ficou com a convenção antiga?**
   Em particular: o gregoriano e o Jianpu foram verificados?
2. **A tabela de inclinação de Gould foi aplicada, mas não há comprimento máximo
   de haste nem quebra de barra por âmbito.** Um salto de duas oitavas dentro de
   um grupo com barra ainda produz haste de ~9 espaços. Meça e julgue.
3. **`TupletGrid` fixou a lei em `sqrt` para não divergir do renderer.** Isso
   significa que o espaçamento INTERNO de quiáltera ignora o `SpacingModel`
   configurado. Isso é aceitável? E o `minimumSlotSpaces = 1.4` — de onde vem?
4. **`_leftExtent`/`_rightExtent` mudaram o significado de "largura".**
   `_getElementWidthSimple` continua sendo o total. Ache todo consumidor
   (`contentWidth`, `_centerFullMeasureRests`, `elementWidth`, `ScoreHitTester`,
   `CollisionDetector`, medição de compasso) e verifique se cada um quer o total
   ou uma das metades.
5. **`_minimumInterNoteGap` deixou de somar `previousRight`.** Prove que isso não
   permite colisão quando o elemento anterior é largo (acorde com acidentes,
   pausa, quialtera).
6. **`canonicalOpeningBlock` ordena só clave/armadura/fórmula.** O que acontece
   se `_isSystemElement` crescer? E se o autor escrever DUAS claves na abertura?
7. **A remoção da duplicação nos parsers** dependia de `_layoutMultiVoiceMeasure`
   ler `measure.elements`. Existe algum outro consumidor que dependia da
   duplicação? (`MeasureValidator`, `Measure.musicalValueOfVoice`,
   `MidiMapper.processMeasure`, export MusicXML/MEI.)
8. **`PositionedElement.movedTo`** foi introduzido para parar de perder campos
   nas cópias. Ache alguma cópia manual remanescente.
9. **O hit-test estima o comprimento de haste em 3,5 espaços**, mas o
   renderizador calcula por `calculateStemLength`/`calculateChordStemLength`
   (que faz `chordSpan + 3.5`, com clamp em 6.0). **As duas ainda divergem** —
   meça o erro e diga se importa.
10. **`_activeClef` no `MidiMapper` ficou write-only** com `// ignore:
    unused_field`. Isso é dívida ou preparação legítima?
11. **Os 16 goldens regravados.** Abra-os **ampliados**. Um deles está errado?
    Compare com `git show HEAD~2:test/golden/goldens/<nome>.png`.
12. **`ScoreRasterizer` ganhou um segundo caminho** (`renderGroupToPage`).
    Ele concorda com `layoutStaff` na altura, na largura e no `pixelRatio`?
13. **Testes que passam por tolerância frouxa.** Releia cada `closeTo`,
    `lessThan`, `greaterThan` em `test/invariants/` — inclusive os NOVOS de
    `remediation_2_7_1_test.dart` — e pergunte se a tolerância esconde um erro.
    (O teste N-04 usa `lessThan(10.0)` sobre uma razão de tempo: isso é medição
    ou é ruído de máquina?)

## B.3 Trabalho declarado como NÃO FEITO

A rodada 2.7.1 **não** fez o seguinte. Não é preciso "descobrir"; é preciso
**confirmar que continua aberto e avaliar o custo**:

- **`Tuplet` ainda é um elemento opaco no fluxo.** A grade interna é
  compartilhada e proporcional, e as barras internas agora têm níveis por nota,
  mas a quiáltera não passa pelo mesmo cursor do resto (`TupletRenderer` ainda
  tem seu próprio desenhador de barras).
- **Sem comprimento máximo de haste e sem quebra de barra por âmbito.**
- **`Note.beam` continua mutável e escrito pelo layout** (decisão do ADR-001).
- **Mapas com chave de identidade ainda não suportam a mesma instância de `Note`
  usada duas vezes** — 3 ocorrências ainda colapsam em 1 entrada de posição.
- **Não existe exportador MEI.**
- **`<unpitched>` ainda vira nota afinada comum** e sai como `<pitch>`.
- **`Transposition.diatonic` é carregado mas não usado** — não há visão em
  altura de concerto (respelling).
- **Layout ainda roda no construtor do `CustomPainter`; zero isolates.**
  6.400 compassos = 313 ms, ainda na UI thread.
- **Playback nativo continua em 1 de 6 plataformas** (documentado no README).
- **Gregoriano continua um pipeline à parte** — identidade, onset, hit-test e
  export PDF do CMN não o alcançam.
- **Cue notes, ossia, números de página, notas coloridas, partes vinculadas:
  não suportados.**

## B.4 Nota de remediação

```
ACHADOS VERIFICADOS: N
  CONFIRMED FIXED : n1   PARTIALLY FIXED : n2
  NOT FIXED       : n3   REGRESSED       : n4   UNVERIFIABLE : n5

NOTA = (n1 + 0.5*n2) / N
ACHADOS NOVOS INTRODUZIDOS PELA REMEDIAÇÃO: n4 + (novos da Parte A)
```

E responda: **a remediação melhorou ou piorou o projeto, e por quê?**

---

# FORMATO OBRIGATÓRIO DOS ACHADOS

```
ID:
SEVERIDADE:            (P0 catastrófico | P1 crítico | P2 alto | P3 médio | P4 baixo)
EVIDÊNCIA:             (A | B | C | D)
ARQUIVO:
LINHA:
COMPONENTE:
PROBLEMA:
COMPORTAMENTO ATUAL:   (com números medidos)
COMPORTAMENTO ESPERADO:
IMPACTO:
CAUSA RAIZ:
POR QUE O BUG EXISTE:
COMO REPRODUZIR:
COMO CORRIGIR:
RISCO DA CORREÇÃO:
TESTE NECESSÁRIO:
```

**Não faça patches cegos.** Para cada problema determine
`symptom → proximate cause → root cause → architectural cause`. Se for
arquitetural, NÃO recomende "adicione um if" — explique a correção estrutural.

---

# RESULTADO FINAL OBRIGATÓRIO

Sua resposta final deve possuir **EXATAMENTE** estas grandes seções:

1. **EXECUTIVE SUMMARY** · 2. **NOTA DE REMEDIAÇÃO** (matriz da Parte B completa)
· 3. **REALIDADE VS DOCUMENTAÇÃO** · 4. **ARQUITETURA ATUAL** · 5. **MUSIC
MODEL** · 6. **ENGRAVING** · 7. **LAYOUT ENGINE** · 8. **SMuFL / BRAVURA** ·
9. **MUSICXML** · 10. **MEI** · 11. **MIDI / PLAYBACK** · 12. **GREGORIAN** ·
13. **POLYPHONY / MULTI-STAFF** · 14. **FLUTTER ARCHITECTURE** ·
15. **PERFORMANCE** · 16. **TESTES** (incluindo *o que os novos testes NÃO
testam*) · 17. **SEGURANÇA** · 18. **API PÚBLICA** · 19. **DÍVIDA TÉCNICA** ·
20. **TOP 10 PROBLEMAS** · 21. **MATRIZ DE MATURIDADE** (nota 0–10 para modelo
musical, engraving, layout, SMuFL, Bravura, MusicXML, MEI, JSON, MIDI, playback,
gregoriano, polifonia, multi-staff, performance, arquitetura Flutter, testes,
golden tests, segurança, API pública, documentação, escalabilidade, prontidão
para editor — **compare cada nota com a de 2.7.0 em
`doc/AUDITORIA_FORENSE_2026-08-22.md` §21** e explique cada mudança) ·
22. **TESTES QUE PRECISAM SER CRIADOS** · 23. **PLANO DE CORREÇÃO** (Fase 0
emergência → Fase 5 editor) · 24. **ARQUITETURA RECOMENDADA** ·
25. **VEREDITO FINAL**, respondendo objetivamente:

1. O engine está realmente pronto para produção?
2. O engraving é profissional?
3. O modelo musical é sólido?
4. MusicXML é confiável?
5. MEI é realmente suportado?
6. MIDI/playback é musicalmente confiável?
7. O sistema suporta partituras complexas?
8. A arquitetura suporta um editor profissional?
9. Quais são os maiores riscos?
10. Qual é a ordem correta para corrigi-los?
11. **A remediação da 2.7.1 foi honesta?** (as alegações correspondem ao código?)
12. **A rodada 2.7.1 corrigiu erros da auditoria anterior, ou apenas concordou
    com ela?** (ela afirma ter retirado dois achados por estarem errados —
    confira se a retirada procede.)

---

# REGRA FINAL — SEJA ADVERSARIAL

Quero que você tente **QUEBRAR** o projeto. Não tente provar que funciona; tente
provar que **não funciona**.

- Se não conseguir encontrar um problema numa área, diga *"Não encontrei
  evidência de falha nesta área"* — nunca *"está perfeito"*.
- Se não conseguir provar uma funcionalidade, marque **UNKNOWN**.
- Se encontrar uma implementação aparentemente correta, procure seus edge cases.
- Se encontrar um teste passando, descubra o que ele **não** testa.
- Se encontrar uma abstração elegante, verifique se preserva a semântica musical.
- **Se encontrar uma correção recente, procure a regressão que ela causou.**
- Se encontrar um magic number, descubra de onde ele veio.
- Se encontrar uma classe aparentemente completa, procure os caminhos que nunca
  chegam até ela.
- Se encontrar uma feature documentada, percorra o caminho inteiro
  `INPUT → PARSER → MODEL → NORMALIZATION → LAYOUT → ENGRAVING → RENDER → OUTPUT`
  e só a considere implementada se ele estiver funcional.
- **Julgue imagens ampliadas.** A rodada anterior errou dois achados por olhar
  goldens em escala 1:1.

Se precisar escolher entre ser gentil e ser tecnicamente preciso: **SEJA PRECISO.**
Se precisar escolher entre velocidade e profundidade: **SEJA PROFUNDO.**
Se precisar escolher entre assumir e provar: **PROVE.**

---

# PRINCÍPIO MÁXIMO

> **"Este código representa corretamente a teoria musical, preserva a semântica
> da partitura, produz engraving visualmente correto, mantém interoperabilidade,
> possui arquitetura sustentável e pode servir de base para um editor
> profissional de partituras?"**

E, desta vez, também:

> **"As correções alegadas são reais, completas e livres de regressão — e a
> rodada anterior foi capaz de corrigir a si mesma?"**
