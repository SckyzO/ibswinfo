# Changelog

All notable changes to this project will be documented in this file.

## [0.8] - 2026-01-14

### Added
- **Dashboard View:** New `-o dashboard` option providing a colorful and structured CLI dashboard with status indicators (🌡️, ⚡, 💨).
- **JSON Output:** New `-o json` option to export all switch data in a comprehensive JSON format for automation.
- **Version Flag:** New `-v` argument to display the script version.
- **CI/CD:** Automated testing workflow with ShellCheck and mock-based tests using real device dumps.
- **Mocking Infrastructure:** Robust testing system allowing regression testing against multiple switch firmware versions/models dumps.

### Changed
- **MFT Support:** Bumped maximum supported MFT version to 4.33.0.
- **Code Quality:** Extensive ShellCheck cleanup and refactoring for better robustness.
- **Translations:** Translated all code comments to English.

### Fixed
- Fixed potential regex issues in PSU parsing.
- Improved error handling for missing tools or devices.

## [0.7] - Pre-fork version
- Initial support for unmanaged switches (inventory, vitals, status).
- Node description setting.
