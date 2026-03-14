import 'package:xml/xml.dart';

/// UDA 1.1 §3.2.5 — UPnP error codes returned in SOAP Fault responses.
///
/// HTTP 500 responses carry a SOAP Fault with `<UPnPError>` containing an
/// `<errorCode>` (401–899) and optional `<errorDescription>`.
class UPnPException implements Exception {
  /// Numeric error code per UDA 1.1 §3.2.5 Table 3-3.
  ///
  /// Standard ranges:
  /// - 401 Invalid Action
  /// - 402 Invalid Args
  /// - 501 Action Failed
  /// - 600–605 Argument value errors
  /// - 606–612 Security errors
  /// - 700–799 Action-specific (defined by DCP)
  /// - 800–899 Vendor-specific
  final int errorCode;

  /// Human-readable error description. May be empty.
  final String errorDescription;

  /// The SOAP action that triggered the error, if known.
  final String? actionName;

  UPnPException({
    required this.errorCode,
    this.errorDescription = '',
    this.actionName,
  });

  /// Parses a UPnP SOAP Fault from a `<Body>` element containing a `<Fault>`.
  ///
  /// Expected XML structure (UDA 1.1 §3.2.5):
  /// ```xml
  /// <s:Body>
  ///   <s:Fault>
  ///     <faultcode>s:Client</faultcode>
  ///     <faultstring>UPnPError</faultstring>
  ///     <detail>
  ///       <UPnPError xmlns="urn:schemas-upnp-org:control-1-0">
  ///         <errorCode>401</errorCode>
  ///         <errorDescription>Invalid Action</errorDescription>
  ///       </UPnPError>
  ///     </detail>
  ///   </s:Fault>
  /// </s:Body>
  /// ```
  ///
  /// Returns `null` if the body does not contain a parseable UPnP fault.
  static UPnPException? tryParseFromBody(XmlElement body,
      {String? actionName}) {
    // Find <Fault> — may be namespace-prefixed or not
    final fault = body.getElement('Fault',
            namespace: 'http://schemas.xmlsoap.org/soap/envelope/') ??
        body.childElements.where((e) => e.name.local == 'Fault').firstOrNull;
    if (fault == null) return null;

    final detail = fault.getElement('detail') ??
        fault.childElements.where((e) => e.name.local == 'detail').firstOrNull;
    if (detail == null) return null;

    final upnpError = detail.getElement('UPnPError',
            namespace: 'urn:schemas-upnp-org:control-1-0') ??
        detail.childElements
            .where((e) => e.name.local == 'UPnPError')
            .firstOrNull;
    if (upnpError == null) return null;

    final codeText = upnpError.getElement('errorCode')?.innerText;
    final code = codeText != null ? int.tryParse(codeText) : null;
    if (code == null) return null;

    final description =
        upnpError.getElement('errorDescription')?.innerText ?? '';

    return UPnPException(
      errorCode: code,
      errorDescription: description,
      actionName: actionName,
    );
  }

  @override
  String toString() {
    final action = actionName != null ? ' (action: $actionName)' : '';
    return 'UPnPException: $errorCode $errorDescription$action';
  }
}
