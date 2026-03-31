# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.12.1] - 2026-03-31

### Added
- **Group Address Topology Mapping**: Devices aren't the only elements that can be assigned to a room in ETS. Direct `GroupAddressRef` assignments mapped inside `<Space>` (Buildings/Floors/Rooms) are now correctly extracted.
  - `KnxGroupAddress` objects are newly enriched with `roomId`, `roomName`, and `locationPath` attributes.

## [1.12.0] - 2026-03-31

### Added
- **Complete ETS Device Information**: `KnxDevice` and `DeviceInstance` enriched with full topology and hardware info:
  - `manufacturerName`: Parsed from `knx_master.xml`.
  - `orderNumber` & `mediumType`: Parsed from `Hardware.xml`.
  - `applicationName` & `applicationVersion`: Parsed from `M-*-*.xml`, with version uniformly mapped to `0.x` representation.
  - `locationPath`: Auto-generated from `<Space>` tree hierarchy traversal (e.g., `Building > Floor > Room`).
- **Complete ETS Communication Objects**: `ComObjectInstanceRef` enriched with detailed flags and metadata:
  - `priority`, `readFlag`, `writeFlag`, `communicationFlag`, `transmitFlag`, and `updateFlag` from `ComObject` definition.
  - `datapointText` (e.g., `"switch"`, `"dimming"`): Translated gracefully using `knx_master.xml`'s `DatapointSubtype` mapping.
  - `channelName`: Expanded from application program XML (`<Channel>` elements).
  - `linkedGroupAddresses`: Provided as a list of `{address, name}` objects instead of just a raw string, for more flexible frontend rendering.
## [1.11.2] - 2026-03-30

### Fixed
- **Template placeholder cleanup**: ComObjectRef overrides containing ETS template placeholders (`{{ChNum}}`, `{{0:...}}`) are now skipped in favor of cleaner base ComObject values (e.g. `"Button 1"` instead of `"Button {{ChNum}} - {{0:...}}"}`).
## [1.11.1] - 2026-03-30

### Fixed
- **ComObject app program matching**: Use HP suffix from `Hardware2ProgramRefId` to match the exact application program for each device. Prevents cross-matching when multiple devices share the same manufacturer prefix (e.g. `O-1_R-1` matching wrong program).

## [1.11.0] - 2026-03-30

### Added
- **ComObject enrichment**: `ComObjectInstanceRef` is now enriched with data from application program XML (`M-*/M-*_A-*.xml`):
  - `name`, `description`, `number`, `functionText`, `objectSize`, `datapointType`
  - `readFlag`, `writeFlag`, `transmitFlag`, `updateFlag` (boolean flags)
  - `channelId` from project XML
  - `groupAddresses` — resolved GA links from raw IDs (e.g. `GA-1`) to formatted addresses (e.g. `0/0/1`)
- Support for module ComObjects (e.g. `MD-1_M-1_MI-1_O-2-1_R-1`) via automatic stripping of module instance prefix.
- `copyWithDefinition()` method on `ComObjectInstanceRef` for immutable enrichment.

## [1.10.2] - 2026-03-30

### Fixed
- Device name fallback: if user didn't set a name in ETS (`Name` attribute is null/empty), `productName` from catalog is used as fallback for `name` field.

## [1.10.1] - 2026-03-30

### Fixed
- **Device name preservation**: Product catalog merge (`copyWithProductCatalog`) no longer overwrites user-defined device names from ETS. Added separate `productName` field.
- Added `description` and `comment` fields to `DeviceInstance` and `KnxDevice`, parsed from XML attributes.
- Renamed `copyWithName()` to `copyWithProductName()` to clarify intent.

## [1.10.0] - 2026-03-17

### Added
- **Topology flat lists**: `KnxArea` and `KnxLine` classes with `areas` and `lines` lists in `KnxFlatProject`.
- **Building level**: `KnxBuilding` class for multi-building projects, with `buildings` list and `floorIds`.
- **Device-room mapping**: `KnxDevice` now includes `roomId`, `roomName`, `areaId`, `areaName`, `lineId`, `lineName`.
- **Rich cross-references**: `KnxDeviceRef` lightweight reference class used in `KnxRoom.devices` and `KnxGroupAddress.devices` (includes `formattedAddress` and `name`).
- **`fromJson()` on all models**: Full JSON deserialization support for `KnxFlatProject` and all nested classes, plus `ComObjectInstanceRef`, `DatapointType`, `DatapointSubtype`, `BackboneKey`, `GroupKey`, `DeviceKey`.
- **Device formatted address**: `KnxDevice.formattedAddress` in `area.line.device` format (e.g., `1.1.3`).
- **DPT format**: `datapointType` converted from `DPST-9-1` to `9.001` format.
- **GA-device mapping**: `KnxGroupAddress.devices` shows linked devices via comObject cross-reference.

### Changed
- `KnxFloor.parentId` renamed to `KnxFloor.buildingId`.
- `KnxRoom.deviceInstanceIds` replaced with `KnxRoom.devices` (`List<KnxDeviceRef>`).
- `KnxGroupAddress.deviceIds` replaced with `KnxGroupAddress.devices` (`List<KnxDeviceRef>`).

## [1.9.0] - 2026-03-17

### Added
- **Typed flat model**: New `KnxFlatProject` with typed classes (`KnxFloor`, `KnxRoom`, `KnxDevice`, `KnxGroupAddress`, `KnxGroupRange`, `KnxSecureKeys`, `KnxGaSecureKey`, `KnxDeviceToolKey`).
- `toFlat()` method on `KnxProject` returns typed `KnxFlatProject` instead of raw `Map`.
- `parseToFlat()` convenience method on `KnxProjectParser`.
- **GA-device mapping**: `KnxGroupAddress.deviceIds` shows which devices reference each group address via comObject links.
- **DPT format conversion**: `datapointType` in flat output now uses `x.yyy` format (e.g., `9.001`) instead of raw `DPST-x-y`.
- Exported `DeviceInstance` and `KnxFlatProject` models from library.

### Changed
- `toFlatJson()` now delegates to `toFlat().toJson()`.

## [1.8.0] - 2026-03-16

### Added
- **Flat JSON output format**: New `toFlatJson()` method on `KnxProject` produces an organized, flat JSON with separate lists for `floors`, `rooms`, `devices`, `groupAddresses`, `datapointTypes`, and `secureKeys`.
- **Device-to-room mapping**: `Location` model now includes `deviceInstanceIds` field, parsed from `DeviceInstanceRef` elements inside `Space` XML nodes.
- **Security detection**: `hasSecure` boolean in flat JSON output, auto-detected from GA keys and device security tool keys.
- `parseToFlatJson()` and `parseToFlatJsonFile()` convenience methods on `KnxProjectParser`.

### Changed
- `Location.fromXml()` now parses `DeviceInstanceRef` children.
- `Location.toJson()` includes `deviceInstanceIds` when non-empty.

## [1.7.1] - 2026-02-09

### Changed
- Downgraded dependencies for Flutter 3.7.12 (Dart 2.19) compatibility:
  - `archive: ^3.3.9`
  - `xml: ^6.3.0`
  - `pointycastle: ^3.7.3`
  - `lints: ^2.1.1`

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
