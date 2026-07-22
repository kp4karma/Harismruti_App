/// Returns true when an API object is explicitly marked to be ignored.
///
/// Backends commonly serialize boolean columns as booleans, 0/1 numbers, or
/// strings. Supporting those forms keeps visibility behavior consistent across
/// every endpoint.
bool isIgnoredApiItem(dynamic value) {
  if (value is! Map) return false;

  dynamic flag;
  for (final key in const [
    'ignore',
    'ignored',
    'is_ignore',
    'is_ignored',
    'isIgnore',
    'isIgnored',
  ]) {
    if (value.containsKey(key)) {
      flag = value[key];
      break;
    }
  }

  if (flag is bool) return flag;
  if (flag is num) return flag != 0;
  if (flag is String) {
    return const {'true', '1', 'yes', 'y'}.contains(flag.trim().toLowerCase());
  }
  return false;
}

/// Recursively removes ignored objects from all lists in an API response.
dynamic filterIgnoredApiItems(dynamic value) {
  if (value is List) {
    return value
        .where((item) => !isIgnoredApiItem(item))
        .map(filterIgnoredApiItems)
        .toList();
  }
  if (value is Map) {
    return value.map((key, item) => MapEntry(key, filterIgnoredApiItems(item)));
  }
  return value;
}
