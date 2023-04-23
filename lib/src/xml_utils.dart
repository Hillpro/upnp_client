import 'package:xml/xml.dart';

extension XmlUtils on XmlElement {
  List<T> loadList<T>(String name, T Function(XmlElement) create) {
    var xmlList = getElement('name');
    List<T> list = <T>[];
    if (xmlList != null) {
      for (var info in xmlList.childElements) {
        list.add(create(info));
      }
    }
    return list;
  }
}