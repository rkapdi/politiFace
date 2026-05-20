// lib/core/cache/lru_cache.dart
//
// O(1) get and put LRU cache.
// Classic doubly linked list + HashMap implementation.
// Used for in-memory card object cache (capacity: 200 cards).

class _Node<K, V> {
  K? key;
  V? value;
  _Node<K, V>? prev;
  _Node<K, V>? next;

  _Node(this.key, this.value);
  _Node.sentinel() : key = null, value = null;
}

class LRUCache<K, V> {
  final int capacity;
  final _map = <K, _Node<K, V>>{};

  // Sentinel nodes — head.next = MRU, tail.prev = LRU
  final _head = _Node<K, V>.sentinel();
  final _tail = _Node<K, V>.sentinel();

  LRUCache(this.capacity) {
    assert(capacity > 0, 'LRUCache capacity must be positive');
    _head.next = _tail;
    _tail.prev = _head;
  }

  int get length => _map.length;

  /// O(1) — returns null if key not present or if value is null
  V? get(K key) {
    final node = _map[key];
    if (node == null) return null;
    _moveToFront(node); // mark as recently used
    return node.value;
  }

  /// O(1) — evicts LRU entry if at capacity
  void put(K key, V value) {
    final existing = _map[key];
    if (existing != null) {
      existing.value = value;
      _moveToFront(existing);
      return;
    }

    final node = _Node(key, value);
    _map[key] = node;
    _addToFront(node);

    if (_map.length > capacity) {
      final lru = _tail.prev!;
      _removeNode(lru);
      _map.remove(lru.key);
    }
  }

  /// O(1) — removes entry if present
  void remove(K key) {
    final node = _map.remove(key);
    if (node != null) _removeNode(node);
  }

  /// O(1)
  bool containsKey(K key) => _map.containsKey(key);

  void clear() {
    _map.clear();
    _head.next = _tail;
    _tail.prev = _head;
  }

  void _moveToFront(_Node<K, V> node) {
    _removeNode(node);
    _addToFront(node);
  }

  void _addToFront(_Node<K, V> node) {
    node.prev = _head;
    node.next = _head.next;
    _head.next!.prev = node;
    _head.next = node;
  }

  void _removeNode(_Node<K, V> node) {
    node.prev!.next = node.next;
    node.next!.prev = node.prev;
  }
}
