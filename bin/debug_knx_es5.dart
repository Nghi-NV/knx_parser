import 'dart:io';

import 'package:knx_parser/knx_parser.dart';

Future<void> main() async {
  final parser = KnxProjectParser();

  const inputPath = '../testing/knxprj_example(1).knxproj';
  const password = '1';

  stdout
      .writeln('Parsing ETS5 project $inputPath with password="$password"...');

  try {
    final project = await parser.parse(inputPath, password: password);
    stdout.writeln('✅ Parsed project: ${project.projectInfo.name}');
    stdout.writeln('  Installations: ${project.installations.length}');

    for (var i = 0; i < project.installations.length; i++) {
      final inst = project.installations[i];
      stdout.writeln(
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

      stdout.writeln('  Areas: $areaCount');
      stdout.writeln('  Lines: $lineCount');
      stdout.writeln('  Devices: $deviceCount');
    }

    // Export JSON để tiện debug
    const jsonOut = '../testing/knxprj_example(1).json';
    final jsonFile = await parser.parseToJsonFile(
      inputPath,
      jsonOut,
      password: password,
    );
    stdout.writeln('\nJSON exported to: ${jsonFile.path}');
  } catch (e, st) {
    stderr.writeln('❌ Error parsing ETS5 project: $e');
    stderr.writeln(st);
  }
}
