import 'project_info.dart';
import 'installation.dart';
import 'datapoint_type.dart';

/// Root model representing a complete KNX project
class KnxProject {
  /// Project metadata
  final ProjectInfo projectInfo;

  /// List of installations in the project
  final List<Installation> installations;

  /// Datapoint type definitions from knx_master.xml
  final List<DatapointType> datapointTypes;

  const KnxProject({
    required this.projectInfo,
    required this.installations,
    this.datapointTypes = const [],
  });

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'project': projectInfo.toJson(),
      'installations': installations.map((i) => i.toJson()).toList(),
      'datapointTypes': datapointTypes.map((d) => d.toJson()).toList(),
    };
  }

  @override
  String toString() => 'KnxProject(${projectInfo.name})';
}
