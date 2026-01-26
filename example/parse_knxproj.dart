import 'dart:io';
import 'package:knx_parser/knx_parser.dart';

void main(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: dart run example/parse_knxproj.dart <path_to_knxproj>');
    print('');
    print('Example:');
    print('  dart run example/parse_knxproj.dart ../ets6_free.knxproj');
    exit(1);
  }

  final filePath = args[0];
  final file = File(filePath);

  if (!await file.exists()) {
    print('Error: File not found: $filePath');
    exit(1);
  }

  print('Parsing KNX project: $filePath');
  print('=' * 50);

  try {
    final parser = KnxProjectParser();
    final project = await parser.parse(filePath);

    // Print project info
    print('\n📂 Project Info:');
    print('  Name: ${project.projectInfo.name}');
    print('  ID: ${project.projectInfo.id}');
    print('  Style: ${project.projectInfo.groupAddressStyle}');
    print('  GUID: ${project.projectInfo.guid}');
    if (project.projectInfo.lastModified != null) {
      print('  Last Modified: ${project.projectInfo.lastModified}');
    }

    // Print installations
    for (final installation in project.installations) {
      print(
          '\n🏠 Installation: ${installation.name.isEmpty ? "(unnamed)" : installation.name}');

      // Topology
      print('\n  📡 Topology:');
      for (final area in installation.topology.areas) {
        print(
            '    Area ${area.address}${area.name != null ? " (${area.name})" : ""}');
        for (final line in area.lines) {
          print('      Line ${area.address}.${line.address}');
        }
      }

      // Group Addresses
      print(
          '\n  🏷️  Group Addresses (${installation.groupAddresses.length}):');
      for (final ga in installation.groupAddresses.take(10)) {
        print('    ${ga.formattedAddress} - "${ga.name}"');
      }
      if (installation.groupAddresses.length > 10) {
        print('    ... and ${installation.groupAddresses.length - 10} more');
      }

      // Locations
      print('\n  📍 Locations (${installation.locations.length}):');
      for (final loc in installation.locations) {
        print('    ${loc.type}: "${loc.name}"');
      }
    }

    // Datapoint Types (summary only)
    print(
        '\n📊 Datapoint Types: ${project.datapointTypes.length} types loaded');

    // Optional: Export to JSON
    final outputPath = filePath.replaceAll('.knxproj', '.json');
    print('\n💾 Exporting to JSON: $outputPath');
    await parser.parseToJsonFile(filePath, outputPath);
    print('✅ Done!');
  } catch (e, stack) {
    print('Error parsing file: $e');
    print(stack);
    exit(1);
  }
}
