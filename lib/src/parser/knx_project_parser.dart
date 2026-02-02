import 'dart:io' if (dart.library.html) 'io_stub.dart' as io;
import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import 'package:pointycastle/export.dart';
import '../models/knx_project.dart';
import '../models/project_info.dart';
import '../models/installation.dart';
import '../models/datapoint_type.dart';
import '../models/knx_keys.dart';

/// Parser for KNX project files (.knxproj)
///
/// Supports both ETS5 and ETS6 encrypted projects.
/// ETS6 uses PBKDF2-HMAC-SHA256 for password derivation.
class KnxProjectParser {
  /// ETS6 salt for PBKDF2 key derivation
  static const String _ets6Salt = '21.project.ets.knx.org';

  /// Generate ETS6 ZIP password from user password
  /// Uses PBKDF2-HMAC-SHA256 with specific salt and iterations
  String _generateEts6ZipPassword(String password) {
    // Encode password as UTF-16-LE
    final passwordBytes = _encodeUtf16Le(password);

    // Salt as UTF-8 bytes
    final saltBytes = Uint8List.fromList(utf8.encode(_ets6Salt));

    // PBKDF2 with HMAC-SHA256
    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
    pbkdf2.init(Pbkdf2Parameters(saltBytes, 65536, 32));

    final derivedKey = Uint8List(32);
    pbkdf2.deriveKey(passwordBytes, 0, derivedKey, 0);

    // Return base64 encoded
    return base64.encode(derivedKey);
  }

  /// Encode string as UTF-16 Little Endian
  Uint8List _encodeUtf16Le(String input) {
    final units = input.codeUnits;
    final bytes = Uint8List(units.length * 2);
    for (var i = 0; i < units.length; i++) {
      bytes[i * 2] = units[i] & 0xFF;
      bytes[i * 2 + 1] = (units[i] >> 8) & 0xFF;
    }
    return bytes;
  }

  /// Detect if project is ETS6 based on schema version
  int? _getSchemaVersion(Archive archive) {
    for (final f in archive) {
      if (f.isFile && f.name == 'knx_master.xml') {
        try {
          final raw = f.content as List<int>;
          final content = _decodeUtf8WithBom(raw);
          // Look for xmlns="http://knx.org/xml/project/XX"
          final match = RegExp(r'xmlns="http://knx\.org/xml/project/(\d+)"')
              .firstMatch(content);
          if (match != null) {
            return int.parse(match.group(1)!);
          }
        } catch (_) {}
        break;
      }
    }
    return null;
  }

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
    final file = io.File(filePath);
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

    // Detect schema version for ETS6 password derivation
    final schemaVersion = _getSchemaVersion(archive);
    final isEts6 = schemaVersion != null && schemaVersion >= 21;

    // Nested P-*.zip (ETS5/6): try to decrypt with appropriate password
    Archive? projectArchive;
    for (final f in archive) {
      if (f.isFile && f.name.endsWith('.zip') && f.name.contains('P-')) {
        final zipBytes = f.content as List<int>;

        // Try with password if available
        if (password != null) {
          // ETS6 uses PBKDF2-derived password
          if (isEts6) {
            final ets6Password = _generateEts6ZipPassword(password);
            try {
              projectArchive =
                  ZipDecoder().decodeBytes(zipBytes, password: ets6Password);
            } catch (_) {}
          }

          // ETS5 uses raw password
          if (projectArchive == null) {
            try {
              projectArchive =
                  ZipDecoder().decodeBytes(zipBytes, password: password);
            } catch (_) {}
          }
        }

        // Fallback: try without password (if not provided or failed)
        if (projectArchive == null) {
          try {
            projectArchive = ZipDecoder().decodeBytes(zipBytes);
          } catch (_) {}
        }

        if (projectArchive == null) {
          throw _secureProjectHint(
            'Unable to open nested P-*.zip (possibly AES-encrypted).\n'
            'If the project is protected with a password, please ensure you pass it to parse(..., password: "xxx").\n'
            'Schema version: $schemaVersion (ETS6: $isEts6)',
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
              'Failed to read file content inside P-*.zip (wrong password or unsupported encryption).\n'
              'Please verify the password or try extracting the project with ETS / 7-Zip and use parseFromExtractedDir().',
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
      // knx_master.xml is usually at the outer archive level (not inside P-*.zip)
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
    return Exception('$msg\nSee also: docs/RESEARCH_KNXPROJ_SECURE.md');
  }

  /// Parse from a directory that already contains extracted project files
  /// (e.g. after manually extracting P-*.zip using ETS, 7-Zip, etc.).
  /// Requires at least project.xml and (optionally) 0.xml in [dirPath].
  Future<KnxProject> parseFromExtractedDir(String dirPath) async {
    final d = io.Directory(dirPath);
    if (!await d.exists()) {
      throw ArgumentError('Directory not found: $dirPath');
    }
    io.File? projectXml;
    io.File? zeroXml;
    for (final e in d.listSync()) {
      if (e is io.File) {
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
    // Some ETS5 projects use a plain (non-encrypted) outer .knxproj ZIP, and
    // only the nested P-*.zip is password-protected. Always passing [password]
    // here can cause "Mac verification failed"/FormatException even when the
    // outer ZIP is not encrypted.
    //
    // Strategy:
    // 1. Try to decode WITHOUT a password first.
    // 2. If that fails with a MAC/Format-related error and [password] is
    //    provided, try again WITH the password.
    // 3. If it still fails, throw a clear "Incorrect password?" style error.
    try {
      // Step 1: prefer decoding without password
      return ZipDecoder().decodeBytes(bytes);
    } catch (e) {
      final isMacOrFormatError =
          e.toString().contains('Mac verification failed') ||
              e is FormatException;

      // If we have no password or the error is not MAC/Format-related,
      // rethrow the original error.
      if (!isMacOrFormatError || password == null) {
        rethrow;
      }

      // Step 2: retry with password (ETS6 outer-encrypted or special cases)
      try {
        return ZipDecoder().decodeBytes(bytes, password: password);
      } catch (e2) {
        if (e2.toString().contains('Mac verification failed') ||
            e2 is FormatException) {
          throw Exception(
              'Failed to decrypt archive. Incorrect password? Original error: $e2');
        }
        rethrow;
      }
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
  Future<io.File> parseToJsonFile(
    String knxprojPath,
    String outputPath, {
    String? password,
  }) async {
    final jsonContent =
        await parseToJson(knxprojPath, pretty: true, password: password);
    final outputFile = io.File(outputPath);
    await outputFile.writeAsString(jsonContent);
    return outputFile;
  }
}
