import 'dart:convert';

String normalizeText(String value) {
  if (value.isEmpty) {
    return value;
  }

  var current = value;
  for (var i = 0; i < 10; i++) {
    if (!looksMojibake(current)) {
      break;
    }
    final repaired = repairMojibakeOnce(current);
    if (repaired == current) {
      break;
    }
    current = repaired;
  }
  return current;
}

String? normalizeNullableText(String? value) {
  if (value == null) {
    return null;
  }
  if (value.isEmpty) {
    return value;
  }
  return normalizeText(value);
}

Map<String, dynamic> normalizeDynamicMap(Map<String, dynamic> input) {
  return input.map(
    (key, value) => MapEntry(key, normalizeDynamicValue(value)),
  );
}

dynamic normalizeDynamicValue(dynamic value) {
  if (value is String) {
    return normalizeText(value);
  }
  if (value is Map) {
    return normalizeDynamicMap(Map<String, dynamic>.from(value));
  }
  if (value is List) {
    return value.map(normalizeDynamicValue).toList();
  }
  return value;
}

bool looksMojibake(String value) {
  const suspiciousFragments = [
    'Ã',
    'Â',
    'â',
    'ï',
    '�',
    '\u0081',
    '\u008d',
    '\u008f',
    '\u0090',
    '\u009d',
  ];

  return suspiciousFragments.any(value.contains);
}

String repairMojibakeOnce(String value) {
  try {
    return utf8.decode(latin1.encode(value), allowMalformed: true);
  } catch (_) {
    return value;
  }
}
