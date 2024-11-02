import 'dart:mirrors';

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

  void loadProperties<T>(T t) {
    ClassMirror xmlPropertyMirror = reflectClass(XmlProperty);
    ClassMirror xmlIgnoreMirror = reflectClass(XmlIgnore);
    ClassMirror xmlClassMirror = reflectClass(XmlClass);

    var reflectee = reflect(t);
    var xmlClass = false;

    // Check if the class is an XmlClass
    for (var metadata in reflectee.type.metadata) {
      if (metadata.type == xmlClassMirror) {
        xmlClass = true;
        break;
      }
    }

    for (var value in reflectee.type.declarations.values) {
      // Check if declatation is a variable declaration
      if (value is! VariableMirror) continue;

      // Verify that the variable definition doesn't use XmlIgnore() annotation
      if (value.metadata.indexWhere((m) => m.type == xmlIgnoreMirror) != -1) continue;

      String? propertyName;

      for (var metadata in value.metadata) {
        if (metadata.type == xmlPropertyMirror) {
          XmlProperty property = metadata.reflectee;
          propertyName = property.propertyName;
        }
      }

      if (xmlClass || propertyName != null) {
        propertyName = propertyName ?? MirrorSystem.getName(value.simpleName);

        XmlElement? element = getElement(propertyName);
        if (element == null) continue;

        String text = element.innerText;

        if (value.type == reflectType(int)) {
          reflectee.setField(value.simpleName, int.tryParse(text));
        } else {
          reflectee.setField(value.simpleName, text);
        }
      }
    }
  }
}

class XmlProperty {
  final String? propertyName;

  const XmlProperty([this.propertyName]);
}

class XmlClass {
  final String? documentName;

  const XmlClass([this.documentName]);
}

class XmlIgnore {
  const XmlIgnore();
}

