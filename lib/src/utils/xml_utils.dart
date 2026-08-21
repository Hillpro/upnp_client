import 'package:xml/xml.dart';

extension XmlElementUtils on XmlElement {
  List<T> loadList<T>(String name, T Function(XmlElement) create) {
    var xmlList = getElement(name);
    List<T> list = <T>[];
    if (xmlList != null) {
      for (var info in xmlList.childElements) {
        list.add(create(info));
      }
    }
    return list;
  }

  /// Finds a child element by [localName], trying [namespace] first and
  /// falling back to a local-name-only scan.
  XmlElement? getElementAnyNs(String localName, {String? namespace}) =>
      getElement(localName, namespace: namespace) ??
      childElements.where((e) => e.name.local == localName).firstOrNull;
}
