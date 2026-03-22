import 'package:flutter_notemus/src/utils/lru_cache.dart';
import 'package:test/test.dart';

void main() {
  group('LruCache', () {
    test('básico - adicionar e recuperar', () {
      final cache = LruCache<String, int>(3);
      cache.put('a', 1);
      cache.put('b', 2);
      cache.put('c', 3);

      expect(cache.size, 3);
      expect(cache.get('a'), 1);
      expect(cache.get('b'), 2);
      expect(cache.get('c'), 3);
    });

    test('eviction - remove item menos recente', () {
      final cache = LruCache<String, int>(3);
      cache.put('a', 1);
      cache.put('b', 2);
      cache.put('c', 3);

      // Adicionar 4º item deve remover 'a' (menos recente)
      cache.put('d', 4);

      expect(cache.size, 3);
      expect(cache.get('a'), null); // Removido
      expect(cache.get('b'), 2);
      expect(cache.get('c'), 3);
      expect(cache.get('d'), 4);
    });

    test('LRU behavior - item acessado fica recente', () {
      final cache = LruCache<String, int>(3);
      cache.put('a', 1);
      cache.put('b', 2);
      cache.put('c', 3);

      // Acessar 'a' o torna recente
      cache.get('a');

      // Adicionar 'd' deve remover 'b' (agora é o menos recente)
      cache.put('d', 4);

      expect(cache.get('a'), 1); // Ainda presente (foi acessado)
      expect(cache.get('b'), null); // Removido (menos recente)
      expect(cache.get('c'), 3);
      expect(cache.get('d'), 4);
    });

    test('clear - limpa todo o cache', () {
      final cache = LruCache<String, int>(3);
      cache.put('a', 1);
      cache.put('b', 2);

      expect(cache.size, 2);

      cache.clear();

      expect(cache.size, 0);
      expect(cache.get('a'), null);
      expect(cache.get('b'), null);
    });

    test('atualizar valor existente', () {
      final cache = LruCache<String, int>(3);
      cache.put('a', 1);
      cache.put('b', 2);

      // Atualizar 'a'
      cache.put('a', 10);

      expect(cache.get('a'), 10);
      expect(cache.size, 2);
    });

    test('containsKey', () {
      final cache = LruCache<String, int>(3);
      cache.put('a', 1);

      expect(cache.containsKey('a'), true);
      expect(cache.containsKey('b'), false);
    });
  });
}
