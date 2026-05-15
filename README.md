# Better Together Google Analytics

Provider gem for adding Google Analytics 4 (`gtag.js`) support to Better Together host apps without duplicating inline head markup in each app.

The gem also listens for CE's generic `better_together:share` browser event so social-share analytics stay in the GA provider layer instead of CE core.

## Configuration

Set `GTAG_ID` in the host app environment. When it is blank, the provider renders nothing.
