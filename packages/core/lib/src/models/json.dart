/// Minimal strict JSON readers shared by all models.
typedef Json = Map<String, dynamic>;

T req<T>(Json j, String key) {
  final v = j[key];
  if (v is! T) {
    throw FormatException('Field "$key" must be $T, got ${v.runtimeType}');
  }
  return v;
}

T? opt<T>(Json j, String key) {
  final v = j[key];
  if (v == null) return null;
  if (v is! T) {
    throw FormatException('Field "$key" must be $T?, got ${v.runtimeType}');
  }
  return v;
}

List<T> reqList<T>(Json j, String key, T Function(Json) parse) =>
    req<List>(j, key).map((e) => parse(e as Json)).toList(growable: false);

List<String> strList(Json j, String key) =>
    (opt<List>(j, key) ?? const []).cast<String>().toList(growable: false);

Map<String, V> mapOf<V>(Json j, String key, V Function(Object?) conv) =>
    Map.unmodifiable(
      (opt<Map>(j, key) ?? const {}).map(
        (k, v) => MapEntry(k as String, conv(v)),
      ),
    );

double toDouble(Object? v) => (v as num).toDouble();
int toInt(Object? v) => v as int;

bool listEq<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool mapEq<V>(Map<String, V> a, Map<String, V> b) =>
    a.length == b.length && a.entries.every((e) => b[e.key] == e.value);

int mapHash<V>(Map<String, V> m) =>
    Object.hashAllUnordered(m.entries.map((e) => Object.hash(e.key, e.value)));
