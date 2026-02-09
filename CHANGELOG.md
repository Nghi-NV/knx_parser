# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.7.0] - 2026-02-09

### Added
- **Device name parsing**: Device names are now extracted from Product catalog (`M-*/Hardware.xml`) and merged into `DeviceInstance` objects.
- `copyWithName()` method to `DeviceInstance`.
- `copyWithProductCatalog()` method to `Segment`, `Line`, `Area`, `Topology`, and `Installation` for immutable updates.

### Fixed
- Device name was previously always `null` because `DeviceInstance` XML elements don't contain `Name` attribute. Now correctly extracted from manufacturer's `Hardware.xml`.

## [1.6.0] - 2026-02-03

### Added
- **ETS version detection**: Added `etsVersion` ("ETS5" or "ETS6") and `schemaVersion` fields to `ProjectInfo` and JSON output.
- **ETS6 Segment device support**: Fixed parsing of `DeviceInstance` elements nested within `Segment` tags (ETS6 structure).

### Changed
- `Segment` class now includes a `devices` property to support ETS6 project structure.
- `Line.fromXml` now combines devices from both direct children (ETS5) and Segment children (ETS6).

## [1.5.0] - 2026-02-02

### Changed
- Improved handling of ETS5 outer .knxproj archives that are not password-protected while still supporting ETS6 outer-encrypted projects.
- Refined error messages and comments to be fully in English for cleaner public API diagnostics.

## [1.4.0] - 2026-02-02

### Added
- **Web support**: Library can be compiled for web (dart compile js). Use `parseBytes(List<int> bytes, ...)` in the browser; `parse(String filePath)` and file-based APIs remain VM-only via conditional import.
- `io_stub.dart` for web builds (stub for dart:io when `dart.library.html` is defined).

### Changed
- Parser uses conditional import `dart:io` / `io_stub` so the same code runs on VM and web.
- `File.exists` / `Directory.exists` usage aligned with dart:io API (getter, no parentheses).

## [1.3.0] - 2026-01-27

### Added
- **ETS6 encryption support**: Implements PBKDF2-HMAC-SHA256 password derivation for ETS6 encrypted projects.
- Auto-detection of ETS version based on schema version (ETS6 = schema >= 21).
- Support for both ETS5 (raw password) and ETS6 (derived password) encrypted projects.

### Dependencies
- Added `pointycastle: ^3.9.1` for PBKDF2 key derivation.
- Added `crypto: ^3.0.3` for cryptographic operations.

## [1.2.0] - 2026-01-26

### Added
- Support for parsing secure KNX projects (AES encrypted `P-*.zip` files) with password.
- Parsing of `DeviceInstance` elements in Topology.
- Parsing of `Security` keys (ToolKey) for devices.
- Parsing of `Key` for Group Addresses.
- Updated JSON export to include new device and security data.

## [1.0.0] - 2026-01-26
- Initial release
- Parse `.knxproj` files (ZIP-based XML format from ETS6)
- Extract project information (name, GUID, dates, style)
- Extract topology (Areas, Lines, Segments)
- Extract group addresses with formatted address support (e.g., 0/0/1)
- Extract group ranges with hierarchical structure
- Extract locations (Buildings, Spaces)
- Parse datapoint types (DPT) from knx_master.xml
- Export to structured JSON format
- Comprehensive unit tests
- Example usage script

### Dependencies
- `archive: ^3.6.1` - ZIP file handling
- `xml: ^6.5.0` - XML parsing
