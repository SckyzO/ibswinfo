# Changelog

All notable changes to this project will be documented in this file.

## [0.8] - 2026-01-14 (Forked Version)

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

## [0.7] - 2025-04-05
- Add support for MFT versions up to 4.31 (fixes #21).
- Add warning when running untested versions of MFT.
- Add temperature warning thresholds in default output.
- Add CPLD version in default and inventory outputs.
- Fix field parsing (#22).
- Rename "QSFP" to "module" in outputs, since different switches use different types of modules (OSFP on NDR switches).
- Fix fan speed value display.
- Fix fan enumeration on recent switches (fixes #17 and #19).

## [0.6] - 2022-11-17
- Add support for setting unmanaged switches' node description (fixes #4).

## [0.5] - 2022-05-31
- Add support for MFT 4.20 (fixes #11).

## [0.4] - 2021-12-07
- Fix potential quoting issue.
- MFT 4.18 is now the minimal MFT version, as MFT 4.16 and 4.17 had issues getting register values (#7, #9).

## [0.3] - 2020-05-15
- Fix an issue for OEM firmware that return indexed fields in random order.
- Fix an issue in determining the number ports.

## [0.2] - 2020-05-05
- Add support to address switches by LID, no `mst` service required.

## [0.1] - 2020-04-30
- Initial release.