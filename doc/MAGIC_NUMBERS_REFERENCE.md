# Magic Numbers - Referência Completa

Este documento explica todos os "magic numbers" (valores numéricos aparentemente arbitrários) usados no Flutter Notemus, fornecendo justificativas matemáticas e referências para cada um.

---

## 1. Stem Renderer — RESOLVIDO (não há mais magic number aqui)

> **Atualizado em 2026-08-21 (2.7.0).** Este documento afirmava, até então, que
> `stem_renderer.dart:20` e `:25` continham `stemUpXOffset = 0.7` e
> `stemDownXOffset = -0.8` **em pixels** — valores calibrados visualmente e
> explicitamente não proporcionais ao `staffSpace` ("para staffSpace muito
> grande (>20px), pode ser necessário ajuste").
>
> **Essas constantes não existem mais.** O `StemRenderer` obtém a anexação da
> haste de `SMuFLPositioningEngine.calculateStemAttachmentOffset`, que soma a
> âncora SMuFL do notehead (`stemUpSE` / `stemDownNW`) com metade da espessura
> da haste (`stemThickness` dos `engravingDefaults`), tudo em *staff spaces* e
> escalado por `staffSpace`. O resultado é invariante à escala — que era
> exatamente o defeito dos offsets em pixels.
>
> A auditoria forense de 2.6.0 registrou esta seção como divergência
> documentação↔código (F-39). Se você voltar a ver um offset em pixels crus no
> renderizador de hastes, é uma regressão.

### `kStandardStemLengthSpaces = 3.5` (staff spaces)
**Arquivo:** `lib/src/rendering/smufl_positioning_engine.dart`

Comprimento padrão de haste segundo *Behind Bars* (Gould): uma oitava, isto é
3,5 espaços de pauta. **Não** vem de `engravingDefaults`: o SMuFL não define
nenhuma chave `stemLength` (confira: as 29 chaves de
`assets/smufl/bravura_metadata.json` não a incluem). Até 2.6.0 o código fazia
`_loadEngravingDefault('stemLength', 3.5)`, o que dava aparência de derivação
com realidade de constante — a leitura sempre caía no fallback. Agora a
constante é declarada como constante e citada como tal.

Mínimo absoluto usado pelo agrupador de barras: **2,5 espaços**, mais
`(beamCount - 1) * (beamThickness + beamSpacing)` lidos do metadado.

## 2. Base Glyph Renderer

### `baselineCorrection = -textPainter.height * 0.5`
**Arquivo:** `lib/src/rendering/renderers/base_glyph_renderer.dart` (aproximadamente linha 200)

#### Origem matemática:
O TextPainter do Flutter usa métricas da fonte (tabela `hhea` do OpenType) que definem:
- **Ascent**: distância do baseline ao topo do glyph = ~2.5 staff spaces
- **Descent**: distância do baseline à base do glyph = ~2.5 staff spaces
- **Total height**: ascent + descent = ~5.0 staff spaces

Para alinhar com a baseline SMuFL (centro do glyph), subtraímos metade da altura:
```
baselineCorrection = -height / 2 = -(5.0 SS) / 2 = -2.5 SS
```

#### Valor:
- **-textPainter.height * 0.5** (dinâmico, varia com glyphSize)
- Com glyphSize = 48px (4 × staffSpace de 12px):
  - height ≈ 60px
  - correction = -30px

#### Por que -0.5 especificamente?
O valor `-0.5` (ou seja, -50%) centraliza verticalmente o glyph. SMuFL assume que glyphs são centralizados no eixo Y (origem = centro), mas TextPainter posiciona glyphs com baseline na origem.

#### Referências:
- OpenType specification: https://docs.microsoft.com/en-us/typography/opentype/spec/
- Tabela `hhea` (Horizontal Header Table)
- SMuFL coordinate system: https://w3c.github.io/smufl/latest/about/

---

## 3. Dot Renderer

### Offset vertical = `-2.5 * staffSpace`
**Arquivo:** `lib/src/rendering/renderers/primitives/dot_renderer.dart` (aproximadamente linha 80)

#### Origem matemática:
Este valor está relacionado com o `baselineCorrection` acima. Quando uma nota está em um espaço PAR (linha da pauta), o ponto de aumento deve ser deslocado para o espaço ACIMA da nota.

#### Cálculo:
```
Nota na linha: staffPosition = par (ex: 0, 2, 4)
Ponto deve ir para espaço acima: staffPosition + 1
Deslocamento vertical: (1 posição × 0.5 SS/posição) = 0.5 SS

Porém, devido ao baselineCorrection do glyph (-2.5 SS), somamos:
Offset total = -2.5 SS + ajuste específico do contexto
```

#### Valor detalhado:
- Para notas em LINHAS (staffPosition par): ponto vai para espaço acima
- Para notas em ESPAÇOS (staffPosition ímpar): ponto fica na mesma altura

#### Referências:
- Behind Bars (Elaine Gould), página 14: "Pontos de aumento em espaços"
- Espaçamento de pontos: 0.5 staff spaces da nota

---

## 4. Layout Engine

### `systemMargin = 2.5` (staff spaces)
**Arquivo:** `lib/src/layout/layout_engine.dart:173`

#### Origem:
Margem lateral padrão para sistemas de partitura, baseada em práticas tipográficas musicais tradicionais.

#### Valor:
- **2.5 staff spaces** = 30px (com staffSpace = 12px)
- Proporcional ao staffSpace (escala corretamente)

#### Referências:
- The Art of Music Engraving (Ted Ross), Chapter 8
- Margem típica: 2-3 staff spaces

---

### `measureMinWidth = 5.0` (staff spaces)
**Arquivo:** `lib/src/layout/layout_engine.dart:174`

#### Origem:
Largura mínima de um compasso para evitar compressão excessiva de elementos musicais.

#### Valor:
- **5.0 staff spaces** = 60px (com staffSpace = 12px)
- Baseado na largura mínima necessária para:
  - 1 notehead (1.18 SS)
  - Acidente opcional (1.5 SS)
  - Espaçamento mínimo (2.32 SS)

#### Referências:
- Behind Bars, página 30: "Espaçamento proporcional à duração"

---

### `noteMinSpacing = 3.5` (staff spaces) — base da lei de espaçamento

> **Atualizado em 2.7.0.** Este é o espaçamento da SEMÍNIMA. O espaçamento de
> qualquer outra duração é **calculado**, não tabelado:
>
> ```
> fator   = sqrt(duracao.absoluteValue / DurationType.quarter.value)
> espaco  = noteMinSpacing * fator * staffSpace * compressao
> ```
>
> A tabela fixa anterior cobria apenas `whole`..`sixtyFourth` e caía em `1.0`
> para o resto, de modo que uma breve era espaçada como semínima (mais estreita
> que uma semibreve!) e uma 1/128 recebia 2,3× o espaço de uma 1/64. A fórmula
> cobre os 15 `DurationType` e inclui pontos de aumento via `absoluteValue`.
**Arquivo:** `lib/src/layout/layout_engine.dart:175`

#### Origem:
Espaçamento mínimo entre notas (semínima como referência), implementando modelo √2 aproximado.

#### Valor:
- **3.5 staff spaces** = 42px (com staffSpace = 12px)
- Progressão geométrica para proporção visual correta

#### Fórmula:
```
espaço = baseSpace × √(duração / menorDuração)
```

Exemplo com menor duração = colcheia (0.125):
- Colcheia: √(0.125/0.125) × 12 = 12px
- Semínima: √(0.25/0.125) × 12 = √2 × 12 = 16.97px ≈ 17px
- Mínima: √(0.5/0.125) × 12 = 2 × 12 = 24px

#### Referências:
- Lime (2016): "Musical notation layout for linear optimization"
- Behind Bars, página 30
- MuseScore MS21 spacing algorithm

---

### `measureEndPadding = 3.0` (staff spaces)
**Arquivo:** `lib/src/layout/layout_engine.dart:177`

#### Origem:
Espaço adequado ANTES da barline, conforme práticas profissionais.

#### Valor:
- **3.0 staff spaces** = 36px (com staffSpace = 12px)
- Garante "ar" adequado antes das barras de compasso

#### Referências:
- Behind Bars: "Air space before barlines"
- Típico: 2.5-3.5 staff spaces

---

### `barlineTrailingSpace = 2.5` (staff spaces) — renomeado

> Chamava-se `barlineSeparation`, o que colidia com a chave homônima do SMuFL
> (`barlineSeparation: 0.4`), que significa outra coisa: a distância **entre os
> dois traços** de uma barra dupla/final. São conceitos diferentes e o nome
> igual induzia a erro (a constante é 6× o valor do metadado). O alias antigo
> continua existindo marcado como `@Deprecated`.
**Arquivo:** `lib/src/layout/layout_engine.dart:169`

#### Origem:
Espaço DEPOIS da barline, antes do próximo elemento musical.

#### Valor:
- **2.5 staff spaces** = 30px (com staffSpace = 12px)
- Menor que `measureEndPadding` pois barline já fornece separação visual

---

### `measuresPerSystem = 4`
**Arquivo:** `lib/src/layout/layout_engine.dart:180`

#### Origem:
Número padrão de compassos por linha (sistema) em partituras impressas.

#### Valor:
- **4 compassos** por linha
- Balanceamento entre legibilidade e uso de espaço

#### Referências:
- Prática comum em partituras profissionais
- Pode variar de 2 a 6 dependendo da densidade musical

---

## 5. Staff Renderer

### `systemEndMargin = -12.0` (pixels)
**Arquivo:** `lib/src/rendering/staff_renderer.dart:45`

#### Origem:
Margem após barras de compasso normais. Valor negativo faz as linhas do pentagrama terminarem **exatamente** na barra de compasso.

#### Valor:
- **-12.0 pixels** = exatamente -1 staff space (com staffSpace = 12px)
- Termina precisamente na barra, sem espaço extra

#### Alternativas testadas:
- `0.0`: Margem padrão de 1 staff space (linhas vão além da barra)
- `-3.0`: Linhas terminam um pouco antes da barra

---

### `finalBarlineMargin = -1.5` (pixels)
**Arquivo:** `lib/src/rendering/staff_renderer.dart:59`

#### Origem:
Margem após barra final (linha fina + linha grossa). Ajustado para terminar visualmente correto.

#### Valor:
- **-1.5 pixels** ≈ -0.125 staff spaces (com staffSpace = 12px)
- Compensa a largura visual da barra grossa final

---

## Conclusão

Todos os magic numbers no Flutter Notemus têm justificativas baseadas em:

1. **Especificação SMuFL 1.4** (W3C)
2. **Bravura metadata** (1.392)
3. **Behind Bars** (Elaine Gould)
4. **The Art of Music Engraving** (Ted Ross)
5. **Pesquisa acadêmica** (Lime, MuseScore MS21)
6. **Calibração visual** comparando com software profissional (Verovio, MuseScore, LilyPond)

Valores não arbitrários, mas sim resultado de análise tipográfica e matemática profunda!

---

**Última atualização:** 6 de Novembro de 2025
**Autor:** Análise técnica completa pelo time Flutter Notemus
**Versão:** 1.0
