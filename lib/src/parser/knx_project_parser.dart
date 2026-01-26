import 'dart:io';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import '../models/knx_project.dart';
import '../models/project_info.dart';
import '../models/installation.dart';
import '../models/datapoint_type.dart';

/// Parser for KNX project files (.knxproj)
class KnxProjectParser {
  /// Parse a .knxproj file and return a KnxProject
  Future<KnxProject> parse(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw ArgumentError('File not found: $filePath');
    }

    final bytes = await file.readAsBytes();
    return parseBytes(bytes);
  }

  /// Parse from bytes (useful for web/memory usage)
  KnxProject parseBytes(List<int> bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);

    ProjectInfo? projectInfo;
    List<Installation> installations = [];
    List<DatapointType> datapointTypes = [];
    String? projectId;

    // First pass: find project ID
    for (final file in archive) {
      if (file.isFile && file.name.endsWith('/project.xml')) {
        projectId = file.name.split('/').first;
        break;
      }
    }

    // Parse each file in the archive
    for (final file in archive) {
      if (!file.isFile) continue;

      final content = utf8.decode(file.content as List<int>);

      if (file.name.endsWith('project.xml')) {
        projectInfo = _parseProjectXml(content);
      } else if (file.name == '$projectId/0.xml' ||
          (projectId == null && file.name.endsWith('/0.xml'))) {
        installations = _parseInstallationXml(content);
      } else if (file.name == 'knx_master.xml') {
        // Optional: parse datapoint types
        // This file is large, so we parse it only if needed
        datapointTypes = _parseDatapointTypes(content);
      }
    }

    if (projectInfo == null) {
      throw FormatException('Invalid .knxproj file: project.xml not found');
    }

    return KnxProject(
      projectInfo: projectInfo,
      installations: installations,
      datapointTypes: datapointTypes,
    );
  }

  /// Parse project.xml
  ProjectInfo _parseProjectXml(String xmlContent) {
    final document = XmlDocument.parse(xmlContent);
    final projectElement = document.findAllElements('Project').first;
    return ProjectInfo.fromXml(projectElement);
  }

  /// Parse installation XML (0.xml, 1.xml, etc.)
  List<Installation> _parseInstallationXml(String xmlContent) {
    final document = XmlDocument.parse(xmlContent);
    final installationsElement =
        document.findAllElements('Installations').firstOrNull;

    if (installationsElement == null) {
      return [];
    }

    return installationsElement
        .findElements('Installation')
        .map((e) => Installation.fromXml(e))
        .toList();
  }

  /// Parse datapoint types from knx_master.xml
  List<DatapointType> _parseDatapointTypes(String xmlContent) {
    final document = XmlDocument.parse(xmlContent);
    final masterData = document.findAllElements('MasterData').firstOrNull;

    if (masterData == null) {
      return [];
    }

    final dpTypes = masterData.findAllElements('DatapointTypes').firstOrNull;
    if (dpTypes == null) {
      return [];
    }

    return dpTypes
        .findElements('DatapointType')
        .map((e) => DatapointType.fromXml(e))
        .toList();
  }

  /// Parse and export to JSON string
  Future<String> parseToJson(String filePath, {bool pretty = true}) async {
    final project = await parse(filePath);
    final encoder =
        pretty ? const JsonEncoder.withIndent('  ') : const JsonEncoder();
    return encoder.convert(project.toJson());
  }

  /// Parse and save to JSON file
  Future<File> parseToJsonFile(String knxprojPath, String outputPath) async {
    final jsonContent = await parseToJson(knxprojPath, pretty: true);
    final outputFile = File(outputPath);
    await outputFile.writeAsString(jsonContent);
    return outputFile;
  }
}
