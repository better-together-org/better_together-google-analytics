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
        options = tag_options(platform)
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

      def flag(platform, field, default: false)
        value = platform_setting(platform, field)
        value.nil? ? default : value == true
      end

      def tag_options(platform)
        { anonymize_ip: flag(platform, 'anonymize_ip', default: true),
          respect_dnt: flag(platform, 'respect_dnt'),
          consent_required: flag(platform, 'consent_required') }
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

      def dnt_js(gtag_id)
        %(if (navigator.doNotTrack === "1" || window.doNotTrack === "1") { window["ga-disable-" + #{gtag_id.to_json}] = true; })
      end

      def bootstrap_js(gtag_id, anonymize_ip: true, respect_dnt: false, consent_required: false)
        config = { anonymize_ip: anonymize_ip }.to_json
        <<~JS
          window.GA_ID = #{gtag_id.to_json};
          window.dataLayer = window.dataLayer || [];
          function gtag(){dataLayer.push(arguments);}
          #{dnt_js(gtag_id) if respect_dnt}
          #{"gtag('consent', 'default', { ad_storage: 'denied', ad_user_data: 'denied', ad_personalization: 'denied', analytics_storage: 'denied' });" if consent_required}
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
