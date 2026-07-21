String maskEmail(String email) {
  final trimmed = email.trim();
  final atIndex = trimmed.indexOf('@');
  if (atIndex <= 0) return trimmed;

  final username = trimmed.substring(0, atIndex);
  final domain = trimmed.substring(atIndex);

  String masked;
  if (username.length <= 2) {
    masked = '*' * username.length;
  } else if (username.length <= 4) {
    masked =
        '${username[0]}${'*' * (username.length - 2)}${username[username.length - 1]}';
  } else {
    final visibleStart = username.substring(0, 2);
    final visibleEnd = username.substring(username.length - 2);
    final hiddenCount = username.length - 4;
    masked = '$visibleStart${'*' * hiddenCount}$visibleEnd';
  }

  return '$masked$domain';
}
