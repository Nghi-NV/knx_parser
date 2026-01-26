import 'package:xml/xml.dart';

/// KNX Datapoint Type (DPT)
class DatapointType {
  final String id;
  final int number;
  final String name;
  final String text;
  final int sizeInBit;
  final String? pdt;
  final List<DatapointSubtype> subtypes;

  const DatapointType({
    required this.id,
    required this.number,
    required this.name,
    required this.text,
    required this.sizeInBit,
    this.pdt,
    this.subtypes = const [],
  });

  /// Parse from XML element
  factory DatapointType.fromXml(XmlElement element) {
    final subtypesElement = element.getElement('DatapointSubtypes');
    final subtypes = subtypesElement
            ?.findElements('DatapointSubtype')
            .map((e) => DatapointSubtype.fromXml(e))
            .toList() ??
        [];

    return DatapointType(
      id: element.getAttribute('Id') ?? '',
      number: int.tryParse(element.getAttribute('Number') ?? '') ?? 0,
      name: element.getAttribute('Name') ?? '',
      text: element.getAttribute('Text') ?? '',
      sizeInBit: int.tryParse(element.getAttribute('SizeInBit') ?? '') ?? 0,
      pdt: element.getAttribute('PDT'),
      subtypes: subtypes,
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'number': number,
      'name': name,
      'text': text,
      'sizeInBit': sizeInBit,
      if (pdt != null) 'pdt': pdt,
      'subtypes': subtypes.map((s) => s.toJson()).toList(),
    };
  }

  @override
  String toString() => 'DatapointType($id: $text)';
}

/// KNX Datapoint Subtype (DPST)
class DatapointSubtype {
  final String id;
  final int number;
  final String name;
  final String text;
  final bool isDefault;
  final String? pdt;

  const DatapointSubtype({
    required this.id,
    required this.number,
    required this.name,
    required this.text,
    this.isDefault = false,
    this.pdt,
  });

  /// Parse from XML element
  factory DatapointSubtype.fromXml(XmlElement element) {
    return DatapointSubtype(
      id: element.getAttribute('Id') ?? '',
      number: int.tryParse(element.getAttribute('Number') ?? '') ?? 0,
      name: element.getAttribute('Name') ?? '',
      text: element.getAttribute('Text') ?? '',
      isDefault: element.getAttribute('Default') == 'true',
      pdt: element.getAttribute('PDT'),
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'number': number,
      'name': name,
      'text': text,
      if (isDefault) 'isDefault': true,
      if (pdt != null) 'pdt': pdt,
    };
  }

  @override
  String toString() => 'DatapointSubtype($id: $text)';
}
