# Per-platform analytics: assessment and design

## Assessment of 0.1.0 (2026-11-13)

0.1.0 does not support per-platform Google Analytics.

- `HeadTags.render` reads `ENV.fetch('GTAG_ID')`, one value for the whole process. Every platform in a host app reports to the same property.
- With `GTAG_ID` blank it renders nothing, so a hosted platform cannot opt in alone.
- CSP origins are registered globally, loosening the policy for platforms that do not use GA.
- Gaps: no settings storage or admin UI, no id validation (`G-`, `GT-`, `GTM-`), no consent handling (PIPEDA, provincial rules, Google consent mode v2), no staging or steward gate, no Do Not Track or IP anonymize options, no cross-domain linking, no Rails dummy-app test, no release process.
- Good: the CE provider hook passes `view_context`, so the provider can resolve the current platform; CE already resolves per-platform CSP per request.

## Design (implemented in I4, after CE gains `register_platform_setting`)

1. The platform owns the setting; the gem consumes it. The gem registers `google_analytics.measurement_id` (validated), `anonymize_ip`, `respect_dnt`, `enabled_on_staging`, `skip_for_stewards` through `BetterTogether.register_platform_setting`; CE renders them on the platform form Integrations tab.
2. `HeadTags.render` uses the current platform's value. `GTAG_ID` stays as a fallback for the host platform only, so existing apps keep working.
3. Output is gated by the platform consent setting and by a staging rule tied to the platform's primary domain, so staging hosts do not pollute the live property.
4. Google origins are added to the platform's effective script, connect and img sources at request time only when an id is set.
5. Two-platform tests: different ids, none, env fallback for host only.
6. Release as 0.2.0; remove the inline `_custom_head_javascript` partial from host apps.


## Consent and cookie policy (0.3.0)

Consent is applied whenever CE's consent system exists, so the former `consent_required` setting was dropped. The provider and the cookie policy segment both depend on the platform having a measurement id.
