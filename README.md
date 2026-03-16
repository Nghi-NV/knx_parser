# KNX Parser

[![Dart](https://img.shields.io/badge/Dart-%3E%3D3.0.0-blue.svg)](https://dart.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![GitHub](https://img.shields.io/github/stars/Nghi-NV/knx_parser?style=social)](https://github.com/Nghi-NV/knx_parser)

A Dart library to parse KNX project files (`.knxproj`) from ETS6 and extract data to JSON format.

## Features

- 📦 Parse `.knxproj` files (ZIP-based XML format)
- 🏗️ Extract project information, topology, group addresses, and locations
- 🏠 Device-to-room mapping via `deviceInstanceIds` in locations
- 📊 Parse datapoint types (DPT) from knx_master.xml
- 💾 Export to structured JSON (nested or flat format)
- 🔒 Security detection (`hasSecure`) with GA keys and device tool keys
- 🔄 Support for hierarchical group ranges

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  knx_parser:
    git:
      url: https://github.com/Nghi-NV/knx_parser.git
      ref: main
```

Or clone locally:

```bash
git clone https://github.com/Nghi-NV/knx_parser.git
```

## Quick Start

```dart
import 'package:knx_parser/knx_parser.dart';

void main() async {
  final parser = KnxProjectParser();
  // Parse project (supports password for encrypted archives)
  final project = await parser.parse('path/to/project.knxproj', password: 'optional-password');
  
  print('Project: ${project.projectInfo.name}');
  print('Group Addresses: ${project.installations.first.groupAddresses.length}');
}
```

## Usage

### Parse and Access Data

```dart
final project = await parser.parse('project.knxproj');

// Project info
print(project.projectInfo.name);
print(project.projectInfo.guid);

// Installations
for (final installation in project.installations) {
  // Topology (Areas > Lines > Segments)
  for (final area in installation.topology.areas) {
    print('Area ${area.address}');
    for (final line in area.lines) {
      print('  Line ${line.address}');
      // Devices
      for (final device in line.devices) {
        print('    Device ${device.address}: ${device.productRefId}');
      }
    }
  }
  
  // Group Addresses
  for (final ga in installation.groupAddresses) {
    print('${ga.formattedAddress} - ${ga.name}');
  }
  
  // Locations with device mapping
  for (final loc in installation.locations) {
    print('${loc.type}: ${loc.name}');
    if (loc.deviceInstanceIds.isNotEmpty) {
      print('  Devices: ${loc.deviceInstanceIds}');
    }
  }
}

// Datapoint Types
for (final dpt in project.datapointTypes) {
  print('${dpt.id}: ${dpt.text}');
}
```

### Export to JSON

```dart
final parser = KnxProjectParser();

// Nested format (original)
final json = await parser.parseToJson('project.knxproj');
await parser.parseToJsonFile('project.knxproj', 'output.json');

// Flat format (organized sections)
final flatJson = await parser.parseToFlatJson('project.knxproj', password: '1');
await parser.parseToFlatJsonFile('project.knxproj', 'output_flat.json', password: '1');

// Or via model
final project = await parser.parse('project.knxproj', password: '1');
final flatMap = project.toFlatJson(); // Map<String, dynamic>
```

## JSON Output Formats

### Flat Format (`toFlatJson()`)

Organized, easy-to-consume format with separate lists:

```json
{
  "projectName": "Lumi Project",
  "projectId": "P-048F",
  "groupAddressStyle": "ThreeLevel",
  "lastModified": "2026-03-10T10:04:29Z",
  "etsVersion": "ETS6",
  "schemaVersion": 23,
  "hasSecure": true,
  "floors": [
    { "id": "...", "name": "Tầng 1", "roomIds": ["BP-4", "BP-5"] }
  ],
  "rooms": [
    { "id": "...", "name": "Phòng Khách", "floorId": "...", "deviceInstanceIds": ["DI-5"] }
  ],
  "devices": [
    { "id": "...", "address": 1, "name": "...", "comObjects": [...] }
  ],
  "groupAddresses": [
    { "id": "...", "address": 1, "formattedAddress": "0/0/1", "name": "GA1", "datapointType": "DPST-1-1", "key": "..." }
  ],
  "groupRanges": [...],
  "datapointTypes": [...],
  "secureKeys": {
    "gaKeys": [ { "gaId": "...", "formattedAddress": "0/0/1", "name": "GA1", "key": "..." } ],
    "deviceToolKeys": [ { "deviceId": "...", "toolKey": "..." } ]
  }
}
```

### Nested Format (`toJson()`)

Original hierarchical format:

```json
{
  "project": {
    "id": "P-0310",
    "name": "ets6_free",
    "groupAddressStyle": "Free",
    "lastModified": "2023-09-11T19:49:52.805Z",
    "guid": "4eb10284-c66c-42a0-9622-48adb78753a3"
  },
  "installations": [
    {
      "topology": { "areas": [...] },
      "groupAddresses": [...],
      "locations": [
        { "id": "...", "type": "Room", "name": "Phòng Khách", "deviceInstanceIds": ["DI-5"] }
      ]
    }
  ],
  "datapointTypes": [...]
}
```

## Running the Example

```bash
cd knx_parser
dart pub get
dart run example/parse_knxproj.dart path/to/your/project.knxproj
```

## Running Tests

```bash
dart test
```

## Supported KNX Data

| Element | Description |
|---------|-------------|
| **Project** | Project metadata (name, GUID, dates, ETS version) |
| **Topology** | Network structure (Areas, Lines, Segments) |
| **Devices** | Device instances with product names and comObjects |
| **GroupAddresses** | Group addresses with formatted display and DPT |
| **GroupRanges** | Hierarchical address groupings |
| **Locations** | Buildings, Floors, Rooms with `deviceInstanceIds` |
| **DatapointTypes** | DPT definitions (DPT-1 to DPT-275+) |
| **Security** | GA keys, device tool keys, backbone keys |

### Secure KNX Projects (ETS6)

The library supports parsing secure KNX projects (AES-encrypted `P-*.zip`) directly by providing the project password.

```dart
final project = await parser.parse(
  'secure_project.knxproj', 
  password: 'your-project-password'
);
```

The parser will:
1. Try to open the archive normally.
2. If encrypted, use the provided password to unlock the inner `P-*.zip`.
3. Extract all data including **Security Keys** (ToolKey, GroupAddress Key) and **Device Instances**.

## Contributing

Contributions are welcome! Please read our [Contributing Guide](CONTRIBUTING.md) first.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [KNX Association](https://www.knx.org/) for the KNX standard
- ETS6 for the project file format
