import 'dart:io';
import 'package:knx_parser/knx_parser.dart';

/// Ví dụ: project có P-*.zip mã hóa AES (ETS6).
/// File .knxkeys bên ngoài không dùng để giải mã P-*.zip.
///
/// Cách xử lý: giải nén P-*.zip (lấy từ trong .knxproj) bằng ETS hoặc 7-Zip
/// (nhập mật khẩu ETS nếu có), lưu project.xml và 0.xml vào một thư mục,
/// rồi dùng parseFromExtractedDir(đường_dẫn).
void main() async {
  final parser = KnxProjectParser();
  const knxproj = '../knxprj_example.knxproj';
  const outputDir = 'output'; // thư mục chứa project.xml, 0.xml đã giải nén

  // Bước 1: Thử parse trực tiếp với password
  try {
    final project = await parser.parse(knxproj, password: '1');
    print('OK: ${project.projectInfo.name}');
    print('  Installations: ${project.installations.length}');

    // Xuất ra file JSON
    final jsonFile = await parser
        .parseToJsonFile(knxproj, '$outputDir/project.json', password: '1');
    print('  Saved JSON to: ${jsonFile.path}');
    // return; // Uncomment nếu muốn dừng khi thành công
  } catch (e) {
    print('Parse trực tiếp lỗi:');
    print('  ${e.toString().split("\n").first}');
  }

  // Bước 2: Parse từ thư mục đã giải nén
  if (await Directory(outputDir).exists()) {
    try {
      final project = await parser.parseFromExtractedDir(outputDir);
      print('\nOK parseFromExtractedDir: ${project.projectInfo.name}');
      print('  Installations: ${project.installations.length}');
      return;
    } catch (e) {
      print('\nparseFromExtractedDir($outputDir) lỗi: $e');
    }
  }

  print('\nHướng dẫn:');
  print('  1. Mở .knxproj bằng 7-Zip (hoặc ETS), tìm P-*.zip.');
  print('  2. Giải nén P-*.zip (nhập mật khẩu ETS nếu được hỏi) vào thư mục.');
  print(
      '  3. Đặt outputDir = đường dẫn thư mục đó (có project.xml, 0.xml) rồi chạy lại.');
  print('  Xem: docs/RESEARCH_KNXPROJ_SECURE.md');
}
