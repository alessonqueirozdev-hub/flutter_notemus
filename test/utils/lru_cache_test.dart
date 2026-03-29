import 'package:flutter_notemus/src/utils/lru_cache.dart';
import 'package:test/test.dart';

void main() {
  group('LruCache', () {
    test('basic - add and retrieve', () {
      final cache = LruCache<String, int>(3);
      cache.put('a', 1);
      cache.put('b', 2);
      cache.put('c', 3);

      expect(cache.size, 3);
      expect(cache.get('a'), 1);
      expect(cache.get('b'), 2);
      expect(cache.get('c'), 3);
    });

    test('eviction - removes least recently used item', () {
      final cache = LruCache<String, int>(3);
      cache.put('a', 1);
      cache.put('b', 2);
      cache.put('c', 3);

      // Adding the 4th item should remove 'a' (least recently used)
      cache.put('d', 4);

      expect(cache.size, 3);
      expect(cache.get('a'), null); // Removed
      expect(cache.get('b'), 2);
      expect(cache.get('c'), 3);
      expect(cache.get('d'), 4);
    });

    test('LRU behavior - accessed item becomes recent', () {
      final cache = LruCache<String, int>(3);
      cache.put('a', 1);
      cache.put('b', 2);
      cache.put('c', 3);

      // Accessing 'a' makes it recent
      cache.get('a');

      // Adding 'd' should remove 'b' (now the least recently used)
      cache.put('d', 4);

      expect(cache.get('a'), 1); // Still present (was accessed)
      expect(cache.get('b'), null); // Removed (least recently used)
      expect(cache.get('c'), 3);
      expect(cache.get('d'), 4);
    });

    test('clear - clears the entire cache', () {
      final cache = LruCache<String, int>(3);
      cache.put('a', 1);
      cache.put('b', 2);

      expect(cache.size, 2);

      cache.clear();

      expect(cache.size, 0);
      expect(cache.get('a'), null);
      expect(cache.get('b'), null);
    });

    test('update existing value', () {
      final cache = LruCache<String, int>(3);
      cache.put('a', 1);
      cache.put('b', 2);

      // Update 'a'
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
