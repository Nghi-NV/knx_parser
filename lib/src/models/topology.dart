import 'package:xml/xml.dart';

/// KNX network topology
class Topology {
  final List<Area> areas;

  const Topology({required this.areas});

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {'areas': areas.map((a) => a.toJson()).toList()};
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
    final lines = element
        .findElements('Line')
        .map((e) => Line.fromXml(e))
        .toList();

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

  const Line({
    required this.id,
    required this.address,
    this.puid,
    this.name,
    this.segments = const [],
  });

  /// Parse from XML element
  factory Line.fromXml(XmlElement element) {
    final segments = element
        .findElements('Segment')
        .map((e) => Segment.fromXml(e))
        .toList();

    return Line(
      id: element.getAttribute('Id') ?? '',
      address: int.tryParse(element.getAttribute('Address') ?? '') ?? 0,
      puid: int.tryParse(element.getAttribute('Puid') ?? ''),
      name: element.getAttribute('Name'),
      segments: segments,
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
    };
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

  const Segment({
    required this.id,
    required this.number,
    this.mediumTypeRefId,
    this.puid,
  });

  /// Parse from XML element
  factory Segment.fromXml(XmlElement element) {
    return Segment(
      id: element.getAttribute('Id') ?? '',
      number: int.tryParse(element.getAttribute('Number') ?? '') ?? 0,
      mediumTypeRefId: element.getAttribute('MediumTypeRefId'),
      puid: int.tryParse(element.getAttribute('Puid') ?? ''),
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'number': number,
      if (mediumTypeRefId != null) 'mediumTypeRefId': mediumTypeRefId,
      if (puid != null) 'puid': puid,
    };
  }

  @override
  String toString() => 'Segment($id, number=$number)';
}
