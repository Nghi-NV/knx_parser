import 'package:xml/xml.dart';
import 'topology.dart';
import 'group_address.dart';
import 'location.dart';

/// Represents a KNX installation
class Installation {
  final String name;
  final int? bcuKey;
  final String? defaultLine;
  final Topology topology;
  final List<GroupAddress> groupAddresses;
  final List<GroupRange> groupRanges;
  final List<Location> locations;

  const Installation({
    this.name = '',
    this.bcuKey,
    this.defaultLine,
    required this.topology,
    this.groupAddresses = const [],
    this.groupRanges = const [],
    this.locations = const [],
  });

  /// Parse from XML element
  factory Installation.fromXml(XmlElement element) {
    final topology = _parseTopology(element);
    final parseResult = _parseGroupAddresses(element);
    final locations = _parseLocations(element);

    return Installation(
      name: element.getAttribute('Name') ?? '',
      bcuKey: int.tryParse(element.getAttribute('BCUKey') ?? ''),
      defaultLine: element.getAttribute('DefaultLine'),
      topology: topology,
      groupAddresses: parseResult.groupAddresses,
      groupRanges: parseResult.groupRanges,
      locations: locations,
    );
  }

  static Topology _parseTopology(XmlElement element) {
    final topologyElement = element.getElement('Topology');
    if (topologyElement == null) {
      return const Topology(areas: []);
    }

    final areas = topologyElement
        .findElements('Area')
        .map((e) => Area.fromXml(e))
        .toList();

    return Topology(areas: areas);
  }

  static _GroupAddressParseResult _parseGroupAddresses(
    XmlElement element,
  ) {
    final gaElement = element.getElement('GroupAddresses');
    if (gaElement == null) {
      return _GroupAddressParseResult([], []);
    }

    final groupAddresses = <GroupAddress>[];
    final groupRanges = <GroupRange>[];

    void parseGroupRanges(XmlElement rangesElement, {GroupRange? parent}) {
      for (final rangeElement in rangesElement.findElements('GroupRange')) {
        final range = GroupRange.fromXml(rangeElement, parent: parent);
        groupRanges.add(range);

        // Parse GroupAddresses directly under this range
        for (final gaElement in rangeElement.findElements('GroupAddress')) {
          groupAddresses.add(GroupAddress.fromXml(gaElement, range: range));
        }

        // Recursively parse nested GroupRanges
        parseGroupRanges(rangeElement, parent: range);
      }
    }

    final rangesRoot = gaElement.getElement('GroupRanges');
    if (rangesRoot != null) {
      parseGroupRanges(rangesRoot);
    }

    return _GroupAddressParseResult(groupAddresses, groupRanges);
  }

  static List<Location> _parseLocations(XmlElement element) {
    final locElement = element.getElement('Locations');
    if (locElement == null) {
      return [];
    }

    final locations = <Location>[];

    void parseSpaces(XmlElement parent, {Location? parentLocation}) {
      for (final spaceElement in parent.findElements('Space')) {
        final location = Location.fromXml(spaceElement, parent: parentLocation);
        locations.add(location);
        parseSpaces(spaceElement, parentLocation: location);
      }
    }

    parseSpaces(locElement);
    return locations;
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (bcuKey != null) 'bcuKey': bcuKey,
      if (defaultLine != null) 'defaultLine': defaultLine,
      'topology': topology.toJson(),
      'groupAddresses': groupAddresses.map((ga) => ga.toJson()).toList(),
      'groupRanges': groupRanges.map((gr) => gr.toJson()).toList(),
      'locations': locations.map((l) => l.toJson()).toList(),
    };
  }

  /// Create a copy with device names updated from product catalog
  Installation copyWithProductCatalog(Map<String, String> productCatalog) {
    return Installation(
      name: name,
      bcuKey: bcuKey,
      defaultLine: defaultLine,
      topology: topology.copyWithProductCatalog(productCatalog),
      groupAddresses: groupAddresses,
      groupRanges: groupRanges,
      locations: locations,
    );
  }

  @override
  String toString() => 'Installation($name)';
}

/// Helper class to return multiple values from _parseGroupAddresses
/// Used instead of Records to support Dart SDK >= 2.19.2
class _GroupAddressParseResult {
  final List<GroupAddress> groupAddresses;
  final List<GroupRange> groupRanges;

  const _GroupAddressParseResult(this.groupAddresses, this.groupRanges);
}
