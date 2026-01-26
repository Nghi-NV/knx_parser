import 'package:xml/xml.dart';

/// Represents a Device Instance in the topology
class DeviceInstance {
  final String id;
  final int address;
  final String? name;
  final String? productRefId;
  final String? hardware2ProgramRefId;
  final int? puid;
  final List<ComObjectInstanceRef> comObjectInstanceRefs;
  final String? securityToolKey;

  const DeviceInstance({
    required this.id,
    required this.address,
    this.name,
    this.productRefId,
    this.hardware2ProgramRefId,
    this.puid,
    this.comObjectInstanceRefs = const [],
    this.securityToolKey,
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
      if (productRefId != null) 'productRefId': productRefId,
      if (hardware2ProgramRefId != null)
        'hardware2ProgramRefId': hardware2ProgramRefId,
      if (puid != null) 'puid': puid,
      'comObjectInstanceRefs':
          comObjectInstanceRefs.map((e) => e.toJson()).toList(),
      if (securityToolKey != null) 'securityToolKey': securityToolKey,
    };
  }

  @override
  String toString() => 'DeviceInstance($id, address=$address)';
}

/// Represents a Communication Object Instance Reference
class ComObjectInstanceRef {
  final String? refId;
  final String? text;
  final String? links; // Space-separated list of group address references

  const ComObjectInstanceRef({
    this.refId,
    this.text,
    this.links,
  });

  factory ComObjectInstanceRef.fromXml(XmlElement element) {
    return ComObjectInstanceRef(
      refId: element.getAttribute('RefId'),
      text: element.getAttribute('Text'),
      links: element.getAttribute('Links'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (refId != null) 'refId': refId,
      if (text != null) 'text': text,
      if (links != null) 'links': links,
    };
  }
}
