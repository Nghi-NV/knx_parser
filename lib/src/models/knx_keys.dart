import 'package:xml/xml.dart';

/// Represents the root Keyring element in a .knxkeys file
class KnxKeys {
  final String project;
  final String createdBy;
  final DateTime created;
  final String signature;
  final String xmlns;
  final BackboneKey? backboneKey;
  final List<GroupKey> groupKeys;
  final List<DeviceKey> deviceKeys;

  const KnxKeys({
    required this.project,
    required this.createdBy,
    required this.created,
    required this.signature,
    required this.xmlns,
    this.backboneKey,
    this.groupKeys = const [],
    this.deviceKeys = const [],
  });

  factory KnxKeys.fromXml(XmlElement element) {
    return KnxKeys(
      project: element.getAttribute('Project') ?? '',
      createdBy: element.getAttribute('CreatedBy') ?? '',
      created: DateTime.parse(
          element.getAttribute('Created') ?? DateTime.now().toIso8601String()),
      signature: element.getAttribute('Signature') ?? '',
      xmlns: element.getAttribute('xmlns') ?? '',
      backboneKey: _parseBackboneKey(element),
      groupKeys: _parseGroupKeys(element),
      deviceKeys: _parseDeviceKeys(element),
    );
  }

  static BackboneKey? _parseBackboneKey(XmlElement element) {
    final backbone = element.getElement('Backbone');
    return backbone != null ? BackboneKey.fromXml(backbone) : null;
  }

  static List<GroupKey> _parseGroupKeys(XmlElement element) {
    final groupAddresses = element.getElement('GroupAddresses');
    if (groupAddresses == null) return [];

    return groupAddresses
        .findElements('Group')
        .map((e) => GroupKey.fromXml(e))
        .toList();
  }

  static List<DeviceKey> _parseDeviceKeys(XmlElement element) {
    final devices = element.getElement('Devices');
    if (devices == null) return [];

    return devices
        .findElements('Device')
        .map((e) => DeviceKey.fromXml(e))
        .toList();
  }

  Map<String, dynamic> toJson() {
    return {
      'project': project,
      'createdBy': createdBy,
      'created': created.toIso8601String(),
      'signature': signature,
      'xmlns': xmlns,
      if (backboneKey != null) 'backboneKey': backboneKey!.toJson(),
      'groupKeys': groupKeys.map((e) => e.toJson()).toList(),
      'deviceKeys': deviceKeys.map((e) => e.toJson()).toList(),
    };
  }
}

/// Represents the Backbone key info
class BackboneKey {
  final String multicastAddress;
  final String? key;
  final int? latency;

  const BackboneKey({
    required this.multicastAddress,
    this.key,
    this.latency,
  });

  factory BackboneKey.fromXml(XmlElement element) {
    return BackboneKey(
      multicastAddress: element.getAttribute('MulticastAddress') ?? '',
      key: element.getAttribute('Key'),
      latency: int.tryParse(element.getAttribute('Latency') ?? ''),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'multicastAddress': multicastAddress,
      if (key != null) 'key': key,
      if (latency != null) 'latency': latency,
    };
  }
}

/// Represents a Group Address Key
class GroupKey {
  final int address;
  final String key;

  const GroupKey({required this.address, required this.key});

  factory GroupKey.fromXml(XmlElement element) {
    return GroupKey(
      address: int.parse(element.getAttribute('Address') ?? '0'),
      key: element.getAttribute('Key') ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'address': address, 'key': key};
}

/// Represents a Device Key
class DeviceKey {
  final String individualAddress;
  final String? toolKey;
  final String? sequenceNumber;
  final String? fdsk;
  final String? serialNumber;
  final String? authenticationCode;

  const DeviceKey({
    required this.individualAddress,
    this.toolKey,
    this.sequenceNumber,
    this.fdsk,
    this.serialNumber,
    this.authenticationCode,
  });

  factory DeviceKey.fromXml(XmlElement element) {
    return DeviceKey(
      individualAddress: element.getAttribute('IndividualAddress') ?? '',
      toolKey: element.getAttribute('ToolKey'),
      sequenceNumber: element.getAttribute('SequenceNumber'),
      fdsk: element.getAttribute('FDSK'),
      serialNumber: element.getAttribute('SerialNumber'),
      authenticationCode: element.getAttribute('AuthenticationCode'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'individualAddress': individualAddress,
      if (toolKey != null) 'toolKey': toolKey,
      if (sequenceNumber != null) 'sequenceNumber': sequenceNumber,
      if (fdsk != null) 'fdsk': fdsk,
      if (serialNumber != null) 'serialNumber': serialNumber,
      if (authenticationCode != null) 'authenticationCode': authenticationCode,
    };
  }
}
