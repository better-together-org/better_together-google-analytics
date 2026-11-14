# Changelog

All notable changes to this gem are recorded here. Format: Keep a Changelog, versioning: SemVer.

## [Unreleased]

### Added
- LICENSE (LGPL-3.0-or-later, matching the gemspec).
- CI workflow, Rakefile and Rubocop config.
- Test support skeleton (`test/support/fake_platform.rb`) for two-platform specs.
- `docs/per-platform-analytics.md`: assessment of the 0.1.0 behavior and the per-platform design.

## [0.2.0]

- Per-platform Google Analytics: settings registered through `BetterTogether.register_platform_setting` (measurement id, anonymize IP, Do Not Track, staging, steward skip, consent mode v2 defaults).
- `GTAG_ID` remains as a host-platform-only fallback, applied by CE's registry.
- Measurement ids are validated (`G-`, `GT-`, `GTM-`).
- Remove the inline `_custom_head_javascript` GA partial from host apps once this version is deployed.

## [0.1.0]

### Added
- Initial provider gem: registers `gtag.js` head tags and CSP sources, reads `GTAG_ID` from the environment.
