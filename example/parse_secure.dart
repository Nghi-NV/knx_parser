import 'dart:io';
import 'package:knx_parser/knx_parser.dart';

void main() async {
  final parser = KnxProjectParser();

  // 1. Parse Keys
  print('Parsing keys...');
  final keysFile = await File('../test_Open_KNX_Stack.knxkeys').readAsString();
  final keys = parser.parseKeys(keysFile);
  print('Keys parsed: ${keys.project}');
  print('Signature: ${keys.signature}');

  // 2. Parse Project with Keys/Password
  print('\nParsing project...');

  // NOTE: You must provide the correct Archive Password.
  // The Signature or Keys from .knxkeys are usually NOT the archive password.
  // Replace 'YOUR_PASSWORD' with the actual project password.
  try {
    print('Attempting to parse with Signature as password...');
    final project = await parser.parse(
      '../Secure_prj.knxproj',
      password: keys.signature, // Or use your password string
      knxKeys: keys,
    );
    print('SUCCESS! Project Parsed: ${project.projectInfo.name}');
  } catch (e) {
    print('Failed with signature: ${e.toString().split('\n').first}');
    print(
        'HINT: Encrypted projects require the specific password set during export (ETS).');
  }
}
