import 'dart:convert';
import 'dart:io';
import 'package:collection/collection.dart';
import 'package:upnp_client/src/services/av_transport.dart';
import 'package:upnp_client/src/services/connection_manager.dart';
import 'package:upnp_client/src/services/rendering_control.dart';
import 'package:upnp_client/src/services/wan_connection.dart';
import 'package:upnp_client/src/action.dart';
import 'package:upnp_client/src/device.dart';
import 'package:upnp_client/src/upnp_exception.dart';
import 'package:upnp_client/src/types/data_type.dart';
import 'package:upnp_client/src/types/data_type_parsers.dart';
import 'package:upnp_client/src/types/upnp_service_type.dart';
import 'package:upnp_client/src/utils/diagnostics.dart';
import 'package:upnp_client/src/utils/xml_utils.dart';
import 'package:xml/xml.dart';

const String _soapEnvelopeNs = 'http://schemas.xmlsoap.org/soap/envelope/';
const String _soapEncodingNs = 'http://schemas.xmlsoap.org/soap/encoding/';

/// UDA 1.1 §3.2.2 — actions must complete within 30 seconds.
const _actionTimeout = Duration(seconds: 30);

/// An UPnP Service
class Service {
  /// The device that provides this service
  final Device device;

  /// The xml element the properties of this object were initialized from
  final XmlElement xml;

  /// The service type, as the `<serviceType>` element declares it, including
  /// its version.
  String? type;

  /// The standard type this service implements, whatever version [type]
  /// declares, or null when it is a vendor service the package does not know.
  ///
  /// Prefer this over comparing [type] directly: UDA 1.1 §1.3.2 makes a higher
  /// version compatible with the one it extends, so a literal string match
  /// against `...:AVTransport:1` misses an `...:AVTransport:2` device that
  /// answers the same actions.
  UpnpServiceType? get standardType => UpnpServiceType.tryParse(type);

  /// The service ID
  String? id;

  /// The location of the service description
  String? url;

  /// The location for service control
  String? controlUrl;

  /// The location for service eventing
  String? eventSubUrl;

  static Service fromXmlTyped(Device device, XmlElement xml) {
    if (xml.name.toString() != 'service') {
      throw Exception('ERROR: Invalid Service XML!\n$xml');
    }

    return switch (UpnpServiceType.tryParse(
      xml.getElement('serviceType')?.innerText,
    )) {
      UpnpServiceType.renderingControl => RenderingControlService.fromXml(
        device,
        xml,
      ),
      UpnpServiceType.connectionManager => ConnectionManagerService.fromXml(
        device,
        xml,
      ),
      UpnpServiceType.avTransport => AvTransportService.fromXml(device, xml),
      UpnpServiceType.wanIpConnection => WanIpConnectionService.fromXml(
        device,
        xml,
      ),
      UpnpServiceType.wanPppConnection => WanPppConnectionService.fromXml(
        device,
        xml,
      ),
      _ => Service.fromXml(device, xml),
    };
  }

  Service.fromXml(this.device, this.xml) {
    if (xml.name.toString() != 'service') {
      throw Exception('ERROR: Invalid Service XML!\n$xml');
    }

    type = xml.getElement('serviceType')?.innerText;
    id = xml.getElement('serviceId')?.innerText;
    url = xml.getElement('SCPDURL')?.innerText;
    controlUrl = xml.getElement('controlURL')?.innerText;
    eventSubUrl = xml.getElement('eventSubURL')?.innerText;
  }

  Future<ServiceDescription> getDescription() async {
    if (device.urlBase == null || url == null) {
      throw Exception('ERROR: Invalid Device or Service URL!');
    }

    final httpClient = HttpClient();
    httpClient.connectionTimeout = _actionTimeout;
    try {
      final Uri descriptionUrl = _resolveUrl(url!);
      final HttpClientRequest request = await httpClient.getUrl(descriptionUrl);
      final HttpClientResponse response = await request.close().timeout(
        _actionTimeout,
      );
      final String body = await response.transform(utf8.decoder).join();

      // UDA 1.1 §2.11 defines the description response as "200 OK";
      // anything else is an error page rather than XML.
      if (response.statusCode != 200) {
        throw Exception(
          'ERROR: Service description request failed with status '
          '${response.statusCode}: $descriptionUrl',
        );
      }

      final XmlElement serviceDescXml = XmlDocument.parse(body).rootElement;
      return ServiceDescription.fromXml(this, serviceDescXml);
    } finally {
      httpClient.close();
    }
  }

  Future<XmlElement> sendToControlUrl(String name, XmlElement body) async {
    if (device.urlBase == null || controlUrl == null) {
      throw Exception('ERROR: Invalid Device or Service Control URL');
    }

    final XmlBuilder builder = XmlBuilder();
    builder.element(
      'Envelope',
      // ignore: deprecated_member_use
      namespace: _soapEnvelopeNs,
      // ignore: deprecated_member_use
      namespaces: {_soapEnvelopeNs: 's'},
      attributes: {'s:encodingStyle': _soapEncodingNs},
      nest: () {
        // ignore: deprecated_member_use
        builder.element('Body', namespace: _soapEnvelopeNs, nest: body);
      },
    );
    final String xmlReq = builder.buildDocument().toXmlString();

    final httpClient = HttpClient();
    httpClient.connectionTimeout = _actionTimeout;
    try {
      final HttpClientRequest request = await httpClient.postUrl(
        _resolveUrl(controlUrl!),
      );
      request.headers.set('SOAPACTION', '"$type#$name"');
      request.headers.set('Content-Type', 'text/xml; charset="utf-8"');
      request.headers.set('Content-Length', utf8.encode(xmlReq).length);
      request.write(xmlReq);
      final HttpClientResponse response = await request.close().timeout(
        _actionTimeout,
      );

      final String respBody = await response
          .cast<List<int>>()
          .transform(utf8.decoder)
          .join();

      XmlElement? soapBody;
      try {
        final XmlDocument xmlResp = XmlDocument.parse(respBody);
        if (xmlResp.rootElement.name.local == 'Envelope') {
          soapBody = xmlResp.rootElement.getElement(
            'Body',
            // ignore: deprecated_member_use
            namespace: _soapEnvelopeNs,
          );
        }
      } on XmlException {
        // Body is not XML (plain text or HTML error page).
      }

      // A fault is a fault whatever the status line says. UDA 1.1 §3.2.5 pairs
      // one with HTTP 500, but devices do return them under 200, and reading
      // the status first would drop the error code the device took the trouble
      // to send.
      if (soapBody != null) {
        final upnpEx = UPnPException.tryParseFromBody(
          soapBody,
          actionName: name,
        );
        if (upnpEx != null) throw upnpEx;
      }

      if (response.statusCode != 200) {
        throw Exception(
          'ERROR: Failed posting action $name, HTTP '
          '${response.statusCode}!\n$respBody',
        );
      }

      if (soapBody == null) {
        throw Exception('ERROR: Invalid SOAP response!\n$respBody');
      }

      return soapBody;
    } finally {
      httpClient.close();
    }
  }

  /// Resolves a relative service [path] against the device's URL base.
  ///
  /// Per UDA 1.1 §2.3, urlBase is either the absolute URLBase from the device
  /// description (UDA 1.0) or the LOCATION URL (UDA 1.1).
  Uri _resolveUrl(String path) => Uri.parse(device.urlBase!).resolve(path);

  Future<Map<String, String>> invokeAction(
    String name,
    Map<String, dynamic> args,
  ) async {
    if (type == null) throw Exception('ERROR: Invalid Service Type');

    final XmlBuilder builder = XmlBuilder();
    builder.element(
      name,
      // ignore: deprecated_member_use
      namespace: type!,
      // ignore: deprecated_member_use
      namespaces: {type!: 'u'},
      nest: () {
        for (final it in args.entries) {
          builder.element(it.key, nest: it.value);
        }
      },
    );

    final XmlElement respXml = await sendToControlUrl(
      name,
      builder.buildDocument().rootElement,
    );

    // Namespace first, then local name. UDA 1.1 §3.2.2 requires the device to
    // echo the request namespace, so a `...:1` request should come back in
    // `...:1` - but a device that answers in another version of its own service
    // type is still answering, and dropping the out arguments over it would
    // undo the version-independent matching.
    final XmlElement? respEl = respXml.getElementAnyNs(
      '${name}Response',
      namespace: type!,
    );

    // Its absence is the only signal that the body was not the response to
    // this action; an action with no out arguments returns the element empty.
    if (respEl == null) {
      throw Exception(
        'ERROR: SOAP response to $name carries no <${name}Response>!\n'
        '${respXml.toXmlString()}',
      );
    }

    final Map<String, String> map = <String, String>{};
    for (final arg in respEl.childElements) {
      map[arg.name.local] = arg.innerText;
    }
    return map;
  }

  @override
  String toString() => buildDescription(runtimeType, describeFields());

  Map<String, dynamic> describeFields() => {'type': type, 'id': id};
}

/// An UPnP Service Description
class ServiceDescription {
  /// The service this description belongs to
  final Service service;

  /// The xml element the properties of this object were initialized from
  final XmlElement xml;

  /// The list of actions provided by this service
  List<Action> actions = [];

  /// The list of state variables provided by this service
  List<StateVariable> stateVariables = [];

  ServiceDescription.fromXml(this.service, this.xml) {
    if (xml.name.toString() != 'scpd') {
      throw Exception('ERROR: Invalid Service Description XML!\n$xml');
    }

    actions = xml.loadList('actionList', (xml) => Action.fromXml(service, xml));
    stateVariables = xml.loadList('serviceStateTable', StateVariable.fromXml);
  }

  @override
  String toString() =>
      buildDescription(runtimeType, describeFields(), describeChildren());

  Map<String, dynamic> describeFields() => {};

  Map<String, List> describeChildren() => {
    'actions': actions,
    'stateVariables': stateVariables,
  };
}

/// An UPnP State Variable
class StateVariable {
  /// The xml element the properties of this object were initialized from
  final XmlElement xml;

  /// The name of this state variable
  String? name;

  /// Whether event messages will be generated when the value of this state
  /// variable changes
  ///
  /// UDA 1.1 §2.5 - the `sendEvents` attribute is OPTIONAL and defaults to
  /// "yes", so a variable that omits it is evented.
  bool sendEventsAttribute = true;

  /// The data type of this state variable
  DataType? dataType;

  /// The list of allowed values of this state variable
  List<String> allowedValues = [];

  StateVariable.fromXml(this.xml) {
    if (xml.name.toString() != 'stateVariable') {
      throw Exception('ERROR: Invalid State Variable XML!\n$xml');
    }

    name = xml.getElement('name')?.innerText;
    // UDA 1.1 §2.5 - `sendEvents` is OPTIONAL and its default is "yes", so an
    // absent attribute means the variable IS evented; §4.4 says the same in
    // as many words. The normative text spells the values "yes"/"no" while
    // UDA 1.1's own appendix B schema spells them "1"/"0", so a device may
    // send either form and [parseUpnpBool] accepts both.
    sendEventsAttribute = parseUpnpBool(
      xml.getAttribute('sendEvents') ?? 'yes',
    );
    dataType = DataType.values.firstWhereOrNull(
      (dt) => dt.value == xml.getElement('dataType')?.innerText,
    );
    allowedValues = xml.loadList('allowedValueList', (xml) => xml.innerText);
  }

  @override
  String toString() {
    return buildDescription(runtimeType, describeFields());
  }

  Map<String, dynamic> describeFields() => {
    'name': name,
    'sendEventsAttribute': sendEventsAttribute,
    'dataType': dataType,
    'allowedValues': allowedValues,
  };
}
