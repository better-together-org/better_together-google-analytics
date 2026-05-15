# frozen_string_literal: true

require 'erb'
require 'json'

module BetterTogether
  module GoogleAnalytics
    module HeadTags
      module_function

      def render(view_context)
        gtag_id = ENV.fetch('GTAG_ID', '').to_s.strip
        return if gtag_id.empty?

        nonce = view_context.content_security_policy_nonce
        tags = []
        tags << view_context.javascript_include_tag(
          "https://www.googletagmanager.com/gtag/js?id=#{ERB::Util.url_encode(gtag_id)}",
          async: true,
          nonce:
        )
        tags << view_context.javascript_tag(bootstrap_js(gtag_id), nonce:)
        view_context.safe_join(tags, "\n")
      end

      def bootstrap_js(gtag_id)
        <<~JS
          window.GA_ID = #{gtag_id.to_json};
          window.dataLayer = window.dataLayer || [];
          function gtag(){dataLayer.push(arguments);}
          gtag('js', new Date());
          gtag('config', #{gtag_id.to_json});
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
