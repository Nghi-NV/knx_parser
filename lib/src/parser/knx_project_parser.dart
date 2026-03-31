import 'dart:io' if (dart.library.html) 'io_stub.dart' as io;
import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import 'package:pointycastle/export.dart';
import '../models/knx_project.dart';
import '../models/knx_flat_project.dart';
import '../models/project_info.dart';
import '../models/installation.dart';
import '../models/device_instance.dart';
import '../models/topology.dart';
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
    // Product catalog: productRefId -> product name (Text attribute)
    final Map<String, Map<String, String>> productCatalog = {};
    final Map<String, Map<String, String>> hw2ProgCatalog = {};
    final Map<String, Map<String, String>> appCatalog = {};
    final Map<String, String> channelCatalog = {};
    final Map<String, String> mfgCatalog = {};
    final Map<String, String> dpstCatalog = {};
    // ComObject definitions: suffixId -> ComObject attributes
    final Map<String, Map<String, String>> comObjectDefs = {};
    // ComObjectRef mapping: comObjectRefSuffix -> comObjectSuffix
    final Map<String, Map<String, String>> comObjectRefMap = {};

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

      // Parse M-*/Hardware.xml and M-*/M-*_A-*.xml from outer archive
      for (final f in archive) {
        if (!f.isFile) continue;
        if (f.name.contains('/Hardware.xml')) {
          try {
            final raw = f.content as List<int>;
            final hwContent = _decodeUtf8WithBom(raw);
            final products = _parseProductCatalog(hwContent);
            productCatalog.addAll(products);
            final h2ps = _parseHardware2ProgramCatalog(hwContent);
            hw2ProgCatalog.addAll(h2ps);
          } catch (_) {}
        } else if (f.name.contains('/M-') &&
            f.name.endsWith('.xml') &&
            !f.name.contains('Hardware') &&
            !f.name.contains('Catalog') &&
            !f.name.contains('Baggages')) {
          // Application program XML (M-*/M-*_A-*.xml)
          try {
            final raw = f.content as List<int>;
            final appContent = _decodeUtf8WithBom(raw);
            _parseComObjectDefinitions(
                appContent, comObjectDefs, comObjectRefMap);
            final apps = _parseApplicationProgramCatalog(appContent);
            appCatalog.addAll(apps);
            final channels = _parseChannelCatalog(appContent);
            channelCatalog.addAll(channels);
          } catch (_) {}
        }
      }

      // Merge product names into devices
      if (productCatalog.isNotEmpty) {
        installations = _mergeProductDataIntoInstallations(
          installations,
          productCatalog,
          hw2ProgCatalog,
          appCatalog,
          mfgCatalog,
        );
      }

      // Enrich ComObjectInstanceRefs with definitions and resolve GA links
      if (comObjectDefs.isNotEmpty || comObjectRefMap.isNotEmpty) {
        installations = _enrichComObjectsInInstallations(
          installations,
          comObjectDefs,
          comObjectRefMap,
          dpstCatalog,
          channelCatalog,
        );
      }

      // knx_master.xml is usually at the outer archive level (not inside P-*.zip)
      if (datapointTypes.isEmpty) {
        for (final f in archive) {
          if (f.isFile && f.name == 'knx_master.xml') {
            final raw = f.content as List<int>;
            final content = _decodeUtf8WithBom(raw);
            datapointTypes = _parseDatapointTypes(content);
            mfgCatalog.addAll(_parseManufacturers(content));
            for (final dt in datapointTypes) {
              for (final st in dt.subtypes) {
                dpstCatalog[st.id] = st.text;
              }
            }
            break;
          }
        }
      }

      if (projectInfo == null) {
        throw FormatException(
            'Invalid or encrypted .knxproj file: project.xml not found.\n'
            'If the project is encrypted, please provide the correct password.');
      }
    } catch (e) {
      if (e is FormatException) {
        throw Exception(
            'Failed to decode project files. Incorrect password? Original error: $e');
      }
      rethrow;
    }

    // Add ETS version info to project
    final etsVersion = isEts6 ? 'ETS6' : 'ETS5';
    final updatedProjectInfo = projectInfo.copyWith(
      etsVersion: etsVersion,
      schemaVersion: schemaVersion,
    );

    return KnxProject(
      projectInfo: updatedProjectInfo,
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

  /// Parse manufacturers from knx_master.xml
  Map<String, String> _parseManufacturers(String xmlContent) {
    String content = xmlContent;
    if (content.codeUnitAt(0) == 0xFEFF) {
      content = content.substring(1);
    }
    final document = XmlDocument.parse(content);
    final masterDataElements = document.findAllElements('MasterData');
    if (masterDataElements.isEmpty) return {};

    final manufacturersElement =
        masterDataElements.first.getElement('Manufacturers');
    if (manufacturersElement == null) return {};

    final manufacturers = <String, String>{};
    for (final element in manufacturersElement.findElements('Manufacturer')) {
      final id = element.getAttribute('Id');
      final name = element.getAttribute('Name');
      if (id != null && name != null) {
        manufacturers[id] = name;
      }
    }
    return manufacturers;
  }

  /// Parse hardware to program catalog from Hardware.xml.
  /// Returns a map of Hardware2ProgramRefId -> Map of attributes (mediumType).
  Map<String, Map<String, String>> _parseHardware2ProgramCatalog(
      String xmlContent) {
    final result = <String, Map<String, String>>{};
    try {
      final document = XmlDocument.parse(xmlContent);
      for (final hp in document.findAllElements('Hardware2Program')) {
        final id = hp.getAttribute('Id');
        final mediumTypes = hp.getAttribute('MediumTypes'); // e.g. "MT-0"
        if (id != null && mediumTypes != null) {
          String medium = mediumTypes;
          if (mediumTypes.contains('MT-0'))
            medium = 'TP';
          else if (mediumTypes.contains('MT-1'))
            medium = 'PL';
          else if (mediumTypes.contains('MT-2'))
            medium = 'RF';
          else if (mediumTypes.contains('MT-5')) medium = 'IP';
          result[id] = {'mediumType': medium};
        }
      }
    } catch (_) {}
    return result;
  }

  /// Parse application programs from M-*-*.xml.
  /// Returns a map of ApplicationProgramId -> Map of attributes (name, version).
  Map<String, Map<String, String>> _parseApplicationProgramCatalog(
      String xmlContent) {
    final result = <String, Map<String, String>>{};
    try {
      final document = XmlDocument.parse(xmlContent);
      for (final app in document.findAllElements('ApplicationProgram')) {
        final id = app.getAttribute('Id');
        final name = app.getAttribute('Name');
        final version = app.getAttribute('ApplicationVersion');
        if (id != null) {
          result[id] = {
            if (name != null) 'name': name,
            if (version != null) 'version': '0.$version',
          };
        }
      }
    } catch (_) {}
    return result;
  }

  /// Parse channels from M-*-*.xml.
  /// Returns a map of ChannelId -> ChannelName.
  Map<String, String> _parseChannelCatalog(String xmlContent) {
    final result = <String, String>{};
    try {
      final document = XmlDocument.parse(xmlContent);
      for (final ch in document.findAllElements('Channel')) {
        final id = ch.getAttribute('Id');
        final name = ch.getAttribute('Name') ?? ch.getAttribute('Text');
        if (id != null && name != null) {
          result[id] = name;
        }
      }
    } catch (_) {}
    return result;
  }

  /// Parse product catalog from Hardware.xml.
  /// Returns a map of ProductRefId -> Map of attributes (name, orderNumber).
  Map<String, Map<String, String>> _parseProductCatalog(String xmlContent) {
    final result = <String, Map<String, String>>{};
    try {
      final document = XmlDocument.parse(xmlContent);
      for (final product in document.findAllElements('Product')) {
        final id = product.getAttribute('Id');
        final text = product.getAttribute('Text');
        final orderNumber = product.getAttribute('OrderNumber');
        if (id != null) {
          result[id] = {
            if (text != null && text.isNotEmpty) 'name': text,
            if (orderNumber != null && orderNumber.isNotEmpty)
              'orderNumber': orderNumber,
          };
        }
      }
    } catch (_) {}
    return result;
  }

  Exception _secureProjectHint(String msg) {
    return Exception('$msg\nSee also: docs/RESEARCH_KNXPROJ_SECURE.md');
  }

  /// Merge hardware/product data into installations' devices
  List<Installation> _mergeProductDataIntoInstallations(
    List<Installation> installations,
    Map<String, Map<String, String>> productCatalog,
    Map<String, Map<String, String>> hw2ProgCatalog,
    Map<String, Map<String, String>> appCatalog,
    Map<String, String> mfgCatalog,
  ) {
    return installations.map((installation) {
      return installation.copyWithEnrichmentCatalogs(
        productCatalog,
        hw2ProgCatalog,
        appCatalog,
        mfgCatalog,
      );
    }).toList();
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

  /// Parse and export to JSON string (original nested format)
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

  /// Parse and save to JSON file (original nested format)
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

  /// Parse and return flat model (organized sections)
  Future<KnxFlatProject> parseToFlat(
    String filePath, {
    String? password,
    KnxKeys? knxKeys,
  }) async {
    final project = await parse(filePath, password: password, knxKeys: knxKeys);
    return project.toFlat();
  }

  /// Parse and export to flat JSON string (organized sections)
  Future<String> parseToFlatJson(
    String filePath, {
    bool pretty = true,
    String? password,
    KnxKeys? knxKeys,
  }) async {
    final flat =
        await parseToFlat(filePath, password: password, knxKeys: knxKeys);
    final encoder =
        pretty ? const JsonEncoder.withIndent('  ') : const JsonEncoder();
    return encoder.convert(flat.toJson());
  }

  /// Parse and save to flat JSON file (organized sections)
  Future<io.File> parseToFlatJsonFile(
    String knxprojPath,
    String outputPath, {
    String? password,
    KnxKeys? knxKeys,
  }) async {
    final jsonContent = await parseToFlatJson(
      knxprojPath,
      pretty: true,
      password: password,
      knxKeys: knxKeys,
    );
    final outputFile = io.File(outputPath);
    await outputFile.writeAsString(jsonContent);
    return outputFile;
  }

  /// Parse ComObject definitions and ComObjectRef mappings from application program XML.
  /// Populates [comObjectDefs] with suffix -> attributes map.
  /// Populates [comObjectRefMap] with refSuffix -> attributes map (including overrides).
  void _parseComObjectDefinitions(
    String xmlContent,
    Map<String, Map<String, String>> comObjectDefs,
    Map<String, Map<String, String>> comObjectRefMap,
  ) {
    try {
      final document = XmlDocument.parse(xmlContent);

      // Parse ComObject elements (definitions)
      for (final co in document.findAllElements('ComObject')) {
        final id = co.getAttribute('Id');
        if (id == null) continue;
        final attrs = <String, String>{};
        for (final attr in co.attributes) {
          attrs[attr.name.local] = attr.value;
        }
        comObjectDefs[id] = attrs;
      }

      // Parse ComObjectRef elements (may override some attributes)
      for (final coRef in document.findAllElements('ComObjectRef')) {
        final id = coRef.getAttribute('Id');
        final refId = coRef.getAttribute('RefId');
        if (id == null) continue;
        final attrs = <String, String>{};
        for (final attr in coRef.attributes) {
          attrs[attr.name.local] = attr.value;
        }
        // Store the ComObject RefId for lookup
        if (refId != null) attrs['_comObjectId'] = refId;
        comObjectRefMap[id] = attrs;
      }
    } catch (_) {}
  }

  /// Merge ComObjectRef overrides into base ComObject attrs.
  /// If a ref value contains ETS template placeholders ({{...}}),
  /// keep the base value instead (which is typically cleaner).
  Map<String, String> _mergeComObjectAttrs(
    Map<String, String> baseAttrs,
    Map<String, String> refAttrs,
  ) {
    final merged = {...baseAttrs};
    for (final entry in refAttrs.entries) {
      final value = entry.value;
      // Skip template placeholders — base value is cleaner
      if (value.contains('{{')) continue;
      merged[entry.key] = value;
    }
    return merged;
  }

  /// Look up ComObject definition for a given ComObjectInstanceRef.RefId
  /// Uses suffix matching: project XML uses short IDs, app program uses full prefixed IDs.
  Map<String, String>? _lookupComObjectDef(
    String instanceRefId,
    String appProgramPrefix,
    Map<String, Map<String, String>> comObjectDefs,
    Map<String, Map<String, String>> comObjectRefMap,
  ) {
    // Try direct match with full prefix: prefix + '_' + instanceRefId
    final fullRefId = '${appProgramPrefix}_$instanceRefId';

    // First try ComObjectRef (may have overridden attributes)
    final refAttrs = comObjectRefMap[fullRefId];
    if (refAttrs != null) {
      // Get base ComObject definition and merge
      final comObjectId = refAttrs['_comObjectId'];
      final baseAttrs = comObjectId != null ? comObjectDefs[comObjectId] : null;
      if (baseAttrs != null) {
        return _mergeComObjectAttrs(baseAttrs, refAttrs);
      }
      return refAttrs;
    }

    // Try suffix match in comObjectRefMap
    for (final entry in comObjectRefMap.entries) {
      if (entry.key.endsWith('_$instanceRefId')) {
        final comObjectId = entry.value['_comObjectId'];
        final baseAttrs =
            comObjectId != null ? comObjectDefs[comObjectId] : null;
        if (baseAttrs != null) {
          return _mergeComObjectAttrs(baseAttrs, entry.value);
        }
        return entry.value;
      }
    }

    // Try suffix match directly in comObjectDefs
    for (final entry in comObjectDefs.entries) {
      if (entry.key.endsWith('_$instanceRefId')) {
        return entry.value;
      }
    }

    return null;
  }

  bool _flagValue(String? value) {
    if (value == null) return false;
    return value == 'Enabled' || value == '1' || value == 'true';
  }

  /// Resolve GA links ("GA-1 GA-2") to formatted addresses using installation's GA list.
  List<String> _resolveGaLinks(
    String? links,
    List<Installation> installations,
  ) {
    if (links == null || links.isEmpty) return [];
    final gaIds = links.split(' ').where((s) => s.isNotEmpty).toList();
    final resolved = <String>[];
    for (final gaId in gaIds) {
      for (final inst in installations) {
        for (final ga in inst.groupAddresses) {
          if (ga.id.endsWith(gaId) || ga.id.endsWith('_$gaId')) {
            resolved.add(ga.formattedAddress);
            break;
          }
        }
      }
    }
    return resolved;
  }

  /// Resolve GA links ("GA-1 GA-2") to KnxGroupAddressLink objects using installation's GA list.
  List<KnxGroupAddressLink> _resolveGaLinksObjects(
    String? links,
    List<Installation> installations,
  ) {
    if (links == null || links.isEmpty) return [];
    final gaIds = links.split(' ').where((s) => s.isNotEmpty).toList();
    final resolved = <KnxGroupAddressLink>[];
    for (final gaId in gaIds) {
      for (final inst in installations) {
        for (final ga in inst.groupAddresses) {
          if (ga.id.endsWith(gaId) || ga.id.endsWith('_$gaId')) {
            resolved.add(KnxGroupAddressLink(
              address: ga.formattedAddress,
              name: ga.name,
            ));
            break;
          }
        }
      }
    }
    return resolved;
  }

  /// Enrich all ComObjectInstanceRefs in installations with definition data.
  List<Installation> _enrichComObjectsInInstallations(
    List<Installation> installations,
    Map<String, Map<String, String>> comObjectDefs,
    Map<String, Map<String, String>> comObjectRefMap,
    Map<String, String> dpstCatalog,
    Map<String, String> channelCatalog,
  ) {
    return installations.map((inst) {
      final updatedTopology = Topology(
        areas: inst.topology.areas.map((area) {
          return Area(
            id: area.id,
            address: area.address,
            puid: area.puid,
            name: area.name,
            lines: area.lines.map((line) {
              return Line(
                id: line.id,
                address: line.address,
                puid: line.puid,
                name: line.name,
                segments: line.segments.map((seg) {
                  return Segment(
                    id: seg.id,
                    number: seg.number,
                    mediumTypeRefId: seg.mediumTypeRefId,
                    puid: seg.puid,
                    devices: seg.devices.map((d) {
                      return _enrichDeviceComObjects(
                          d,
                          comObjectDefs,
                          comObjectRefMap,
                          installations,
                          dpstCatalog,
                          channelCatalog);
                    }).toList(),
                  );
                }).toList(),
                devices: line.devices.map((d) {
                  return _enrichDeviceComObjects(
                      d,
                      comObjectDefs,
                      comObjectRefMap,
                      installations,
                      dpstCatalog,
                      channelCatalog);
                }).toList(),
              );
            }).toList(),
          );
        }).toList(),
      );
      return Installation(
        name: inst.name,
        bcuKey: inst.bcuKey,
        defaultLine: inst.defaultLine,
        topology: updatedTopology,
        groupAddresses: inst.groupAddresses,
        groupRanges: inst.groupRanges,
        locations: inst.locations,
      );
    }).toList();
  }

  /// Enrich a single DeviceInstance's ComObjects
  DeviceInstance _enrichDeviceComObjects(
    DeviceInstance device,
    Map<String, Map<String, String>> comObjectDefs,
    Map<String, Map<String, String>> comObjectRefMap,
    List<Installation> installations,
    Map<String, String> dpstCatalog,
    Map<String, String> channelCatalog,
  ) {
    // Determine app program prefix from hardware2ProgramRefId
    // e.g. "M-0085_H-RL.2D4CH.2D2025-1_HP-07E9-01-1D78" -> "M-0085_A-07E9-01-1D78"
    final h2pRefId = device.hardware2ProgramRefId ?? '';
    // Extract manufacturer prefix (e.g. "M-0085")
    final mfgMatch = RegExp(r'^(M-[^_]+)').firstMatch(h2pRefId);
    final mfgPrefix = mfgMatch?.group(1) ?? '';
    // Extract HP suffix and build exact app program prefix
    // HP-07E9-01-1D78 -> A-07E9-01-1D78
    final hpMatch = RegExp(r'HP-(.+)$').firstMatch(h2pRefId);
    final appProgramPrefix =
        hpMatch != null ? '${mfgPrefix}_A-${hpMatch.group(1)}' : null;

    final enrichedComObjects = device.comObjectInstanceRefs.map((co) {
      if (co.refId == null) return co;

      // Try to find definition
      Map<String, String>? def;

      // For module ComObjects, strip module instance part:
      // e.g. "MD-1_M-1_MI-1_O-2-1_R-1" -> "MD-1_O-2-1_R-1"
      final refId = co.refId!;
      final strippedRefId = refId.replaceAll(RegExp(r'_M-\d+_MI-\d+'), '');

      // Try exact app program prefix first (derived from HP suffix)
      if (appProgramPrefix != null) {
        def = _lookupComObjectDef(
            refId, appProgramPrefix, comObjectDefs, comObjectRefMap);
        if (def == null && strippedRefId != refId) {
          def = _lookupComObjectDef(
              strippedRefId, appProgramPrefix, comObjectDefs, comObjectRefMap);
        }
      }

      // Fallback: try all app programs with same manufacturer prefix
      if (def == null) {
        for (final key in comObjectDefs.keys) {
          if (key.startsWith(mfgPrefix)) {
            final appMatch = RegExp(r'^(M-[^_]+_A-[^_]+)').firstMatch(key);
            if (appMatch != null) {
              final prefix = appMatch.group(1)!;
              def = _lookupComObjectDef(
                  refId, prefix, comObjectDefs, comObjectRefMap);
              if (def == null && strippedRefId != refId) {
                def = _lookupComObjectDef(
                    strippedRefId, prefix, comObjectDefs, comObjectRefMap);
              }
              if (def != null) break;
            }
          }
        }
      }

      // Fallback: try suffix match across all defs (original + stripped)
      if (def == null) {
        for (final suffix in [
          refId,
          if (strippedRefId != refId) strippedRefId
        ]) {
          for (final entry in comObjectRefMap.entries) {
            if (entry.key.endsWith('_$suffix')) {
              final comObjId = entry.value['_comObjectId'];
              final baseDef = comObjId != null ? comObjectDefs[comObjId] : null;
              def = baseDef != null
                  ? _mergeComObjectAttrs(baseDef, entry.value)
                  : entry.value;
              break;
            }
          }
          if (def != null) break;
        }
      }

      final resolvedGAs = _resolveGaLinks(co.links, installations);
      final resolvedGAsLinks = _resolveGaLinksObjects(co.links, installations);

      if (def == null && resolvedGAs.isEmpty) return co;

      String? dptText;
      if (def != null && def['DatapointType'] != null) {
        dptText = dpstCatalog[def['DatapointType']];
      }

      String? chName;
      if (co.channelId != null) {
        chName = channelCatalog[co.channelId];
      }

      return co.copyWithDefinition(
        name: def?['Name'],
        description: def?['Text'],
        number: int.tryParse(def?['Number'] ?? ''),
        functionText: def?['FunctionText'],
        objectSize: def?['ObjectSize'],
        datapointType: def?['DatapointType'],
        datapointText: dptText,
        priority: def?['Priority'],
        communicationFlag:
            def != null ? _flagValue(def['CommunicationFlag']) : null,
        readFlag: def != null ? _flagValue(def['ReadFlag']) : null,
        writeFlag: def != null ? _flagValue(def['WriteFlag']) : null,
        transmitFlag: def != null ? _flagValue(def['TransmitFlag']) : null,
        updateFlag: def != null ? _flagValue(def['UpdateFlag']) : null,
        channelName: chName,
        groupAddresses: resolvedGAs.isNotEmpty ? resolvedGAs : null,
        linkedGroupAddresses:
            resolvedGAsLinks.isNotEmpty ? resolvedGAsLinks : null,
      );
    }).toList();

    return DeviceInstance(
      id: device.id,
      address: device.address,
      name: device.name,
      description: device.description,
      comment: device.comment,
      productName: device.productName,
      productRefId: device.productRefId,
      hardware2ProgramRefId: device.hardware2ProgramRefId,
      puid: device.puid,
      comObjectInstanceRefs: enrichedComObjects,
      securityToolKey: device.securityToolKey,
    );
  }
}
