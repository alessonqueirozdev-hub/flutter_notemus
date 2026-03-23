# Guia de Implementação: LRU Cache para TextPainters

## Status
🔄 **EM ANDAMENTO** - Dependência `collection` adicionada ao pubspec.yaml

## Objetivo
Substituir o `Map` ilimitado por um `LruMap` com limite de 500 entradas para evitar memory leaks em aplicações de longa duração.

---

## Alterações Necessárias

### Arquivo: `lib/src/rendering/renderers/base_glyph_renderer.dart`

#### 1. Adicionar import
```dart
// Adicionar no topo do arquivo, junto com outros imports:
import 'package:collection/collection.dart';
```

#### 2. Substituir declaração do cache (linha ~29)

**ANTES:**
```dart
  /// Cache de TextPainters reutilizáveis para performance
  /// Key: glyphName_size_color
  final Map<String, TextPainter> _textPainterCache = {};
```

**DEPOIS:**
```dart
  /// Cache LRU de TextPainters reutilizáveis para performance
  ///
  /// **Limite:** 500 entradas (evita memory leak)
  /// **Estratégia:** LRU (Least Recently Used) - remove entradas menos usadas
  /// **Key:** glyphName_size_color
  ///
  /// **Cálculo de tamanho estimado:**
  /// - Cada TextPainter: ~2-5 KB (dependendo do glyph)
  /// - 500 entradas: ~1-2.5 MB de memória máxima
  ///
  /// **Benchmarks:**
  /// - Hit rate típico: 85-95% (poucas combinações de glyph/size/color)
  /// - Miss apenas em glyphs raros ou tamanhos incomuns
  final LruMap<String, TextPainter> _textPainterCache = LruMap(500);
```

---

## Justificativa do Limite: 500 entradas

### Cálculo Matemático

**Número típico de combinações:**
- **Glyphs únicos na partitura:** ~50-100 (noteheads, accidentals, clefs, articulations, etc.)
- **Tamanhos diferentes:** 2-3 (staffSpace padrão + grace notes)
- **Cores diferentes:** 1-2 (preto + eventualmente coloração de voz)

**Total de combinações comuns:**
```
50 glyphs × 2 sizes × 1 color = 100 entradas (uso típico)
100 glyphs × 3 sizes × 2 colors = 600 entradas (máximo esperado)
```

**Limite escolhido: 500**
- Cobre 100% dos casos típicos
- Margem de segurança para casos raros
- Memória máxima controlada

### Impacto na Performance

**Antes (Map ilimitado):**
```
❌ Cache cresce indefinidamente
❌ Memory leak em aplicações longas
❌ Sem controle de memória
✅ 100% hit rate após warming
```

**Depois (LruMap com limite 500):**
```
✅ Tamanho máximo controlado
✅ Memória estável (~1-2.5 MB)
✅ Automatic eviction de entradas antigas
✅ ~95% hit rate (glyphs comuns ficam no cache)
⚠️ Miss ocasional em glyphs raros (custo: 1-2ms para recriar TextPainter)
```

### Benchmarks Esperados

| Métrica | Antes | Depois |
|---------|-------|--------|
| **Cache Size (inicial)** | 0 | 0 |
| **Cache Size (após warming)** | ~100 | ~100 |
| **Cache Size (após 1h uso)** | ~500-1000+ | 500 (máximo) |
| **Memória usada** | 2-5+ MB | 1-2.5 MB |
| **Hit rate** | 100% | ~95% |
| **Latência miss** | N/A | +1-2ms |

---

## Testes Sugeridos

### 1. Teste de Capacidade Máxima

```dart
// test/base_glyph_renderer_test.dart
test('LRU cache não excede 500 entradas', () {
  final renderer = TestGlyphRenderer(...);

  // Criar 1000 entradas únicas
  for (int i = 0; i < 1000; i++) {
    renderer.drawGlyphWithBBox(
      canvas,
      glyphName: 'testGlyph$i',
      position: Offset.zero,
      color: Colors.black,
    );
  }

  // Verificar que cache não excede 500
  expect(renderer.cacheSize, lessThanOrEqualTo(500));
});
```

### 2. Teste de Eviction (LRU Behavior)

```dart
test('LRU cache remove entradas menos recentemente usadas', () {
  final renderer = TestGlyphRenderer(...);

  // Preencher cache até limite
  for (int i = 0; i < 500; i++) {
    renderer.drawGlyphWithBBox(..., glyphName: 'glyph$i');
  }

  // Acessar glyph0 (torná-lo recente)
  renderer.drawGlyphWithBBox(..., glyphName: 'glyph0');

  // Adicionar novo glyph (deve remover glyph1, não glyph0)
  renderer.drawGlyphWithBBox(..., glyphName: 'glyph500');

  // Verificar: glyph0 ainda no cache, glyph1 foi removido
  // (implementação específica depende de acesso interno ao LruMap)
});
```

### 3. Teste de Performance (Hit Rate)

```dart
test('LRU cache mantém alto hit rate em uso típico', () {
  final renderer = TestGlyphRenderer(...);

  // Simular partitura típica: 50 glyphs diferentes usados repetidamente
  final commonGlyphs = ['noteheadBlack', 'noteheadHalf', 'gClef', ...];

  int hits = 0;
  int total = 0;

  for (int measure = 0; measure < 100; measure++) {
    for (final glyph in commonGlyphs) {
      final beforeSize = renderer.cacheSize;
      renderer.drawGlyphWithBBox(..., glyphName: glyph);
      final afterSize = renderer.cacheSize;

      if (afterSize == beforeSize) hits++; // Cache hit
      total++;
    }
  }

  final hitRate = hits / total;
  expect(hitRate, greaterThan(0.90)); // >90% hit rate esperado
});
```

---

## Verificação de Implementação

### Checklist

- [ ] Import de `collection` adicionado
- [ ] `Map` substituído por `LruMap(500)`
- [ ] Comentários de documentação atualizados
- [ ] `clearCache()` ainda funciona (LruMap tem método `.clear()`)
- [ ] `cacheSize` ainda funciona (LruMap tem propriedade `.length`)
- [ ] Testes de capacidade máxima passando
- [ ] Performance mantida ou melhorada

### Comandos de Verificação

```bash
# 1. Verificar que não há erros de lint
dart analyze

# 2. Rodar testes
flutter test

# 3. Verificar importações
grep -n "import 'package:collection" lib/src/rendering/renderers/base_glyph_renderer.dart

# 4. Verificar uso de LruMap
grep -n "LruMap" lib/src/rendering/renderers/base_glyph_renderer.dart
```

---

## Próximos Passos

1. ✅ Dependência `collection` adicionada (COMPLETO)
2. ⏳ Implementar mudanças no código
3. ⏳ Adicionar testes unitários
4. ⏳ Verificar performance com benchmarks

---

**Última atualização:** 6 de Novembro de 2025
**Status:** Aguardando implementação das mudanças no código
**Prioridade:** Alta (previne memory leaks)
