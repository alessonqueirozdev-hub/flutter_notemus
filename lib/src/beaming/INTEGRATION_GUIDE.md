# 🔧 Guia de Integração - Sistema de Beaming Avançado

Este documento orienta a integração do sistema de beaming com o LayoutEngine existente.

---

## 📋 Checklist de Integração

### ✅ Fase 1: Componentes Implementados (COMPLETO)

- [x] `beam_types.dart` - Enums e tipos base
- [x] `beam_segment.dart` - Estrutura de segmentos
- [x] `beam_group.dart` - Grupo de notas beamed
- [x] `beam_analyzer.dart` - Análise e geometria
- [x] `beam_renderer.dart` - Renderização no canvas
- [x] `beaming.dart` - Barrel file
- [x] `README.md` - Documentação completa
- [x] `INTEGRATION_GUIDE.md` - Este guia

### 🔄 Fase 2: Integração com LayoutEngine (PENDENTE)

- [ ] Detectar grupos de notas beamed consecutivas
- [ ] Calcular posições X e Y das notas durante layout
- [ ] Criar mapa de posições para BeamAnalyzer
- [ ] Gerar BeamGroups para cada grupo detectado
- [ ] Renderizar beams após notas no StaffRenderer
- [ ] Ajustar comprimento de hastes baseado em beams
- [ ] Testar com exemplos reais

### 🧪 Fase 3: Testes e Refinamento (FUTURO)

- [ ] Testes unitários para BeamAnalyzer
- [ ] Testes unitários para BeamSegment
- [ ] Testes de renderização visual
- [ ] Benchmarks de performance
- [ ] Ajustes finos de geometria
- [ ] Documentação de API

---

## 🏗️ Pontos de Integração

### 1. Detectar Grupos de Notas Beamed

**Localização:** `LayoutEngine._layoutStaff()`

```dart
class LayoutEngine {
  List<List<Note>> _detectBeamGroups(List<MusicalElement> elements) {
    final beamGroups = <List<Note>>[];
    List<Note>? currentGroup;

    for (final element in elements) {
      if (element is Note) {
        final hasBeam = element.beam != null;
        final needsBeam = _needsBeam(element.duration);

        if (needsBeam) {
          currentGroup ??= [];
          currentGroup.add(element);

          // Finalizar grupo se nota marca fim de beam
          if (element.beam == BeamType.end) {
            beamGroups.add(currentGroup);
            currentGroup = null;
          }
        } else {
          // Nota não beamed: finalizar grupo anterior se existir
          if (currentGroup != null && currentGroup.isNotEmpty) {
            beamGroups.add(currentGroup);
            currentGroup = null;
          }
        }
      }
    }

    // Finalizar último grupo se existir
    if (currentGroup != null && currentGroup.isNotEmpty) {
      beamGroups.add(currentGroup);
    }

    return beamGroups;
  }

  bool _needsBeam(Duration duration) {
    return duration.type == DurationType.eighth ||
           duration.type == DurationType.sixteenth ||
           duration.type == DurationType.thirtySecond ||
           duration.type == DurationType.sixtyFourth ||
           duration.type == DurationType.oneHundredTwentyEighth;
  }
}
```

### 2. Coletar Posições das Notas

**Durante o layout, armazenar:**

```dart
class LayoutEngine {
  final Map<Note, double> _noteXPositions = {};
  final Map<Note, int> _noteStaffPositions = {};
  
  void _layoutNote(Note note, double x) {
    // Calcular staff position (0 = linha inferior)
    final staffPosition = _calculateStaffPosition(note.pitch);
    
    // Armazenar posições
    _noteXPositions[note] = x;
    _noteStaffPositions[note] = staffPosition;
    
    // ... resto do layout de nota
  }
  
  int _calculateStaffPosition(Pitch pitch) {
    // C4 (Dó central) = posição 0 em clave de Sol
    // Cada semitom = 0.5 posição (linha ou espaço)
    // TODO: Ajustar baseado na clave atual
    const c4Position = 0;
    final semitonesFromC4 = _calculateSemitones(pitch);
    return c4Position + (semitonesFromC4 ~/ 2);
  }
}
```

### 3. Criar BeamGroups

```dart
class LayoutEngine {
  late final BeamAnalyzer beamAnalyzer;
  final List<BeamGroup> _beamGroups = [];
  
  void _initializeBeamSystem() {
    beamAnalyzer = BeamAnalyzer(
      staffSpace: staffSpace,
      noteheadWidth: noteheadWidth,
    );
  }
  
  void _analyzeBeamGroups(List<List<Note>> beamGroups) {
    for (final notes in beamGroups) {
      if (notes.length < 2) continue; // Precisa de pelo menos 2 notas
      
      final beamGroup = beamAnalyzer.analyzeBeamGroup(
        notes,
        currentTimeSignature,
        noteXPositions: _noteXPositions,
        noteStaffPositions: _noteStaffPositions,
      );
      
      _beamGroups.add(beamGroup);
    }
  }
}
```

### 4. Renderizar Beams

**Localização:** `StaffRenderer.render()`

```dart
class StaffRenderer {
  late final BeamRenderer beamRenderer;
  
  void _initializeRenderers() {
    // ... outros renderers
    
    beamRenderer = BeamRenderer(
      theme: theme,
      staffSpace: staffSpace,
      noteheadWidth: noteheadWidth,
    );
  }
  
  void render(Canvas canvas, Staff staff, LayoutResult layout) {
    // 1. Desenhar pauta
    _drawStaffLines(canvas);
    
    // 2. Desenhar elementos (clefs, notas, etc.)
    for (final positioned in layout.positionedElements) {
      _renderElement(canvas, positioned);
    }
    
    // 3. Desenhar beams (POR CIMA das notas e hastes)
    for (final beamGroup in layout.beamGroups) {
      beamRenderer.renderBeamGroup(canvas, beamGroup);
    }
    
    // 4. Outros elementos (slurs, dynamics, etc.)
  }
}
```

### 5. Ajustar Comprimento de Hastes

**IMPORTANTE:** Hastes individuais não devem ser desenhadas para notas beamed. O `BeamRenderer` desenha as hastes completas.

```dart
class NoteRenderer {
  void render(Canvas canvas, Note note, Offset position) {
    // Desenhar notehead
    _renderNotehead(canvas, note, position);
    
    // NÃO desenhar haste se nota estiver em beam
    if (note.beam == null || note.beam == BeamType.none) {
      _renderStem(canvas, note, position);
    }
    
    // Desenhar outros elementos (accidentals, dots, etc.)
  }
}
```

---

## 🎯 Exemplo de Integração Completa

```dart
class LayoutEngine {
  // Instâncias
  late final BeamAnalyzer beamAnalyzer;
  late final BeamRenderer beamRenderer;
  
  // Dados de posicionamento
  final Map<Note, double> _noteXPositions = {};
  final Map<Note, int> _noteStaffPositions = {};
  final List<BeamGroup> _beamGroups = [];
  
  void initialize() {
    beamAnalyzer = BeamAnalyzer(
      staffSpace: staffSpace,
      noteheadWidth: noteheadWidth,
    );
    
    beamRenderer = BeamRenderer(
      theme: theme,
      staffSpace: staffSpace,
      noteheadWidth: noteheadWidth,
    );
  }
  
  LayoutResult layoutStaff(Staff staff) {
    // 1. Layout normal de elementos
    for (final measure in staff.measures) {
      _layoutMeasure(measure);
    }
    
    // 2. Detectar grupos de beam
    final beamGroups = _detectBeamGroups(staff.allElements);
    
    // 3. Analisar geometria de beams
    _beamGroups.clear();
    for (final notes in beamGroups) {
      final group = beamAnalyzer.analyzeBeamGroup(
        notes,
        currentTimeSignature,
        noteXPositions: _noteXPositions,
        noteStaffPositions: _noteStaffPositions,
      );
      _beamGroups.add(group);
    }
    
    // 4. Retornar resultado com beams
    return LayoutResult(
      positionedElements: _positionedElements,
      beamGroups: _beamGroups,
      totalWidth: _currentX,
      totalHeight: staffHeight,
    );
  }
}

class LayoutResult {
  final List<PositionedElement> positionedElements;
  final List<BeamGroup> beamGroups; // NOVO
  final double totalWidth;
  final double totalHeight;
  
  LayoutResult({
    required this.positionedElements,
    required this.beamGroups,
    required this.totalWidth,
    required this.totalHeight,
  });
}
```

---

## 🚨 Pontos de Atenção

### 1. Ordem de Renderização

```
CORRETO:
1. Staff lines
2. Clefs, key signatures, time signatures
3. Noteheads
4. Accidentals
5. Dots
6. BEAMS (com hastes)  ← Beam renderer desenha hastes
7. Articulations
8. Slurs, ties
9. Dynamics, text
```

### 2. Sistema de Coordenadas

O `BeamAnalyzer` espera:
- **X positions**: Canto esquerdo da notehead
- **Staff positions**: Inteiro (0 = linha inferior, 2 = segunda linha, etc.)
  - Linhas = pares (0, 2, 4, 6, 8)
  - Espaços = ímpares (1, 3, 5, 7)

### 3. TimeSignature

Passar sempre o `TimeSignature` atual para `analyzeBeamGroup()` - é essencial para regras de quebra de secondary beams.

### 4. Hastes Não Duplicadas

**CRÍTICO:** Desabilitar renderização de hastes individuais em `NoteRenderer` para notas beamed!

```dart
// ❌ ERRADO - duplica hastes
void renderNote(Note note) {
  drawNotehead();
  drawStem(); // Sempre desenha
}

// ✅ CORRETO - só desenha se não beamed
void renderNote(Note note) {
  drawNotehead();
  if (note.beam == null) {
    drawStem();
  }
}
```

---

## 🧪 Como Testar

### Teste 1: Colcheias Simples

```dart
final notes = [
  Note(
    pitch: Pitch(step: 'C', octave: 5),
    duration: Duration(DurationType.eighth),
    beam: BeamType.start,
  ),
  Note(
    pitch: Pitch(step: 'D', octave: 5),
    duration: Duration(DurationType.eighth),
    beam: BeamType.inner,
  ),
  Note(
    pitch: Pitch(step: 'E', octave: 5),
    duration: Duration(DurationType.eighth),
    beam: BeamType.inner,
  ),
  Note(
    pitch: Pitch(step: 'F', octave: 5),
    duration: Duration(DurationType.eighth),
    beam: BeamType.end,
  ),
];

// Deve criar 1 beam horizontal conectando as 4 notas
```

### Teste 2: Ritmo Pontuado

```dart
final notes = [
  Note(
    pitch: Pitch(step: 'G', octave: 5),
    duration: Duration(DurationType.eighth, dots: 1),
    beam: BeamType.start,
  ),
  Note(
    pitch: Pitch(step: 'A', octave: 5),
    duration: Duration(DurationType.sixteenth),
    beam: BeamType.end,
  ),
];

// Deve criar:
// - 1 primary beam conectando as 2 notas
// - 1 fractional beam (stub) na segunda nota
```

### Teste 3: Semicolcheias com Quebra

```dart
final notes = List.generate(8, (i) => Note(
  pitch: Pitch(step: 'C', octave: 5),
  duration: Duration(DurationType.sixteenth),
  beam: i == 0 ? BeamType.start : (i == 7 ? BeamType.end : BeamType.inner),
));

// Em 4/4, deve criar:
// - 1 primary beam contínuo (8 notas)
// - 2 secondary beams (quebrado no meio - tempo 1 e tempo 2)
```

---

## 📊 Métricas de Sucesso

### Visual

- [ ] Beams conectam corretamente as notas
- [ ] Inclinação é suave e profissional (< 1.25 SS)
- [ ] Secondary beams quebram nos lugares certos
- [ ] Fractional beams têm comprimento correto (~1 notehead)
- [ ] Hastes não estão duplicadas
- [ ] Beams "snap" para linhas da pauta

### Técnico

- [ ] Nenhum warning de lint
- [ ] Performance adequada (< 16ms por frame)
- [ ] Memória estável (sem leaks)
- [ ] Funciona com todos os tipos de duração

---

## 🐛 Troubleshooting

### Problema: Beams não aparecem

**Causas possíveis:**
- `BeamRenderer` não foi inicializado
- `beamGroups` vazios no `LayoutResult`
- Renderização acontece antes das notas (ordem errada)

**Solução:** Verificar ordem de renderização e se `_beamGroups` está populado.

### Problema: Hastes duplicadas

**Causa:** `NoteRenderer` desenha hastes individuais E `BeamRenderer` também.

**Solução:** Checar `note.beam` antes de desenhar haste individual.

### Problema: Inclinação muito acentuada

**Causa:** Notas muito distantes ou erro no cálculo de `staffPosition`.

**Solução:** Verificar cálculo de staff position e limitar slope em `BeamAnalyzer`.

### Problema: Secondary beams não quebram

**Causa:** Lógica de `_shouldBreakSecondaryBeam` não implementada completamente.

**Solução:** Implementar cálculo de beat position baseado em `TimeSignature`.

---

## 📚 Próximos Desenvolvimentos

### Curto Prazo

1. **Integração básica** com LayoutEngine
2. **Testes visuais** com exemplos reais
3. **Ajustes finos** de geometria

### Médio Prazo

4. **Pausas em beam groups**
5. **Beams através de mudança de clave**
6. **Grace notes** com beams

### Longo Prazo

7. **Tuplets** com beams
8. **Polifonia** (múltiplas vozes)
9. **Cross-staff beaming**
10. **Feathered beams** (accelerando/ritardando)

---

## ✅ Status Atual

| Componente | Status | Progresso |
|------------|--------|-----------|
| Estruturas de dados | ✅ | 100% |
| BeamAnalyzer | ✅ | 100% |
| BeamRenderer | ✅ | 100% |
| Documentação | ✅ | 100% |
| **Integração com Layout** | ⏳ | **0%** |
| Testes unitários | ⏳ | 0% |
| Exemplos visuais | ⏳ | 0% |

---

**🎵 Sistema Pronto para Integração! 🎵**

Siga este guia passo a passo para integrar o beaming system com o resto da biblioteca Flutter Notemus.
