import 'project_info.dart';
import 'installation.dart';
import 'device_instance.dart';
import 'group_address.dart';
import 'location.dart';
import 'datapoint_type.dart';
import 'knx_keys.dart';
import 'knx_flat_project.dart';

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

  /// Convert to flat model with organized sections
  KnxFlatProject toFlat() {
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

    // Separate locations into floors and rooms
    final floorLocations = allLocations.where((l) => l.type == 'Floor');
    final roomLocations = allLocations.where((l) => l.type == 'Room');

    // Detect hasSecure
    final hasGaKeys = allGroupAddresses.any(
        (ga) => ga.key != null && ga.key!.isNotEmpty);
    final hasDeviceKeys = allDevices.any(
        (d) => d.securityToolKey != null && d.securityToolKey!.isNotEmpty);
    final hasKnxKeys = knxKeys != null &&
        (knxKeys!.groupKeys.isNotEmpty || knxKeys!.deviceKeys.isNotEmpty);
    final hasSecure = hasGaKeys || hasDeviceKeys || hasKnxKeys;

    // Build floors
    final floors = floorLocations.map((floor) {
      final floorRoomIds = roomLocations
          .where((r) => r.parent?.id == floor.id)
          .map((r) => r.id)
          .toList();
      return KnxFloor(
        id: floor.id,
        name: floor.name,
        puid: floor.puid,
        parentId: floor.parent?.id,
        roomIds: floorRoomIds,
      );
    }).toList();

    // Build rooms
    final rooms = roomLocations.map((room) {
      return KnxRoom(
        id: room.id,
        name: room.name,
        puid: room.puid,
        floorId: room.parent?.id,
        deviceInstanceIds: room.deviceInstanceIds,
      );
    }).toList();

    // Build devices
    final devices = allDevices.map((d) {
      return KnxDevice(
        id: d.id,
        address: d.address,
        name: d.name,
        productRefId: d.productRefId,
        hardware2ProgramRefId: d.hardware2ProgramRefId,
        puid: d.puid,
        comObjects: d.comObjectInstanceRefs,
        securityToolKey: d.securityToolKey,
      );
    }).toList();

    // Build GA-to-device mapping from comObject links
    final gaToDeviceIds = <String, List<String>>{};
    for (final device in allDevices) {
      for (final comObj in device.comObjectInstanceRefs) {
        if (comObj.links != null) {
          for (final link in comObj.links!.split(' ')) {
            final trimmed = link.trim();
            if (trimmed.isEmpty) continue;
            // Find matching GA by suffix (link is short id like "GA-1")
            for (final ga in allGroupAddresses) {
              if (ga.id.endsWith('_$trimmed') || ga.id == trimmed) {
                gaToDeviceIds.putIfAbsent(ga.id, () => []);
                if (!gaToDeviceIds[ga.id]!.contains(device.id)) {
                  gaToDeviceIds[ga.id]!.add(device.id);
                }
                break;
              }
            }
          }
        }
      }
    }

    // Build group addresses
    final groupAddresses = allGroupAddresses.map((ga) {
      return KnxGroupAddress(
        id: ga.id,
        address: ga.address,
        formattedAddress: ga.formattedAddress,
        name: ga.name,
        datapointType: _formatDpt(ga.datapointType),
        rangeName: ga.range?.name,
        key: ga.key,
        deviceIds: gaToDeviceIds[ga.id] ?? const [],
      );
    }).toList();

    // Build group ranges
    final groupRanges = allGroupRanges.map((gr) {
      return KnxGroupRange(
        id: gr.id,
        rangeStart: gr.rangeStart,
        rangeEnd: gr.rangeEnd,
        name: gr.name,
        puid: gr.puid,
        parentId: gr.parent?.id,
      );
    }).toList();

    // Build secureKeys
    KnxSecureKeys? secureKeys;
    if (hasSecure) {
      final gaKeys = allGroupAddresses
          .where((ga) => ga.key != null && ga.key!.isNotEmpty)
          .map((ga) => KnxGaSecureKey(
                gaId: ga.id,
                formattedAddress: ga.formattedAddress,
                name: ga.name,
                key: ga.key,
              ))
          .toList();

      final deviceToolKeys = allDevices
          .where((d) =>
              d.securityToolKey != null && d.securityToolKey!.isNotEmpty)
          .map((d) => KnxDeviceToolKey(
                deviceId: d.id,
                address: d.address,
                name: d.name,
                toolKey: d.securityToolKey,
              ))
          .toList();

      secureKeys = KnxSecureKeys(
        backboneKey: knxKeys?.backboneKey,
        groupKeys: knxKeys?.groupKeys ?? const [],
        deviceKeys: knxKeys?.deviceKeys ?? const [],
        gaKeys: gaKeys,
        deviceToolKeys: deviceToolKeys,
      );
    }

    return KnxFlatProject(
      projectName: projectInfo.name,
      projectId: projectInfo.id,
      groupAddressStyle: projectInfo.groupAddressStyle,
      lastModified: projectInfo.lastModified,
      etsVersion: projectInfo.etsVersion,
      schemaVersion: projectInfo.schemaVersion,
      hasSecure: hasSecure,
      floors: floors,
      rooms: rooms,
      devices: devices,
      groupAddresses: groupAddresses,
      groupRanges: groupRanges,
      datapointTypes: datapointTypes,
      secureKeys: secureKeys,
    );
  }

  /// Convert to flat JSON map with organized sections
  Map<String, dynamic> toFlatJson() => toFlat().toJson();

  /// Format DPT from "DPST-9-1" to "9.001"
  static String? _formatDpt(String? dpt) {
    if (dpt == null) return null;
    final raw = dpt.startsWith('DPST-') ? dpt.substring(5) : dpt;
    final parts = raw.split('-');
    if (parts.length == 2) {
      final main = parts[0];
      final sub = parts[1].padLeft(3, '0');
      return '$main.$sub';
    }
    return dpt;
  }

  @override
  String toString() => 'KnxProject(${projectInfo.name})';
}
