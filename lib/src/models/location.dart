import 'package:xml/xml.dart';

/// KNX Location / Space
class Location {
  final String id;
  final String type;
  final String name;
  final int? puid;
  final String? description;
  final Location? parent;

  const Location({
    required this.id,
    required this.type,
    required this.name,
    this.puid,
    this.description,
    this.parent,
  });

  /// Parse from XML element
  factory Location.fromXml(XmlElement element, {Location? parent}) {
    return Location(
      id: element.getAttribute('Id') ?? '',
      type: element.getAttribute('Type') ?? 'Unknown',
      name: element.getAttribute('Name') ?? '',
      puid: int.tryParse(element.getAttribute('Puid') ?? ''),
      description: element.getAttribute('Description'),
      parent: parent,
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'name': name,
      if (puid != null) 'puid': puid,
      if (description != null) 'description': description,
      if (parent != null) 'parentId': parent!.id,
    };
  }

  @override
  String toString() => 'Location($type: "$name")';
}
