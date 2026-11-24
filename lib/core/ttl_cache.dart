/// Basit, bellek içi süreli önbellek.
///
/// Amaç gereksiz API isteklerini azaltmak. Kalıcı değildir: uygulama
/// kapanınca silinir, böylece eski veri sonraki açılışta "güncel" gibi görünmez.
class TtlCache<T> {
  TtlCache(this.ttl, {this.maxEntries = 32});

  final Duration ttl;
  final int maxEntries;
  final _entries = <String, (DateTime, T)>{};

  T? get(String key) {
    final e = _entries[key];
    if (e == null) return null;
    if (DateTime.now().difference(e.$1) > ttl) {
      _entries.remove(key);
      return null;
    }
    return e.$2;
  }

  void put(String key, T value) {
    if (_entries.length >= maxEntries) _entries.remove(_entries.keys.first);
    _entries[key] = (DateTime.now(), value);
  }

  void clear() => _entries.clear();
}
