import 'dart:io';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import '../models/knx_project.dart';
import '../models/project_info.dart';
import '../models/installation.dart';
import '../models/datapoint_type.dart';
import '../models/knx_keys.dart';

/// Parser for KNX project files (.knxproj)
class KnxProjectParser {
  /// Parse a .knxkeys file
  KnxKeys parseKeys(String xmlContent) {
    final document = XmlDocument.parse(xmlContent);
    final keyringElement = document.findAllElements('Keyring').first;
    return KnxKeys.fromXml(keyringElement);
  }

  /// Parse a .knxproj file and return a KnxProject
  /// [password] is optional for encrypted archives
  Future<KnxProject> parse(
    String filePath, {
    String? password,
    KnxKeys? knxKeys,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw ArgumentError('File not found: $filePath');
    }

    final bytes = await file.readAsBytes();
    return parseBytes(bytes, password: password, knxKeys: knxKeys);
  }

  /// Parse from bytes (useful for web/memory usage)
  KnxProject parseBytes(
    List<int> bytes, {
    String? password,
    KnxKeys? knxKeys,
  }) {
    final archive = _decodeArchive(bytes, password: password);

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
    try {
      for (final file in archive) {
        if (!file.isFile) continue;

        final content = utf8.decode(file.content as List<int>);

        if (file.name.endsWith('project.xml')) {
          projectInfo = _parseProjectXml(content);
        } else if (file.name == '$projectId/0.xml' ||
            (projectId == null && file.name.endsWith('/0.xml'))) {
          installations = _parseInstallationXml(content);
          // Optional: parse datapoint types
          // This file is large, so we parse it only if needed
          datapointTypes = _parseDatapointTypes(content);
        }
      }
    } catch (e) {
      if (e is FormatException) {
        throw Exception(
            'Failed to decode project files. Incorrect password? Original error: $e');
      }
      rethrow;
    }

    if (projectInfo == null) {
      throw FormatException(
          'Invalid or encrypted .knxproj file: project.xml not found.\n'
          'If the project is encrypted, please provide the correct password.');
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
    final installationElements = document.findAllElements('Installations');

    if (installationElements.isEmpty) {
      return [];
    }

    final installationsElement = installationElements.first;

    return installationsElement
        .findElements('Installation')
        .map((e) => Installation.fromXml(e))
        .toList();
  }

  /// Parse datapoint types from knx_master.xml
  List<DatapointType> _parseDatapointTypes(String xmlContent) {
    final document = XmlDocument.parse(xmlContent);
    final masterDataElements = document.findAllElements('MasterData');

    if (masterDataElements.isEmpty) {
      return [];
    }

    final masterData = masterDataElements.first;
    final dpTypesElements = masterData.findAllElements('DatapointTypes');

    if (dpTypesElements.isEmpty) {
      return [];
    }

    final dpTypes = dpTypesElements.first;

    return dpTypes
        .findElements('DatapointType')
        .map((e) => DatapointType.fromXml(e))
        .toList();
  }

  Archive _decodeArchive(List<int> bytes, {String? password}) {
    try {
      return ZipDecoder().decodeBytes(bytes, password: password);
    } catch (e) {
      if (e.toString().contains('Mac verification failed') ||
          e is FormatException) {
        // ZipDecoder might throw FormatException on bad password
        throw Exception(
            'Failed to decrypt archive. Incorrect password? Original error: $e');
      }
      rethrow;
    }
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
