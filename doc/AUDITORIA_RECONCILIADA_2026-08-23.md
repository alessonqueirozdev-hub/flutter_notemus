# Auditoria reconciliada e programa de remediação — 2.7.1 → 2.8.0

**Data:** 2026-08-23
**Base:** `5e58fab` (2.7.1), branch `sprint/forensic-remediation-2.7.1`
**Entradas:** duas auditorias forenses adversariais independentes da 2.7.1, produzidas em
sessões separadas e sem contato entre si:

| Documento | Achados |
|---|---|
| [`AUDITORIA_FORENSE_2026-08-22_2.7.1.md`](AUDITORIA_FORENSE_2026-08-22_2.7.1.md) | 42 (R-01…R-42) |
| [`AUDITORIA_FORENSE_2026-08-22_REAUDIT_2.7.1.md`](AUDITORIA_FORENSE_2026-08-22_REAUDIT_2.7.1.md) | 20 (A-01…A-20) |

Este documento existe porque o auditor de fechamento registrou como **UNKNOWN** a
ausência de um mapeamento canônico entre os dois conjuntos. É esse mapeamento.

---

## 1. Por que as duas auditorias discordaram

As duas usaram a **mesma fórmula** (`(n1 + 0,5·n2)/33`) sobre o **mesmo N = 33** e
chegaram a **0,742** e **0,939**. A diferença não é de medição — é de critério, e
nenhuma das duas leu a matriz da outra:

- **Critério nominal (E):** a linha é CONFIRMADA se o invariante vale *no caminho que
  a própria alegação nomeia*. Um caminho vizinho que falha vira achado novo.
- **Critério universal (U):** a linha só é CONFIRMADA se o invariante vale em *toda a
  classe* que a alegação implica — todos os formatos de entrada da mesma API, todos os
  compassos, todos os caminhos de renderização.

Reconciliado, pós-adjudicação: **0,864 (E)** e **0,712 (U)**. A nota muda com o
critério; o defeito não muda com nada.

## 2. Como as divergências foram resolvidas

13 divergências diretas foram adjudicadas **executando código**, não comparando prosa.
Placar: relatório A correto em 5 decisões, B em 0, 2 empates por caminhos de código
diferentes, 4 achados exclusivos de B confirmados, 2 confirmados com a lista corrigida.
Nenhum UNKNOWN.

**Números de manchete dos dois lados que NÃO reproduzem** (registrados porque uma
auditoria que só publica o que confirmou não é auditável):

| Alegação | Publicado | Medido |
|---|---|---|
| A: ponta de haste fora da caixa de hit-test | 70,8 px | **80,02 px** (o cálculo omitia `att.dy = ±2,016`) |
| A: layout de 400 compassos | 94,5 ms | é a **segunda chamada a frio**; mediana quente 33,8 ms |
| B: razão colcheia:semicolcheia em quiáltera | 1,414 | **1,263** (o piso de 1,4 SS torna 1,414 inatingível) |
| B: razão no modelo `logarithmic` | 1,816 | **1,137** — não reproduz em nenhuma configuração |

**Retratações confirmadas como corretas:** a retirada de N-27 (colchete de quiáltera
não colinear) procede — as duas metades ficam sobre uma reta com Δ = −0,045 px,
diferença de inclinação 0,000567. A retirada de NOVO-6 (estrutura aditiva do MEI)
também procede.

**Retratação minha:** cheguei a registrar que `gregorian_renderer.dart:725` usava a
família `'Greciliae'` sem qualificação de pacote. **Falso** — a linha seguinte passa
`package: 'flutter_notemus'`. Meu grep cortou a linha. Retirado antes de propagar.

## 3. Cobertura cruzada

| | Achados | Observação |
|---|---:|---|
| Só o relatório A viu | 32 de 50 (64%) | **7 dos 9 P1**; em 5 deles B declarou a linha corrigida |
| Só o relatório B viu | 11 de 50 (22%) | inclui **M-09**, um P1 que A perdeu inteiro |
| Os dois viram | 7 de 50 (14%) | |
| Nenhum dos dois viu | 2 | `symbol_and_text_renderer.dart:863` e `:945` — só a varredura exaustiva os achou |

---

## 4. Lista mestra M-01…M-50 e situação final

Legenda: **✅** corrigido e medido · **◐** parcial · **○** aberto · **⏸** adiado por decisão

### P1 — bloqueadores

| ID | Origem | Defeito | Antes → depois (medido) | Est. |
|---|---|---|---|---|
| M-01 | R-01 | Clave no meio de compasso dentro de uma voz é invisível à restatement de sistema | sys3–9 restatavam `treble@30` com a clave de fá em vigor → todos restatam `bass@30`; nos **dois** caminhos (grand staff e pauta única) | ✅ |
| M-02 | R-02 | Export MusicXML não emite `<notations><tuplet>` | valor do compasso 0,5 → 0,625 no round-trip → **0,5 → 0,5** | ✅ |
| M-03 | R-03 | `<time-modification>` sem `<tuplet>` ignorado no import | tercina de semínimas a 960 ticks → **640 ticks**; compasso 1,0 → **0,75** correto | ✅ |
| M-04 | R-04 | Apagiaturas consomem tempo musical no layout | compasso 1,1875 → **1,0**; onsets deslocados 0,1875 → **0/0,25/0,5/0,75** | ✅ |
| M-05 | R-05 | Haste de acorde travada em 6,0 SS | spans 7/14/21/28 meias-posições todos a 6,0 SS → **7,00/10,50/14,00/17,50 SS**; alcança as duas cabeças | ✅ |
| M-07 | R-09+R-42 | 26 combinações métrica×figura sem nenhuma barra; 6/2, 9/2, 12/2, 15/2 com barras de doze | varredura de 127 combinações: **grupos > 8 = 0**, **compassos ≥2 notas sem barra = 0** | ✅ |
| M-09 | A-01 | `OctaveMark` não desloca a altura impressa; `octaveShift` sem consumidor | C6 sob 8va/8vb/15ma/15mb/22da/22db todos em `staffPos=8` → **1 / 15 / −6 / 22 / −13 / 29**; tinta moveu **+42,5 px** = 1 oitava; MIDI inalterado | ✅ |
| M-21 | R-11=A-03 | Round-trip JSON duplica o bloco de abertura | 2 claves + 2 armaduras + 2 fórmulas desenhadas → **1 de cada**, estável na 2ª viagem | ✅ |
| M-26 | A-04 | A pintura muta `Note.beam`; export depende de ter exibido antes | XML 3346 → 3970 chars, `<beam>` 0 → 16 → **idêntico nos três pontos**, `Note.beam` nulo | ✅ |

### P2 — sérios

| ID | Origem | Defeito | Antes → depois | Est. |
|---|---|---|---|---|
| M-06 | R-06=A-12 | MEI descarta nota sem `@oct` em silêncio | 0 notas, sem exceção → **`FormatException`** nomeando o atributo; nota de tablatura tolerada com aviso | ✅ |
| M-08 | R-10 | Piso de slot por filho: golden congelou regressão de legibilidade | vão de tinta 15 px → 2 px (2.7.1) → **9 px (0,75 SS)**, 3× o `minGap` do próprio pacote | ✅ |
| M-10 | R-07 | Acidentes dentro de quiáltera colidem | folgas −20,78 / −12,96 / −11,81 / −12,91 px → **+3,00 px (0,25 SS) nas quatro** | ✅ |
| M-11 | R-08 | `TupletRenderer` ignora `accidentalDecisions` | 3 sustenidos impressos onde o resolvedor decidiu `hide` → **1 sustenido** | ✅ |
| M-12 | R-12 | PDF de grand staff: todos os sistemas numa página, altura cortada | 60,2% da música perdida → **14/14 sistemas em 3–4 páginas** | ✅ |
| M-13 | R-13+A-07 | `renderGroupToPage` sem alargamento nem banding | canvas de 200 px para 1200 px de música; 15.168 px de altura → **largura = contentWidth**, banda por página, máximo documentado | ✅ |
| M-14 | R-14 | Hit-test estima a haste em 3,5 SS constantes | ponta 80,02 px fora da caixa, MISS em todas as posições → **HIT em ±20 e em acorde de span 28** | ✅ |
| M-15 | R-15 | Dois desenhadores de barra discordando entre si e do metadado | 0,400/0,600 SS vs 0,500/0,250 → **0,500/0,250 nos dois**, = `engravingDefaults` da Bravura | ✅ |
| M-16 | R-16 | Coluna de acidentes de acorde sub-reservada | 25,82 px fixos para 2/3/4/5 acidentes → **29,18/42,67/57,26/57,26 px**, igual ao que o renderer desenha (1e-9) | ✅ |
| M-17 | R-17 | Segunda em acorde deslocada no desenho, não no layout | C5-D5-E5 e C5-E5-G5 idênticos a 14,16 px → **28,89 px** com o deslocamento reservado | ✅ |
| M-18 | R-18 | MEI `clef.dis`/`clef.dis.place` ignorados | clave de oitava importava como simples → **`treble8vb`, `octaveShift=−1`** | ✅ |
| M-19 | R-19 | MEI `trans.semi`/`trans.diat` ignorados | `transposition=null`, MIDI 60 → **`Transposition(−1,−2)`, MIDI 58** | ✅ |
| M-20 | R-20 | JSON perde nome/abreviação/linhas/transposição da pauta | os quatro nulos → **os quatro preservados** | ✅ |
| M-22 | R-21 | `crossStaffMove` só honrado em grupos com barra | nota solta ficava na pauta de origem → **desenhada na pauta destino** | ✅ |
| M-24 | R-23=A-06 | Sem comprimento máximo de haste nem quebra por âmbito | 9,03 SS medido → cap de 5,50–8,50 SS por nº de barras + divisão acima de 12 graus | ✅ |
| M-25 | R-24/25/26 | `group-abbreviation` perdido; `BracketType.none` vira `bracket` | 3/3 grupos com `abbreviation=null` → **preservados**; `<group-symbol>none` emitido e reimportado | ✅ |
| M-27 | A-05 | Numeral da quiáltera fora da linha do colchete | 1,0052 SS (plano) / 1,0799 SS (inclinado) fora, vão com 0 de 2340 px de tinta → **numeral dentro da interrupção, sobre a linha** | ✅ |
| M-28 | A-08 | `GrandStaff` sem rolagem horizontal | 0 scrollables, ~99,5% da música inalcançável → **`maxScrollExtent` == `contentWidth`** | ✅ |
| M-29 | A-11/16/17 | 29 entradas MusicXML malformadas aceitas em silêncio, zero avisos | `grep "warn" lib/src/parsers/` = 0 em 5.935 linhas → **canal `warnings`**, 9 entradas → 12 avisos, 3 rejeitadas | ✅ |
| M-30 | A-13+R-30 | 6 sítios de texto burlam a cadeia de fontes; escotilha inerte | tinta 14.942 px com e sem injeção (inerte) → **14.942 → 6.886 px**, caixas `.notdef` 2 → 0 | ✅ |
| M-31 | R-31 | Grade de quiáltera satura: 10 de 15 durações no mesmo slot | todas a 1,4000 SS → **razão 1,4142 exata em todo par adjacente**, e entre quiálteras do mesmo compasso (1,0000 → **1,4142**) | ✅ |
| M-37 | A-09 | `PdfExporter`/`ScoreRasterizer`/`GrandStaffPainter` fora da API pública | 0 de 26 exports alcançavam → **25 tipos resolvem pelo barril** | ✅ |
| M-38 | R-40 | Quiáltera com acorde ou pausa nunca gera barra | `[start,inner,end]` impossível → acorde e pausa entram; 128ª e menores também | ✅ |
| M-46 | A-08 | Compasso sobrecheio transborda em silêncio | 2,03× a viewport sem diagnóstico → **rolagem cobre + `LayoutEngine.warnings` nomeia o compasso** | ✅ |
| M-49 | — | Sinal de `<octave-shift>` invertido no import MusicXML | `down`→8vb, `up`→8va (todos os braços) → **`down`→8va, `up`→8vb**, conforme a spec | ✅ |

### P3/P4

| ID | Defeito | Situação |
|---|---|---|
| M-23 | Colchete/numeral de quiáltera cortados na borda do canvas | ✅ 74 px na linha 0 → **0 px**, para oitava 6 e oitava 3 |
| M-32 | `staffBaselineY` é local à pauta sob `alignedSystem()` | ✅ dartdoc corrigido; delta de 132,0 px documentado |
| M-33 | Larguras de cabeça por `DurationType` | ◐ **metade fechada**: semibreve/breve reservavam 1,18 SS contra 1,688 e 2,396 reais → agora do metadado; orçamento do invariante caiu de 27,0/71,0 px para **3,0 px** (antialiasing). Aberto: a **bandeirola** pinta 0,93 SS além da reserva — separar "avanço para espaçamento" de "extensão pintada" é mudança de design, não de constante |
| M-34 | `stemExtensionPerBeam` literal | ✅ 0,5 → `beamThickness + beamSpacing` = 0,75 |
| M-35 | Espessura do colchete usava `stemThickness` | ✅ 0,1199 → **0,1598 SS** = `tupletBracketThickness` |
| M-36 | `contentWidth` conta o `leftExtent` duas vezes | ✅ |
| M-39 | `MidiMapper._activeClef` write-only | ✅ removido |
| M-40 | `probe/` polui `dart analyze` na raiz | ✅ 470 → **0** |
| M-41 | `MusicTextFallback` inalcançável | ✅ exportado |
| M-42 | Teste do N-22 não invocava o motor; 9 achados sem teste; N-04 com `lessThan(10.0)` | ✅ reescritos e fortalecidos |
| M-43 | Lei √2 em duas fontes de verdade | ✅ |
| M-44 | XXE / billion laughs | ✅ reverificado negativo por execução (5 ms, sem vazamento) |
| M-45 | Texto do ADR-003 impreciso | ✅ `Pitch` é **invariante à clave de oitava**, não "a altura soante" |
| M-47 | Larguras de pausa fixas em 1,5 SS | ✅ do metadado |
| M-48 | `needsLedgerLines(±5)` discorda de `getLedgerLinePositions` | ✅ concordam de −12 a +12 |
| M-50 | Versão/CHANGELOG/README inconsistentes | ✅ 2.8.0 nos três |
| ADR-005 #8 | `layout()` escreve `Measure.inheritedTimeSignature` no modelo do chamador | ✅ **`Measure.add` ACEITA antes, depois do layout e depois do paint** — era ACEITA→lança |
| Behind Bars p.201 | `TupletBracket.shouldShow` sem chamador de produção | ✅ ligado ao renderer; grupo com barra imprime só o numeral |

### Adiados por decisão, não por esquecimento

| Item | Motivo |
|---|---|
| ⏸ `Duration` do pacote sombreia `dart:core.Duration` | Quebra de API pública — pertence a uma 3.0, não a uma release de remediação |
| ⏸ Empacotar uma face de texto real | O repositório não tem nenhuma face OFL em `assets/`; a correção entregue é a escotilha programática + documentação honesta da dependência do host |
| ⏸ Layout fora da UI thread / isolates | Refatoração arquitetural, fora do escopo |
| ⏸ Exportador MEI | Nunca existiu; o README nunca prometeu round-trip MEI |

---

## 5. O que o programa quebrou e como foi pego

Registrado porque é o dado mais útil do ciclo inteiro.

| Regressão | Introduzida por | Pega por | Estado |
|---|---|---|---|
| Span de oitava vazava entre vozes de um `MultiVoiceMeasure` | Wave 1 (M-09) | Verificador da wave 1 | ✅ corrigida na wave 2 |
| Âncora de onset do grand staff arrastada pela apagiatura (43,32 px) | Wave 2 (M-04) | Verificador da wave 2 | ✅ corrigida na wave 3 |
| **Barras entre pautas mortas** — `_crossStaffGroups` devolvia zero corridas | Wave 4 (M-26) | **Auditor final da wave 4** | ✅ corrigida na wave 4 |
| Desempenho 1,19×–2,89× mais lento | Wave 4 (ADR-005) | Auditor final da wave 4 | ✅ recuperado na wave 5 (paridade, ±10%) |
| `beamOf` não consultava `tupletBeams` | Wave 4 | Selo da wave 5 | ✅ corrigida na wave 5 |

**A lição do ciclo:** a regressão mais grave (barras entre pautas) foi **corretamente
diagnosticada por duas waves independentes, cada uma com o patch literal escrito no
campo de observações, e nenhuma das duas foi aplicada**. Sobreviveu até a auditoria
final. `notes` não é executável.

Daí o item de maior valor do lote inteiro: o **guarda executável do ADR-005**
(`test/invariants/adr005_guard_test.dart`), que varre `lib/` e falha em (a) qualquer
escrita `.beam =` em `layout/` ou `rendering/`, e (b) qualquer leitura nua de `.beam`
fora de uma lista de permissão explícita e comentada. Foi testado adversarialmente:
reintroduzindo o defeito histórico, o teste fica vermelho nomeando arquivo, linha, a
linha de código ofensora e o remédio.

---

## 6. Protocolo de verificação

Cada correção passou por três estágios independentes:

1. **Implementação** — agente com propriedade exclusiva de arquivos, obrigado a
   reproduzir o defeito por medição antes de corrigir.
2. **Verificação adversarial** — agente separado que re-mede tudo com sondas próprias,
   lê cada `expect` removido ou alterado e julga se o teste antigo fixava o defeito ou
   se foi quebrado para a mudança passar.
3. **Julgamento de golden** — os 12 goldens que se moveram foram comparados ampliados
   (≥4×, NEAREST) contra a versão anterior, com o veredito *melhor / igual / pior* por
   imagem e a correção que causou o movimento nomeada. **Regra: um golden julgado pior
   fica vermelho.** Nenhum ficou.

**Testes:** 821 → **1010** (+189). Todos verdes.
**Analisadores:** `dart analyze lib`, `dart analyze` (raiz) e `flutter analyze example`
sem problemas. Na raiz eram **470** no início.
**Goldens:** 53 no total, **12 regravados** com veredito medido por imagem.

## 7. O que continua aberto

| Item | Sev | O que falta |
|---|---|---|
| Playback nativo | P3 | Existe de verdade só no Android (`native_audio_engine.cpp`); iOS, macOS, Linux e Windows são stubs honestos que devolvem `false` de `nativeIsReady`. Fechar exige AVAudioEngine, WASAPI/XAudio2 e ALSA/PulseAudio — código nativo que **não pode ser compilado nem testado neste ambiente**, e escrevê-lo às cegas produziria exatamente a alegação não verificável que este programa existe para eliminar |
| Layout fora da UI thread | P3 | `GrandStaffPainter` faz o layout no construtor. Tirá-lo de lá é viável; **isolates não são**: `LayoutEngine._measuredTextWidth` usa `TextPainter`, que exige o engine do Flutter e não roda em isolate. Offload real exigiria substituir a medição de texto por métrica pura em Dart — perda de fidelidade, não ganho |
| Face de texto não embarcada | P3 | `assets/` não contém nenhuma face OFL. A escotilha `MusicTextFont.use` está pronta e provada (tinta 14.942 → 6.886 px, caixas `.notdef` 2 → 0); fechar de vez exige alguém colocar um arquivo de fonte no repositório |
| Espaçamento de quiáltera ignora o `SpacingModel` | P3 | Trade-off **declarado** no dartdoc e no commit `fa2cce5`: fechá-lo exige dar um motor de espaçamento ao `TupletRenderer`, ou os dois lados divergem de novo |
| Pipeline gregoriano apartado | P3 | Identidade, onset, hit-test e export PDF do CMN não o alcançam |
| Exportador MEI | P4 | Nunca existiu; o README nunca prometeu round-trip MEI |

**Fechados depois do relatório de fechamento** (§4 atualizada): `M-33` por inteiro
— avanço de cabeça por `DurationType`, extensão pintada separada do avanço para a
bandeirola, e reserva de pausa centrada como a tinta. Os sete casos que carregavam
orçamento no invariante `elementWidth × tinta` passaram de 27,0/71,0/47,0/47,0/
29,0/28,0/43,0 px para **3,0 px cada** — antialiasing. Mais `MusicDuration` como
nome canônico ao lado do alias legado `Duration`.

---

## 8. Matriz de maturidade

| Área | 2.7.0 | 2.7.1 | **2.8.0** | Δ |
|---|---:|---:|---:|---:|
| Modelo musical | 7 | 7 | **7,5** | +0,5 |
| Engraving | 5,5 | 5 | **7** | +2 |
| Layout | 5 | 5,5 | **7** | +1,5 |
| SMuFL | 7,5 | 7 | **8** | +1 |
| Bravura | 8 | 8 | **8** | 0 |
| MusicXML | 5,5 | 5,5 | **7,5** | +2 |
| MEI | 6,5 | 6 | **7,5** | +1,5 |
| JSON | 5 | 6 | **7,5** | +1,5 |
| MIDI | 8 | 8,5 | **8,5** | 0 |
| Playback | 3,5 | 3,5 | **3,5** | 0 |
| Gregoriano | 8 | 8 | **8** | 0 |
| Polifonia | 5 | 5,5 | **6,5** | +1 |
| Multi-staff | 5 | 5 | **6** | +1 |
| Performance | 4 | 6 | **6** | 0 |
| Arquitetura Flutter | 4,5 | 4,5 | **4,5** | 0 |
| Testes | 7 | 7 | **8,5** | +1,5 |
| Golden tests | 6,5 | 6 | **7,5** | +1,5 |
| Segurança | 7,5 | 7,5 | **8** | +0,5 |
| API pública | 5 | 5 | **6,5** | +1,5 |
| Documentação | 6 | 6,5 | **7,5** | +1 |
| Escalabilidade | 3 | 5 | **5** | 0 |
| Prontidão p/ editor | 4,5 | 5 | **6,5** | +1,5 |

**Média ponderada informal: ≈ 6,9 / 10** (era 5,8 na 2.7.0 e 6,0–6,7 nas duas frentes
da 2.7.1).

---

## 9. Veredito

O motor está mensuravelmente melhor, e as provas são de execução:

- o export é **byte-idêntico** antes e depois de layout e de paint — antes ia de 0 para
  16 tags `<beam>` só por olhar a partitura;
- o valor de um compasso com quiáltera volta **0,5** em vez de 0,625;
- hastes de acorde alcançam span de **28 meias-posições** em vez de travar em 6,0 SS;
- barras têm **0,500 SS de espessura e 0,250 SS de vão**, dentro e fora da quiáltera,
  batendo com o metadado da própria fonte;
- **26 combinações métrica×figura** que não produziam barra nenhuma agora produzem;
- o golden que a 2.7.1 regravou congelando uma colisão (vão de tinta de 2 px) hoje mede
  **9 px** e está coberto por um invariante que falha se voltar abaixo de 0,25 SS.

**Onde continua fraco:** o layout ainda roda no construtor do `CustomPainter`, sem
isolates; o playback continua em uma plataforma de seis; o gregoriano continua um
pipeline à parte; e o `Duration` do pacote ainda sombreia o de `dart:core`.

**A coisa de maior valor a fazer em seguida:** estender o padrão do guarda do ADR-005
às outras invariantes estruturais que este ciclo estabeleceu — largura reservada ≥ tinta
pintada, folga entre cabeças ≥ `minGap`, constante de gravação vinda do metadado. Foram
provadas uma vez, por sonda; enquanto não forem guardas executáveis, a próxima rodada
vai reencontrá-las num vizinho diferente.
