# Changelog

All notable changes to this gem are recorded here. Format: Keep a Changelog, versioning: SemVer.

## [Unreleased]

### Added
- LICENSE (LGPL-3.0-or-later, matching the gemspec).
- CI workflow, Rakefile and Rubocop config.
- Test support skeleton (`test/support/fake_platform.rb`) for two-platform specs.
- `docs/per-platform-analytics.md`: assessment of the 0.1.0 behavior and the per-platform design.

## [0.3.0]

### Added
- Cookie policy segment `:google_analytics` (category `analytics`) describing `_ga` and `_ga_<id>`, shown only for platforms with a measurement id, with a link to Google's privacy policy.
- Consent provider now returns the `analytics` category only for platforms that have a measurement id.
- Consent mode v2 reads the `bt_consent` cookie synchronously (policy version aware) so returning visitors who agreed are never sent as denied, and keeps reacting to `better_together:consent` for banner and settings-form changes.
- rspec suite using Community Engine's cookie policy shared examples (two platforms, host environment fallback).

### Changed
- The `consent_required` platform setting is removed: consent mode is applied whenever Community Engine provides the consent system. Stored values are ignored.
- Development dependencies moved to the Gemfile; Rubocop baseline is clean.

## [0.2.0]

- Per-platform Google Analytics: settings registered through `BetterTogether.register_platform_setting` (measurement id, anonymize IP, Do Not Track, staging, steward skip, consent mode v2 defaults).
- Consent mode v2 updates: the gem listens for CE's `better_together:consent` event and sends `gtag('consent','update')`, and tells CE's banner when consent is needed (`register_consent_provider`).
- `GTAG_ID` remains as a host-platform-only fallback, applied by CE's registry.
- Measurement ids are validated (`G-`, `GT-`, `GTM-`).
- Remove the inline `_custom_head_javascript` GA partial from host apps once this version is deployed.

## [0.1.0]

### Added
- Initial provider gem: registers `gtag.js` head tags and CSP sources, reads `GTAG_ID` from the environment.
