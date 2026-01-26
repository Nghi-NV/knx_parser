import 'package:xml/xml.dart';

/// KNX Group Address
class GroupAddress {
  final String id;
  final int address;
  final String name;
  final int? puid;
  final String? description;
  final String? datapointType;
  final GroupRange? range;
  final String? key;

  const GroupAddress({
    required this.id,
    required this.address,
    required this.name,
    this.puid,
    this.description,
    this.datapointType,
    this.range,
    this.key,
  });

  /// Parse from XML element
  factory GroupAddress.fromXml(XmlElement element, {GroupRange? range}) {
    return GroupAddress(
      id: element.getAttribute('Id') ?? '',
      address: int.tryParse(element.getAttribute('Address') ?? '') ?? 0,
      name: element.getAttribute('Name') ?? '',
      puid: int.tryParse(element.getAttribute('Puid') ?? ''),
      description: element.getAttribute('Description'),
      datapointType: element.getAttribute('DatapointType'),
      range: range,
      key: element.getAttribute('Key'),
    );
  }

  /// Get the formatted group address (e.g., 1/2/3)
  String get formattedAddress {
    // Free style: just return the raw address
    // Three-level style: main/middle/sub
    final main = (address >> 11) & 0x1F;
    final middle = (address >> 8) & 0x07;
    final sub = address & 0xFF;
    return '$main/$middle/$sub';
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'address': address,
      'formattedAddress': formattedAddress,
      'name': name,
      if (puid != null) 'puid': puid,
      if (description != null) 'description': description,
      if (datapointType != null) 'datapointType': datapointType,
      if (range != null) 'rangeId': range!.id,
      if (key != null) 'key': key,
    };
  }

  @override
  String toString() => 'GroupAddress($formattedAddress, "$name")';
}

/// KNX Group Range (hierarchical grouping of addresses)
class GroupRange {
  final String id;
  final int rangeStart;
  final int rangeEnd;
  final String name;
  final int? puid;
  final GroupRange? parent;

  const GroupRange({
    required this.id,
    required this.rangeStart,
    required this.rangeEnd,
    required this.name,
    this.puid,
    this.parent,
  });

  /// Parse from XML element
  factory GroupRange.fromXml(XmlElement element, {GroupRange? parent}) {
    return GroupRange(
      id: element.getAttribute('Id') ?? '',
      rangeStart: int.tryParse(element.getAttribute('RangeStart') ?? '') ?? 0,
      rangeEnd: int.tryParse(element.getAttribute('RangeEnd') ?? '') ?? 0,
      name: element.getAttribute('Name') ?? '',
      puid: int.tryParse(element.getAttribute('Puid') ?? ''),
      parent: parent,
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'rangeStart': rangeStart,
      'rangeEnd': rangeEnd,
      'name': name,
      if (puid != null) 'puid': puid,
      if (parent != null) 'parentId': parent!.id,
    };
  }

  @override
  String toString() => 'GroupRange("$name", $rangeStart-$rangeEnd)';
}
