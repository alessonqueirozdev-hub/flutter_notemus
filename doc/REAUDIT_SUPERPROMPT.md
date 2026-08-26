# SUPERPROMPT — RE-AUDITORIA FORENSE, ADVERSARIAL E DE VERIFICAÇÃO
## flutter_notemus 2.7.0 (pós-remediação)

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

**PARTE B — Verificação adversarial de alegações.** Uma auditoria anterior
catalogou 42 achados e uma rodada de remediação afirma tê-los corrigido. Você
deve **verificar cada alegação executando código**, e produzir uma nota de
remediação quantificada.

Este é um projeto real e ativo. NÃO faça uma revisão superficial.

---

# 0. REGRAS FUNDAMENTAIS (valem para as duas partes)

Trate todo o repositório como potencialmente incorreto até que a **execução** de
código prove o contrário.

NÃO presuma que uma funcionalidade existe porque existe:
classe, enum, método, comentário, dartdoc, README, CHANGELOG, ADR, arquivo em
`doc/`, nome de teste, ou um teste que passa.

**Em especial, nesta auditoria:**

1. **NÃO confie em `doc/AUDITORIA_FORENSE_2026-08-21.md`.** É a auditoria
   anterior. Pode conter erros. Verifique os achados que ela alega.
2. **NÃO confie em `test/invariants/`, `test/interaction/`, `test/fuzz/`,
   `test/gregorian/`.** Esses testes foram escritos pela MESMA rodada que fez as
   correções. Um teste escrito pelo autor da correção pode:
   - testar exatamente o caso fácil que ele consertou e não o caso geral;
   - afirmar uma invariante mais fraca do que a regra musical real;
   - passar por acidente de tolerância (`closeTo`, `lessThan` frouxo);
   - não ser executado (grupo com `skip:`, arquivo fora do padrão de descoberta).
   **Leia cada asserção e pergunte: o que ela NÃO testa?**
3. **NÃO confie nos goldens.** 39 dos 52 existentes foram regravados nesta
   rodada (e um novo foi acrescentado, 53 no total). Um
   golden regravado documenta o que o renderizador faz, não o que ele deveria
   fazer. Abra as imagens. Julgue-as como gravador musical.
4. **NÃO confie nos ADRs** (`doc/adr/`). Eles descrevem a intenção. Verifique se
   a intenção foi implementada e se as consequências declaradas são reais.
5. **NÃO confie nas notas dos agentes** nem em `CHANGELOG.md`.

Classifique cada capacidade como:

* ✅ REALMENTE IMPLEMENTADA E VALIDADA (por execução)
* 🟢 IMPLEMENTADA, MAS COM RISCOS
* 🟡 PARCIAL
* 🟠 IMPLEMENTADA APENAS SUPERFICIALMENTE
* 🔴 INCORRETA
* ⚫ APENAS MODELADA / PLACEHOLDER
* ❌ NÃO IMPLEMENTADA
* ❓ NÃO FOI POSSÍVEL PROVAR

Nunca transforme "classe existente" em "funcionalidade existente".

**Níveis de evidência obrigatórios em cada achado:**
- **A** = confirmado executando código (sonda que você escreveu e rodou)
- **B** = confirmado lendo o código
- **C** = inferência arquitetural forte
- **D** = hipótese

**NUNCA apresente hipótese como fato.** Se não conseguir provar, escreva
`UNKNOWN` e diga por quê.

---

# PARTE A — AUDITORIA COMPLETA

Execute integralmente as seções 1 a 73 abaixo. Elas reproduzem o escopo da
auditoria original; nada foi removido.

## A.1 Reconstrução do sistema

Antes de qualquer julgamento, reconstrua a arquitetura inteira. Mapeie:
estrutura do projeto, `lib/`, modelos, renderizadores, layout engine, parsers,
exporters, MusicXML, MEI, JSON, MIDI, playback, fontes, SMuFL, Bravura,
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
Conte quantos pipelines de layout independentes existem de fato.

## A.2 Engraving musical

Audite como **especialista em gravação musical profissional**, não como
revisor de software.

**Notas:** posicionamento horizontal e vertical, notehead, stem, stem direction,
stem length, stem attachment, ledger lines, accidentals, spacing, chord spacing,
overlapping, grace notes, cue notes, cross-staff notes. Teste C4, notas extremas
(C0, C8, B10), acordes, intervalos muito próximos e muito largos, notas em linhas
e espaços, notas com várias alterações.

**Accidentals:** sharp, flat, natural, double sharp, double flat, microtonais,
posicionamento, collision avoidance, stacking, spacing, repetidos, cautelares,
editoriais, em acordes, em múltiplas vozes. Pergunta crítica: *o sistema sabe
quando um acidente deve aparecer, ou apenas renderiza o que recebeu?*

**Ritmo e duração:** de `maxima` a 1/2048, pontos, quialteras, quialteras
aninhadas, breve, longa, máxima, aritmética e normalização de duração. Verifique
se duração é tratada corretamente como enum, valor musical, duração temporal,
relativa, MIDI e de layout — e procure erros de conversão em
`notation duration → beat duration → ticks → milliseconds → MIDI`.

**Beaming:** automático, manual, agrupamento, direção, inclinação, espessura,
espaçamento, barras parciais, pausas dentro de grupos, cross-staff, multi-voz,
quialteras + beams, grace notes, colisão, anexação, posicionamento vertical.
Determine se o algoritmo segue regras musicais reais ou heurísticas geométricas.
Procure stems atravessando beams, beams impossíveis, inclinação incorreta e
grupos rítmicos musicalmente errados.

**Stems, chords, voices, multi-staff, layout engine, engraving algorítmico,
SMuFL, Bravura, texto e lyrics, slurs e ties, articulações, dinâmicas,
quialteras, claves, armaduras, fórmulas de compasso, barras e repetições** —
audite cada um com o mesmo rigor. Para cada um, pergunte se existe *semântica
musical* ou apenas desenho.

Perguntas arquiteturais que você **deve** responder com evidência A:
- Todas as pautas compartilham uma verdadeira coordenada temporal/horizontal, ou
  cada pauta é renderizada independentemente e depois posicionada?
- Existe layout determinístico ou uma coleção de heurísticas e offsets?
- O código é realmente SMuFL-compliant ou apenas Bravura-compatible?
- Uma lyric longa empurra a próxima nota, ou sobrepõe?
- Existe algoritmo de routing de ligaduras ou curvas aproximadas?

## A.3 Interoperabilidade

**MusicXML:** faça auditoria REAL do parser. Determine quais elementos são
importados, ignorados, parcialmente interpretados, descartados silenciosamente,
convertidos incorretamente, e quais causam perda semântica. Cubra
`score-partwise`, `score-timewise`, `part-list`, `part-group`, `attributes`,
`divisions`, notes, rests, chords, **backups**, **forwards**, voices, staff,
beams (incluindo `number=2,3,4`), tuplets, ties, slurs, articulations, dynamics,
ornaments, lyrics, directions, tempos, repeats, endings, clefs, keys, meters,
**transposition**, instruments, **percussion/unpitched**, grace notes, **cue notes**.

**Round-trip:** `MusicXML → parser → modelo → export → MusicXML`. Liste **cada
perda** e classifique: lossless / mostly lossless / lossy / severely lossy.

**MEI v5:** não confie na tabela do README. Compare a especificação com parser,
modelo, renderizador e exportador. Para cada módulo separe explicitamente:
`MODEL ONLY | PARSED | RENDERED | EXPORTED | ROUND-TRIPPABLE`.

**JSON:** serialização, desserialização, compatibilidade retroativa, schema,
nullability, defaults, enums, versionamento, entrada malformada, campos
desconhecidos. *O JSON representa o modelo musical inteiro ou apenas uma visão
conveniente dele?*

## A.4 MIDI e playback

Pipeline completo `notation → semantic timeline → MIDI events → MIDI file`.
Verifique pitch, duration, velocity, channel, tempo, PPQ, ticks, ties, tuplets,
voices, repeats, volta, grace notes, transposição, percussão, múltiplas partes,
múltiplas faixas.

Playback como sistema musical: tempo, beat/measure position, scheduling,
note-off, ties, repeats, volta, polifonia, sincronização, drift, latência,
pause, resume, seek, stop, restart.

**Seleção:** é possível selecionar e tocar por parte, por pauta, por voz, por
região da partitura? Solo? Mute? Se não, quais mudanças arquiteturais faltam?

## A.5 Gregoriano / Greciliae

Audite **separadamente** do CMN. Neumes, punctum, virga, podatus, clivis,
torculus, porrectus, climacus, scandicus, quilisma, liquescência, episema, mora,
divisio, custos, quebra de linha, GABC, mapeamento de altura, playback.
Determine quais elementos são realmente musicais e quais são apenas desenho de
glifo. Verifique a calibração vertical **contra o arquivo de fonte enviado**
(`assets/gregorian/greciliae_glyphnames.json`), não contra o código.

## A.6 Software

**Performance:** O(n²)/O(n³), rebuild e repaint excessivos, layout repetido,
parsing repetido, alocações, caching, carregamento de fonte e metadata,
partituras grandes, scrolling, zoom, milhares de compassos, orquestra.
**Estime a complexidade e meça.**

**Memória:** leaks, listeners, controllers, streams, caches, objetos retidos,
estruturas imutáveis grandes, representações duplicadas da partitura.

**Flutter:** widgets, RenderObjects, CustomPainter, state management,
imutabilidade, rebuilds, keys, controllers, ciclo de vida, async, isolates,
platform channels, código nativo. A arquitetura é adequada para um editor
profissional?

**Concorrência:** parsing/rendering assíncronos, MIDI, playback, carregamento de
fonte e metadata, isolates, race conditions, estado mutável, modelo
compartilhado, reentrância.

**Cross-platform:** Android, iOS, Windows, macOS, Linux, Web. Não considere uma
plataforma suportada só porque aparece no projeto Flutter — **leia o código
nativo**.

**Testes:** de forma adversarial. Os testes realmente provam correção? Procure
testes frágeis, triviais, cobertura falsa, assertions insuficientes, ausência de
golden tests, round-trip tests, fuzzing, stress tests e invariantes musicais.
Monte a matriz `FEATURE | IMPLEMENTATION | TEST | TEST QUALITY | RISK`.

**Segurança:** parser XML, entidades externas, entrada malformada, path
traversal, acesso arbitrário a arquivos, desserialização insegura,
vulnerabilidades de dependências, segredos, credenciais, tokens, CI secrets.
*O que acontece se alguém abrir uma partitura maliciosamente construída?*

**Determinismo:** o mesmo `Score` gera exatamente o mesmo layout? Verifique
floating point, ordem de iteração, hash maps, coleções não ordenadas, valores
aleatórios, operações assíncronas. Os golden tests são confiáveis?

**Dependências, API pública, compatibilidade (Dart/Flutter SDK, pub.dev,
semver), documentação vs código, issues vs código, histórico do git,
regressões, magic numbers, design musical, source of truth.**

Para magic numbers, para cada um: `valor | local | função | por que existe | é
justificável | deveria vir de metadata`.

Para source of truth, identifique a verdadeira fonte para: pitch, duration,
position, voice, measure, staff, lyrics, dynamics, articulation, beam, slur,
tie, tempo, repeat. Se houver múltiplas, explique o risco.

## A.7 Capacidade de sustentar um editor

Avalie suporte arquitetural **atual** (não invente funcionalidades) para: cursor,
seleção, inserção, deleção, drag, resize, note entry, teclado, mouse, touch,
undo, redo, clipboard, seleção por região/compasso/pauta/voz, playback de
seleção.

## A.8 Escalabilidade e teste de estresse conceitual

*Esse modelo consegue representar uma sinfonia? um coral SATB? um piano
complexo? 100 instrumentos? milhares de compassos? múltiplas vozes
independentes?* Se não, onde quebra exatamente?

Para cada cenário abaixo determine `PASS | PARTIAL | FAIL | UNKNOWN` **e
justifique com evidência**:

- **A** Piano, 500 compassos
- **B** SATB, 300 compassos
- **C** Orquestra, 100 instrumentos
- **D** 4 vozes independentes por pauta
- **E** Partitura com lyrics longas
- **F** MusicXML complexo (sem `<type>`, com `<backup>`, `<forward>`,
  `<transpose>`, `<unpitched>`, beams secundários)
- **G** Gregoriano extenso
- **H** repeats + volta + quialteras + ties + cross-staff

## A.9 Corrupção semântica

Procure situações em que `INPUT MUSIC → PARSER → MODEL` altera a música sem
indicação: nota muda de pitch, duração muda, voice desaparece, lyric desaparece,
articulation desaparece, repeat desaparece, metadata desaparece, staff
desaparece, instrument desaparece. **Isso é crítico.**

---

# PARTE B — VERIFICAÇÃO DAS ALEGAÇÕES DE REMEDIAÇÃO

A tabela abaixo lista o que a rodada de remediação **alega** ter corrigido.
Para **cada linha**, escreva uma sonda executável, rode-a, e classifique:

| Veredito | Significado |
|---|---|
| **CONFIRMED FIXED** | você reproduziu o cenário e o comportamento correto ocorre |
| **PARTIALLY FIXED** | o caso citado funciona, mas você encontrou um caso vizinho que ainda falha |
| **NOT FIXED** | o defeito original ainda reproduz |
| **REGRESSED** | a correção introduziu um defeito novo |
| **UNVERIFIABLE** | você não conseguiu montar a sonda — explique por quê |

Para **PARTIALLY FIXED** e **REGRESSED**, o caso vizinho que falha é um achado
novo e entra na sua lista de bugs com o formato completo da seção "FORMATO DOS
ACHADOS".

## B.1 Matriz de verificação

| ID | Alegação | Sonda mínima sugerida (crie outras) |
|---|---|---|
| F-01 | Mudança de clave no meio do compasso fica na ordem do documento e só afeta as notas seguintes | compasso `[Sol, Dó4, Fá, Dó4]`: as duas notas têm Y diferente? o glifo da clave está depois da 1ª nota? |
| F-02 | O layout não clona mais objetos do modelo; regra de acidentes vale para notas com barra | 4 colcheias Fá♯4 → decisões `[show, hide, hide, hide]`; `noteXPositions[minhaNota] != null` |
| F-02b | Assinatura de layout determinística | 3 layouts do mesmo `Staff` → mesma assinatura |
| F-03 | Compassos compostos agrupam em 3 | 3/8, 6/8, 9/8, 12/8, 6/8 em semicolcheias; **e 6/16, 9/16, 12/16, 2/2, 5/8, 7/8, 8/8, compasso aditivo** |
| F-04 | Pautas alinhadas por onset musical | 4 semínimas × 2 mínimas; **e quialtera contra semínimas, e 3+ pautas, e sistemas quebrados** |
| F-05 | Compasso denso é comprimido e o resto é rolável | 32 semicolcheias em 400 px; **e 64 semicolcheias, e staffSpace 6 e 24** |
| F-06 | `<divisions>`/`<duration>` usados quando falta `<type>` | nota sem `<type>`; **e pausa de compasso, e quialtera sem `<type>`, e divisions redefinido no meio** |
| F-07 | `<backup>`/`<forward>` implementados | polifonia sem `<voice>`; `<forward>` inicial; **e 3 vozes, e backup parcial** |
| F-08 | Instância de `Note` reutilizada não some | 3 instâncias iguais → 3 renderizadas; **e dentro de acorde e de quialtera** |
| F-09 | `Measure.add` é voice-aware | 4+4 semínimas em 4/4 com vozes 1 e 2; **e overflow de voz única ainda barrado** |
| F-10 | Entrada inválida falha com exceção de domínio | `<step>H</step>`, oitava 999999; **e MEI `@pname`, e JSON, e valores vazios** |
| F-11 | Espaçamento proporcional em todos os 15 `DurationType` | monotonicidade da máxima à 1/2048; **e com pontos, e em quialteras** |
| F-13 | Justificação não estica o bloco clave/armadura | gap clave→armadura constante em larguras diferentes |
| F-14 | Toda haste em grupo com barra ≥ mínimo | Mi4+Fá5; **e grupos de 4+ com nota interna extrema, e stem-down, e fora da pauta** |
| F-15 | Lyrics ocupam espaço horizontal | sílaba de 15 caracteres alarga o vão; **e melisma, e 2+ versos, e em acordes** |
| F-16 | Acidente de cortesia sempre desenhado, com parênteses/colchetes | decisão = `show`; e o glifo aparece no golden |
| F-17 | MEI lê todas as `<section>` | 2 seções → 2 compassos; **e seções aninhadas, e `<ending>`** |
| F-19/20/21 | `intervalInSemitones`, oitava negativa, `==`/`hashCode` | tabela de intervalos; `'C-1'`; igualdade de F♯4 |
| F-22 | Sem teto de 1000 sistemas | 1200+ sistemas renderizam |
| F-24 | Claves 8va/8vb aplicadas ao playback | MIDI de uma nota em `treble8vb` |
| F-25 | Notas dentro de quialteras têm geometria | `noteXPositions` das internas; acorde e quialtera aninhada dentro de quialtera |
| F-26 | Ligaduras que cruzam sistema viram dois segmentos | tie/slur em quebra de linha |
| F-27 | Larguras de acidente vêm do metadado | dobrado-bemol reserva ≈1,652 |
| F-29 | Calibração gregoriana derivada da fonte | passo diatônico medido no asset ≈157,5 |
| F-30 | Colisão entre vozes agrupada por onset | 2ª entre vozes com X ligeiramente diferente |
| F-33 | Números de compasso renderizados | início de cada sistema, compasso 1 não numerado |
| F-40 | Fonte SMuFL trocável | nenhum `fontFamily: 'Bravura'` literal em `lib/` |
| F-36 | Export PDF gera a notação real | bytes do PDF contêm imagem, não placeholder |
| §30 | Playback por voz/pauta/seleção | `separateTracksPerVoice`, `mutedVoices`, `soloVoices` |
| §53 | Hit-test/seleção | `ScoreHitTester` devolve o objeto do usuário |
| §55 | Marcas de ensaio desenhadas (caixa SMuFL) | `TextType.rehearsal` no golden `m04s_rehearsal_marks` |
| NOVO-1 | Nada é cortado acima/abaixo da pauta | C9 em clave de sol; marca de ensaio; 3 versos de lyric |
| NOVO-2 | `Tuplet.totalDuration` soma o conteúdo real | tercina colcheia+semínima+colcheia; tercina só de pausas; só de acordes |
| NOVO-3 | PDF reserva a mesma folga da tela | exportar partitura com C9 e verificar a página 1 |
| NOVO-4 | Numeração de compasso não muta o modelo | `Measure.number` continua null após renderizar um `GrandStaff` |
| NOVO-5 | Acordes e quiálteras aninhadas dentro de quiáltera são desenhados | eram pulados por todos os ramos do renderizador |
| NOVO-6 | Import MEI: `@mode`, compasso aditivo, `@tab.*`, `<meiHead>` | `MEIParser.scoreFromMei` |
| NOVO-7 | Import MusicXML: `<transpose>`, `<unpitched>`, `<sound tempo>`, `<staff-lines>` | nota de percussão não é mais descartada |

## B.2 Ataques específicos que você DEVE tentar

Estes são os pontos onde a remediação tem maior chance de estar errada. Ataque-os
com prioridade:

1. **O layout muta o modelo.** `Note.beam` virou mutável e `layout()` escreve
   nele. Procure as consequências: layout duas vezes com larguras diferentes
   muda o modelo? Um `Staff` compartilhado entre dois `MusicScore` de larguras
   diferentes? Layout concorrente? `Measure.autoBeaming = false` realmente
   preserva o beam do autor?
2. **Compressão de compasso.** Existe um `_spacingScale` com piso. Verifique se
   a compressão vaza para o compasso seguinte, se a justificação a desfaz, e se
   o piso anti-colisão realmente impede sobreposição em todos os casos.
3. **Medição por dry-run.** A largura do compasso agora é medida executando o
   layout num cursor descartável. Verifique se o dry-run tem efeitos colaterais
   (ele chama o mesmo código que escreve nos mapas de posição e que muta
   `Note.beam`) e se o custo dobrou o tempo de layout.
4. **Alinhamento por onset.** O onset é `double`. Procure erros de ponto
   flutuante com quialteras aninhadas (1/3 de 1/5), compassos aditivos e
   durações de 1/2048. A quantização usada é `(onset * 1024).round()` — ela é
   suficiente?
5. **`ScoreHitTester`.** As caixas são estimadas. Verifique se batem com o que é
   desenhado (acidentes, hastes, barras, ledger lines ficam fora da caixa?).
6. **Validação de `Pitch`.** Há `assert` no construtor const. Asserts só rodam em
   debug. Em release, o que acontece com dados inválidos?
7. **Numeração de compasso.** `_systemStaff` faz `orig.number ??= i + 1`, ou
   seja, **muta o modelo do usuário**. Isso é aceitável? Quebra anacruse?
8. **Export MusicXML.** Muita coisa nova é emitida. Valide o XML resultante
   contra o schema MusicXML 4.0 se possível, e importe-o de volta.
9. **Testes que passam por tolerância frouxa.** Releia cada `closeTo`,
   `lessThan`, `greaterThan` em `test/invariants/` e pergunte se a tolerância
   esconde um erro real.
10. **Os goldens regravados.** Abra as 39 imagens modificadas. Julgue-as. Uma
    delas está errada?
11. **O compensador óptico foi LIGADO** junto com o motor de espaçamento
    (`enableOpticalSpacing` é `true` por padrão). Ele mexe em todo espaçamento.
    Verifique se as regras que ele aplica (hastes alternadas, pausa antes de
    nota com haste para cima, transição de duração) estão corretas segundo Gould
    — e não apenas se o resultado "parece bom".
12. **`ScoreRasterizer` duplica a geometria de `MusicScorePainter`** (baseline de
    sistema, agrupamento, folga). Duas implementações da mesma coisa é
    exatamente o padrão que gerou o achado F-12. Elas concordam hoje?
13. **`GrandStaffPainter.totalHeight` e `LayoutEngine.calculateTotalHeight`** são
    duas fórmulas de altura. Idem.

## B.3 Nota de remediação

Ao final da Parte B produza:

```
ACHADOS VERIFICADOS: N
  CONFIRMED FIXED    : n1  (n1/N = xx%)
  PARTIALLY FIXED    : n2
  NOT FIXED          : n3
  REGRESSED          : n4
  UNVERIFIABLE       : n5

NOTA DE REMEDIAÇÃO = (n1 + 0.5*n2) / N
ACHADOS NOVOS INTRODUZIDOS PELA REMEDIAÇÃO: n4 + (novos encontrados na Parte A)
```

E responda: **a remediação melhorou ou piorou o projeto, e por quê?**

---

# FORMATO OBRIGATÓRIO DOS ACHADOS

Para cada problema importante:

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

1. **EXECUTIVE SUMMARY** — o verdadeiro estado do projeto hoje
2. **NOTA DE REMEDIAÇÃO** — a matriz da Parte B, completa, linha por linha
3. **REALIDADE VS DOCUMENTAÇÃO** — divergências (obrigatória)
4. **ARQUITETURA ATUAL** — sistema reconstruído
5. **MUSIC MODEL**
6. **ENGRAVING**
7. **LAYOUT ENGINE**
8. **SMuFL / BRAVURA**
9. **MUSICXML**
10. **MEI**
11. **MIDI / PLAYBACK**
12. **GREGORIAN**
13. **POLYPHONY / MULTI-STAFF**
14. **FLUTTER ARCHITECTURE**
15. **PERFORMANCE**
16. **TESTES** — incluindo *o que os novos testes NÃO testam*
17. **SEGURANÇA**
18. **API PÚBLICA**
19. **DÍVIDA TÉCNICA** — por categoria
20. **TOP 10 PROBLEMAS** — ordenados por `impacto × probabilidade × dano arquitetural`
21. **MATRIZ DE MATURIDADE** — nota 0–10 para: modelo musical, engraving, layout, SMuFL, Bravura, MusicXML, MEI, JSON, MIDI, playback, gregoriano, polifonia, multi-staff, performance, arquitetura Flutter, testes, golden tests, segurança, API pública, documentação, escalabilidade, prontidão para editor profissional. **Compare cada nota com a da auditoria de 2.6.0** (ver `doc/AUDITORIA_FORENSE_2026-08-21.md` §20) e explique cada mudança
22. **TESTES QUE PRECISAM SER CRIADOS**
23. **PLANO DE CORREÇÃO** — Fase 0 emergência, 1 críticas, 2 arquiteturais, 3 engraving profissional, 4 interoperabilidade, 5 editor profissional
24. **ARQUITETURA RECOMENDADA**
25. **VEREDITO FINAL** — responda objetivamente:
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
    11. **A remediação da 2.7.0 foi honesta?** (as alegações correspondem ao código?)

---

# REGRA FINAL — SEJA ADVERSARIAL

Quero que você tente **QUEBRAR** o projeto. Não tente provar que funciona; tente
provar que **não funciona**.

- Se não conseguir encontrar um problema numa área, diga
  *"Não encontrei evidência de falha nesta área"* — nunca *"está perfeito"*.
- Se não conseguir provar uma funcionalidade, marque **UNKNOWN**.
- Se encontrar uma implementação aparentemente correta, procure seus edge cases.
- Se encontrar um teste passando, descubra o que ele **não** testa.
- Se encontrar uma abstração elegante, verifique se ela preserva a semântica
  musical.
- **Se encontrar uma correção recente, procure a regressão que ela causou.**
- Se encontrar um magic number, descubra de onde ele veio.
- Se encontrar uma classe aparentemente completa, procure os caminhos que nunca
  chegam até ela.
- Se encontrar uma feature documentada, percorra o caminho inteiro
  `INPUT → PARSER → MODEL → NORMALIZATION → LAYOUT → ENGRAVING → RENDER → OUTPUT`
  e só a considere implementada se ele estiver funcional.

Se precisar escolher entre ser gentil e ser tecnicamente preciso: **SEJA PRECISO.**
Se precisar escolher entre velocidade e profundidade: **SEJA PROFUNDO.**
Se precisar escolher entre assumir e provar: **PROVE.**

---

# PRINCÍPIO MÁXIMO

A pergunta central não é *"o código parece bom?"*, é:

> **"Este código representa corretamente a teoria musical, preserva a semântica
> da partitura, produz engraving visualmente correto, mantém interoperabilidade,
> possui arquitetura sustentável e pode servir de base para um editor
> profissional de partituras?"**

E, desta vez, também:

> **"As correções alegadas são reais, completas e livres de regressão?"**
