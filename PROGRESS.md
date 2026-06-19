# PROGRESS — Sprint de qualidade tipográfica (pré-ANPPOM)

> Diário de auditoria e correções da biblioteca `flutter_notemus` (v2.6.0).
> Cláusula de honestidade ativa: preferir "parcial" a "pronto"; sinalizar overclaims do artigo.
> Início do sprint: 2026-06-17.

---

## Como ler este arquivo

- **CONFIRMADO** = verifiquei pessoalmente no código (file:line citado).
- **A VERIFICAR** = achado do reconhecimento automatizado, ainda não confirmado de primeira mão; será confirmado antes de qualquer correção na Fase 2.
- Severidade: `ALTA` (impacto visual/correção alto e frequente) · `MÉDIA` · `BAIXA`.

---

## Fase 0 — Reconhecimento

### Ambiente e baseline (CONFIRMADO)

| Item | Estado |
|---|---|
| Toolchain | Dart 3.11.0 (stable) + Flutter instalado |
| `flutter pub get` | OK (lib + example) |
| **`flutter test`** | ✅ **447 testes passando** (baseline limpa) |
| `flutter analyze` | ainda não rodado nesta sessão (pendente) |
| Verovio (baseline externo p/ Fase 1) | ✅ instalado via `pip` — **v6.2.1**. Ferramenta **externa** de comparação; **não** entra nas dependências da lib (que permanece Dart puro). |
| Linhas de código (lib) | ~31.890 linhas Dart |

### Arquitetura — como o posicionamento é calculado (CONFIRMADO)

Pipeline: `Staff/Score → LayoutEngine → List<PositionedElement> → MusicScorePainter → StaffRenderer → Canvas`.

- **Unidade fundamental:** *staff space* (SS). `staffSpace` padrão = 12.0 px. Tudo é dimensionado em SS e multiplicado por `staffSpace`.
- **Sistema de coordenadas:** `StaffPositionCalculator` mapeia altura→`staffPosition` (meios-espaços; 0 = linha do meio, positivo acima). `toPixelY = baseline.dy − staffPosition * staffSpace * 0.5` (eixo Y do Flutter é invertido em relação à música).
- **Metadados SMuFL/Bravura:** `SmuflMetadata` (singleton) carrega `bravura_metadata.json` + `glyphnames.json` via `rootBundle` com prefixo `packages/flutter_notemus/...`. Fornece bounding boxes, *advance widths*, âncoras de haste (`stemUpSE`/`stemDownNW`) e `engravingDefaults`.
- **Espaçamento horizontal (mais sofisticado do que aparenta):**
  - Largura de compasso por cursor (`_calculateMeasureWidthCursor`), espaçamento mínimo nota-a-nota = 3.5 SS.
  - **Espaçamento rítmico proporcional à duração** — `IntelligentSpacingEngine` com 4 modelos; padrão `squareRoot` (`s = √(dur/menorDur)`), o mais próximo da tabela de Gould (validado por `compareAgainstGould()`).
  - Algoritmo dual-fase (textual anticolisão + duracional) + **compensação óptica** (alternância de haste, acidentes, pontos, feixes).
- **Skyline / colisão:** `SkyBottomLineCalculator` (grade de ocupação) e `CollisionDetector` (caixas delimitadoras O(n²)) existem e funcionam, mas **só são usados para elementos flutuantes** (dinâmicas, ligaduras, texto). **Não** estão integrados ao espaçamento nota-a-nota — colisão de notas é opt-in (`layoutWithCollisionDetection()`), não no caminho principal.
- **Justificação:** `_justifyHorizontally` (`layout_engine.dart:574-595`) redistribui a folga **proporcionalmente à posição** no sistema. Preserva os *ratios* de espaçamento do layout interno (não os "perde", como um achado automatizado sugeriu); o refinamento ausente é redistribuir a folga proporcional ao espaçamento *local*, não à posição. Impacto **baixo/médio**, não é um defeito grosseiro.

### Estado real das issues conhecidas (CONFIRMADO via código)

| Issue | Estado real |
|---|---|
| **#13 melisma** | Stub fixo de 1 SS desenhado; a extensão real até a próxima nota exige passe pós-layout (com contexto multi-nota). Confirmado em `OPEN_ISSUES.md:43-46` e na ausência de lógica multi-nota no renderer. |
| **#14 hífen entre sílabas** | Hífen colado à sílaba; centralização entre X de sílabas consecutivas exige passe pós-layout. Confirmado. |
| **Áudio nativo fora do Android** | Confirmado pendente — ver inventário "MIDI/áudio". |

---

## Fase 1 — Harness visual + corpus + inventário visual (CONCLUÍDA — infra)

### Harness golden headless (CONFIRMADO funcionando)
- `test/golden/_harness.dart` + `corpus.dart` + `corpus_golden_test.dart`.
- Renderiza o widget público real `MusicScore` headless e captura via `matchesGoldenFile` → serve como **gerador de figuras** (`--update-goldens`) **e** suíte de regressão.
- **2 armadilhas resolvidas no caminho** (ambas documentadas no harness):
  1. `pumpAndSettle` **trava 9+ min** no `CircularProgressIndicator` do `FutureBuilder` de metadados → usar `pump()`.
  2. **Fonte sob 2 nomes**: `base_glyph_renderer` usa `'Bravura'`; `bar_element_renderer` usa `'Bravura'`+`package:'flutter_notemus'` (→ `packages/flutter_notemus/Bravura`). Sem registrar ambos no teste, **clave/armadura/fórmula viram caixas**. _(Isto é uma inconsistência real da lib — ver R4.)_
- **14 casos** gerados (simple→complex), incluindo a Ode à Alegria com os **mesmos dados da figura do artigo**.

### Inventário VISUAL (confirmado por inspeção dos PNGs gerados)

| ID | Severidade | Defeito visual | Caso golden |
|---|---|---|---|
| **V1** ★ | ALTA | **Ligadura (slur) multi-nota renderiza quebrada em ~2 segmentos** em vez de um arco contínuo | `m05_slurs_ties` |
| **V2** ★ | ALTA | **Dinâmicas não renderizam** para nomes longos. Causa-raiz: `_getDynamicGlyph` (symbol_and_text_renderer.dart:404) só mapeia abreviações (`p/f/mf/pp/ff/mp/sforzando`); `DynamicType.piano/.forte/.mezzoForte/.fff/.ppp/...` → `null` → nada desenhado. **Os próprios exemplos do README não renderizam.** | `m07_dynamics` |
| **V3** ★ | MÉDIA-ALTA | **Acidentes em acordes amontoados/sobrepostos** — sem algoritmo de colunas (Behind Bars/Gould) | `c02_chromatic_chords`, `m02_accidentals` |
| **V4** | MÉDIA | **8 colcheias em 4/4 unidas num único feixe** — deveria quebrar em 2 grupos de 4 (na metade do compasso) | `s01_c_major_scale` |
| **V5** | BAIXA-MÉDIA | **Colchete de quiáltera posicionado longe, do lado oposto ao feixe** (estilo discutível; brackets horizontais são aceitáveis) | `m04_triplets` |

### Renderiza BEM (confirmado visualmente — não mexer)
Clave, armadura (sustenidos/bemóis), fórmula (C/comum), cabeças, hastes, feixe simples, bandeirolas, barras de compasso, linhas suplementares, notas pontuadas, pausas (semínima/compasso), **acidentes simples**, articulações (staccato/acento/tenuto/marcato), **polifonia a 2 vozes** (direção de haste por voz + alinhamento temporal), tríades, **ties**, quebra de sistema, import JSON (Ode).

### Baseline Verovio (Fase 1, item 3)
- Verovio 6.2.1 instalado. Comparação lado a lado pendente (próximo passo): exige versões MusicXML do corpus (a lib não exporta MusicXML; gerar à mão p/ casos-chave, a começar pela Ode).

---

## ⚠️ Lacunas entre documentação e código → **fechar no código** (decisão do autor)

> **Decisão (2026-06-17):** o autor optou por **NÃO rebaixar a documentação**, e sim **elevar o código** para cumprir/superar o que está documentado ("não devemos ter perdas"). Portanto cada item abaixo deixa de ser "corrigir o texto" e passa a ser **uma meta de implementação**. A honestidade permanece no rastreio interno: nunca marcar como "pronto" o que está parcial; provar cada ganho com teste/golden.
>
> **Reality-check honesto:** fechar TODAS as lacunas até "100% MEI v5 renderizado" inclui implementar renderização de **Mensural** e **Neuma** (sistemas de notação inteiros, com glifos/ligaduras específicos) — esse é o maior esforço e provavelmente não cabe num único sprint. Sequência por valor×viabilidade: importação de letras → tab/microtons → baixo cifrado/análise harmônica/tablatura (render) → mensural/neuma (render, maior risco).

### H1 — "100% MEI v5 conformance" é **overclaim** (CONFIRMADO) — ALTA
- README e `doc/MEI_V5_AUDIT.md` afirmam **100% de conformidade com MEI v5**, cobrindo os 4 repertórios (CMN, Mensural, Neuma, Tablatura) e recursos analíticos.
- **Realidade:** existe **modelo de dados** para esses módulos, mas:
  - **Renderização existe apenas para CMN.** Mensural, Neuma, Baixo cifrado e Análise harmônica são **classes de dados sem backend de renderização** (`grep` em `lib/src/rendering` retorna 0 ocorrências de `Neume`/`MensuralNote`).
  - **O parser MEI importa ~30% dos módulos.** Confirmei de primeira mão: **nenhum** parser referencia `lyric/verse/syl/neume/mensur/harm/fb/tab.fret/tabGrp`. Logo, **letras, neumas, mensural, baixo cifrado, análise harmônica e elementos de tablatura NÃO são importados de MEI/MusicXML**, apesar do "100%".
- **Recomendação p/ o artigo:** trocar "100% MEI v5" por algo como *"modelo de dados abrangente alinhado ao MEI v5; renderização e importação cobrem CMN (notação comum); demais repertórios são modelados mas ainda não renderizados/importados"*.

### H2 — Letras (lyrics) **não são importadas** de MusicXML nem MEI (CONFIRMADO) — ALTA
- O modelo/API suporta `Syllable`/`Verse`, e a renderização desenha sílabas. Mas **a importação ignora `<lyric>` (MusicXML) e `<verse>/<syl>` (MEI) silenciosamente**.
- Consequência: letras só funcionam via API Dart, não por importação de arquivos.

### H3 — Exportação PDF é **placeholder** (CONFIRMADO via OPEN_ISSUES + recon) — MÉDIA
- `pdf_exporter.dart` exporta metadados, mas a "partitura" é apenas 5 linhas de pauta vazias (`// TODO: Implement actual music rendering`). Já honesto em OPEN_ISSUES #2; o artigo não deve listar "export PDF da partitura" como pronto.

### H4 — Áudio nativo: só Android, e mesmo assim limitado (CONFIRMADO via recon) — MÉDIA
- iOS/macOS/Windows: métodos de playback são *no-ops*. Linux/Web: sem implementação localizada (apesar de registrados no `pubspec`).
- Android: funciona, mas é síntese por **osciladores** (sine/triangle/saw/square); SoundFont é aceito na API mas **nunca carregado/usado**. Metrônomo com frequências fixas.
- README diz "Android ativo; outros pendentes" — razoavelmente honesto, mas "configured" superdimensiona Linux/Web.

### H5 — `EngravingRules` (40+ constantes) é majoritariamente código morto (CONFIRMADO, com ressalva) — BAIXA
- A classe **é** usada — mas **apenas** pelo `SlurCalculator`/`SlurRenderer` (ligaduras/ties). Os demais primitivos (hastes, feixes, espaçamento) **não** a consomem; usam valores próprios ou metadados diretamente. Não é "nunca usada", como um achado automatizado disse — é **subutilizada**.

---

## Inventário de defeitos priorizado (guia da Fase 2)

> Priorização: impacto visual × frequência × **baixo risco de regressão**. Itens marcados ★ = candidatos de maior valor para o sprint.
> Todos serão **confirmados de primeira mão** e cobertos por golden test antes/depois.

### Tipografia / engraving (núcleo do §6 do artigo)

| # | Severidade | Defeito | Evidência (A VERIFICAR salvo indicado) | Risco |
|---|---|---|---|---|
| E1 ★ | MÉDIA | **Empilhamento de acidentes em acordes** não evita cair sobre linha de pauta; sem ordem de empilhamento à esquerda canônica | `chord_renderer.dart:146-169` | baixo-médio |
| E2 ★ | MÉDIA | **Colchete de quiáltera nunca é angulado** — desenha só linhas horizontais; campo `TupletBracket.slope` existe e é ignorado | `tuplet_renderer.dart:204-267`; `tuplet_bracket.dart:29-30` | baixo |
| E3 ★ | MÉDIA | **Inclinação de feixe pode escapar do clamp** após correção de direção melódica (inversão de sinal) | `beam_analyzer.dart:190-198` | baixo |
| E4 | MÉDIA | **Espessura/gap de feixe hardcoded** (0.4/0.60 SS) em vez de `engravingDefaults` (beamThickness 0.5, beamSpacing 0.25) | `beam_renderer.dart:29-31` | baixo (muda aparência de feixes) |
| E5 ★ | MÉDIA | **Ponto de aumento**: espaçamento hardcoded (1.0/0.6 SS) sem metadado; sem folga óptica quando o ponto cai sobre/junto à linha | `dot_renderer.dart:51,54` | baixo |
| E6 | BAIXA | **Linha suplementar**: extensão (0.4 SS) hardcoded, não usa `legerLineExtension` do SMuFL | `ledger_line_renderer.dart:68` | baixo |
| E7 | BAIXA | **Acidente vs. linha suplementar**: sem detecção de sobreposição em notas muito agudas/graves com acidente | `accidental_renderer.dart` | baixo |
| E8 | MÉDIA | **Forma da ligadura (slur)** é fixa (`altura ∝ √comprimento`), sem tensão adaptativa; **sem colisão horizontal** com notas/hastes intermediárias | `slur_calculator.dart` (layout) | médio-alto (slurs são delicados) |
| E9 | ALTA | **Melisma (#13)** — stub de 1 SS; precisa passe pós-layout até a próxima nota | `OPEN_ISSUES #13` (CONFIRMADO) | médio |
| E10 | ALTA | **Hífen (#14)** — hífen colado; precisa centralização pós-layout entre sílabas | `OPEN_ISSUES #14` (CONFIRMADO) | médio |
| E11 | BAIXA | **Largura de tuplet ingênua** (`numElements * 2.5 SS` constante), ignora durações internas | `layout_engine.dart:1101-1107` | médio |
| E12 | BAIXA | **Justificação** redistribui folga ∝ posição, não ∝ espaçamento local | `layout_engine.dart:574-595` (CONFIRMADO) | médio (afeta todas as figuras) |

### Robustez / correção (não-visual, baixo risco)

| # | Severidade | Defeito | Evidência | Risco |
|---|---|---|---|---|
| R1 ★ | MÉDIA | `getEngravingDefault()` **quebra com null** (sem null-check); existe variante segura `getEngravingDefaultValue()` | `smufl_metadata_loader.dart:68-71` | baixíssimo |
| R2 | BAIXA | Tolerância de capacidade de compasso fixa (0.0001) pode acumular erro em pontos/quiálteras | `measure.dart:89-91` | baixo |
| R3 | BAIXA | `Tuplet.getModifiedDuration()` não valida soma das durações vs. ratio | `tuplet.dart:82-94` | baixo |
| R4 ★ | MÉDIA | **Referência de fonte inconsistente**: `'Bravura'` (sem package) nos primitivos vs. `'Bravura'`+`package` em clave/armadura/fórmula. Apps que carregam só um dos nomes veem metade dos glifos como caixas. Unificar. | base_glyph_renderer.dart:106 vs bar_element_renderer.dart:236-238 (CONFIRMADO) | baixo-médio |

### Importação (Fase 3)

| # | Severidade | Defeito | Evidência | Risco |
|---|---|---|---|---|
| I1 ★ | ALTA | **MusicXML `<lyric>` ignorado** (letras não importam) | parsers sem `lyric` (CONFIRMADO) | baixo-médio |
| I2 | MÉDIA | **MusicXML `divisions` ignorado** — durações podem ficar imprecisas se `divisions` varia | recon | médio |
| I3 | MÉDIA | **MEI `<verse>/<syl>` ignorado** | parsers sem `verse/syl` (CONFIRMADO) | baixo-médio |
| I4 | BAIXA | Microtons em MusicXML/MEI não importados (só acidentes simples/duplos) | recon | baixo |
| I5 | — | Módulos MEI não-CMN (mensural/neuma/tab/harm/fb) não importados | CONFIRMADO (ver H1) | documentar, não "implementar" |

### Testes / evidência (Fase 4)

| # | Severidade | Lacuna | Evidência |
|---|---|---|---|
| T1 ★ | ALTA | **Zero golden tests / zero harness de PNG.** Asserções 100% procedurais (`returnsNormally`), nunca pixels | `grep golden` = 0; `pubspec` sem `golden_toolkit` (CONFIRMADO) |
| T2 | MÉDIA | Sem validação visual de slurs/tuplets/feixes (só endpoints/matemática) | recon |

---

## Pontos fortes reais (para retrato equilibrado no artigo)

- Espaçamento proporcional à duração com modelo `squareRoot` validado contra Gould; dual-fase + compensação óptica.
- Anexação de haste/bandeirola derivada de **âncoras SMuFL** + meia-espessura de haste, escalando proporcionalmente.
- Cálculo de comprimento de haste segue Behind Bars (regra da linha do meio; extensão por feixe).
- Modelo musical rico e notação-agnóstico (permitiu o renderer Jianpu paralelo).
- Suíte de 447 testes (unitários/algorítmicos) verde e abrangente em lógica de posicionamento.

---

## Plano de execução (fases restantes)

- **Fase 1:** harness headless de PNG (via `matchesGoldenFile` + fonte Bravura no `setUpAll`) que serve **simultaneamente** como gerador de figuras (`--update-goldens`) e suíte de regressão (Fase 4). Corpus progressivo (simples→complexo). Baseline Verovio (SVG→PNG) lado a lado.
- **Fase 2:** correções priorizadas (★ primeiro), uma por commit, com golden antes/depois.
- **Fase 3:** robustez de importação MusicXML/MEI (I1/I3 letras; I2 divisions).
- **Fase 4:** promover corpus a suíte golden no CI (com nota honesta sobre dependência de plataforma dos goldens).
- **Fase 5:** `docs/CAPABILITIES.md` (suportado/parcial/não) + `docs/EVALUATION_NOTES.md` (flutter_notemus vs Verovio).

## Decisões tomadas (autor, 2026-06-17)

1. **Escopo Fase 2 = MÁXIMA COBERTURA.** Atacar todo o inventário possível, aceitando maior risco de regressão visual (figuras serão regeradas conforme necessário).
2. **Overclaims = fechar no código, não rebaixar docs.** Implementar render/import faltante para que H1/H2 se tornem verdadeiros; sem perda de capacidade documentada. Ver seção "Lacunas".
3. **Corpus = inclui MusicXML públicos** (suíte MusicXML / regressões LilyPond) + casos próprios + adaptados dos exemplos.

### Ordem de ataque acordada
- **Onda A (infra):** harness golden headless + corpus + baseline Verovio. _(linchpin — sem isso, nada é comprovável)_
- **Onda B (import, fecha H2):** I1 MusicXML `<lyric>`, I3 MEI `<verse>/<syl>`, MEI `tab.fret/tab.string`, I2 `divisions`, I4 microtons.
- **Onda C (engraving, máx. cobertura):** R1, E3, E4, E1, E2, E5, E6, E7, E11, E12, E8, E9 (#13), E10 (#14).
- **Onda D (render não-CMN, fecha H1):** baixo cifrado, rótulos de análise harmônica, tablatura; depois mensural/neuma (maior risco).

---

## Registro de mudanças do sprint

| Commit | Item | O quê | Evidência |
|---|---|---|---|
| `docs:` PROGRESS | Fase 0 | Reconhecimento + inventário | — |
| `test(golden):` harness | Fase 1 | Harness headless + corpus (14) + baselines | 14 goldens |
| `fix(smufl):` R1 | **R1 ✅** | `getEngravingDefault` null-safe (não quebra mais com chave/seção ausente) | `test/smufl/engraving_default_test.dart` (3 testes) |
| `fix(rendering):` V2 | **V2 ✅** | Mapa completo `DynamicType→glifo` + fallback de texto; antes só ~7 abreviações renderizavam | golden `m07_dynamics` + `m07b_dynamics_spectrum` (11 dinâmicas) |
| `fix(slur):` V1 | **V1 ✅** | Slur multi-nota agora é **um arco contínuo** (pontos de controle perpendiculares à corda + altura em staff-spaces); antes dobrava em 2 segmentos | `slur_shape_test.dart` (3) + goldens m05, c01 |
| `fix(chord):` V3 | **V3 ✅** | Empilhamento de acidentes em colunas sem sobreposição (clareamento por altura/largura reais do glifo); algoritmo extraído p/ `ChordRenderer.assignAccidentalColumns` | `accidental_columns_test.dart` (4) + goldens m02, c02 |
| `fix(rendering):` R4 | **R4 ✅** | Referência da fonte unificada para `package:'flutter_notemus'` em todos os renderers — fonte resolve sem registro manual | 15 goldens byte-idênticos sob registro só-do-pacote |
| `feat(parsers):` letras | **H2 (import) ✅** | Import de letras MusicXML `<lyric>` e MEI `<verse>/<syl>` → `Note.syllables` (antes ignorado silenciosamente) | `lyrics_import_test.dart` (6) |
| `feat(lyrics):` render | **lyrics render ✅** | `_renderSyllable` agora respeita `theme.lyricTextStyle` (campo antes ignorado); harness ganhou fonte de texto real | golden `m11_lyrics` |
| `fix(lyrics):` #14 | **#14 ✅** | Hífen entre sílabas **centralizado** (passe pós-layout), antes colado | golden `m11_lyrics` |
| `fix(lyrics):` #13 | **#13 ✅** | Linha de melisma estende até o fim real (passe pós-layout), antes stub fixo de 1 SS | golden `m12_melisma` |
| `fix(beaming):` V4 | **V4 ✅** | Feixe por meia-barra no 4/4 (grupos de 4) / por beat nos demais; antes a barra inteira virava 1 feixe | `beam_grouping_test.dart` (4) + goldens s01, c01 |

### Épico Gregoriano — renderização de notação quadrada (em andamento)

Meta do autor: **suporte completo a canto gregoriano** (renderização nível-editor + futura execução), superando o que a doc registra. Decisão-chave: notação por **fonte Greciliae** (projeto Gregorio, SIL OFL 1.1) com **neumas pré-compostos** desenhados por tipógrafos de canto — abandonadas as tentativas com Bravura (glifos calligráficos como *componentes*) e com geometria primitiva (ambas rejeitadas visualmente pelo autor).

| Commit | O quê | Evidência |
|---|---|---|
| `feat(gregorian):` Greciliae | Adoção da fonte Greciliae: `greciliae.ttf` + `OFL.txt` + mapa `nome→[cp,adv,bbox]`; loader `GreciliaeFont`; renderer reescrito (grade de pauta precisa, 1 passo diatônico ≈ 147 unidades de fonte). **Corrige "clave fora da pauta"**: clave registra pelo centro da bbox; divisórias desenhadas como barras geométricas (minima/minor/maior + finalis dupla). | goldens `chant_kyrie_tierA`, `chant_from_gabc` |
| `feat(gregorian):` marcas rítmicas | Episema horizontal, ictus (episema vertical) e ponto(s) de mora — o parser GABC já os populava; agora são desenhados por componente. | golden `chant_kyrie_tierA` (nota "A" episema+ictus, "men" mora) |
| `feat(gregorian):` liquescências | Neumas líquidos (deminutus): epiphonus (pes), cephalicus (clivis) + torculus/porrectus/scandicus/quilisma-pes; fallback p/ forma plena quando o âmbito não tem glifo líquido. | golden `chant_liquescence` |
| `feat(gregorian):` neumas compostos | Salicus (oriscus no meio) + torculus resupinus e porrectus flexus de 4 notas como glifos únicos; classificador GABC detecta âmbito de 3 intervalos. | golden `chant_compound` |
| `feat(gregorian):` acidentes | Campo aditivo `NeumeAccidental` em `NeumeComponent` (aprovado pelo autor); sinais bemol/bequadro/sustenido autônomos no estilo GABC. | golden `chant_accidentals` |
| `feat(gregorian):` repetidos + mora | bivirga/distropha/tristropha; ponto de mora no espaço correto (sobe quando a nota está na linha). | golden `chant_repeated` |
| `fix(gregorian):` âncora à clave | **Resolução de altura RELATIVA à clave** (achado por revisão adversarial do playback): clave-dó → linha=dó(C), clave-fá → linha=fá(F); semitons E-F/B-C caem nas linhas certas; clave pode mudar no meio. Render inalterado (contorno relativo preservado). | testes do parser |
| `feat(midi):` **playback gregoriano** | `ChantMidiMapper` (Dart puro) neuma→`MidiSequence`: altura diatônica resolvida pela clave→MIDI, acidentes locais + clave-bemol (si suave), ritmo livre como pulso igual com alongamento por mora, divisórias como respiros, transposição configurável, linha do tempo por nota p/ editor. Ponte `gabcToMidiSequence()` + extensão `ChantScore.toMidiSequence()`. `MidiFileWriter` valida ticksPerQuarter. | 18 testes `chant_midi_mapper_test` |
| `feat(gregorian):` clave-bemol | Desenha o bemol (si suave) após a clave (cb/fb). | golden `chant_clef_flat` |
| `feat(gregorian):` **âncora absoluta à clave** | Posicionamento vertical agora é ABSOLUTO pela clave (não centrado na mediana): linha 0 = linha da clave (dó/fá), notas lidas a partir dela; clave, acidentes, custos e clave-bemol alinham consistentemente. **Item #1 da auditoria SOTA.** | todos os goldens de canto |
| `feat(gregorian):` quilisma+Ancus | Glifo do quilisma preservado em grupos ascendentes (era perdido p/ scandicus/pes plano); climacus líquido → Ancus pré-composto. | golden `chant_special_neumes` |
| `feat(gregorian):` letras sob 1ª nota | Sílaba centrada sob a 1ª nota do neuma (underlay Solesmes). | goldens de canto |
| `feat(gregorian):` hifenização | Sílabas da mesma palavra unidas por hífen (detecção de fronteira de palavra no GABC); campo aditivo `Neume.hyphenAfter`. | golden `chant_from_gabc` (Sal-ve, Re-gí-na) |

**Auditoria adversarial SOTA gregoriana:** 59 lacunas confirmadas (doc/GREGORIAN_AUDIT_BACKLOG.md). Atacados os itens de maior impacto: âncora à clave (#1), quilisma/Ancus, hifenização, alinhamento de letras. Restantes (médio/baixo): modelo completo de sílaba (melisma/multi-verso), pressus, glifos de episema por forma, linhas de fusão, renderização de cabeçalhos (modo/título) — refinamentos.

### Fase 3 — Biblioteca inteira (CMN) ao estado da arte (em andamento)

**Auditoria adversarial de renderização CMN:** 72 lacunas confirmadas em 10 dimensões de gravação (doc/LIBRARY_AUDIT_BACKLOG.md). Atacados:

| Commit | O quê | Evidência |
|---|---|---|
| `fix(engraving):` fórmulas multi-dígito | Fórmulas de compasso ≥10 (12/8, 16…) decompostas em dígitos e centradas; antes não desenhavam nada. | golden `m04b_compound_meter` |
| `fix(engraving):` haste na linha do meio | Nota na linha do meio → haste para baixo (Gould), era para cima. | goldens m02/m03/c01 |
| `fix(engraving):` pontos em pausas | Pausas pontuadas agora desenham o ponto de aumento. | golden `m10_rests` |
| `fix(engraving):` articulações estendidas | portato/snap/stopped/open/half-stopped/thumb agora renderizam (mapeamento SMuFL). | golden `m04c_articulations_extended` |
| `feat(engraving):` **persistência de acidente no compasso** | Regra CMN #1: acidente mostrado 1×/compasso, bequadro automático ao reverter, reset na barra, ciente da armadura. Resolver baseado no modelo alimenta largura+render+acordes. Corrigiu bug latente (Ode to Joy fá♮→fá♯). | golden `m04d` + 7 testes do resolver |
| `feat(engraving):` **clave/armadura por sistema** | Pauta quebrada redesenha clave + armadura no início de cada sistema (Gould/Verovio). | golden `m04e_multi_system` |
| `fix(engraving):` haste linha do meio | Nota na linha do meio → haste para baixo. | m02/m03/c01 |
| `fix(engraving):` pontos em pausas | Pausas pontuadas desenham o ponto. | `m10_rests` |
| `fix(engraving):` articulações empilhadas | Múltiplas articulações empilham (não sobrepõem). | `m04f` |
| `fix(engraving):` claves C/F | soprano/mezzo/baritono/baritono-fá: glifo na linha certa + posição de nota. | `m04g` + testes |

**Os 3 itens HIGH da auditoria CMN foram resolvidos.** ~58 itens médio/baixo restantes no [LIBRARY_AUDIT_BACKLOG.md](LIBRARY_AUDIT_BACKLOG.md): hairpins por glifo SMuFL, articulações de acorde, naturais de cancelamento sem largura reservada, espaço do ponto de aumento, último sistema não justificar à largura cheia, mudanças de clave no meio do sistema (caixa pequena), etc.

### Fase 4 — Import/Export + Playback em todo o sistema (em andamento)

Auditoria adversarial de I/O + MIDI: 41 lacunas confirmadas em 6 dimensões (doc/IO_MIDI_AUDIT_BACKLOG.md). Atacadas:

| Commit | O quê |
|---|---|
| `feat(midi):` articulações | staccato encurta, accent/marcato aumentam velocity (notas + acordes); notas ligadas nunca encurtam |
| `feat(musicxml):` letras+feixes | export de `<lyric>` (por verso) e `<beam>` — letras agora sobrevivem ao round-trip |
| `fix(musicxml):` durações+tuplets | `<divisions>` + duração real por nota (era `1` fixo); tuplets exportados com `<time-modification>` (antes sumiam) |
| `feat(mei):` scoreDef/staffDef + containers | lê clave/armadura/compasso do `<scoreDef>/<staffDef>`; recursão em `<beam>`/`<tuplet>` (antes perdiam as notas) |
| `feat(musicxml):` wedges | `<wedge>` cresc./dim. → Dynamic hairpin |
| `fix(midi):` tempo+hairpin | unidade de batida do TempoMark respeitada; hairpin não reseta mais o velocity |
| `fix(midi):` grace notes | apogiatura "rouba" tempo em vez de transbordar o compasso |
| `fix(musicxml):` claves | linha de clave correta (alto=3, etc.) + `<clef-octave-change>` |

| `feat(musicxml):` multi-parte/multi-pauta | `scoreFromMusicXML()` → `Score`: cada `<part>` vira pauta; parte com `<staves>` divide por `<staff>` com claves por pauta. **Antes piano/SATB colapsavam em 1 pauta.** |
| `feat(midi):` ornamentos | trinado/mordente/grupeto expandidos em sub-notas no playback (antes nota única). |
| `feat(musicxml):` export round-trip | barras/repetições, ornamentos e grace notes agora exportados (antes perdidos no round-trip). |

**Cobertura de export MusicXML agora**: notas/acordes/pausas, durações reais + `<divisions>`, tuplets (`<time-modification>`), ligaduras/laços, articulações, **ornamentos**, **grace notes**, dinâmicas, letras (por verso), feixes, claves (com octave-change), armaduras, fórmulas, **barras/repetições**.

| `feat(mei):` eventos de controle | `<slur>/<tie>/<dynam>` por `@startid/@endid` resolvidos para as notas referenciadas. |
| `feat(musicxml):` export multi-voz | medidas polifônicas exportam com `<backup>`+`<voice>` (antes vazias); round-trip 2 vozes. |

**TODOS os itens HIGH das 3 auditorias (CMN render, I/O, MIDI) foram resolvidos**, além dos principais médios de I/O (export round-trip completo, import multi-parte/multi-pauta, MEI scoreDef/containers/control-events).

### Lote de polimento de render CMN (por impacto)

| Commit | Correção | Item backlog |
|---|---|---|
| `fix(engraving):` direção de haste de acorde | `resolveStemDirection` estava **invertida** (`mostExtremePos > 0`): tríade grave abaixo da pauta tinha haste p/ baixo. Corrigido p/ `< 0` (alinhado à regra de nota + Behind Bars). Afeta **todos** os acordes. | #21 (metade acorde) |
| `fix(engraving):` articulações de acorde | staccato/acento/etc. de acorde agora renderizam na cabeça externa do lado oposto à haste (antes ignorados apesar de `Chord.articulations`). | #12 |
| `fix(engraving):` mudanças de clave/armadura/fórmula no meio do sistema | filtro de layout descartava **toda** mudança de elemento de sistema fora do 1º compasso do sistema (ex.: caso "12/8, 6/8" nunca mostrava o 6/8). Agora renderizam. | causa raiz de #10/#19 |
| `fix(engraving):` largura dos bequadros de cancelamento | layout reserva `previousCount` bequadros + folga (antes colidiam com as notas). | #10/#19 |
| `fix(engraving):` espaço do ponto de aumento | reserva `0.7 + (n-1)·0.6` SS na largura da nota/acorde pontuado (antes o ponto invadia a próxima nota). | #6 |
| `fix(spacing):` pausas `restSpacingRatio` (~0.8×) | substituído o `1.15×` que alargava pausas (contradizia Gould). | #7 |
| `fix(engraving):` tempo livre não desenha `0/4` | `isFreeTime` → nenhum glifo + 0 de largura. | #20 |
| `fix(engraving):` barras pesadas | heavyLight → `barlineReverseFinal`, heavyHeavy → `barlineHeavyHeavy` (antes ambas viravam `barlineHeavy`). | #64 |
| `fix(engraving):` linhas suplementares via metadata | `legerLineThickness` (0.16) + `legerLineExtension` (0.4) do metadata SMuFL (antes 0.13/0.4 hardcoded). | #66/#67 |

Restam itens médio/baixo de polimento de render (hairpin por glifo SMuFL, justificação do último sistema, mudança de clave no meio do sistema em tamanho cue, centralização de pausa de compasso inteiro, modelo de spacing √t) e refinamentos gregorianos (modelo de melisma/multi-verso, pressus), documentados nos backlogs.

**Renderiza com autenticidade (confirmado nos PNGs):** clave-dó centrada na linha, punctum/virga, pes, clivis (flexus), torculus, porrectus (oblíqua), scandicus, climacus (losangos *inclinatum*), quilisma, salicus, resupinus/flexus, líquidas, episema/ictus/mora, custos de fim de linha, divisórias, justificação por sistema, letras em fonte serifada.

**Resolvido desde então:** acidentes (campo aditivo), repetidos, ponto de mora no espaço, **âncora de altura à clave** (modelo de altura agora correto para playback), **execução/playback** (neuma→MIDI), clave-bemol.

**Lacunas conhecidas (honestidade):**
- **Posicionamento vertical do render**: ainda **centrado na mediana** (robusto p/ entrada GABC e notas reais). A altura é musicalmente correta no MODELO/playback (clave do/fa), mas o render não ancora visualmente cada nota à linha da clave — escolha deliberada (ancorar exigiria que o app garanta clave compatível; risco de transbordo p/ entrada programática). Glifo do clave-bemol é posicionado relativo à clave (ok).
- **Pressus, oriscus isolado, quilisma-scandicus, initio debilis**: ainda montados nota-a-nota ou não tratados (initio debilis exigiria campo aditivo).
- **GABC**: `@` (fusões), acidentais suaves especiais, claves duplas, custos manual — não tratados (Tier B).
- Auditoria adversarial de estado-da-arte em andamento p/ ranquear o que falta.

**Verificado como NÃO-defeito:** **V5** — o colchete da quiáltera já fica do lado correto (lado da haste/feixe); estilo válido, sem ação.

**Follow-ups restantes (menor impacto):** V3b (layout reservar largura p/ acidentes quando o acorde inicia o compasso), I2 (`divisions` MusicXML — só afeta arquivos sem `<type>`), I4 (microtons no import).

**Follow-ups abertos (não-bloqueantes):**
- **V3b (layout):** quando o acorde é o 1º elemento, os acidentes ficam espremidos junto à clave — o layout não reserva largura p/ as colunas de acidentes. (espaçamento, risco médio)
- **Texto no harness:** `_dynamicTextStyle`/letras usam só `fontFamilyFallback` (sem família primária) → não resolve fontes do `FontLoader` no `flutter test`. Resolver no início da renderização de letras (Onda B).
- **V4** (agrupamento de feixe em 4/4), **V5** (posição do colchete de quiáltera).

**Pendências de harness conhecidas:** texto via `_dynamicTextStyle` usa apenas `fontFamilyFallback` (sem família primária), que no `flutter test` não resolve fontes do `FontLoader` de forma confiável → dinâmicas-palavra (cresc./dim.) e possivelmente letras renderizam como caixas no harness. **A resolver no início da Onda B (letras)**, onde isso é crítico.

### Próximos (ordem)
- **V1** (slur quebrada) — investigar `slur_renderer`/`slur_calculator`.
- **V3** (empilhamento de acidentes em acordes) — `chord_renderer.dart:146-169`.
- **R4** (unificar referência de fonte Bravura) — remove a fragilidade dos 2 nomes.
- **V4** (agrupamento de feixe em 4/4) — `beam_grouper`/`beat_position_calculator`.
- **Onda B** (letras MusicXML/MEI) — exige resolver render de texto no harness.
