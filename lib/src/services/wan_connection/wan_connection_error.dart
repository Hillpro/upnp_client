/// Error codes the WAN connection services add to the UDA set.
///
/// WANIPConnection:1 §2.4 - the 700 range is reserved for a working committee,
/// so these numbers mean something different in a non-gateway service.
///
/// These are plain `int` values to compare [UPnPException.errorCode] against,
/// not a type the exception carries. Nothing here is enforced by the type
/// system, so an unrecognised code is not a compile error - a gateway may
/// answer one of these, a UDA code from §3.2.5, or a vendor code in the 800
/// range, and only the first is named here:
///
/// ```dart
/// try {
///   await connection.addPortMapping(/* ... */);
/// } on UPnPException catch (e) {
///   if (e.errorCode == WanConnectionError.onlyPermanentLeasesSupported) {
///     // retry with Duration.zero
///   }
/// }
/// ```
///
/// Scoped to the port mapping and status actions [WanConnectionService] wraps.
/// The connection-lifecycle codes 701 to 712, and PPP's 719, belong to
/// `SetConnectionType`, `RequestConnection` and `ForceTermination`, which are
/// not wrapped; reach those through `invokeAction` and read the code off the
/// [UPnPException] directly.
///
/// All of these are worth knowing even against a v2 gateway. WANIPConnection:2
/// retires four of them - [samePortValuesRequired], [onlyPermanentLeasesSupported],
/// [remoteHostOnlySupportsWildcard] and [externalPortOnlySupportsWildcard] -
/// with the wording *"This error code MUST NOT be used by WANIPConnection:2
/// services, but Control points are REQUIRED to support this error code"*, and
/// adds three more, marked below. WANPPPConnection:1 declares the same v1 set.
abstract final class WanConnectionError {
  /// The port mapping index is past the end of the table. Ends an enumeration
  /// with `GetGenericPortMappingEntry`.
  static const int specifiedArrayIndexInvalid = 713;

  /// No mapping matches the requested host, port and protocol.
  static const int noSuchEntryInArray = 714;

  // The four wildcard errors come in two opposed pairs: 715 and 716 reject a
  // wildcard the gateway will not take, 726 and 727 demand one it insists on.
  // Either way the recovery is to retry with the opposite value.

  /// `internalClient` may not be a wildcard, and an empty string is one.
  static const int wildCardNotPermittedInSrcIp = 715;

  /// `externalPort` may not be the `0` wildcard on this gateway; ask for a
  /// specific port.
  static const int wildCardNotPermittedInExtPort = 716;

  /// The requested mapping is held by a different internal client.
  static const int conflictInMappingEntry = 718;

  /// The gateway requires `internalPort` to equal `externalPort`.
  static const int samePortValuesRequired = 724;

  /// The gateway supports permanent mappings only, so a non-zero lease was
  /// refused. Retrying with [Duration.zero] is the usual response.
  static const int onlyPermanentLeasesSupported = 725;

  /// `remoteHost` must be the wildcard on this gateway, so pass an empty
  /// string rather than a specific address or name.
  static const int remoteHostOnlySupportsWildcard = 726;

  /// `externalPort` must be the `0` wildcard on this gateway.
  static const int externalPortOnlySupportsWildcard = 727;

  /// The gateway has no free ports left to map. WANIPConnection:2 only.
  static const int noPortMapsAvailable = 728;

  /// The mapping collides with something outside UPnP's view - a static rule,
  /// or another port-control protocol. WANIPConnection:2 only.
  static const int conflictWithOtherMechanisms = 729;

  /// `internalPort` may not be the `0` wildcard. WANIPConnection:2 only.
  static const int wildCardNotPermittedInIntPort = 732;
}
