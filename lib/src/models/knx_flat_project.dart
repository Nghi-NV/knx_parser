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
  final List<KnxBuilding> buildings;
  final List<KnxFloor> floors;
  final List<KnxRoom> rooms;
  final List<KnxArea> areas;
  final List<KnxLine> lines;
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
    this.buildings = const [],
    this.floors = const [],
    this.rooms = const [],
    this.areas = const [],
    this.lines = const [],
    this.devices = const [],
    this.groupAddresses = const [],
    this.groupRanges = const [],
    this.datapointTypes = const [],
    this.secureKeys,
  });

  factory KnxFlatProject.fromJson(Map<String, dynamic> json) {
    return KnxFlatProject(
      projectName: json['projectName'] as String,
      projectId: json['projectId'] as String,
      groupAddressStyle: json['groupAddressStyle'] as String,
      lastModified: json['lastModified'] != null
          ? DateTime.parse(json['lastModified'] as String)
          : null,
      etsVersion: json['etsVersion'] as String?,
      schemaVersion: json['schemaVersion'] as int?,
      hasSecure: json['hasSecure'] as bool,
      buildings: (json['buildings'] as List<dynamic>?)
              ?.map((e) => KnxBuilding.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      floors: (json['floors'] as List<dynamic>?)
              ?.map((e) => KnxFloor.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      rooms: (json['rooms'] as List<dynamic>?)
              ?.map((e) => KnxRoom.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      areas: (json['areas'] as List<dynamic>?)
              ?.map((e) => KnxArea.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      lines: (json['lines'] as List<dynamic>?)
              ?.map((e) => KnxLine.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      devices: (json['devices'] as List<dynamic>?)
              ?.map((e) => KnxDevice.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      groupAddresses: (json['groupAddresses'] as List<dynamic>?)
              ?.map(
                  (e) => KnxGroupAddress.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      groupRanges: (json['groupRanges'] as List<dynamic>?)
              ?.map((e) => KnxGroupRange.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      datapointTypes: (json['datapointTypes'] as List<dynamic>?)
              ?.map((e) => DatapointType.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      secureKeys: json['secureKeys'] != null
          ? KnxSecureKeys.fromJson(json['secureKeys'] as Map<String, dynamic>)
          : null,
    );
  }

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
      if (buildings.isNotEmpty)
        'buildings': buildings.map((b) => b.toJson()).toList(),
      'floors': floors.map((f) => f.toJson()).toList(),
      'rooms': rooms.map((r) => r.toJson()).toList(),
      'areas': areas.map((a) => a.toJson()).toList(),
      'lines': lines.map((l) => l.toJson()).toList(),
      'devices': devices.map((d) => d.toJson()).toList(),
      'groupAddresses': groupAddresses.map((ga) => ga.toJson()).toList(),
      'groupRanges': groupRanges.map((gr) => gr.toJson()).toList(),
      'datapointTypes': datapointTypes.map((d) => d.toJson()).toList(),
      if (secureKeys != null) 'secureKeys': secureKeys!.toJson(),
    };
  }

  String toJsonString({bool pretty = true}) {
    final encoder =
        pretty ? const JsonEncoder.withIndent('  ') : const JsonEncoder();
    return encoder.convert(toJson());
  }

  @override
  String toString() => 'KnxFlatProject($projectName)';
}

// ---------------------------------------------------------------------------
// Location hierarchy: Building > Floor > Room
// ---------------------------------------------------------------------------

/// KNX Building
class KnxBuilding {
  final String id;
  final String name;
  final int? puid;
  final List<String> floorIds;

  const KnxBuilding({
    required this.id,
    required this.name,
    this.puid,
    this.floorIds = const [],
  });

  factory KnxBuilding.fromJson(Map<String, dynamic> json) {
    return KnxBuilding(
      id: json['id'] as String,
      name: json['name'] as String,
      puid: json['puid'] as int?,
      floorIds: (json['floorIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (puid != null) 'puid': puid,
      if (floorIds.isNotEmpty) 'floorIds': floorIds,
    };
  }

  @override
  String toString() => 'KnxBuilding($name)';
}

/// KNX Floor
class KnxFloor {
  final String id;
  final String name;
  final int? puid;
  final String? buildingId;
  final List<String> roomIds;

  const KnxFloor({
    required this.id,
    required this.name,
    this.puid,
    this.buildingId,
    this.roomIds = const [],
  });

  factory KnxFloor.fromJson(Map<String, dynamic> json) {
    return KnxFloor(
      id: json['id'] as String,
      name: json['name'] as String,
      puid: json['puid'] as int?,
      buildingId: json['buildingId'] as String?,
      roomIds: (json['roomIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (puid != null) 'puid': puid,
      if (buildingId != null) 'buildingId': buildingId,
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
  final List<KnxDeviceRef> devices;

  const KnxRoom({
    required this.id,
    required this.name,
    this.puid,
    this.floorId,
    this.devices = const [],
  });

  factory KnxRoom.fromJson(Map<String, dynamic> json) {
    return KnxRoom(
      id: json['id'] as String,
      name: json['name'] as String,
      puid: json['puid'] as int?,
      floorId: json['floorId'] as String?,
      devices: (json['devices'] as List<dynamic>?)
              ?.map((e) => KnxDeviceRef.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (puid != null) 'puid': puid,
      if (floorId != null) 'floorId': floorId,
      if (devices.isNotEmpty)
        'devices': devices.map((d) => d.toJson()).toList(),
    };
  }

  @override
  String toString() => 'KnxRoom($name)';
}

// ---------------------------------------------------------------------------
// Topology: Area > Line > Device
// ---------------------------------------------------------------------------

/// KNX Area (topology level 1)
class KnxArea {
  final String id;
  final int address;
  final String? name;
  final int? puid;
  final List<String> lineIds;

  const KnxArea({
    required this.id,
    required this.address,
    this.name,
    this.puid,
    this.lineIds = const [],
  });

  factory KnxArea.fromJson(Map<String, dynamic> json) {
    return KnxArea(
      id: json['id'] as String,
      address: json['address'] as int,
      name: json['name'] as String?,
      puid: json['puid'] as int?,
      lineIds: (json['lineIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'address': address,
      if (name != null) 'name': name,
      if (puid != null) 'puid': puid,
      if (lineIds.isNotEmpty) 'lineIds': lineIds,
    };
  }

  @override
  String toString() => 'KnxArea($address, "$name")';
}

/// KNX Line (topology level 2)
class KnxLine {
  final String id;
  final int address;
  final String? name;
  final int? puid;
  final String areaId;
  final List<String> deviceIds;

  const KnxLine({
    required this.id,
    required this.address,
    this.name,
    this.puid,
    required this.areaId,
    this.deviceIds = const [],
  });

  factory KnxLine.fromJson(Map<String, dynamic> json) {
    return KnxLine(
      id: json['id'] as String,
      address: json['address'] as int,
      name: json['name'] as String?,
      puid: json['puid'] as int?,
      areaId: json['areaId'] as String,
      deviceIds: (json['deviceIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'address': address,
      if (name != null) 'name': name,
      if (puid != null) 'puid': puid,
      'areaId': areaId,
      if (deviceIds.isNotEmpty) 'deviceIds': deviceIds,
    };
  }

  @override
  String toString() => 'KnxLine($address, "$name")';
}

// ---------------------------------------------------------------------------
// Lightweight references
// ---------------------------------------------------------------------------

/// Lightweight device reference (used in rooms and GA)
class KnxDeviceRef {
  final String id;
  final String formattedAddress;
  final String? name;

  const KnxDeviceRef({
    required this.id,
    required this.formattedAddress,
    this.name,
  });

  factory KnxDeviceRef.fromJson(Map<String, dynamic> json) {
    return KnxDeviceRef(
      id: json['id'] as String,
      formattedAddress: json['formattedAddress'] as String,
      name: json['name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'formattedAddress': formattedAddress,
      if (name != null) 'name': name,
    };
  }

  @override
  String toString() => 'KnxDeviceRef($formattedAddress)';
}

// ---------------------------------------------------------------------------
// Device
// ---------------------------------------------------------------------------

/// KNX Device
class KnxDevice {
  final String id;
  final int address;
  final String formattedAddress;
  final String? name;
  final String? roomId;
  final String? roomName;
  final String? areaId;
  final String? areaName;
  final String? lineId;
  final String? lineName;
  final String? productRefId;
  final String? hardware2ProgramRefId;
  final int? puid;
  final List<ComObjectInstanceRef> comObjects;
  final String? securityToolKey;

  const KnxDevice({
    required this.id,
    required this.address,
    required this.formattedAddress,
    this.name,
    this.roomId,
    this.roomName,
    this.areaId,
    this.areaName,
    this.lineId,
    this.lineName,
    this.productRefId,
    this.hardware2ProgramRefId,
    this.puid,
    this.comObjects = const [],
    this.securityToolKey,
  });

  factory KnxDevice.fromJson(Map<String, dynamic> json) {
    return KnxDevice(
      id: json['id'] as String,
      address: json['address'] as int,
      formattedAddress: json['formattedAddress'] as String,
      name: json['name'] as String?,
      roomId: json['roomId'] as String?,
      roomName: json['roomName'] as String?,
      areaId: json['areaId'] as String?,
      areaName: json['areaName'] as String?,
      lineId: json['lineId'] as String?,
      lineName: json['lineName'] as String?,
      productRefId: json['productRefId'] as String?,
      hardware2ProgramRefId: json['hardware2ProgramRefId'] as String?,
      puid: json['puid'] as int?,
      comObjects: (json['comObjects'] as List<dynamic>?)
              ?.map((e) =>
                  ComObjectInstanceRef.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      securityToolKey: json['securityToolKey'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'address': address,
      'formattedAddress': formattedAddress,
      if (name != null && name!.isNotEmpty) 'name': name,
      if (roomId != null) 'roomId': roomId,
      if (roomName != null) 'roomName': roomName,
      if (areaId != null) 'areaId': areaId,
      if (areaName != null) 'areaName': areaName,
      if (lineId != null) 'lineId': lineId,
      if (lineName != null) 'lineName': lineName,
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
  String toString() => 'KnxDevice($formattedAddress, $id)';
}

// ---------------------------------------------------------------------------
// Group Address & Range
// ---------------------------------------------------------------------------

/// KNX Group Address
class KnxGroupAddress {
  final String id;
  final int address;
  final String formattedAddress;
  final String name;
  final String? datapointType;
  final String? rangeName;
  final String? key;
  final List<KnxDeviceRef> devices;

  const KnxGroupAddress({
    required this.id,
    required this.address,
    required this.formattedAddress,
    required this.name,
    this.datapointType,
    this.rangeName,
    this.key,
    this.devices = const [],
  });

  factory KnxGroupAddress.fromJson(Map<String, dynamic> json) {
    return KnxGroupAddress(
      id: json['id'] as String,
      address: json['address'] as int,
      formattedAddress: json['formattedAddress'] as String,
      name: json['name'] as String,
      datapointType: json['datapointType'] as String?,
      rangeName: json['rangeName'] as String?,
      key: json['key'] as String?,
      devices: (json['devices'] as List<dynamic>?)
              ?.map((e) => KnxDeviceRef.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'address': address,
      'formattedAddress': formattedAddress,
      'name': name,
      if (datapointType != null) 'datapointType': datapointType,
      if (rangeName != null) 'rangeName': rangeName,
      if (key != null) 'key': key,
      if (devices.isNotEmpty)
        'devices': devices.map((d) => d.toJson()).toList(),
    };
  }

  @override
  String toString() => 'KnxGroupAddress($formattedAddress, "$name")';
}

/// KNX Group Range
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

  factory KnxGroupRange.fromJson(Map<String, dynamic> json) {
    return KnxGroupRange(
      id: json['id'] as String,
      rangeStart: json['rangeStart'] as int,
      rangeEnd: json['rangeEnd'] as int,
      name: json['name'] as String,
      puid: json['puid'] as int?,
      parentId: json['parentId'] as String?,
    );
  }

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

// ---------------------------------------------------------------------------
// Security
// ---------------------------------------------------------------------------

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

  factory KnxSecureKeys.fromJson(Map<String, dynamic> json) {
    return KnxSecureKeys(
      backboneKey: json['backboneKey'] != null
          ? BackboneKey.fromJson(json['backboneKey'] as Map<String, dynamic>)
          : null,
      groupKeys: (json['groupKeys'] as List<dynamic>?)
              ?.map((e) => GroupKey.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      deviceKeys: (json['deviceKeys'] as List<dynamic>?)
              ?.map((e) => DeviceKey.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      gaKeys: (json['gaKeys'] as List<dynamic>?)
              ?.map((e) => KnxGaSecureKey.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      deviceToolKeys: (json['deviceToolKeys'] as List<dynamic>?)
              ?.map(
                  (e) => KnxDeviceToolKey.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

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

  factory KnxGaSecureKey.fromJson(Map<String, dynamic> json) {
    return KnxGaSecureKey(
      gaId: json['gaId'] as String,
      formattedAddress: json['formattedAddress'] as String,
      name: json['name'] as String,
      key: json['key'] as String?,
    );
  }

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

  factory KnxDeviceToolKey.fromJson(Map<String, dynamic> json) {
    return KnxDeviceToolKey(
      deviceId: json['deviceId'] as String,
      address: json['address'] as int,
      name: json['name'] as String?,
      toolKey: json['toolKey'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'address': address,
      if (name != null) 'name': name,
      if (toolKey != null) 'toolKey': toolKey,
    };
  }
}
