import 'project_info.dart';
import 'installation.dart';
import 'device_instance.dart';
import 'group_address.dart';
import 'location.dart';
import 'datapoint_type.dart';
import 'knx_keys.dart';

/// Root model representing a complete KNX project
class KnxProject {
  /// Project metadata
  final ProjectInfo projectInfo;

  /// List of installations in the project
  final List<Installation> installations;

  /// Datapoint type definitions from knx_master.xml
  final List<DatapointType> datapointTypes;

  /// Keyring data from .knxkeys file (optional)
  final KnxKeys? knxKeys;

  const KnxProject({
    required this.projectInfo,
    required this.installations,
    this.datapointTypes = const [],
    this.knxKeys,
  });

  /// Convert to JSON map (original nested format)
  Map<String, dynamic> toJson() {
    return {
      'project': projectInfo.toJson(),
      'installations': installations.map((i) => i.toJson()).toList(),
      'datapointTypes': datapointTypes.map((d) => d.toJson()).toList(),
      if (knxKeys != null) 'knxKeys': knxKeys!.toJson(),
    };
  }

  /// Convert to flat JSON map with organized sections
  Map<String, dynamic> toFlatJson() {
    // Collect all data from installations
    final allLocations = <Location>[];
    final allGroupAddresses = <GroupAddress>[];
    final allGroupRanges = <GroupRange>[];
    final allDevices = <DeviceInstance>[];

    for (final inst in installations) {
      allLocations.addAll(inst.locations);
      allGroupAddresses.addAll(inst.groupAddresses);
      allGroupRanges.addAll(inst.groupRanges);

      // Collect devices from topology
      for (final area in inst.topology.areas) {
        for (final line in area.lines) {
          allDevices.addAll(line.devices);
        }
      }
    }

    // Separate locations into building, floors, rooms
    final floors = allLocations
        .where((l) => l.type == 'Floor')
        .toList();
    final rooms = allLocations
        .where((l) => l.type == 'Room')
        .toList();

    // Detect hasSecure
    final hasGaKeys = allGroupAddresses.any((ga) => ga.key != null && ga.key!.isNotEmpty);
    final hasDeviceKeys = allDevices.any((d) => d.securityToolKey != null && d.securityToolKey!.isNotEmpty);
    final hasKnxKeys = knxKeys != null && (knxKeys!.groupKeys.isNotEmpty || knxKeys!.deviceKeys.isNotEmpty);
    final hasSecure = hasGaKeys || hasDeviceKeys || hasKnxKeys;

    // Build floor JSON with roomIds
    final floorJsonList = floors.map((floor) {
      final floorRoomIds = rooms
          .where((r) => r.parent?.id == floor.id)
          .map((r) => r.id)
          .toList();
      return {
        'id': floor.id,
        'name': floor.name,
        if (floor.puid != null) 'puid': floor.puid,
        if (floor.parent != null) 'parentId': floor.parent!.id,
        if (floorRoomIds.isNotEmpty) 'roomIds': floorRoomIds,
      };
    }).toList();

    // Build room JSON with floorId
    final roomJsonList = rooms.map((room) {
      return {
        'id': room.id,
        'name': room.name,
        if (room.puid != null) 'puid': room.puid,
        if (room.parent != null) 'floorId': room.parent!.id,
        if (room.deviceInstanceIds.isNotEmpty)
          'deviceInstanceIds': room.deviceInstanceIds,
      };
    }).toList();

    // Build device JSON
    final deviceJsonList = allDevices.map((d) {
      return {
        'id': d.id,
        'address': d.address,
        if (d.name != null && d.name!.isNotEmpty) 'name': d.name,
        if (d.productRefId != null) 'productRefId': d.productRefId,
        if (d.hardware2ProgramRefId != null)
          'hardware2ProgramRefId': d.hardware2ProgramRefId,
        if (d.puid != null) 'puid': d.puid,
        if (d.comObjectInstanceRefs.isNotEmpty)
          'comObjects': d.comObjectInstanceRefs.map((c) => c.toJson()).toList(),
        if (d.securityToolKey != null) 'securityToolKey': d.securityToolKey,
      };
    }).toList();

    // Build GA JSON
    final gaJsonList = allGroupAddresses.map((ga) {
      return {
        'id': ga.id,
        'address': ga.address,
        'formattedAddress': ga.formattedAddress,
        'name': ga.name,
        if (ga.datapointType != null) 'datapointType': ga.datapointType,
        if (ga.range != null) 'rangeName': ga.range!.name,
        if (ga.key != null) 'key': ga.key,
      };
    }).toList();

    // Build DPT JSON
    final dptJsonList = datapointTypes.map((d) => d.toJson()).toList();

    // Build secureKeys section
    Map<String, dynamic>? secureKeysJson;
    if (hasSecure) {
      secureKeysJson = {};
      if (knxKeys != null) {
        if (knxKeys!.backboneKey != null) {
          secureKeysJson['backboneKey'] = knxKeys!.backboneKey!.toJson();
        }
        if (knxKeys!.groupKeys.isNotEmpty) {
          secureKeysJson['groupKeys'] =
              knxKeys!.groupKeys.map((k) => k.toJson()).toList();
        }
        if (knxKeys!.deviceKeys.isNotEmpty) {
          secureKeysJson['deviceKeys'] =
              knxKeys!.deviceKeys.map((k) => k.toJson()).toList();
        }
      }
      // Also collect inline GA keys
      final inlineGaKeys = allGroupAddresses
          .where((ga) => ga.key != null && ga.key!.isNotEmpty)
          .map((ga) => {
                'gaId': ga.id,
                'formattedAddress': ga.formattedAddress,
                'name': ga.name,
                'key': ga.key,
              })
          .toList();
      if (inlineGaKeys.isNotEmpty) {
        secureKeysJson['gaKeys'] = inlineGaKeys;
      }
      // Collect inline device security tool keys
      final inlineDeviceKeys = allDevices
          .where((d) => d.securityToolKey != null && d.securityToolKey!.isNotEmpty)
          .map((d) => {
                'deviceId': d.id,
                'address': d.address,
                if (d.name != null) 'name': d.name,
                'toolKey': d.securityToolKey,
              })
          .toList();
      if (inlineDeviceKeys.isNotEmpty) {
        secureKeysJson['deviceToolKeys'] = inlineDeviceKeys;
      }
    }

    return {
      'projectName': projectInfo.name,
      'projectId': projectInfo.id,
      'groupAddressStyle': projectInfo.groupAddressStyle,
      if (projectInfo.lastModified != null)
        'lastModified': projectInfo.lastModified!.toIso8601String(),
      if (projectInfo.etsVersion != null) 'etsVersion': projectInfo.etsVersion,
      if (projectInfo.schemaVersion != null)
        'schemaVersion': projectInfo.schemaVersion,
      'hasSecure': hasSecure,
      'floors': floorJsonList,
      'rooms': roomJsonList,
      'devices': deviceJsonList,
      'groupAddresses': gaJsonList,
      'groupRanges': allGroupRanges.map((gr) => gr.toJson()).toList(),
      'datapointTypes': dptJsonList,
      if (secureKeysJson != null && secureKeysJson.isNotEmpty)
        'secureKeys': secureKeysJson,
    };
  }

  @override
  String toString() => 'KnxProject(${projectInfo.name})';
}
