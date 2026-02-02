// Stub for dart:io when compiling for web (dart.library.html).
// On web, only parseBytes() should be used; parse()/parseToJsonFile() will throw.

import 'dart:typed_data';

class FileSystemEntity {
  String get path => '';
}

class File extends FileSystemEntity {
  File(this.path);
  @override
  final String path;
  Future<bool> exists() => Future.value(false);
  Future<Uint8List> readAsBytes() =>
      throw UnsupportedError('On web use KnxProjectParser().parseBytes(bytes)');
  Future<String> readAsString() =>
      throw UnsupportedError('On web use parseBytes()');
  Future<File> writeAsString(String contents) =>
      throw UnsupportedError('On web use browser download for JSON');
}

class Directory extends FileSystemEntity {
  Directory(this.path);
  @override
  final String path;
  Future<bool> exists() => Future.value(false);
  List<FileSystemEntity> listSync() => [];
}
