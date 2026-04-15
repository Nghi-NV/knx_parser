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

    // Device entries: device, formattedAddress, areaId, areaName, lineId, lineName
    final deviceEntries = <_DeviceEntry>[];
    final flatAreas = <KnxArea>[];
    final flatLines = <KnxLine>[];

    for (final inst in installations) {
      allLocations.addAll(inst.locations);
      allGroupAddresses.addAll(inst.groupAddresses);
      allGroupRanges.addAll(inst.groupRanges);

      for (final area in inst.topology.areas) {
        final lineIds = <String>[];
        for (final line in area.lines) {
          lineIds.add(line.id);
          final deviceIds = <String>[];
          for (final device in line.devices) {
            final formatted =
                '${area.address}.${line.address}.${device.address}';
            deviceEntries.add(_DeviceEntry(
              device: device,
              formattedAddress: formatted,
              areaId: area.id,
              areaName: area.name,
              lineId: line.id,
              lineName: line.name,
            ));
            deviceIds.add(device.id);
          }
          flatLines.add(KnxLine(
            id: line.id,
            address: line.address,
            name: line.name,
            puid: line.puid,
            areaId: area.id,
            deviceIds: deviceIds,
          ));
        }
        flatAreas.add(KnxArea(
          id: area.id,
          address: area.address,
          name: area.name,
          puid: area.puid,
          lineIds: lineIds,
        ));
      }
    }

    // Build device lookup: deviceId -> formattedAddress, name
    final deviceRefMap = <String, KnxDeviceRef>{};
    for (final entry in deviceEntries) {
      deviceRefMap[entry.device.id] = KnxDeviceRef(
        id: entry.device.id,
        formattedAddress: entry.formattedAddress,
        name: entry.device.name,
      );
    }

    // Separate locations into buildings, floors and rooms
    final buildingLocations = <Location>[];
    final floorLocations = <Location>[];
    final roomLocations = <Location>[];
    for (final loc in allLocations) {
      if (loc.type == 'Building') {
        buildingLocations.add(loc);
      } else if (loc.type == 'Floor') {
        floorLocations.add(loc);
      } else if (loc.type == 'Room') {
        roomLocations.add(loc);
      }
    }

    final deviceToRoom = <String, Location>{};
    final gaToLocation = <String, Location>{};
    final gaToLocationBySuffix = <String, Location>{};
    final floorIdsByBuildingId = <String, List<String>>{};
    final roomIdsByFloorId = <String, List<String>>{};
    final locationPathCache = <String, String>{};

    String locationPathOf(Location location) {
      final cached = locationPathCache[location.id];
      if (cached != null) return cached;

      final pathParts = <String>[];
      Location? current = location;
      // ignore: unnecessary_null_comparison
      while (current != null) {
        pathParts.add(current.name);
        current = current.parent;
      }
      final path = pathParts.reversed.join(' > ');
      locationPathCache[location.id] = path;
      return path;
    }

    for (final room in roomLocations) {
      for (final devId in room.deviceInstanceIds) {
        deviceToRoom[devId] = room;
      }

      final floorId = room.parent?.id;
      if (floorId != null) {
        roomIdsByFloorId.putIfAbsent(floorId, () => []).add(room.id);
      }
    }

    for (final floor in floorLocations) {
      final buildingId = floor.parent?.id;
      if (buildingId != null) {
        floorIdsByBuildingId.putIfAbsent(buildingId, () => []).add(floor.id);
      }
    }

    for (final loc in allLocations) {
      for (final gaRefId in loc.groupAddressRefIds) {
        gaToLocation[gaRefId] = loc;
        gaToLocationBySuffix.putIfAbsent(_idSuffix(gaRefId), () => loc);
      }
    }

    // Detect hasSecure
    final hasGaKeys =
        allGroupAddresses.any((ga) => ga.key != null && ga.key!.isNotEmpty);
    final hasDeviceKeys = deviceEntries.any((e) =>
        e.device.securityToolKey != null &&
        e.device.securityToolKey!.isNotEmpty);
    final hasKnxKeys = knxKeys != null &&
        (knxKeys!.groupKeys.isNotEmpty || knxKeys!.deviceKeys.isNotEmpty);
    final hasSecure = hasGaKeys || hasDeviceKeys || hasKnxKeys;

    // Build buildings
    final buildings = buildingLocations.map((building) {
      return KnxBuilding(
        id: building.id,
        name: building.name,
        puid: building.puid,
        floorIds: floorIdsByBuildingId[building.id] ?? const [],
      );
    }).toList();

    // Build floors
    final floors = floorLocations.map((floor) {
      return KnxFloor(
        id: floor.id,
        name: floor.name,
        puid: floor.puid,
        buildingId: floor.parent?.id,
        roomIds: roomIdsByFloorId[floor.id] ?? const [],
      );
    }).toList();

    // Build rooms with device refs
    final rooms = roomLocations.map((room) {
      final roomDeviceRefs = room.deviceInstanceIds
          .map((id) => deviceRefMap[id])
          .whereType<KnxDeviceRef>()
          .toList();
      return KnxRoom(
        id: room.id,
        name: room.name,
        puid: room.puid,
        floorId: room.parent?.id,
        devices: roomDeviceRefs,
      );
    }).toList();

    // Build devices with room/area/line info
    final devices = deviceEntries.map((entry) {
      final d = entry.device;
      final room = deviceToRoom[d.id];

      String? locPath = d.locationPath;
      if (locPath == null && room != null) {
        locPath = locationPathOf(room);
      }

      return KnxDevice(
        id: d.id,
        address: d.address,
        formattedAddress: entry.formattedAddress,
        name: d.name,
        description: d.description,
        comment: d.comment,
        productName: d.productName,
        roomId: room?.id,
        roomName: room?.name,
        areaId: entry.areaId,
        areaName: entry.areaName,
        lineId: entry.lineId,
        lineName: entry.lineName,
        productRefId: d.productRefId,
        hardware2ProgramRefId: d.hardware2ProgramRefId,
        puid: d.puid,
        securityToolKey: d.securityToolKey,
        manufacturerName: d.manufacturerName,
        orderNumber: d.orderNumber,
        applicationName: d.applicationName,
        applicationVersion: d.applicationVersion,
        mediumType: d.mediumType,
        locationPath: locPath,
        comObjects: d.comObjectInstanceRefs,
        datapointTypes: d.comObjectInstanceRefs
            .map((co) => co.datapointType)
            .whereType<String>()
            .toSet()
            .toList(),
      );
    }).toList();

    // Build GA-to-device mapping from comObject links
    final gaById = <String, GroupAddress>{};
    final gaBySuffix = <String, GroupAddress>{};
    for (final ga in allGroupAddresses) {
      gaById[ga.id] = ga;
      gaBySuffix.putIfAbsent(_idSuffix(ga.id), () => ga);
    }

    final gaToDeviceIds = <String, Set<String>>{};
    for (final entry in deviceEntries) {
      for (final comObj in entry.device.comObjectInstanceRefs) {
        final links = comObj.links;
        if (links == null || links.isEmpty) continue;

        for (final link in links.split(' ')) {
          final trimmed = link.trim();
          if (trimmed.isEmpty) continue;

          final ga = gaById[trimmed] ?? gaBySuffix[trimmed];
          if (ga == null) continue;

          gaToDeviceIds
              .putIfAbsent(ga.id, () => <String>{})
              .add(entry.device.id);
        }
      }
    }

    // Build group addresses
    final groupAddresses = allGroupAddresses.map((ga) {
      final gaSuffix = _idSuffix(ga.id);
      final loc = gaToLocation[ga.id] ??
          gaToLocation[gaSuffix] ??
          gaToLocationBySuffix[gaSuffix];

      String? locPath;
      if (loc != null) {
        locPath = locationPathOf(loc);
      }

      final linkedDeviceRefs = (gaToDeviceIds[ga.id] ?? const <String>{})
          .map((id) => deviceRefMap[id])
          .whereType<KnxDeviceRef>()
          .toList();

      return KnxGroupAddress(
        id: ga.id,
        address: ga.address,
        formattedAddress: ga.formattedAddress,
        name: ga.name,
        datapointType: _formatDpt(ga.datapointType),
        rangeName: ga.range?.name,
        roomId: loc?.type == 'Room' ? loc?.id : null,
        roomName: loc?.type == 'Room' ? loc?.name : null,
        locationPath: locPath,
        key: ga.key,
        devices: linkedDeviceRefs,
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

      final deviceToolKeys = deviceEntries
          .where((e) =>
              e.device.securityToolKey != null &&
              e.device.securityToolKey!.isNotEmpty)
          .map((e) => KnxDeviceToolKey(
                deviceId: e.device.id,
                address: e.device.address,
                name: e.device.name,
                toolKey: e.device.securityToolKey,
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
      buildings: buildings,
      floors: floors,
      rooms: rooms,
      areas: flatAreas,
      lines: flatLines,
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

  static String _idSuffix(String id) {
    final idx = id.lastIndexOf('_');
    if (idx < 0 || idx == id.length - 1) return id;
    return id.substring(idx + 1);
  }

  @override
  String toString() => 'KnxProject(${projectInfo.name})';
}

/// Internal helper for collecting device info during toFlat()
class _DeviceEntry {
  final DeviceInstance device;
  final String formattedAddress;
  final String areaId;
  final String? areaName;
  final String lineId;
  final String? lineName;

  const _DeviceEntry({
    required this.device,
    required this.formattedAddress,
    required this.areaId,
    this.areaName,
    required this.lineId,
    this.lineName,
  });
}
