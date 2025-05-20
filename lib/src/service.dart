import 'package:xml/xml.dart';
import 'dart:convert';
import 'package:upnp_client/src/device.dart';
import 'dart:io';
import 'package:upnp_client/src/xml_utils.dart';
import 'package:upnp_client/src/action.dart';
import 'package:upnp_client/src/data_type.dart';
import 'package:collection/collection.dart';
import 'package:upnp_client/src/common_services/rendering_control.dart';
import 'package:upnp_client/src/common_services/connection_manager.dart';
import 'package:upnp_client/src/common_services/av_transport.dart';

final String _soapEnvelopeNs = 'http://schemas.xmlsoap.org/soap/envelope/';
final String _soapEncodingNs = 'http://schemas.xmlsoap.org/soap/encoding/';

/// An UPnP Service
class Service {
  /// The device that provides this service
  final Device device;

  /// The xml element the properties of this object were initialized from
  final XmlElement xml;

  /// The service type
  String? type;

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

    return switch (xml.getElement('serviceType')?.innerText) {
      'urn:schemas-upnp-org:service:RenderingControl:1' =>
        RenderingControlService.fromXml(device, xml),
      'urn:schemas-upnp-org:service:ConnectionManager:1' =>
        ConnectionManagerService.fromXml(device, xml),
      'urn:schemas-upnp-org:service:AVTransport:1' =>
        AvTransportService.fromXml(device, xml),
      _ => Service.fromXml(device, xml)
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
    eventSubUrl = xml.getElement('eventsubURL')?.innerText;
  }

  Future<ServiceDescription> getDescription() async {
    if (device.url == null || url == null) {
      throw Exception('ERROR: Invalid Device or Service URL!');
    }

    final Uri deviceUri = Uri.parse(device.url!);
    final HttpClientRequest request =
        await HttpClient().getUrl(deviceUri.resolve(url!));
    final HttpClientResponse response = await request.close();
    final XmlElement serviceDescXml =
        XmlDocument.parse(await response.transform(utf8.decoder).join())
            .rootElement;
    return ServiceDescription.fromXml(this, serviceDescXml);
  }

  Future<XmlElement> sendToControlUrl(String name, XmlElement body) async {
    if (device.url == null || controlUrl == null) {
      throw Exception('ERROR: Invalid Device or Service Control URL');
    }

    final XmlBuilder builder = XmlBuilder();
    builder.element('Envelope',
        namespace: _soapEnvelopeNs,
        namespaces: {_soapEnvelopeNs: 's'},
        attributes: {'s:encodingStyle': _soapEncodingNs}, nest: () {
      builder.element('Body', namespace: _soapEnvelopeNs, nest: body);
    });
    final String xmlReq = builder.buildDocument().toXmlString();

    final HttpClientRequest request =
        await HttpClient().postUrl(Uri.parse(device.url!).resolve(controlUrl!));
    request.headers.set('SOAPACTION', '"$type#$name"');
    request.headers.set('Content-Type', 'text/xml; charset="utf-8"');
    request.headers.set('Content-Length', utf8.encode(xmlReq).length);
    request.write(xmlReq);
    final HttpClientResponse response = await request.close();

    final String respBody =
        await response.cast<List<int>>().transform(utf8.decoder).join();
    final XmlDocument xmlResp = XmlDocument.parse(respBody);
    if (xmlResp.rootElement.name.local != 'Envelope') {
      throw Exception('ERROR: Invalid SOAP response!\n$respBody');
    }

    if (response.statusCode != 200) {
      throw Exception('ERROR: Failed posting action $name!\n$respBody');
    }

    final XmlElement? xmlRespBody =
        xmlResp.rootElement.getElement('Body', namespace: _soapEnvelopeNs);

    if (xmlRespBody == null) {
      throw Exception('ERROR: Invalid SOAP response!\n$respBody');
    }

    return xmlRespBody;
  }

  Future<Map<String, String>> invokeAction(
      String name, Map<String, dynamic> args) async {
    if (type == null) throw Exception('ERROR: Invalid Service Type');

    final XmlBuilder builder = XmlBuilder();
    builder.element(name, namespace: type!, namespaces: {type!: 'u'}, nest: () {
      for (final it in args.entries) {
        builder.element(it.key, nest: it.value);
      }
    });

    final XmlElement respXml =
        await sendToControlUrl(name, builder.buildDocument().rootElement);

    final XmlElement? respEl =
        respXml.getElement('${name}Response', namespace: type!);

    final List<XmlElement> respArgs =
        (respEl?.children ?? []).whereType<XmlElement>().toList();
    final Map<String, String> map = <String, String>{};
    for (final arg in respArgs) {
      map[arg.name.local] = arg.innerText;
    }
    return map;
  }

  @override
  String toString() {
    return 'Service{type: $type, id: $id}';
  }
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
  String toString() {
    StringBuffer sb = StringBuffer('ServiceDescription{actions: [');
    for (var action in actions) {
      sb.write('\n\t${action.toString().replaceAll('\n', '\n\t')}');
    }
    sb.write('\n], stateVariables: [');
    for (var stateVariable in stateVariables) {
      sb.write('\n\t${stateVariable.toString().replaceAll('\n', '\n\t')}');
    }
    sb.write('\n]}');
    return sb.toString();
  }
}

/// An UPnP State Variable
class StateVariable {
  /// The xml element the properties of this object were initialized from
  final XmlElement xml;

  /// The name of this state variable
  String? name;

  /// Whether event messages will be generated when the value of this state variable changes
  bool sendEventsAttribute = false;

  /// The data type of this state variable
  DataType? dataType;

  /// The list of allowed values of this state variable
  List<String> allowedValues = [];

  StateVariable.fromXml(this.xml) {
    if (xml.name.toString() != 'stateVariable') {
      throw Exception('ERROR: Invalid State Variable XML!\n$xml');
    }

    name = xml.getElement('name')?.innerText;
    sendEventsAttribute = xml.getAttribute('sendEvents') == 'yes';
    dataType = DataType.values.firstWhereOrNull(
        (dt) => dt.value == xml.getElement('dataType')?.innerText);
    allowedValues = xml.loadList('allowedValueList', (xml) => xml.innerText);
  }

  @override
  String toString() {
    return 'StateVariable{name: $name, sendEventsAttribute: $sendEventsAttribute, dataType: $dataType, allowedValues: $allowedValues}';
  }
}
