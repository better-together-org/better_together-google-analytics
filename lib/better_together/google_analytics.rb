# frozen_string_literal: true

require 'erb'

require 'better_together/google_analytics/version'
require 'better_together/google_analytics/head_tags'

module BetterTogether
  module GoogleAnalytics
    module_function

    def register!
      return unless BetterTogether.respond_to?(:register_head_tag_provider)
      return unless BetterTogether.respond_to?(:register_content_security_policy_sources)

      BetterTogether.register_head_tag_provider(:google_analytics) do |view_context|
        HeadTags.render(view_context)
      end
      BetterTogether.register_content_security_policy_sources(:script_src, 'https://www.googletagmanager.com')
      BetterTogether.register_content_security_policy_sources(
        :connect_src,
        'https://www.google-analytics.com',
        'https://region1.google-analytics.com'
      )
      BetterTogether.register_content_security_policy_sources(
        :img_src,
        'https://www.google-analytics.com',
        'https://region1.google-analytics.com'
      )
    end
  end
end

BetterTogether::GoogleAnalytics.register!
