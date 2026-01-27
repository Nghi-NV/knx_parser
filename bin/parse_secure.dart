import 'package:knx_parser/knx_parser.dart';

void main() async {
  final parser = KnxProjectParser();

  final inputPath = '../testing/Secure_prj.knxproj';
  final outputPath = '../testing/Secure_prj.json';
  final password = '1';

  print('Parsing $inputPath with password...');

  try {
    final outputFile = await parser.parseToJsonFile(
      inputPath,
      outputPath,
      password: password,
    );
    print('✅ Successfully parsed to: ${outputFile.path}');
  } catch (e) {
    print('❌ Error: $e');
  }
}
