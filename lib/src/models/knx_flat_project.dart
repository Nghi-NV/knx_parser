import 'dart:convert';
import 'device_instance.dart';
import 'datapoint_type.dart';
import 'knx_keys.dart';

/// Flat representation of a KNX project with organized, easy-to-consume sections.
///
/// Use [KnxProject.toFlat()] to create an instance from a parsed project.
class KnxFlatProject {
  final String projectName;
  final String projectId;
  final String groupAddressStyle;
  final DateTime? lastModified;
  final String? etsVersion;
  final int? schemaVersion;
  final bool hasSecure;
  final List<KnxFloor> floors;
  final List<KnxRoom> rooms;
  final List<KnxDevice> devices;
  final List<KnxGroupAddress> groupAddresses;
  final List<KnxGroupRange> groupRanges;
  final List<DatapointType> datapointTypes;
  final KnxSecureKeys? secureKeys;

  const KnxFlatProject({
    required this.projectName,
    required this.projectId,
    required this.groupAddressStyle,
    this.lastModified,
    this.etsVersion,
    this.schemaVersion,
    required this.hasSecure,
    this.floors = const [],
    this.rooms = const [],
    this.devices = const [],
    this.groupAddresses = const [],
    this.groupRanges = const [],
    this.datapointTypes = const [],
    this.secureKeys,
  });

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'projectName': projectName,
      'projectId': projectId,
      'groupAddressStyle': groupAddressStyle,
      if (lastModified != null)
        'lastModified': lastModified!.toIso8601String(),
      if (etsVersion != null) 'etsVersion': etsVersion,
      if (schemaVersion != null) 'schemaVersion': schemaVersion,
      'hasSecure': hasSecure,
      'floors': floors.map((f) => f.toJson()).toList(),
      'rooms': rooms.map((r) => r.toJson()).toList(),
      'devices': devices.map((d) => d.toJson()).toList(),
      'groupAddresses': groupAddresses.map((ga) => ga.toJson()).toList(),
      'groupRanges': groupRanges.map((gr) => gr.toJson()).toList(),
      'datapointTypes': datapointTypes.map((d) => d.toJson()).toList(),
      if (secureKeys != null) 'secureKeys': secureKeys!.toJson(),
    };
  }

  /// Convert to JSON string
  String toJsonString({bool pretty = true}) {
    final encoder =
        pretty ? const JsonEncoder.withIndent('  ') : const JsonEncoder();
    return encoder.convert(toJson());
  }

  @override
  String toString() => 'KnxFlatProject($projectName)';
}

/// KNX Floor
class KnxFloor {
  final String id;
  final String name;
  final int? puid;
  final String? parentId;
  final List<String> roomIds;

  const KnxFloor({
    required this.id,
    required this.name,
    this.puid,
    this.parentId,
    this.roomIds = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (puid != null) 'puid': puid,
      if (parentId != null) 'parentId': parentId,
      if (roomIds.isNotEmpty) 'roomIds': roomIds,
    };
  }

  @override
  String toString() => 'KnxFloor($name)';
}

/// KNX Room
class KnxRoom {
  final String id;
  final String name;
  final int? puid;
  final String? floorId;
  final List<String> deviceInstanceIds;

  const KnxRoom({
    required this.id,
    required this.name,
    this.puid,
    this.floorId,
    this.deviceInstanceIds = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (puid != null) 'puid': puid,
      if (floorId != null) 'floorId': floorId,
      if (deviceInstanceIds.isNotEmpty)
        'deviceInstanceIds': deviceInstanceIds,
    };
  }

  @override
  String toString() => 'KnxRoom($name)';
}

/// KNX Device
class KnxDevice {
  final String id;
  final int address;
  final String? name;
  final String? productRefId;
  final String? hardware2ProgramRefId;
  final int? puid;
  final List<ComObjectInstanceRef> comObjects;
  final String? securityToolKey;

  const KnxDevice({
    required this.id,
    required this.address,
    this.name,
    this.productRefId,
    this.hardware2ProgramRefId,
    this.puid,
    this.comObjects = const [],
    this.securityToolKey,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'address': address,
      if (name != null && name!.isNotEmpty) 'name': name,
      if (productRefId != null) 'productRefId': productRefId,
      if (hardware2ProgramRefId != null)
        'hardware2ProgramRefId': hardware2ProgramRefId,
      if (puid != null) 'puid': puid,
      if (comObjects.isNotEmpty)
        'comObjects': comObjects.map((c) => c.toJson()).toList(),
      if (securityToolKey != null) 'securityToolKey': securityToolKey,
    };
  }

  @override
  String toString() => 'KnxDevice($id, address=$address)';
}

/// KNX Group Address (flat)
class KnxGroupAddress {
  final String id;
  final int address;
  final String formattedAddress;
  final String name;
  final String? datapointType;
  final String? rangeName;
  final String? key;
  final List<String> deviceIds;

  const KnxGroupAddress({
    required this.id,
    required this.address,
    required this.formattedAddress,
    required this.name,
    this.datapointType,
    this.rangeName,
    this.key,
    this.deviceIds = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'address': address,
      'formattedAddress': formattedAddress,
      'name': name,
      if (datapointType != null) 'datapointType': datapointType,
      if (rangeName != null) 'rangeName': rangeName,
      if (key != null) 'key': key,
      if (deviceIds.isNotEmpty) 'deviceIds': deviceIds,
    };
  }

  @override
  String toString() => 'KnxGroupAddress($formattedAddress, "$name")';
}

/// KNX Group Range (flat)
class KnxGroupRange {
  final String id;
  final int rangeStart;
  final int rangeEnd;
  final String name;
  final int? puid;
  final String? parentId;

  const KnxGroupRange({
    required this.id,
    required this.rangeStart,
    required this.rangeEnd,
    required this.name,
    this.puid,
    this.parentId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'rangeStart': rangeStart,
      'rangeEnd': rangeEnd,
      'name': name,
      if (puid != null) 'puid': puid,
      if (parentId != null) 'parentId': parentId,
    };
  }

  @override
  String toString() => 'KnxGroupRange("$name", $rangeStart-$rangeEnd)';
}

/// KNX Security Keys
class KnxSecureKeys {
  final BackboneKey? backboneKey;
  final List<GroupKey> groupKeys;
  final List<DeviceKey> deviceKeys;
  final List<KnxGaSecureKey> gaKeys;
  final List<KnxDeviceToolKey> deviceToolKeys;

  const KnxSecureKeys({
    this.backboneKey,
    this.groupKeys = const [],
    this.deviceKeys = const [],
    this.gaKeys = const [],
    this.deviceToolKeys = const [],
  });

  bool get isEmpty =>
      backboneKey == null &&
      groupKeys.isEmpty &&
      deviceKeys.isEmpty &&
      gaKeys.isEmpty &&
      deviceToolKeys.isEmpty;

  Map<String, dynamic> toJson() {
    return {
      if (backboneKey != null) 'backboneKey': backboneKey!.toJson(),
      if (groupKeys.isNotEmpty)
        'groupKeys': groupKeys.map((k) => k.toJson()).toList(),
      if (deviceKeys.isNotEmpty)
        'deviceKeys': deviceKeys.map((k) => k.toJson()).toList(),
      if (gaKeys.isNotEmpty)
        'gaKeys': gaKeys.map((k) => k.toJson()).toList(),
      if (deviceToolKeys.isNotEmpty)
        'deviceToolKeys': deviceToolKeys.map((k) => k.toJson()).toList(),
    };
  }
}

/// KNX GA Security Key
class KnxGaSecureKey {
  final String gaId;
  final String formattedAddress;
  final String name;
  final String? key;

  const KnxGaSecureKey({
    required this.gaId,
    required this.formattedAddress,
    required this.name,
    this.key,
  });

  Map<String, dynamic> toJson() {
    return {
      'gaId': gaId,
      'formattedAddress': formattedAddress,
      'name': name,
      if (key != null) 'key': key,
    };
  }
}

/// KNX Device Tool Key
class KnxDeviceToolKey {
  final String deviceId;
  final int address;
  final String? name;
  final String? toolKey;

  const KnxDeviceToolKey({
    required this.deviceId,
    required this.address,
    this.name,
    this.toolKey,
  });

  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'address': address,
      if (name != null) 'name': name,
      if (toolKey != null) 'toolKey': toolKey,
    };
  }
}
