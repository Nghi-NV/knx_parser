import 'package:xml/xml.dart';

/// Project metadata from project.xml
class ProjectInfo {
  final String id;
  final String name;
  final String groupAddressStyle;
  final DateTime? lastModified;
  final DateTime? projectStart;
  final String? comment;
  final String? guid;
  final String? projectType;

  const ProjectInfo({
    required this.id,
    required this.name,
    this.groupAddressStyle = 'Free',
    this.lastModified,
    this.projectStart,
    this.comment,
    this.guid,
    this.projectType,
  });

  /// Parse from XML element
  factory ProjectInfo.fromXml(XmlElement projectElement) {
    final id = projectElement.getAttribute('Id') ?? '';
    final infoElement = projectElement.getElement('ProjectInformation');

    if (infoElement == null) {
      return ProjectInfo(id: id, name: '');
    }

    return ProjectInfo(
      id: id,
      name: infoElement.getAttribute('Name') ?? '',
      groupAddressStyle:
          infoElement.getAttribute('GroupAddressStyle') ?? 'Free',
      lastModified: _parseDateTime(infoElement.getAttribute('LastModified')),
      projectStart: _parseDateTime(infoElement.getAttribute('ProjectStart')),
      comment: infoElement.getAttribute('Comment'),
      guid: infoElement.getAttribute('Guid'),
      projectType: infoElement.getAttribute('ProjectType'),
    );
  }

  static DateTime? _parseDateTime(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'groupAddressStyle': groupAddressStyle,
      if (lastModified != null) 'lastModified': lastModified!.toIso8601String(),
      if (projectStart != null) 'projectStart': projectStart!.toIso8601String(),
      if (comment != null && comment!.isNotEmpty) 'comment': comment,
      if (guid != null) 'guid': guid,
      if (projectType != null) 'projectType': projectType,
    };
  }

  @override
  String toString() => 'ProjectInfo($name)';
}
