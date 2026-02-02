import 'dart:io';
import 'package:knx_parser/knx_parser.dart';

/// Example: ETS6 project with AES-encrypted P-*.zip.
/// The external .knxkeys file is not used to decrypt P-*.zip.
///
/// Workflow:
/// 1. Extract P-*.zip (from inside .knxproj) using ETS or 7-Zip (enter the
///    ETS project password if requested) and save project.xml + 0.xml
///    into a directory.
/// 2. Use parseFromExtractedDir(<directory_path>) on that directory.
void main() async {
  final parser = KnxProjectParser();
  const knxproj = '../knxprj_example.knxproj';
  // Directory that will contain extracted project.xml and 0.xml
  const outputDir = 'output';

  // Step 1: try to parse directly with password
  try {
    final project = await parser.parse(knxproj, password: '1');
    print('OK: ${project.projectInfo.name}');
    print('  Installations: ${project.installations.length}');

    // Export JSON
    final jsonFile = await parser
        .parseToJsonFile(knxproj, '$outputDir/project.json', password: '1');
    print('  Saved JSON to: ${jsonFile.path}');
    // return; // Uncomment if you want to stop when direct parse succeeds
  } catch (e) {
    print('Direct parse failed:');
    print('  ${e.toString().split("\n").first}');
  }

  // Step 2: parse from an already extracted directory
  if (await Directory(outputDir).exists()) {
    try {
      final project = await parser.parseFromExtractedDir(outputDir);
      print('\nOK parseFromExtractedDir: ${project.projectInfo.name}');
      print('  Installations: ${project.installations.length}');
      return;
    } catch (e) {
      print('\nparseFromExtractedDir($outputDir) failed: $e');
    }
  }

  print('\nHow to use this example:');
  print('  1. Open the .knxproj with 7-Zip (or ETS) and locate P-*.zip.');
  print(
      '  2. Extract P-*.zip (enter the ETS password if requested) into a directory.');
  print(
      '  3. Set outputDir to that directory (containing project.xml and 0.xml) and run again.');
  print('  See also: docs/RESEARCH_KNXPROJ_SECURE.md');
}
