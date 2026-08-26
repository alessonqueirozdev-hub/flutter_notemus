# flutter_notemus — Brief de entrega para o artigo (ANPPOM, tool paper)

> **Para quê este documento.** Material consolidado e **honesto** para concluir
> o artigo (tool paper) sobre a `flutter_notemus` em outra sessão (Claude
> Desktop). Já existe um **rascunho parcial**: a tarefa é **completar seções** e,
> sobretudo, **alinhar todas as afirmações ao que o código realmente faz**.
> Versão de referência: **flutter_notemus 2.6.0** (2026-06-19).
>
> ⚠️ **Cláusula de honestidade (obrigatória).** Preferir "parcial" a "pronto";
> nunca afirmar mais do que o código entrega. Ver a seção *Guardrails contra
> overclaim* — várias alegações antigas (ex.: "100% MEI v5") eram falsas e já
> foram corrigidas; **não reintroduzir**.

---

## 1. Identidade e posicionamento

- **O que é:** biblioteca **Dart/Flutter** para **renderização de notação
  musical** com gravação (engraving) de qualidade tipográfica, mais I/O
  (MusicXML/MEI/JSON) e mapeamento para MIDI.
- **Lacuna que preenche:** renderização de partitura **nativa em Flutter**,
  **Dart puro** (sem FFI/binários nativos para o núcleo de render), multiplataforma.
- **Diferencial declarável:** suporte a **canto gregoriano (notação quadrada)**
  com a fonte **Greciliae** (neumas **precompostos**, não montados a partir de
  cabeças de nota da notação comum) — objetivo primário do projeto.
- **Licença:** Apache-2.0. **pub.dev:** `flutter_notemus`. **Repo:**
  https://github.com/alessonqueirozdev-hub/flutter_notemus

## 2. Contribuições (destaques para o tool paper)

1. **Engraving SMuFL/Bravura em Dart puro** sobre `Canvas`/`CustomPainter`, com
   métricas do `bravura_metadata.json` (anchors de haste, espessuras, etc.).
2. **Regras tipográficas "Behind Bars" (Gould):** espaçamento por lei da raiz
   quadrada / inter-onset, direção de haste, feixes, colisões entre vozes,
   acidentes por contexto de compasso, etc. (ver §5).
3. **Multi-pauta / grand staff / partitura** (novo na 2.6.0): widgets `GrandStaff`
   e `ScoreView`, grade horizontal compartilhada, chave/colchete SMuFL, barra de
   sistema, **quebra multi-sistema** e **feixes cross-staff** (`Note.crossStaffMove`).
4. **Canto gregoriano** via Greciliae + import **GABC** (`ChantScore.fromGabc`).
5. **Modelo de dados agnóstico de notação** que representa conceitos amplos do
   MEI v5 (vários repertórios são *construtíveis em Dart*).
6. **I/O e MIDI:** parsers MusicXML (partwise/timewise), MEI (CMN) e JSON;
   exportação `.mid` (`MidiFileWriter`).
7. **Jianpu** (notação cifrada numérica) — **experimental** (ver §6).

## 3. Arquitetura (resumo)

- `lib/core/` — modelo musical agnóstico (Note, Rest, Chord, Measure, Staff,
  Score, StaffGroup, Clef, KeySignature, TimeSignature, Tuplet, Neume, etc.).
- `lib/src/layout/` — `LayoutEngine`: posiciona elementos (espaçamento,
  justificação por sistema, quebras), `collision_detector`.
- `lib/src/rendering/` — `StaffRenderer` + renderers por elemento; sistema de
  coordenadas (`StaffCoordinateSystem`); `gregorian/` (GregorianPainter,
  GabcParser, GreciliaeFont); `jianpu/`.
- `lib/src/smufl/` — carregamento de metadados SMuFL (Bravura).
- `lib/src/parsers/` — MusicXML, MEI, JSON → normalizam para o mesmo modelo.
- `lib/src/midi/` — mapeamento notação→MIDI e escrita de arquivo.
- **Fontes:** Bravura (SMuFL, CMN) e Greciliae (SIL OFL, gregoriano).
- **Métrica:** ~**36.650 linhas** Dart em **137 arquivos** (`lib/`).

## 4. Inventário de recursos (com status honesto)

Legenda: ✅ implementado e funcional · ◐ parcial · ○ só modelo (sem render/import).

**Notação comum (CMN) — núcleo sólido (✅):**
- Durações maxima→2048 avos; pausas; acidentes (inclusive micro: sagittal,
  koma, quarto de tom); ledger lines; ~20 claves (treble/bass/alto/tenor/
  percussão/tab + variantes oitavadas).
- Cabeças/hastes/bandeirolas via anchor SMuFL; **feixes**; **quiálteras**
  (razões a:b, multidígito, aninhadas, colchete inclinado); **acordes**
  (empilhamento de acidentes em colunas).
- **Acidentes por contexto de compasso** (`AccidentalResolver`): mostra no
  primeiro; oculta repetições; bequadro ao reverter; reseta na barra.
- Ligaduras: tie/slur, **slurs aninhados/numerados** (`SlurEvent`).
- Articulações (17 tipos), dinâmicas (`DynamicType` tem **36** valores; **9**
  renderizados + hairpins), ornamentos (`OrnamentType` tem **43**; **33** com
  glifo).
- Polifonia (`MultiVoiceMeasure`, vozes), deslocamento de cabeça em 2ª/uníssono.
- Repetições/volta, barras (15 tipos), marcações de oitava, letras (sílabas).
- **Multi-pauta**: grand staff, SATB, partitura multi-seção, multi-sistema,
  **feixe cross-staff** (manual e importado de MusicXML).

**Gregoriano (◐ alto, via Greciliae/GABC):**
- Punctum, virga, podatus/clivis, torculus/porrectus, scandicus/climacus,
  quilisma, salicus, compostos, repetidos (bivirga/strophae), liquescências.
- Episema (por forma), mora (AuctumMora), divisórias com respiro assimétrico,
  custos por salto, **hífen de palavra repetido** (estilo GregorioTeX),
  âncora de altura à clave (correto p/ playback), clave-bemol.
- Import **GABC**; playback (neuma→MIDI via `ChantMidiMapper`).
- Lacunas (○/◐): import **MEI `<neume>`** não implementado (render só por GABC);
  pressus/oriscus isolado e algumas fusões ainda montados nota-a-nota.

**I/O (◐):**
- Import: MusicXML (partwise/timewise) e MEI **focados em CMN**; JSON.
  `<part-group>`, cross-staff por mudança de `<staff>`, letras (`<lyric>`/`<syl>`)
  **são** importados (sílabas planas; agrupamento `Verse` não populado).
- Export: MusicXML (com letras); MIDI `.mid`. **Export MEI não existe.**
  Export MusicXML de quiálteras/algumas estruturas é **parcial**.

**MIDI (✅ geração):** mapeamento de Staff/Score, expansão de repetições/volta,
quiáltera/polifonia/tie, metrônomo, escrita de arquivo.

## 5. Metodologia de engraving (para a seção de método)

- Lei de espaçamento proporcional (raiz quadrada) e **inter-onset**.
- Direção de haste (regra da linha do meio → haste para baixo).
- Feixes: espessura/again via engravingDefaults; anchors SMuFL.
- Colisões entre vozes; ties de acorde "abrindo"; marcato sempre acima.
- **Baseline externo de comparação:** **Verovio 6.2.1** (instalado via pip,
  **ferramenta externa**, não é dependência da lib). Referências teóricas:
  Gould, *Behind Bars*; saídas de LilyPond/Verovio.

## 6. Escopo e limitações (seção de honestidade — ESSENCIAL no artigo)

- **Conformidade MEI v5 ≈ 58% dos itens catalogados** (79/137 modelados **e**
  ligados a import/render), **não 100%**. Reauditoria adversarial de 2026-06-19
  (ver `doc/MEI_V5_AUDIT.md`). O **modelo de dados** cobre amplamente o MEI v5,
  mas o **import/render foca em CMN**.
- **Só modelo (○), sem import/render MEI:** metadados/FRBR (`meiHead`), análise
  harmônica (`harm`/`intm`/`deg`/`ChordTable`), baixo cifrado (`fb`/`f`),
  notação **mensural**. Classes existem, mas nenhum parser/renderer as usa.
- **Parcial (◐):** tablatura (render via modelo; **sem import MEI `@tab.*`**);
  neuma via MEI; `@mode`/metro aditivo (no modelo, não lidos do MEI); `Verse`.
- **Áudio:** backend nativo **só Android**; iOS/macOS/Windows/Web são *no-op*.
- **Export PDF:** **placeholder** (exporta metadados; a "partitura" são linhas
  de pauta vazias). Não listar como pronto.
- **Jianpu:** **work in progress / experimental** (render básico na galeria;
  cobertura parcial; API pode mudar).
- `AdvancedSlur` (direção/voz forçadas) é **classe morta** (não ligada) — não
  citar como recurso.

## 7. Verificação e reprodutibilidade

- **Testes:** **594** testes da biblioteca + **24** do exemplo, todos verdes;
  **52 golden tests** (PNG) incluindo CMN, grand staff e canto (`chant_*`).
  `dart analyze` limpo.
- **50** arquivos de teste; **35** exemplos no catálogo (deploy GitHub Pages).
- **Toolchain:** Dart 3.11 / Flutter 3.41.0 (stable). Dependências: `xml`,
  `collection`, `pdf`, `printing` (e `flutter`). CI roda analyze + test +
  `pub publish --dry-run`.
- **Reprodutível offline**: build/test sem rede (assets e fontes embarcados).
- Métrica de código: ~36.650 LOC Dart em 137 arquivos.

## 8. Guardrails contra overclaim (revisar o rascunho com esta lista)

NÃO afirmar (foram corrigidos no README/audit — não reintroduzir):
- ❌ "100% de conformidade MEI v5" → usar "**modelo abrangente alinhado ao MEI
  v5; import/render cobrem CMN; ~58% dos itens totalmente conformes**".
- ❌ "exportação PDF da partitura" → é placeholder.
- ❌ "playback/áudio multiplataforma" → só Android; demais no-op.
- ❌ "suporte a análise harmônica / baixo cifrado / mensural / FRBR" → só modelo.
- ❌ "Jianpu pronto" → experimental.
- ❌ "AdvancedSlur (direção forçada)" → classe morta.
- ❌ contagens infladas: dinâmicas são **36** (não 44), ornamentos **43** (não 60+).

## 9. Estrutura sugerida do tool paper × documento-fonte

| Seção do artigo | Fonte principal no repo |
|---|---|
| Introdução / motivação / lacuna | este brief §1; README (topo) |
| Trabalhos relacionados (Verovio, LilyPond, MuseScore) | este brief §5 (baseline) |
| Arquitetura | este brief §3; README "Architecture"; PROGRESS (notas) |
| Recursos / funcionalidades | este brief §4; README "Highlights"/"API Guide"; CHANGELOG 2.6.0 |
| Método de engraving | este brief §5; PROGRESS; LIBRARY_AUDIT_BACKLOG |
| Canto gregoriano (destaque) | este brief §4 (gregoriano); GREGORIAN_PLAN; GREGORIAN_AUDIT_BACKLOG |
| Conformidade / cobertura | **MEI_V5_AUDIT.md (corrigido)**; este brief §6 |
| Avaliação / validação | este brief §7 (testes/goldens) |
| Limitações & trabalhos futuros | este brief §6/§8; OPEN_ISSUES; backlogs |
| Reprodutibilidade / disponibilidade | este brief §7; pubspec; README "Installation" |

## 10. Mapa dos documentos-fonte (o que levar)

**Essenciais (levar todos):**
- `doc/ARTICLE_HANDOFF.md` — este brief (fatos consolidados + guardrails).
- `README.md` — visão geral, API, instalação, tabela de conformidade (corrigida).
- `CHANGELOG.md` — o que entrou na 2.6.0 (recursos novos, com escopo).
- `doc/MEI_V5_AUDIT.md` — conformidade reauditada (~58%), por categoria.
- `PROGRESS.md` — diário de auditoria com reality-checks honestos (H1–H4) e
  notas de arquitetura.

**Apoio (úteis conforme a seção):**
- `doc/GREGORIAN_PLAN.md`, `doc/GREGORIAN_AUDIT_BACKLOG.md` — gregoriano.
- `doc/LIBRARY_AUDIT_BACKLOG.md`, `doc/IO_MIDI_AUDIT_BACKLOG.md` — engraving e I/O
  (com overlay de status resolvido/parcial/aberto).
- `doc/OPEN_ISSUES.md` — limitações e roadmap.
- `doc/json_schema.md` — formato JSON de entrada.

**Dispensáveis para o artigo** (detalhe de implementação): `MAGIC_NUMBERS_REFERENCE.md`,
`IMPLEMENTATION_GUIDE_LRU_CACHE.md`, `PROGRESS_REPORT_2025-11-06.md`.

**Levar também:** o **rascunho parcial** atual do artigo (fora do repo) — o
Claude Desktop precisa dele para completar e revisar contra estes fatos.
