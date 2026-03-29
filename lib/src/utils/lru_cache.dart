// lib/src/utils/lru_cache.dart
// Implementação simples de LRU Cache using LinkedHashMap

import 'dart:collection';

/// Cache LRU (Least Recently Used) simples e síncrono
///
/// Implementação baseada in [LinkedHashMap] that mantém ordem de acesso.
/// When o cache atinge o size máximo, remove o item menos recentemente used.
///
/// **Performance:**
/// - get(): O(1)
/// - put(): O(1)
/// - Eviction: O(1)
///
/// **Thread-safety:** Not é thread-safe. Use in contexto single-threaded (Rendersção Flutter).
class LruCache<K, V> {
  final int maxSize;
  final LinkedHashMap<K, V> _cache;

  /// Creates um LRU cache with size máximo especificado
  LruCache(this.maxSize) : _cache = LinkedHashMap<K, V>();

  /// Gets value of the cache
  ///
  /// Move o item for o fim (mais recente) se existir.
  /// Returns null se not encontrado.
  V? get(K key) {
    if (!_cache.containsKey(key)) {
      return null;
    }

    // Mover for o fim (mais recente)
    final value = _cache[key] as V;
    _cache.remove(key);
    _cache[key] = value;
    return value;
  }

  /// Adds ou currentiza value no cache
  ///
  /// Se cache está cheio, remove o item mais antigo (first of the list).
  void put(K key, V value) {
    // Se já existe, remover for add no fim
    if (_cache.containsKey(key)) {
      _cache.remove(key);
    }

    // Se atingiu limite, remover o mais antigo (first item)
    if (_cache.length >= maxSize) {
      _cache.remove(_cache.keys.first);
    }

    // add no fim (mais recente)
    _cache[key] = value;
  }

  /// Checks se chave existe no cache
  bool containsKey(K key) => _cache.containsKey(key);

  /// Limpa todo o cache
  void clear() => _cache.clear();

  /// Returns number de itens no cache
  int get size => _cache.length;

  /// Returns number de itens no cache (alias for size)
  int get length => _cache.length;

  @override
  String toString() => 'LruCache[maxSize=$maxSize,size=$size]';
}
