/// Error codes the WAN connection services add to the UDA set.
///
/// WANIPConnection:1 §2.4 - the 700 range is reserved for a working committee,
/// so these numbers mean something different in a non-gateway service.
abstract final class WanConnectionError {
  /// The port mapping index is past the end of the table. Ends an enumeration
  /// with `GetGenericPortMappingEntry`.
  static const int specifiedArrayIndexInvalid = 713;

  /// No mapping matches the requested host, port and protocol.
  static const int noSuchEntryInArray = 714;

  /// The requested mapping is held by a different internal client.
  static const int conflictInMappingEntry = 718;

  /// The gateway requires `internalPort` to equal `externalPort`.
  static const int samePortValuesRequired = 724;

  /// The gateway supports permanent mappings only, so a non-zero lease was
  /// refused.
  static const int onlyPermanentLeasesSupported = 725;
}
