# frozen_string_literal: true

require 'erb'
require 'json'

module BetterTogether
  module GoogleAnalytics
    module HeadTags
      module_function

      ID_FORMAT = /\A(G|GT|GTM)-[A-Z0-9]{4,}\z/
      STAGING_HOST = /(\A|\.)(staging|stage|dev|test|localhost)(\.|\z)|\.local\z/

      def render(view_context)
        platform = current_platform(view_context)
        gtag_id = measurement_id(platform)
        return unless gtag_id && render_for?(view_context, platform)

        nonce = view_context.content_security_policy_nonce
        options = tag_options(platform).merge(policy_version: policy_version(view_context, platform))
        tags = []
        tags << view_context.javascript_include_tag(
          "https://www.googletagmanager.com/gtag/js?id=#{ERB::Util.url_encode(gtag_id)}",
          async: true,
          nonce:
        )
        tags << view_context.javascript_tag(bootstrap_js(gtag_id, **options), nonce:)
        view_context.safe_join(tags, "\n")
      end

      def current_platform(view_context)
        view_context.host_platform if view_context.respond_to?(:host_platform)
      end

      # The platform setting wins; the host-only GTAG_ID fallback is applied by CE's registry.
      def measurement_id(platform)
        value = platform_setting(platform, 'measurement_id')
        value = ENV.fetch('GTAG_ID', '') if value.nil? && platform.nil?
        value = value.to_s.strip.upcase
        value if ID_FORMAT.match?(value)
      end

      def platform_setting(platform, field)
        return unless platform.respond_to?(:integration_setting)

        platform.integration_setting("google_analytics.#{field}")
      end

      # Consent categories this gem needs on a platform: analytics when it has a measurement id,
      # nothing otherwise (so no banner appears for a platform that does not use Google Analytics).
      def consent_categories(platform)
        measurement_id(platform) ? :analytics : false
      end

      # Consent mode is on whenever CE's consent system exists, because the provider then asks
      # visitors; without that system nobody could ever grant, so tracking would stay denied.
      def consent_mode?
        BetterTogether.respond_to?(:register_consent_provider)
      end

      # The policy version the visitor's decision must match (same value CE writes into bt_consent).
      def policy_version(view_context, platform)
        return unless consent_mode?

        if view_context.respond_to?(:consent_policy_version)
          view_context.consent_policy_version(platform)
        elsif defined?(BetterTogether::Consent)
          BetterTogether::Consent.policy_version(platform)
        end
      end

      def flag(platform, field, default: false)
        value = platform_setting(platform, field)
        value.nil? ? default : value == true
      end

      def tag_options(platform)
        { anonymize_ip: flag(platform, 'anonymize_ip', default: true),
          respect_dnt: flag(platform, 'respect_dnt'),
          consent_required: consent_mode? }
      end

      def render_for?(view_context, platform)
        return false if staging?(view_context) && !flag(platform, 'enabled_on_staging')
        return false if flag(platform, 'skip_for_stewards') && steward?(view_context, platform)

        true
      end

      def staging?(view_context)
        host = view_context.respond_to?(:request) ? view_context.request&.host.to_s : ''
        STAGING_HOST.match?(host)
      end

      def steward?(view_context, platform)
        user = view_context.respond_to?(:current_user) ? view_context.current_user : nil
        user.respond_to?(:permitted_to?) && user.permitted_to?('manage_platform', platform)
      end

      # Consent mode v2: everything denied by default, then updated from the visitor's decision.
      # The decision is read synchronously from the bt_consent cookie (CE rewrites it from the
      # signed-in person's stored choice before rendering, and discards it when the policy version
      # changed), so a returning visitor who agreed never flashes a denied state. Later choices from
      # the banner or the settings form arrive as the better_together:consent event.
      def consent_js(policy_version = nil)
        <<~JS.strip
          gtag('consent', 'default', { ad_storage: 'denied', ad_user_data: 'denied', ad_personalization: 'denied', analytics_storage: 'denied', wait_for_update: 500 });
          (function() {
            var policyVersion = #{policy_version.to_json};
            function update(c) {
              c = c || {};
              gtag('consent', 'update', {
                analytics_storage: c.analytics ? 'granted' : 'denied',
                ad_storage: c.marketing ? 'granted' : 'denied',
                ad_user_data: c.marketing ? 'granted' : 'denied',
                ad_personalization: c.marketing ? 'granted' : 'denied'
              });
            }
            try {
              var match = document.cookie.match(/(?:^|; )bt_consent=([^;]*)/);
              var saved = match ? JSON.parse(decodeURIComponent(match[1])) : null;
              if (saved && saved.v === 1 && (!policyVersion || saved.pv === policyVersion)) update(saved);
            } catch (e) {}
            window.addEventListener('better_together:consent', function(event) { update(event && event.detail); });
            if (window.btConsent) update(window.btConsent);
          })();
        JS
      end

      def dnt_js(gtag_id)
        %(if (navigator.doNotTrack === "1" || window.doNotTrack === "1") { window["ga-disable-" + #{gtag_id.to_json}] = true; })
      end

      def bootstrap_js(gtag_id, anonymize_ip: true, respect_dnt: false, consent_required: false, policy_version: nil)
        config = { anonymize_ip: anonymize_ip }.to_json
        <<~JS
          window.GA_ID = #{gtag_id.to_json};
          window.dataLayer = window.dataLayer || [];
          function gtag(){dataLayer.push(arguments);}
          #{dnt_js(gtag_id) if respect_dnt}
          #{consent_js(policy_version) if consent_required}
          gtag('js', new Date());
          gtag('config', #{gtag_id.to_json}, #{config});
          window.addEventListener('better_together:share', function(event) {
            var detail = event && event.detail ? event.detail : {};
            var method = detail.platform;
            var itemId = detail.url;
            var itemTitle = detail.title;

            if (typeof window.gtag === 'function') {
              window.gtag('event', 'share', {
                method: method,
                content_type: 'article',
                item_id: itemId,
                item_title: itemTitle
              });
            } else if (typeof window.ga === 'function') {
              window.ga('send', 'event', 'Social Share', method, itemTitle);
            } else if (window.console && typeof window.console.warn === 'function') {
              window.console.warn('share_controller.ga_not_initialized');
            }
          });
        JS
      end
    end
  end
end
