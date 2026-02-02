import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:knx_parser/knx_parser.dart';

Future<void> main() async {
  final parser = KnxProjectParser();
  const inputPath =
      '../testing/knx_secure_onoff_dim_curtain_sensor_0202_v2.knxproj';
  const password = '1';

  print('Parsing $inputPath with password="$password"...');

  try {
    final project = await parser.parse(inputPath, password: password);
    print('✅ Parsed project: ${project.projectInfo.name}');
    print('  Installations: ${project.installations.length}');

    for (var i = 0; i < project.installations.length; i++) {
      final inst = project.installations[i];
      print(
          '\nInstallation #$i: ${inst.name.isEmpty ? '(unnamed)' : inst.name}');

      var areaCount = 0;
      var lineCount = 0;
      var deviceCount = 0;

      for (final area in inst.topology.areas) {
        areaCount++;
        for (final line in area.lines) {
          lineCount++;
          deviceCount += line.devices.length;
        }
      }

      print('  Areas: $areaCount');
      print('  Lines: $lineCount');
      print('  Devices: $deviceCount');

      // In case there are devices, print a small sample
      if (deviceCount > 0) {
        print('  Sample devices (first 10):');
        var printed = 0;
        for (final area in inst.topology.areas) {
          for (final line in area.lines) {
            for (final dev in line.devices) {
              print(
                  '    Line ${line.address}: Device addr=${dev.address}, name=${dev.name ?? '(no name)'}');
              printed++;
              if (printed >= 10) break;
            }
            if (printed >= 10) break;
          }
          if (printed >= 10) break;
        }
      }
    }

    // Also export full JSON for manual inspection
    final jsonFilePath =
        '../testing/knx_secure_onoff_dim_curtain_sensor_0202_v2.json';
    final jsonFile = await parser.parseToJsonFile(
      inputPath,
      jsonFilePath,
      password: password,
    );
    print('\nJSON exported to: ${jsonFile.path}');

    // Extra debug: manually decrypt P-*.zip and inspect 0.xml text
    print('\n--- Debug: decrypt P-*.zip and preview 0.xml ---');
    final knxBytes = await File(inputPath).readAsBytes();
    final outerArchive = ZipDecoder().decodeBytes(knxBytes);

    ArchiveFile? projectZipFile;
    for (final f in outerArchive) {
      if (f.isFile && f.name.endsWith('.zip') && f.name.contains('P-')) {
        projectZipFile = f;
        break;
      }
    }

    if (projectZipFile == null) {
      print('No P-*.zip found in outer archive.');
      return;
    }

    print('Found nested archive: ${projectZipFile.name} '
        '(size=${projectZipFile.size} bytes)');

    final nestedBytes = projectZipFile.content as List<int>;
    Archive nestedArchive;
    try {
      nestedArchive = ZipDecoder().decodeBytes(nestedBytes, password: password);
      print('Nested archive decrypted successfully with password "$password".');
    } catch (e) {
      print('Failed to decrypt nested P-zip with password "$password": $e');
      return;
    }

    print('Inner files:');
    for (final f in nestedArchive) {
      print('  - ${f.name} (size=${f.size})');
    }

    ArchiveFile? zeroXmlFile;
    for (final f in nestedArchive) {
      if (f.isFile && f.name.endsWith('0.xml')) {
        zeroXmlFile = f;
        break;
      }
    }

    if (zeroXmlFile == null) {
      print('0.xml not found inside nested archive.');
      return;
    }

    final zeroBytes = zeroXmlFile.content as List<int>;
    var zeroText = utf8.decode(zeroBytes, allowMalformed: true);
    // Strip BOM if present
    if (zeroText.isNotEmpty && zeroText.codeUnitAt(0) == 0xFEFF) {
      zeroText = zeroText.substring(1);
    }

    print('\nFirst 2000 chars of decrypted 0.xml:\n');
    final previewLen = zeroText.length > 2000 ? 2000 : zeroText.length;
    print(zeroText.substring(0, previewLen));

    final deviceCountInXml =
        RegExp(r'<DeviceInstance\\b').allMatches(zeroText).length;
    print('\nDeviceInstance tag count in 0.xml (raw XML): $deviceCountInXml');
  } catch (e, st) {
    print('❌ Error parsing project: $e');
    print(st);
  }
}
