# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-01-26

### Added
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
