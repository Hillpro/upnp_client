import 'dart:io';

/// The version of this package. Kept in sync with `pubspec.yaml` by
/// `test/user_agent_test.dart`.
const packageVersion = '1.4.1';

/// Characters an HTTP/1.1 product token may not hold. RFC 2616 §2.2 bars the
/// separators and CTLs; this keeps a conservative subset of what is left.
final _notToken = RegExp(r'[^\w.+-]+');

final _edgeHyphens = RegExp(r'^-+|-+$');

/// Reduces [value] to a single HTTP/1.1 product token.
///
/// `Platform.operatingSystemVersion` is documented as human-readable and "not
/// suitable for parsing": on Windows it carries quotes, spaces and parentheses,
/// each of which would end the token early. Illegal runs collapse to one hyphen.
String productToken(String value) {
  final token = value.replaceAll(_notToken, '-').replaceAll(_edgeHyphens, '');
  return token.isEmpty ? 'unknown' : token;
}

/// The `USER-AGENT` field value for SSDP requests.
///
/// UDA 1.1 §1.3.2: the value MUST begin with three product tokens — the OS as
/// `name/version`, then `UPnP/1.1`, then the product.
final userAgent =
    '${productToken(Platform.operatingSystem)}/'
    '${productToken(Platform.operatingSystemVersion)} '
    'UPnP/1.1 '
    'upnp_client/$packageVersion';
