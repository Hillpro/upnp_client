import 'package:collection/collection.dart';
import 'package:upnp_client/src/xml_utils.dart';
import 'package:upnp_client/src/service.dart';
import 'package:xml/xml.dart';
import 'package:upnp_client/src/device.dart';

/// An UPnP Action
class Action {
  /// The service that provides this action
  final Service service;

  /// The xml element the properties of this object were initialized from
  final XmlElement xml;

  /// The name of this action
  String? name;

  /// The list of arguments of this action
  List<Argument> arguments = [];

  Action.fromXml(this.service, this.xml) {
    if (xml.name.toString() != 'action') {
      throw Exception('ERROR: Invalid Action XML!\n$xml');
    }

    name = xml.getElement('name')?.innerText;
    arguments = xml.loadList('argumentList', Argument.fromXml);
  }

  @override
  String toString() {
    StringBuffer sb = StringBuffer()..write('Action{name: $name, arguments: [');
    for (var argument in arguments) {
      sb.write('\n\t${argument.toString().replaceAll('\n', '\n\t')}');
    }
    sb.write('\n]}');
    return sb.toString();
  }
}

/// An UPnP Action Argument
class Argument {
  /// The xml element the properties of this object were initialized from
  final XmlElement xml;

  /// The name of this argument
  String? name;

  /// The direction of this argument
  Direction? direction;

  /// The name of the state variable related to this argument
  String? relatedStateVariable;

  Argument.fromXml(this.xml) {
    if (xml.name.toString() != 'argument') {
      throw Exception('ERROR: Invalid Argument XML!\n$xml');
    }

    name = xml.getElement('name')?.innerText;
    direction = Direction.values.firstWhereOrNull(
        (dir) => dir.value == xml.getElement('direction')?.innerText);
    relatedStateVariable =
        xml.getElement('relatedStateVariable')?.innerText ?? '';
  }

  @override
  String toString() {
    return 'Argument{name: $name, direction: $direction, relatedStateVariable: $relatedStateVariable}';
  }
}

/// The direction of an UPnP Action Argument
enum Direction {
  in_('in'),
  out('out');

  const Direction(this.value);

  final String value;
}
