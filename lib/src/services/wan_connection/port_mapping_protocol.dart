/// The transport protocol of a port mapping.
///
/// WANIPConnection:1 §2.2.18 - the `PortMappingProtocol` state variable.
enum PortMappingProtocol {
  tcp('TCP'),
  udp('UDP');

  const PortMappingProtocol(this.wireValue);

  /// The value sent to and received from the gateway.
  ///
  /// WANIPConnection:1 Table 1.4 - the `PortMappingProtocol`
  /// `allowedValueList` is exactly `TCP` and `UDP`, uppercase. Dart's [name]
  /// would send lowercase, which is not a permitted value.
  final String wireValue;

  /// Parses a protocol as reported by a gateway, ignoring case.
  ///
  /// Returns null for any other value, which only a non-compliant device
  /// sends.
  static PortMappingProtocol? tryParse(String? value) =>
      switch (value?.toUpperCase()) {
        'TCP' => tcp,
        'UDP' => udp,
        _ => null,
      };
}
