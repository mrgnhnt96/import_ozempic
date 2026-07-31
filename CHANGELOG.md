# CHANGELOG

## Unreleased

- Speed up analysis with a persistent on-disk analyzer cache (`.dart_tool/import_ozempic/analysis-cache/<version>`)
- Evict stale analysis caches and AOT binaries when the package version changes
- Fix Dart SDK discovery when running as an AOT binary (no longer treats `~/.import_ozempic` as the SDK)
- Defer full library resolution until after exclude / part-file filtering
- Skip generated files during directory walks by default (`*.g.dart`, `*.freezed.dart`, `*.mocks.dart`, `*.config.dart`)
- Resolve and rewrite libraries in parallel
- Auto-compile a native AOT binary on first CLI run (disable with `IOZ_NO_AOT=1`; force with `--recompile`)

## 0.0.20 | 6.2.26

- Add `sober` command to collapse granular package imports back to barrel exports (`package:name/name.dart`) when the barrel file exists on disk
- Refactor `fix` command to support granular and barrel import styles

## 0.0.19 | 3.23.26

- Fix doc comment references like `[Subclass.inheritedMethod]`: resolve the type written before the dot (the subclass) instead of the declaring superclass of the method

## 0.0.18 | 3.6.26

- Fix part file detection to skip comment lines between part directives, so parts after `// dart format on` (or similar) are no longer missed
- Prefer type alias over underlying class when collecting imports—use the alias the user wrote (e.g. `SegmentTabController`, `DioMediaType`) instead of the canonical type (`TabController`, `MediaType`), avoiding unused imports from constructor calls, static method calls, and type annotations

## 0.0.17 | 2.10.26

- Fix import parsing to correctly handle multi-line `show` and `hide` clauses that span multiple lines until the terminating semicolon
- Fix part file detection to use shared import-block logic, so parts are correctly found when imports use multi-line show/hide
- Support both single- and double-quoted paths in part directives

## 0.0.16 | 2.6.26

- Fixes issue where the update command would check for updates, after updating the package

## 0.0.15 | 2.3.26

- Fix issue where the fix command would hang when receiving more than 1 directories

## 0.0.14 | 1.29.26

- Fix issue where the last line of grouped comments at the start of the file would be lost

## 0.0.13 | 1.29.26

- Fix issue where duplicate import would be added if a constructor was used with an import prefix
- Fix issue where `library` statements were not being maintained when fixing imports
- Fix issue where `dart format on` comments were not being removed if whitespace (line breaks) were present

## 0.0.12 | 12.30.25

### Fixes

- Fixes issue where the script would fail because of an unwrapped directory pattern
  - Applies only to Linux and macOS

### Enhancements

- Add `loud` flag to print more verbose output

## 0.0.11 | 11.4.25

- Move analysis options file to a temporary location to prevent any paths from being excluded from analysis
- Add `restore` command to restore the analysis options file to its original location
  - This is only necessary if you ctrl-c the process while it is running

## 0.0.10 | 11.4.25

- Format files after fixing imports if `format` is true in the config
- Add ignore comments for types with `deprecated_member_use` annotations

## 0.0.9 | 11.4.25

- Fix bug where the stdout was not being logged

## 0.0.8 | 11.4.25

- Add `--version` flag to print the version of the package
- Add check for new versions of the package

## 0.0.7 | 11.4.25

- Add `update` command to update the package to the latest version

## 0.0.6 | 11.4.25

- Add `help` flag to commands
- Update usage messages

## 0.0.5 | 11.4.25

- Update README

## 0.0.2 | 11.4.25

- Initial release
