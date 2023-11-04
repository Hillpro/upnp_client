import 'package:xml/xml.dart';

// An upnp service action
class Action {
  /// The xml element the properties of this object were initialized from
  XmlElement xml;

  // Action name
  String? name;

  Action.fromXml(this.xml) {
    if (xml.name.toString() != 'action') {
      throw Exception('ERROR: Invalid Action XML!\n$xml');
    }

    name = xml.getElement('name')?.innerText;
  }

  @override
  String toString() {
    StringBuffer sb = StringBuffer()
      ..writeln('Name: $name');

    return sb.toString();
  }
}