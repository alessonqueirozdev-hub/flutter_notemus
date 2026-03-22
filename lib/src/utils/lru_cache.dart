// lib/src/utils/lru_cache.dart
// Implementação simples de LRU Cache usando LinkedHashMap

import 'dart:collection';

/// Cache LRU (Least Recently Used) simples e síncrono
///
/// Implementação baseada em [LinkedHashMap] que mantém ordem de acesso.
/// Quando o cache atinge o tamanho máximo, remove o item menos recentemente usado.
///
/// **Performance:**
/// - get(): O(1)
/// - put(): O(1)
/// - Eviction: O(1)
///
/// **Thread-safety:** Não é thread-safe. Use em contexto single-threaded (renderização Flutter).
class LruCache<K, V> {
  final int maxSize;
  final LinkedHashMap<K, V> _cache;

  /// Cria um LRU cache com tamanho máximo especificado
  LruCache(this.maxSize) : _cache = LinkedHashMap<K, V>();

  /// Obtém valor do cache
  ///
  /// Move o item para o fim (mais recente) se existir.
  /// Retorna null se não encontrado.
  V? get(K key) {
    if (!_cache.containsKey(key)) {
      return null;
    }

    // Mover para o fim (mais recente)
    final value = _cache.remove(key)!;
    _cache[key] = value;
    return value;
  }

  /// Adiciona ou atualiza valor no cache
  ///
  /// Se cache está cheio, remove o item mais antigo (primeiro da lista).
  void put(K key, V value) {
    // Se já existe, remover para adicionar no fim
    if (_cache.containsKey(key)) {
      _cache.remove(key);
    }

    // Se atingiu limite, remover o mais antigo (primeiro item)
    if (_cache.length >= maxSize) {
      _cache.remove(_cache.keys.first);
    }

    // Adicionar no fim (mais recente)
    _cache[key] = value;
  }

  /// Verifica se chave existe no cache
  bool containsKey(K key) => _cache.containsKey(key);

  /// Limpa todo o cache
  void clear() => _cache.clear();

  /// Retorna número de itens no cache
  int get size => _cache.length;

  /// Retorna número de itens no cache (alias para size)
  int get length => _cache.length;

  @override
  String toString() => 'LruCache[maxSize=$maxSize,size=$size]';
}
