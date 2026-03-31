import 'package:xml/xml.dart';

/// Represents a Device Instance in the topology
class DeviceInstance {
  final String id;
  final int address;
  final String? name;
  final String? description;
  final String? comment;
  final String? productName;
  final String? productRefId;
  final String? hardware2ProgramRefId;
  final int? puid;
  final List<ComObjectInstanceRef> comObjectInstanceRefs;
  final String? securityToolKey;

  // ── Enriched data ──
  final String? manufacturerName;
  final String? orderNumber;
  final String? applicationName;
  final String? applicationVersion;
  final String? mediumType;
  final String? locationPath;

  const DeviceInstance({
    required this.id,
    required this.address,
    this.name,
    this.description,
    this.comment,
    this.productName,
    this.productRefId,
    this.hardware2ProgramRefId,
    this.puid,
    this.comObjectInstanceRefs = const [],
    this.securityToolKey,
    this.manufacturerName,
    this.orderNumber,
    this.applicationName,
    this.applicationVersion,
    this.mediumType,
    this.locationPath,
  });

  factory DeviceInstance.fromXml(XmlElement element) {
    final comObjects = element
        .findAllElements('ComObjectInstanceRef')
        .map((e) => ComObjectInstanceRef.fromXml(e))
        .toList();

    String? toolKey;
    final securityElement = element.getElement('Security');
    if (securityElement != null) {
      toolKey = securityElement.getAttribute('ToolKey');
    }

    return DeviceInstance(
      id: element.getAttribute('Id') ?? '',
      address: int.tryParse(element.getAttribute('Address') ?? '') ?? 0,
      name: element.getAttribute('Name'),
      description: element.getAttribute('Description'),
      comment: element.getAttribute('Comment'),
      productRefId: element.getAttribute('ProductRefId'),
      hardware2ProgramRefId: element.getAttribute('Hardware2ProgramRefId'),
      puid: int.tryParse(element.getAttribute('Puid') ?? ''),
      comObjectInstanceRefs: comObjects,
      securityToolKey: toolKey,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'address': address,
      if (name != null && name!.isNotEmpty) 'name': name,
      if (description != null && description!.isNotEmpty)
        'description': description,
      if (comment != null && comment!.isNotEmpty) 'comment': comment,
      if (productName != null && productName!.isNotEmpty)
        'productName': productName,
      if (productRefId != null) 'productRefId': productRefId,
      if (hardware2ProgramRefId != null)
        'hardware2ProgramRefId': hardware2ProgramRefId,
      if (puid != null) 'puid': puid,
      'comObjectInstanceRefs':
          comObjectInstanceRefs.map((e) => e.toJson()).toList(),
      if (securityToolKey != null) 'securityToolKey': securityToolKey,
      if (manufacturerName != null) 'manufacturerName': manufacturerName,
      if (orderNumber != null) 'orderNumber': orderNumber,
      if (applicationName != null) 'applicationName': applicationName,
      if (applicationVersion != null) 'applicationVersion': applicationVersion,
      if (mediumType != null) 'mediumType': mediumType,
      if (locationPath != null) 'locationPath': locationPath,
    };
  }

  /// Create an enriched copy of DeviceInstance
  DeviceInstance copyWithEnrichment({
    String? productName,
    String? manufacturerName,
    String? orderNumber,
    String? applicationName,
    String? applicationVersion,
    String? mediumType,
    String? locationPath,
    List<ComObjectInstanceRef>? comObjectInstanceRefs,
  }) {
    final hasName = name != null && name!.isNotEmpty;
    return DeviceInstance(
      id: id,
      address: address,
      name: hasName ? name : (productName ?? this.productName),
      description: description,
      comment: comment,
      productName: productName ?? this.productName,
      productRefId: productRefId,
      hardware2ProgramRefId: hardware2ProgramRefId,
      puid: puid,
      securityToolKey: securityToolKey,
      manufacturerName: manufacturerName ?? this.manufacturerName,
      orderNumber: orderNumber ?? this.orderNumber,
      applicationName: applicationName ?? this.applicationName,
      applicationVersion: applicationVersion ?? this.applicationVersion,
      mediumType: mediumType ?? this.mediumType,
      locationPath: locationPath ?? this.locationPath,
      comObjectInstanceRefs:
          comObjectInstanceRefs ?? this.comObjectInstanceRefs,
    );
  }

  @override
  String toString() => 'DeviceInstance($id, address=$address)';
}

class KnxGroupAddressLink {
  final String address;
  final String? name;

  const KnxGroupAddressLink({
    required this.address,
    this.name,
  });

  factory KnxGroupAddressLink.fromJson(Map<String, dynamic> json) {
    return KnxGroupAddressLink(
      address: json['address'] as String,
      name: json['name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'address': address,
      if (name != null) 'name': name,
    };
  }

  @override
  String toString() => 'KnxGroupAddressLink($address, name: $name)';
}

/// Represents a Communication Object Instance Reference
/// enriched with ComObject definition data from application program XML.
class ComObjectInstanceRef {
  final String? refId;
  final String? text;
  final String? links; // Space-separated list of group address IDs (raw)
  final String? channelId;

  // ── Enriched from ComObject definition (M-*/M-*_A-*.xml) ──
  final String? name; // e.g. "Relay1_Switch"
  final String? description; // from ComObject Text attr, e.g. "Relay 1 Switch"
  final int? number; // ComObject Number
  final String? functionText; // e.g. "Switch", "Dimming Control"
  final String? objectSize; // e.g. "1 Bit", "1 Byte"
  final String? datapointType; // e.g. "DPST-1-1"
  final String? datapointText; // e.g. "switch", "dimming"
  final String? priority; // e.g. "Low", "High"
  final bool? communicationFlag; // C flag
  final bool? readFlag; // R flag
  final bool? writeFlag; // W flag
  final bool? transmitFlag; // T flag
  final bool? updateFlag; // U flag
  final String? channelName; // e.g. "Buttons", "Sensors"

  // ── Resolved GA links ──
  final List<String> groupAddresses; // legacy formatted GA addresses
  final List<KnxGroupAddressLink> linkedGroupAddresses; // address + name

  const ComObjectInstanceRef({
    this.refId,
    this.text,
    this.links,
    this.channelId,
    this.name,
    this.description,
    this.number,
    this.functionText,
    this.objectSize,
    this.datapointType,
    this.datapointText,
    this.priority,
    this.communicationFlag,
    this.readFlag,
    this.writeFlag,
    this.transmitFlag,
    this.updateFlag,
    this.channelName,
    this.groupAddresses = const [],
    this.linkedGroupAddresses = const [],
  });

  factory ComObjectInstanceRef.fromXml(XmlElement element) {
    return ComObjectInstanceRef(
      refId: element.getAttribute('RefId'),
      text: element.getAttribute('Text'),
      links: element.getAttribute('Links'),
      channelId: element.getAttribute('ChannelId'),
    );
  }

  factory ComObjectInstanceRef.fromJson(Map<String, dynamic> json) {
    return ComObjectInstanceRef(
      refId: json['refId'] as String?,
      text: json['text'] as String?,
      links: json['links'] as String?,
      channelId: json['channelId'] as String?,
      name: json['name'] as String?,
      description: json['description'] as String?,
      number: json['number'] as int?,
      functionText: json['functionText'] as String?,
      objectSize: json['objectSize'] as String?,
      datapointType: json['datapointType'] as String?,
      datapointText: json['datapointText'] as String?,
      priority: json['priority'] as String?,
      communicationFlag: json['communicationFlag'] as bool?,
      readFlag: json['readFlag'] as bool?,
      writeFlag: json['writeFlag'] as bool?,
      transmitFlag: json['transmitFlag'] as bool?,
      updateFlag: json['updateFlag'] as bool?,
      channelName: json['channelName'] as String?,
      groupAddresses:
          (json['groupAddresses'] as List<dynamic>?)?.cast<String>() ??
              const [],
      linkedGroupAddresses: (json['linkedGroupAddresses'] as List<dynamic>?)
              ?.map((e) =>
                  KnxGroupAddressLink.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (refId != null) 'refId': refId,
      if (text != null && text!.isNotEmpty) 'text': text,
      if (channelId != null) 'channelId': channelId,
      if (name != null && name!.isNotEmpty) 'name': name,
      if (description != null && description!.isNotEmpty)
        'description': description,
      if (number != null) 'number': number,
      if (functionText != null && functionText!.isNotEmpty)
        'functionText': functionText,
      if (objectSize != null && objectSize!.isNotEmpty)
        'objectSize': objectSize,
      if (datapointType != null && datapointType!.isNotEmpty)
        'datapointType': datapointType,
      if (datapointText != null && datapointText!.isNotEmpty)
        'datapointText': datapointText,
      if (priority != null && priority!.isNotEmpty) 'priority': priority,
      if (communicationFlag != null) 'communicationFlag': communicationFlag,
      if (readFlag != null) 'readFlag': readFlag,
      if (writeFlag != null) 'writeFlag': writeFlag,
      if (transmitFlag != null) 'transmitFlag': transmitFlag,
      if (updateFlag != null) 'updateFlag': updateFlag,
      if (channelName != null && channelName!.isNotEmpty)
        'channelName': channelName,
      if (groupAddresses.isNotEmpty) 'groupAddresses': groupAddresses,
      if (linkedGroupAddresses.isNotEmpty)
        'linkedGroupAddresses':
            linkedGroupAddresses.map((e) => e.toJson()).toList(),
      if (links != null) 'links': links,
    };
  }

  /// Create an enriched copy with ComObject definition data
  ComObjectInstanceRef copyWithDefinition({
    String? name,
    String? description,
    int? number,
    String? functionText,
    String? objectSize,
    String? datapointType,
    String? datapointText,
    String? priority,
    bool? communicationFlag,
    bool? readFlag,
    bool? writeFlag,
    bool? transmitFlag,
    bool? updateFlag,
    String? channelName,
    List<String>? groupAddresses,
    List<KnxGroupAddressLink>? linkedGroupAddresses,
  }) {
    return ComObjectInstanceRef(
      refId: refId,
      text: text,
      links: links,
      channelId: channelId,
      name: name ?? this.name,
      description: description ?? this.description,
      number: number ?? this.number,
      functionText: functionText ?? this.functionText,
      objectSize: objectSize ?? this.objectSize,
      datapointType: datapointType ?? this.datapointType,
      datapointText: datapointText ?? this.datapointText,
      priority: priority ?? this.priority,
      communicationFlag: communicationFlag ?? this.communicationFlag,
      readFlag: readFlag ?? this.readFlag,
      writeFlag: writeFlag ?? this.writeFlag,
      transmitFlag: transmitFlag ?? this.transmitFlag,
      updateFlag: updateFlag ?? this.updateFlag,
      channelName: channelName ?? this.channelName,
      groupAddresses: groupAddresses ?? this.groupAddresses,
      linkedGroupAddresses: linkedGroupAddresses ?? this.linkedGroupAddresses,
    );
  }
}
