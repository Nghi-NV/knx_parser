import 'package:knx_parser/knx_parser.dart';
import 'package:test/test.dart';

void main() {
  group('KnxKeys', () {
    const xmlContent = '''
<?xml version="1.0" encoding="utf-8"?>
<Keyring Project="test_Open_KNX_Stack" CreatedBy="6.2.2" Created="2026-01-24T07:01:45" Signature="DOa4GMgcJrpCtnysC2ybqw==" xmlns="http://knx.org/xml/keyring/1">
  <Backbone MulticastAddress="224.0.23.12" />
  <GroupAddresses>
    <Group Address="256" Key="EGcQm0uDPM780QdTrSOJsA==" />
    <Group Address="257" Key="GgCOERSw4/mb7fjZ28r06w==" />
  </GroupAddresses>
  <Devices>
    <Device IndividualAddress="1.1.3" ToolKey="9xVPHKYoIjRdK0jUE635og==" SequenceNumber="250247656046" FDSK="wKroEMcmPEG8ygV5yaFXoA==" SerialNumber="008555150365" />
  </Devices>
</Keyring>
''';

    test('should parse KnxKeys correctly', () {
      final parser = KnxProjectParser();
      final keys = parser.parseKeys(xmlContent);

      expect(keys.project, 'test_Open_KNX_Stack');
      expect(keys.signature, 'DOa4GMgcJrpCtnysC2ybqw==');
      expect(keys.xmlns, 'http://knx.org/xml/keyring/1');
      expect(keys.created.year, 2026);
    });

    test('should parse BackboneKey correctly', () {
      final parser = KnxProjectParser();
      final keys = parser.parseKeys(xmlContent);

      expect(keys.backboneKey, isNotNull);
      expect(keys.backboneKey!.multicastAddress, '224.0.23.12');
    });

    test('should parse GroupKeys correctly', () {
      final parser = KnxProjectParser();
      final keys = parser.parseKeys(xmlContent);

      expect(keys.groupKeys.length, 2);
      expect(keys.groupKeys[0].address, 256);
      expect(keys.groupKeys[0].key, 'EGcQm0uDPM780QdTrSOJsA==');
    });

    test('should parse DeviceKeys correctly', () {
      final parser = KnxProjectParser();
      final keys = parser.parseKeys(xmlContent);

      expect(keys.deviceKeys.length, 1);
      expect(keys.deviceKeys[0].individualAddress, '1.1.3');
      expect(keys.deviceKeys[0].toolKey, '9xVPHKYoIjRdK0jUE635og==');
      expect(keys.deviceKeys[0].fdsk, 'wKroEMcmPEG8ygV5yaFXoA==');
    });
  });
}
