import 'dart:convert';
import 'dart:typed_data';

/// Parses a UPnP boolean string per UDA 1.1 §2.5.
///
/// '1' is the canonical value; 'true' and 'yes' are deprecated UDA 1.0 values
/// that MUST still be accepted when received from older devices.
///
/// Matched case-insensitively. Every UDA version repeats that values are not
/// case sensitive except where noted - UDA 1.0 §2.1 and §2.3, UDA 1.1 §2.3,
/// §2.5, §3.2 and §4.3, UDA 2.0 §2.3 and §2.5 - and neither the `boolean`
/// data type nor the `sendEvents` attribute is ever noted as an exception, so
/// 'YES' means what 'yes' means.
bool parseUpnpBool(String? value) =>
    const {'1', 'true', 'yes'}.contains(value?.toLowerCase());

/// Parses a `ui4` count of seconds into a [Duration].
///
/// Distinct from [parseUpnpTime]: several IGD state variables carry a plain
/// seconds count with Eng. Units "seconds" (WANIPConnection:1 §2.2) rather
/// than a `time` string. Returns null when the value is absent or not an
/// integer, which a compliant device never sends.
Duration? parseUpnpSeconds(String? value) {
  final seconds = int.tryParse(value ?? '');
  return seconds == null ? null : Duration(seconds: seconds);
}

/// Parses a UPnP time or time.tz string per UDA 1.1 §2.5.
///
/// Format is HH:MM:SS[.fraction][±HH:MM|Z]. Dart has no native time-of-day
/// type, so the result is a [Duration] from midnight. The timezone offset is
/// stripped before parsing; callers that need TZ-aware semantics should handle
/// the raw string themselves.
Duration? parseUpnpTime(String? value) {
  if (value == null) return null;
  // Strip optional timezone suffix (±HH:MM or Z).
  final normalized = value.replaceFirst(RegExp(r'[+-]\d{2}:\d{2}$|Z$'), '');
  final parts = normalized.split(':');
  if (parts.length < 2) return null;
  final hours = int.tryParse(parts[0]);
  final minutes = int.tryParse(parts[1]);
  // Seconds are optional and may carry a fractional part.
  final secParts = parts.length > 2 ? parts[2].split('.') : ['0'];
  final seconds = int.tryParse(secParts[0]);
  final millis = secParts.length > 1
      ? int.tryParse(secParts[1].padRight(3, '0').substring(0, 3))
      : 0;
  if (hours == null || minutes == null || seconds == null) return null;
  return Duration(
    hours: hours,
    minutes: minutes,
    seconds: seconds,
    milliseconds: millis ?? 0,
  );
}

/// Decodes a UPnP bin.base64 string per UDA 1.1 §2.5.
///
/// MIME-style base64 includes CRLF line breaks every 76 characters. Dart's
/// [base64] codec rejects those, so all whitespace is stripped first.
Uint8List? parseUpnpBase64(String? value) {
  if (value == null) return null;
  try {
    return base64.decode(base64.normalize(value.replaceAll(RegExp(r'\s'), '')));
  } on FormatException {
    return null;
  }
}

/// Decodes a UPnP bin.hex string per UDA 1.1 §2.5.
///
/// Dart has no built-in hex decoder; each pair of hex digits is parsed
/// individually. Returns null if the input is not valid hex.
Uint8List? parseUpnpHex(String? value) {
  if (value == null) return null;
  final hex = value.replaceAll(RegExp(r'\s'), '');
  if (hex.isEmpty || hex.length.isOdd) return null;
  try {
    return Uint8List.fromList([
      for (var i = 0; i < hex.length; i += 2)
        int.parse(hex.substring(i, i + 2), radix: 16),
    ]);
  } on FormatException {
    return null;
  }
}
