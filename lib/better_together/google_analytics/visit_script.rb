# frozen_string_literal: true

require 'json'

module BetterTogether
  module GoogleAnalytics
    module VisitScript
      module_function

      SENSITIVE_PARAMS = %w[
        invitation_code token reset_password_token confirmation_token unlock_token access_token code state
      ].freeze

      # Page views are sent by hand so each visit can be checked against the page's
      # bt-third-party-tracking meta tag. This script stays loaded across Turbo visits, so the check
      # runs on every turbo:load, and measurement is switched off as soon as a visit starts, before
      # the browser history changes, so a private destination is never reported. Query parameters
      # that carry tokens are removed from the reported address.
      def render(gtag_id, respect_dnt)
        id = gtag_id.to_json
        <<~JS.strip
          (function() {
            var id = #{id}, sensitive = #{SENSITIVE_PARAMS.to_json}, last = null;
            var dnt = #{respect_dnt ? '(navigator.doNotTrack === "1" || window.doNotTrack === "1")' : 'false'};
            function allowed() {
              var meta = document.querySelector('meta[name="bt-third-party-tracking"]');
              return !meta || meta.getAttribute('content') !== 'off';
            }
            function location_without_secrets() {
              try {
                var url = new URL(window.location.href);
                sensitive.forEach(function(key) { url.searchParams.delete(key); });
                return url.toString();
              } catch (e) { return window.location.href; }
            }
            function visit() {
              var on = allowed();
              window["ga-disable-" + id] = dnt || !on;
              if (!on || dnt || last === window.location.href) return;
              last = window.location.href;
              gtag('event', 'page_view', { page_location: location_without_secrets(), page_title: document.title });
            }
            document.addEventListener('turbo:before-visit', function() { window["ga-disable-" + id] = true; });
            document.addEventListener('turbo:load', visit);
            if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', visit); else visit();
          })();
        JS
      end
    end
  end
end
