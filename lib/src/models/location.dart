import 'package:xml/xml.dart';

/// KNX Location / Space
class Location {
  final String id;
  final String type;
  final String name;
  final int? puid;
  final String? description;
  final Location? parent;
  final List<String> deviceInstanceIds;

  const Location({
    required this.id,
    required this.type,
    required this.name,
    this.puid,
    this.description,
    this.parent,
    this.deviceInstanceIds = const [],
  });

  /// Parse from XML element
  factory Location.fromXml(XmlElement element, {Location? parent}) {
    // Parse DeviceInstanceRef children
    final deviceIds = element
        .findElements('DeviceInstanceRef')
        .map((ref) => ref.getAttribute('RefId'))
        .where((id) => id != null && id.isNotEmpty)
        .cast<String>()
        .toList();

    return Location(
      id: element.getAttribute('Id') ?? '',
      type: element.getAttribute('Type') ?? 'Unknown',
      name: element.getAttribute('Name') ?? '',
      puid: int.tryParse(element.getAttribute('Puid') ?? ''),
      description: element.getAttribute('Description'),
      parent: parent,
      deviceInstanceIds: deviceIds,
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
      if (deviceInstanceIds.isNotEmpty)
        'deviceInstanceIds': deviceInstanceIds,
    };
  }

  @override
  String toString() => 'Location($type: "$name")';
}

