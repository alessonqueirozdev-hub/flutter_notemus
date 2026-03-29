// lib/src/utils/lru_cache.dart
// Implementation simples de LRU Cache using LinkedHashMap

import 'dart:collection';

/// Cache LRU (Least Recently Used) simples and síncrono
///
/// Implementation baseada in [LinkedHashMap] that mantém ordem de acesso.
/// When o cache atinge o size máximo, remove o item less recentemente used.
///
/// **Performance:**
/// - get(): O(1)
/// - put(): O(1)
/// - Eviction: O(1)
///
/// **Thread-safety:** Not is thread-safe. Use in context single-threaded (Rendering Flutter).
class LruCache<K, V> {
  final int maxSize;
  final LinkedHashMap<K, V> _cache;

  /// Creates a LRU cache with size máximo especificado
  LruCache(this.maxSize) : _cache = LinkedHashMap<K, V>();

  /// Gets value of the cache
  ///
  /// Move o item for o end (more recente) if existir.
  /// Returns null if not encontrado.
  V? get(K key) {
    if (!_cache.containsKey(key)) {
      return null;
    }

    // Mover for o end (more recente)
    final value = _cache[key] as V;
    _cache.remove(key);
    _cache[key] = value;
    return value;
  }

  /// Adds or currentiza value no cache
  ///
  /// If cache está cheio, remove o item more antigo (first of the list).
  void put(K key, V value) {
    // If already existe, remover for add no end
    if (_cache.containsKey(key)) {
      _cache.remove(key);
    }

    // If atingiu limite, remover o more antigo (first item)
    if (_cache.length >= maxSize) {
      _cache.remove(_cache.keys.first);
    }

    // add no end (more recente)
    _cache[key] = value;
  }

  /// Checks if chave existe no cache
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
