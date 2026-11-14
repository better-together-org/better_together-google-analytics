# Better Together Google Analytics

Provider gem for adding Google Analytics 4 (`gtag.js`) support to Better Together host apps without duplicating inline head markup in each app.

The gem also listens for CE's generic `better_together:share` browser event so social-share analytics stay in the GA provider layer instead of CE core.

## Configuration

Requires a Community Engine version with `BetterTogether.register_platform_setting` (the platform Integrations tab). Each platform sets its own values there:

- Measurement ID (`G-`, `GT-` or `GTM-`). Blank turns analytics off for that platform.
- Anonymize IP addresses (on by default), respect Do Not Track, track staging hosts, skip platform stewards.

`GTAG_ID` still works as a fallback for the host platform only, so existing apps keep working. Other platforms never inherit it. Google origins stay registered in the CSP allow-list, but no tag is emitted for a platform without an id.

## Consent and cookie policy

Needs a Community Engine with the consent system (`register_consent_provider`, `register_cookie_policy_segment`). The gem registers:

- A consent provider that asks for the `analytics` category only on platforms that have a measurement id. Platforms without one get no banner entry for Google Analytics.
- A cookie policy segment (category `analytics`) listing `_ga` and `_ga_<id>` (purpose, 2 years, provider Google, third party) with a link to Google's privacy page. It is shown only on platforms that have a measurement id (the host platform counts when `GTAG_ID` supplies one).
- Consent mode v2: `gtag('consent', 'default', denied)` first, then an `update` from the visitor's `bt_consent` cookie at page load (CE rewrites that cookie from a signed-in person's stored choice, and ignores it when the policy version changed), and again whenever the banner or the settings form fires `better_together:consent`. Withdrawing consent denies again without a reload. The old "wait for visitor consent" setting is gone: when consent is available it is always applied.

After upgrading, remove any inline GA partial (`_custom_head_javascript`) from the host app so the tag is not sent twice.

## Private pages are never measured

Needs a Community Engine with `third_party_tracking_allowed?` ([community-engine-rails#2237](https://github.com/better-together-org/community-engine-rails/pull/2237)). The gem renders nothing, and sends no page views, on pages Community Engine excludes: conversations and messages, notifications, settings and dashboards, sign-in and password flows, URLs that carry a token, error responses, non-public platforms and non-public records, plus any rule a host app registers with `BetterTogether.register_third_party_tracking_exclusion`.

Page views are sent by the gem, not by `gtag('config')`, so each Turbo visit is checked against the page's `bt-third-party-tracking` meta tag. Measurement is switched off the moment a visit starts and back on only when the new page allows it. Token query parameters (`invitation_code`, `token`, `reset_password_token` and similar) are removed from the reported address.

In Google Analytics, turn off **Enhanced measurement, Page changes based on browser history events**. The gem reports page views itself, and the browser Back button can still trigger Google's own history listener before the gem can switch it off. With older Community Engine versions the gem behaves as before (the check passes), apart from sending page views itself.

## Development

```bash
bundle exec rake test      # unit tests, no Community Engine needed
BETTER_TOGETHER_CE_LIB=/path/to/community-engine-rails/lib bundle exec rspec   # cookie policy specs
bundle exec rubocop
```

The rspec suite uses Community Engine's shared examples (`better_together/cookie_policy/rspec`) and skips when they are not on the load path.

Design notes are in `docs/per-platform-analytics.md`. Changes are recorded in `CHANGELOG.md`.

## License

LGPL-3.0-or-later, see `LICENSE`.
