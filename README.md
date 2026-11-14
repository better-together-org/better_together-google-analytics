# Better Together Google Analytics

Provider gem for adding Google Analytics 4 (`gtag.js`) support to Better Together host apps without duplicating inline head markup in each app.

The gem also listens for CE's generic `better_together:share` browser event so social-share analytics stay in the GA provider layer instead of CE core.

## Configuration

Requires a Community Engine version with `BetterTogether.register_platform_setting` (the platform Integrations tab). Each platform sets its own values there:

- Measurement ID (`G-`, `GT-` or `GTM-`). Blank turns analytics off for that platform.
- Anonymize IP addresses (on by default), respect Do Not Track, track staging hosts, skip platform stewards, wait for visitor consent (consent mode v2 defaults to denied).

`GTAG_ID` still works as a fallback for the host platform only, so existing apps keep working. Other platforms never inherit it. Google origins stay registered in the CSP allow-list, but no tag is emitted for a platform without an id.

After upgrading, remove any inline GA partial (`_custom_head_javascript`) from the host app so the tag is not sent twice.

## Development

```bash
bundle install
bundle exec rake test
bundle exec rubocop
```

Design notes are in `docs/per-platform-analytics.md`. Changes are recorded in `CHANGELOG.md`.

## License

LGPL-3.0-or-later, see `LICENSE`.
