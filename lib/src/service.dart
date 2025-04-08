import 'package:xml/xml.dart';
import 'package:upnp_client/src/device.dart';
import 'package:upnp_client/src/xml_utils.dart';
import 'package:upnp_client/src/action.dart';
import 'package:upnp_client/src/data_type.dart';
import 'package:collection/collection.dart';

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
