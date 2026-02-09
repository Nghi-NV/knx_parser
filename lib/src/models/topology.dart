import 'package:xml/xml.dart';
import 'device_instance.dart';

/// KNX network topology
class Topology {
  final List<Area> areas;

  const Topology({required this.areas});

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {'areas': areas.map((a) => a.toJson()).toList()};
  }

  /// Create a copy with device names updated from product catalog
  Topology copyWithProductCatalog(Map<String, String> productCatalog) {
    final updatedAreas =
        areas.map((a) => a.copyWithProductCatalog(productCatalog)).toList();
    return Topology(areas: updatedAreas);
  }
}

/// KNX Area (first level of topology)
class Area {
  final String id;
  final int address;
  final int? puid;
  final String? name;
  final List<Line> lines;

  const Area({
    required this.id,
    required this.address,
    this.puid,
    this.name,
    this.lines = const [],
  });

  /// Parse from XML element
  factory Area.fromXml(XmlElement element) {
    final lines =
        element.findElements('Line').map((e) => Line.fromXml(e)).toList();

    return Area(
      id: element.getAttribute('Id') ?? '',
      address: int.tryParse(element.getAttribute('Address') ?? '') ?? 0,
      puid: int.tryParse(element.getAttribute('Puid') ?? ''),
      name: element.getAttribute('Name'),
      lines: lines,
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'address': address,
      if (puid != null) 'puid': puid,
      if (name != null) 'name': name,
      'lines': lines.map((l) => l.toJson()).toList(),
    };
  }

  /// Create a copy with device names updated from product catalog
  Area copyWithProductCatalog(Map<String, String> productCatalog) {
    final updatedLines =
        lines.map((l) => l.copyWithProductCatalog(productCatalog)).toList();
    return Area(
      id: id,
      address: address,
      puid: puid,
      name: name,
      lines: updatedLines,
    );
  }

  @override
  String toString() => 'Area($id, address=$address)';
}

/// KNX Line (second level of topology)
class Line {
  final String id;
  final int address;
  final int? puid;
  final String? name;
  final List<Segment> segments;
  final List<DeviceInstance> devices;

  const Line({
    required this.id,
    required this.address,
    this.puid,
    this.name,
    this.segments = const [],
    this.devices = const [],
  });

  /// Parse from XML element
  factory Line.fromXml(XmlElement element) {
    final segments =
        element.findElements('Segment').map((e) => Segment.fromXml(e)).toList();

    // ETS5: DeviceInstance directly under Line
    // ETS6: DeviceInstance under Segment
    final directDevices = element
        .findElements('DeviceInstance')
        .map((e) => DeviceInstance.fromXml(e))
        .toList();

    // Collect devices from all segments (ETS6 format)
    final segmentDevices = segments.expand((s) => s.devices).toList();

    // Combine both sources
    final allDevices = [...directDevices, ...segmentDevices];

    return Line(
      id: element.getAttribute('Id') ?? '',
      address: int.tryParse(element.getAttribute('Address') ?? '') ?? 0,
      puid: int.tryParse(element.getAttribute('Puid') ?? ''),
      name: element.getAttribute('Name'),
      segments: segments,
      devices: allDevices,
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'address': address,
      if (puid != null) 'puid': puid,
      if (name != null) 'name': name,
      'segments': segments.map((s) => s.toJson()).toList(),
      'devices': devices.map((d) => d.toJson()).toList(),
    };
  }

  /// Create a copy with device names updated from product catalog
  Line copyWithProductCatalog(Map<String, String> productCatalog) {
    final updatedDevices = devices.map((device) {
      final productName = productCatalog[device.productRefId];
      return productName != null ? device.copyWithName(productName) : device;
    }).toList();
    final updatedSegments =
        segments.map((s) => s.copyWithProductCatalog(productCatalog)).toList();
    return Line(
      id: id,
      address: address,
      puid: puid,
      name: name,
      segments: updatedSegments,
      devices: updatedDevices,
    );
  }

  @override
  String toString() => 'Line($id, address=$address)';
}

/// KNX Segment
class Segment {
  final String id;
  final int number;
  final String? mediumTypeRefId;
  final int? puid;
  final List<DeviceInstance> devices;

  const Segment({
    required this.id,
    required this.number,
    this.mediumTypeRefId,
    this.puid,
    this.devices = const [],
  });

  /// Parse from XML element
  factory Segment.fromXml(XmlElement element) {
    // ETS6: DeviceInstance elements are nested inside Segment
    final devices = element
        .findElements('DeviceInstance')
        .map((e) => DeviceInstance.fromXml(e))
        .toList();

    return Segment(
      id: element.getAttribute('Id') ?? '',
      number: int.tryParse(element.getAttribute('Number') ?? '') ?? 0,
      mediumTypeRefId: element.getAttribute('MediumTypeRefId'),
      puid: int.tryParse(element.getAttribute('Puid') ?? ''),
      devices: devices,
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'number': number,
      if (mediumTypeRefId != null) 'mediumTypeRefId': mediumTypeRefId,
      if (puid != null) 'puid': puid,
      if (devices.isNotEmpty)
        'devices': devices.map((d) => d.toJson()).toList(),
    };
  }

  /// Create a copy with device names updated from product catalog
  Segment copyWithProductCatalog(Map<String, String> productCatalog) {
    final updatedDevices = devices.map((device) {
      final productName = productCatalog[device.productRefId];
      return productName != null ? device.copyWithName(productName) : device;
    }).toList();
    return Segment(
      id: id,
      number: number,
      mediumTypeRefId: mediumTypeRefId,
      puid: puid,
      devices: updatedDevices,
    );
  }

  @override
  String toString() => 'Segment($id, number=$number)';
}
