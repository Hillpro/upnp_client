/// Strips the trailing version from a UPnP device or service type URN.
///
/// UDA 1.1 §1.3.2 - a control point must treat a device or service whose type
/// version is *higher* than the one it knows as compatible with that version,
/// because a type is only ever extended within a major version. So matching on
/// the full URN is wrong: `...:WANIPConnection:2` has to select the same
/// implementation as `:1`.
///
/// Returns the URN up to and including the final colon, so the result is a
/// prefix rather than a valid type URN:
///
/// ```dart
/// baseTypeUrn('urn:schemas-upnp-org:service:AVTransport:1');
/// // 'urn:schemas-upnp-org:service:AVTransport:'
/// ```
///
/// A URN with no trailing version is returned unchanged, and null passes
/// through, so this is safe to apply to whatever a device description happens
/// to contain.
///
/// The `UpnpDeviceType` and `UpnpServiceType` enums wrap this for the
/// standard types; reach for it directly only when handling a vendor URN.
String? baseTypeUrn(String? urn) => urn?.replaceFirst(RegExp(r':\d+$'), ':');
