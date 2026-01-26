import 'dart:io';
import 'package:test/test.dart';
import 'package:knx_parser/knx_parser.dart';

void main() {
  group('KnxProjectParser', () {
    late KnxProjectParser parser;

    setUp(() {
      parser = KnxProjectParser();
    });

    test('parses ets6_free.knxproj successfully', () async {
      final testFile = '../ets6_free.knxproj';
      if (!File(testFile).existsSync()) {
        print('Test file not found, skipping...');
        return;
      }

      final project = await parser.parse(testFile);

      expect(project.projectInfo.name, equals('ets6_free'));
      expect(project.projectInfo.id, equals('P-0310'));
      expect(project.projectInfo.groupAddressStyle, equals('Free'));
      expect(project.projectInfo.guid, isNotNull);
    });

    test('extracts group addresses correctly', () async {
      final testFile = '../ets6_free.knxproj';
      if (!File(testFile).existsSync()) {
        print('Test file not found, skipping...');
        return;
      }

      final project = await parser.parse(testFile);
      final installation = project.installations.first;

      expect(installation.groupAddresses, isNotEmpty);

      // Check for expected addresses
      final fooAddress = installation.groupAddresses.firstWhere(
        (ga) => ga.name == 'foo',
        orElse: () => throw StateError('Address "foo" not found'),
      );
      expect(fooAddress.address, equals(1));
    });

    test('extracts topology correctly', () async {
      final testFile = '../ets6_free.knxproj';
      if (!File(testFile).existsSync()) {
        print('Test file not found, skipping...');
        return;
      }

      final project = await parser.parse(testFile);
      final installation = project.installations.first;

      expect(installation.topology.areas, isNotEmpty);
      expect(installation.topology.areas.first.lines, isNotEmpty);
    });

    test('exports to JSON correctly', () async {
      final testFile = '../ets6_free.knxproj';
      if (!File(testFile).existsSync()) {
        print('Test file not found, skipping...');
        return;
      }

      final json = await parser.parseToJson(testFile);

      expect(json, contains('"name": "ets6_free"'));
      expect(json, contains('"groupAddresses"'));
      expect(json, contains('"topology"'));
    });

    test('parses datapoint types from knx_master.xml', () async {
      final testFile = '../ets6_free.knxproj';
      if (!File(testFile).existsSync()) {
        print('Test file not found, skipping...');
        return;
      }

      final project = await parser.parse(testFile);

      expect(project.datapointTypes, isNotEmpty);

      // Check for common DPT-1 (Switch)
      final dpt1 = project.datapointTypes.firstWhere(
        (dpt) => dpt.id == 'DPT-1',
        orElse: () => throw StateError('DPT-1 not found'),
      );
      expect(dpt1.name, equals('1.xxx'));
      expect(dpt1.text, equals('1-bit'));
      expect(dpt1.sizeInBit, equals(1));
      expect(dpt1.subtypes, isNotEmpty);
    });
  });
}
