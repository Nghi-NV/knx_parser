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

    // Nested P-*.zip (ETS5/6): thử giải nén không mật khẩu. Nếu mã hóa AES (ETS6) thì
    // cần giải nén P-*.zip bằng ETS, 7-Zip hoặc công cụ hỗ trợ WinZip AES, rồi dùng parseFromExtractedDir.
    Archive? projectArchive;
    for (final f in archive) {
      if (f.isFile && f.name.endsWith('.zip') && f.name.contains('P-')) {
        final zipBytes = f.content as List<int>;
        // Try with password first if available
        if (password != null) {
          try {
            projectArchive =
                ZipDecoder().decodeBytes(zipBytes, password: password);
          } catch (_) {}
        }

        // Fallback: try without password (if not provided or failed)
        if (projectArchive == null) {
          try {
            projectArchive = ZipDecoder().decodeBytes(zipBytes);
          } catch (_) {}
        }

        if (projectArchive == null) {
          throw _secureProjectHint(
            'P-*.zip không mở được (có thể đã mã hóa AES). '
            'Nếu có mật khẩu, hãy đảm bảo đã truyền đúng vào hàm parse(..., password: "xxx").\n'
            'Hoặc giải nén thủ công bằng ETS/7-Zip.',
          );
        }
        break;
      }
    }

    final targetArchive = projectArchive ?? archive;

    // First pass: find project ID
    for (final file in targetArchive) {
      if (file.isFile && file.name.endsWith('/project.xml')) {
        projectId = file.name.split('/').first;
        break;
      }
    }

    // Also check for project.xml without prefix
    if (projectId == null) {
      for (final file in targetArchive) {
        if (file.isFile && file.name == 'project.xml') {
          break;
        }
      }
    }

    // Parse each file in the archive
    try {
      for (final file in targetArchive) {
        if (!file.isFile) continue;

        List<int> raw;
        try {
          raw = file.content as List<int>;
        } catch (e) {
          if (projectArchive != null) {
            throw _secureProjectHint(
              'Không thể đọc nội dung file trong P-*.zip (có thể do sai mật khẩu hoặc mã hóa không hỗ trợ). '
              'Thử kiểm tra lại mật khẩu hoặc giải nén thủ công bằng ETS/7-Zip.',
            );
          }
          rethrow;
        }
        final content = _decodeUtf8WithBom(raw);

        if (file.name.endsWith('project.xml')) {
          projectInfo = _parseProjectXml(content);
        } else if (file.name == '$projectId/0.xml' ||
            (projectId == null && file.name.endsWith('/0.xml')) ||
            file.name == '0.xml') {
          installations = _parseInstallationXml(content);
          final from0 = _parseDatapointTypes(content);
          if (from0.isNotEmpty) datapointTypes = from0;
        }
      }
      // knx_master.xml thường ở archive gốc (không nằm trong P-*.zip)
      if (datapointTypes.isEmpty) {
        for (final f in archive) {
          if (f.isFile && f.name == 'knx_master.xml') {
            try {
              final raw = f.content as List<int>;
              datapointTypes = _parseDatapointTypes(_decodeUtf8WithBom(raw));
            } catch (_) {}
            break;
          }
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

  /// Decode UTF-8 content, handling BOM (Byte Order Mark)
  String _decodeUtf8WithBom(List<int> bytes) {
    // UTF-8 BOM is EF BB BF
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      // Skip BOM
      return utf8.decode(bytes.sublist(3));
    }
    return utf8.decode(bytes);
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
    // Some files may have XML declaration with encoding attribute
    // but actually contain UTF-8 BOM, so we need to handle it
    String content = xmlContent;

    // Check for BOM at the start
    if (content.codeUnitAt(0) == 0xFEFF) {
      // Remove BOM
      content = content.substring(1);
    }

    final document = XmlDocument.parse(content);
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

  Exception _secureProjectHint(String msg) {
    return Exception('$msg\nXem thêm: docs/RESEARCH_KNXPROJ_SECURE.md');
  }

  /// Parse từ thư mục đã giải nén (sau khi giải nén P-*.zip bằng ETS, 7-Zip, v.v.).
  /// Cần có project.xml và (tùy chọn) 0.xml trong [dirPath].
  Future<KnxProject> parseFromExtractedDir(String dirPath) async {
    final d = Directory(dirPath);
    if (!await d.exists()) {
      throw ArgumentError('Directory not found: $dirPath');
    }
    File? projectXml;
    File? zeroXml;
    for (final e in d.listSync()) {
      if (e is File) {
        if (e.path.endsWith('project.xml')) projectXml = e;
        if (e.path.endsWith('0.xml')) zeroXml = e;
      }
    }
    if (projectXml == null || !await projectXml.exists()) {
      throw ArgumentError('project.xml not found in $dirPath');
    }
    final projectInfo = _parseProjectXml(await projectXml.readAsString());
    var installations = <Installation>[];
    var datapointTypes = <DatapointType>[];
    if (zeroXml != null && await zeroXml.exists()) {
      final c = await zeroXml.readAsString();
      installations = _parseInstallationXml(c);
      datapointTypes = _parseDatapointTypes(c);
    }
    return KnxProject(
      projectInfo: projectInfo,
      installations: installations,
      datapointTypes: datapointTypes,
    );
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
  Future<String> parseToJson(
    String filePath, {
    bool pretty = true,
    String? password,
  }) async {
    final project = await parse(filePath, password: password);
    final encoder =
        pretty ? const JsonEncoder.withIndent('  ') : const JsonEncoder();
    return encoder.convert(project.toJson());
  }

  /// Parse and save to JSON file
  Future<File> parseToJsonFile(
    String knxprojPath,
    String outputPath, {
    String? password,
  }) async {
    final jsonContent =
        await parseToJson(knxprojPath, pretty: true, password: password);
    final outputFile = File(outputPath);
    await outputFile.writeAsString(jsonContent);
    return outputFile;
  }
}
