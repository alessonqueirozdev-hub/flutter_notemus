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

_(vazio — nenhuma correção de código aplicada ainda; apenas reconhecimento)_
