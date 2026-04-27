# Changelog

All notable changes to this project will be documented in this file.

## [0.8.1] - 2026-04-27

### Fixed
- **Graceful handling of unsupported registers on older firmware (#1, #6).** Switches whose firmware cannot serve some MFT registers (typically returning `-E- FW burnt on device does not support generic access register`) no longer cause the script to abort with `exit 1`. The script now warns on stderr and continues with empty data for the unavailable register; downstream parsing already tolerates missing values. Resolves the long-standing integration failure with `infiniband_exporter` where affected switches produced no metrics at all.
- **Dependency check uses correct MFT binary names (#2, #7).** The startup check now looks for `mlxreg_ext` (what the script actually calls) instead of the legacy `mlxreg`. Recent MFT releases ship `mlxreg_ext` only, so the previous check was a false positive. The unused `smpquery` dependency has also been removed.
- **JSON output now properly escapes special characters (#3, #8).** A new `json_escape()` helper neutralizes backslashes, double quotes, and standard control characters in every string value. Previously, a switch with a node description containing `"` or `\` produced invalid JSON that broke `jq`, Prometheus exporters, and any downstream parser.
- **Empty `-S` argument is rejected (#4, #9).** Running `ibswinfo -d <device> -S ""` no longer corrupts the node description: it left `node_description[0]` untouched while zeroing slots `[1]`..`[15]`. The empty case now fails fast with a clear error message.

### Added
- New test fixtures in `tests/dumps/`:
  - `ibsw_dump_LID6_Sequana3-IB400.txt`: real-hardware dump from a Bull/Atos Sequana3 chassis switch (PSID `BL_12002101`, MFT 4.32.0). First HDR400 OEM and chassis-managed fixture in the suite.
  - `ibsw_dump_LID42_FW-LIMITED.txt`: synthetic fixture for the unsupported-register error path (Issue #1).
  - `ibsw_dump_LID77_JSON-SPECIAL.txt`: synthetic fixture with `"` and `\` in `node_description` for JSON-safety testing (Issue #3).
- New explicit test assertions in `tests/run_tests.sh`: `[FW-burnt]`, `[JSON-safe]` (with `jq` / `python3` fallback), and `[empty -S]`.

### Changed
- `tests/bin/mlxreg_ext` mock: error blocks (`-E-`) are now correctly propagated to the caller. Previously, a bug in the mock's `awk` parser silently swallowed them, hiding the unsupported-register failure mode from the test suite.

### Hardware coverage
- **Tested** (real-hardware dumps in `tests/dumps/`): MQM8790 Quantum HDR, MQM9790 Quantum2 NDR, Sequana3 Unmng IB 400 (Bull/Atos OEM, HDR400, water-cooled chassis-integrated).

## [0.8] - 2026-01-14 (Forked Version)

### Added
- **Dashboard View:** New `-o dashboard` option providing a clean CLI dashboard with colored status blocks (██), progress bars, and grid layouts for fans/modules.
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